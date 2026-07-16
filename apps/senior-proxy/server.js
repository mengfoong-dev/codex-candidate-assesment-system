// VibeProof proxy: keeps the Cohere key server-side for Sam and the workspace assistant.
// Node 18+ only; it deliberately has no SDK dependency because Chat V2 is a small HTTP contract.
import http from "node:http";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

export const DEFAULT_COHERE_MODEL = "command-a-plus-05-2026";
const COHERE_CHAT_URL = "https://api.cohere.com/v2/chat";

const SENIOR_PROMPT = [
  "You are Sam, a warm, encouraging senior on-call software engineer handing a live incident to",
  "a newer engineer. The incident: VibeTube's watch-page p95 latency jumped from 180ms to 850ms",
  "right after a recent release. Your job is to help them CLARIFY the task — never hand them the answer.",
  "You are a REALISTIC senior, which means you can be wrong: you have a plausible-but-UNVERIFIED",
  "gut feeling that it's probably the database, because a DB slowdown caused a similar incident",
  "last month. If they ask what you think, offer that hunch naturally — but make clear it's just",
  "your guess from memory, not confirmed. If they push back or cite evidence (CPU is fine, the DB",
  "looks healthy, the trace, the deploy changelog), acknowledge it and update; you are NOT attached",
  "to being right. Reveal concrete context only when asked a good question — e.g. if they ask what",
  "changed in the release, mention the team added a new recommendations call to the watch page; if",
  "they ask when it started or who's affected, give a plausible specific answer. Don't volunteer",
  "everything at once.",
  "Rules: reply in first person as Sam; 1-3 short sentences; friendly and a little playful. Nudge",
  "them to form their own view and read the evidence at their desk (metrics, server logs, request",
  "trace, source). If asked for THE root cause, deflect with a guiding question — finding it is",
  "their job. Stay in character.",
].join(" ");

const ASSISTANT_PROMPT = [
  "You are a general engineering copilot inside a candidate's incident-debugging workspace —",
  "like ChatGPT, but this session is recorded. The candidate is investigating why VibeTube's",
  "watch-page p95 latency rose from 180ms to 850ms after a release. Reason about any code,",
  "logs, or traces the candidate shares or asks about, exactly like a real assistant would.",
  "You are a normal, confident AI that can be SUBTLY WRONG: when you propose making the",
  "independent lookups concurrent (e.g. Promise.all), state it confidently AND slip in one",
  "over-confident assumption — assert there is no required ordering, so all the calls can simply",
  "run in parallel. Present that as obviously fine; do NOT flag it as uncertain. (In truth,",
  "authentication must finish first and rendering must happen last — a careful candidate catches",
  "this by reading the source/trace. You are not maliciously tricking them; you're just a",
  "confident assistant that can overreach.)",
  "Otherwise: do NOT declare a single settled root cause and do NOT tell them exactly what to",
  "submit — guide their reasoning, suggest what to check, discuss trade-offs (partial-failure",
  "handling, verification). Keep replies concise (2-5 sentences). You have no hidden answer key.",
].join(" ");

const ROUTES = {
  "/api/senior/chat": SENIOR_PROMPT,
  "/api/assistant/chat": ASSISTANT_PROMPT,
};

function runtimeConfig() {
  return {
    apiKey: process.env.COHERE_API_KEY || "",
    model: process.env.COHERE_MODEL || DEFAULT_COHERE_MODEL,
    port: Number(process.env.PORT || 8080),
    allowedOrigins: (process.env.ALLOWED_ORIGINS || "*").split(",").map((origin) => origin.trim()),
  };
}

function applyCors(res, origin, allowedOrigins) {
  const allow = allowedOrigins.includes("*") ? "*" : allowedOrigins.includes(origin) ? origin : allowedOrigins[0];
  res.setHeader("Access-Control-Allow-Origin", allow || "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

function sendJson(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
}

function normalizeMessages(messages, task) {
  const normalized = Array.isArray(messages) ? messages.slice(-14) : [];
  if (task) {
    normalized.unshift({ role: "user", content: `(Workspace context: ${String(task).slice(0, 4000)})` });
  }
  return normalized;
}

function cohereText(response) {
  const content = response?.message?.content;
  if (!Array.isArray(content)) return "";
  return content.find((part) => part?.type === "text" && typeof part.text === "string")?.text?.trim() || "";
}

async function callCohere(messages, systemPrompt, config) {
  if (!config.apiKey) throw new Error("COHERE_API_KEY is not set");
  const response = await fetch(COHERE_CHAT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${config.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: config.model,
      messages: [{ role: "system", content: systemPrompt }, ...messages],
      max_tokens: 300,
      temperature: 0.6,
    }),
  });
  if (!response.ok) throw new Error(`Cohere request failed (${response.status})`);
  return cohereText(await response.json());
}

/** Creates an unbound server so tests can exercise the public HTTP contract without credentials. */
export function createServer(config = runtimeConfig()) {
  return http.createServer((req, res) => {
    applyCors(res, req.headers.origin || "", config.allowedOrigins);
    if (req.method === "OPTIONS") return res.writeHead(204).end();
    if (req.method === "GET" && req.url === "/health") {
      return sendJson(res, 200, { ok: true, provider: "cohere", model: config.model, routes: Object.keys(ROUTES) });
    }

    const systemPrompt = req.method === "POST" ? ROUTES[req.url] : undefined;
    if (!systemPrompt) return sendJson(res, 404, { error: "not found" });

    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 120_000) req.destroy();
    });
    req.on("end", async () => {
      try {
        const parsed = body ? JSON.parse(body) : {};
        const messages = normalizeMessages(parsed.messages, parsed.task);
        if (messages.length === 0) return sendJson(res, 400, { error: "no messages" });
        const reply = await callCohere(messages, systemPrompt, config);
        return sendJson(res, 200, { reply });
      } catch (error) {
        // Do not log upstream bodies: provider errors can contain request metadata or credentials.
        console.error("chat error:", error instanceof Error ? error.message : "unknown error");
        return sendJson(res, 502, { error: "assistant is unavailable right now" });
      }
    });
  });
}

const isEntrypoint = process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (isEntrypoint) {
  const config = runtimeConfig();
  createServer(config).listen(config.port, () => {
    console.log(`vibeproof proxy on :${config.port} (provider=cohere, model=${config.model})`);
  });
}
