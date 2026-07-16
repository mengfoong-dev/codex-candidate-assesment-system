// VibeProof proxy: keeps the Cohere key server-side for Sam and the workspace assistant.
// Node 18+ only; it deliberately has no SDK dependency because Chat V2 is a small HTTP contract.
import http from "node:http";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

export const DEFAULT_COHERE_MODEL = "command-a-plus-05-2026";
const COHERE_CHAT_URL = "https://api.cohere.com/v2/chat";

const SENIOR_PROMPT = [
  "You are Sam, a warm, encouraging senior on-call software engineer mentoring a newer",
  "engineer during a live incident. The incident: the homepage p95 latency jumped from",
  "180ms to 850ms right after a recent release. Your job is to help the player CLARIFY the",
  "task and their approach - never hand them the answer.",
  "Rules: reply in first person as Sam; keep it to 1-3 short sentences; be friendly and a",
  "little playful. Nudge them toward forming a hypothesis and reading the evidence at their",
  "desk (metrics, logs, request trace, orchestration source). If asked for the root cause,",
  "deflect with a guiding question instead of stating it. Stay in character.",
].join(" ");

const ASSISTANT_PROMPT = [
  "You are a general engineering copilot inside a candidate's incident-debugging workspace -",
  "like ChatGPT, but this session is recorded. The candidate is investigating why the",
  "homepage p95 latency rose from 180ms to 850ms after a release. Reason about any code,",
  "logs, or traces the candidate shares or asks about, exactly like a real assistant would.",
  "Be genuinely helpful and technical, but do NOT declare a single definitive root cause as",
  "settled fact and do NOT tell them exactly what to submit - guide their own reasoning:",
  "suggest what to check, discuss trade-offs (concurrency vs required ordering, partial-failure",
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
