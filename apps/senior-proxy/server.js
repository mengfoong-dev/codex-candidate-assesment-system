// VibeProof proxy: keeps the API key server-side. Two roles behind one server:
//   POST /api/senior/chat     -> "Sam", the senior who briefs/clarifies the task (3D office)
//   POST /api/assistant/chat  -> the in-workspace engineering copilot ("ChatGPT but recorded")
// Zero dependencies — Node 18+ (global fetch). Run: npm start.
import http from "node:http";

const PROVIDER = (process.env.PROVIDER || "openai").toLowerCase();
const PORT = process.env.PORT || 8080;
const ALLOWED = (process.env.ALLOWED_ORIGINS || "*").split(",").map((s) => s.trim());
const MODEL = process.env.MODEL || (PROVIDER === "anthropic" ? "claude-sonnet-4-5" : "gpt-4o-mini");

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

function applyCors(res, origin) {
  const allow = ALLOWED.includes("*") ? "*" : ALLOWED.includes(origin) ? origin : ALLOWED[0];
  res.setHeader("Access-Control-Allow-Origin", allow || "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

async function callOpenAI(messages, systemPrompt) {
  const key = process.env.OPENAI_API_KEY;
  if (!key) throw new Error("OPENAI_API_KEY is not set");
  const r = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: MODEL,
      messages: [{ role: "system", content: systemPrompt }, ...messages],
      max_tokens: 300,
      temperature: 0.6,
    }),
  });
  if (!r.ok) throw new Error(`OpenAI ${r.status}: ${await r.text()}`);
  const data = await r.json();
  return (data.choices?.[0]?.message?.content || "").trim();
}

async function callAnthropic(messages, systemPrompt) {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY is not set");
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": key,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ model: MODEL, max_tokens: 300, system: systemPrompt, messages }),
  });
  if (!r.ok) throw new Error(`Anthropic ${r.status}: ${await r.text()}`);
  const data = await r.json();
  return (data.content?.[0]?.text || "").trim();
}

function sendJson(res, status, obj) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(obj));
}

const ROUTES = {
  "/api/senior/chat": SENIOR_PROMPT,
  "/api/assistant/chat": ASSISTANT_PROMPT,
};

const server = http.createServer((req, res) => {
  applyCors(res, req.headers.origin || "");
  if (req.method === "OPTIONS") return res.writeHead(204).end();
  if (req.method === "GET" && req.url === "/health") {
    return sendJson(res, 200, { ok: true, provider: PROVIDER, model: MODEL, routes: Object.keys(ROUTES) });
  }
  const systemPrompt = req.method === "POST" ? ROUTES[req.url] : undefined;
  if (systemPrompt) {
    let body = "";
    req.on("data", (c) => {
      body += c;
      if (body.length > 120_000) req.destroy();
    });
    req.on("end", async () => {
      try {
        const parsed = body ? JSON.parse(body) : {};
        const messages = Array.isArray(parsed.messages) ? parsed.messages.slice(-14) : [];
        if (parsed.task) {
          messages.unshift({ role: "user", content: `(Workspace context: ${String(parsed.task).slice(0, 4000)})` });
        }
        if (messages.length === 0) return sendJson(res, 400, { error: "no messages" });
        const reply = PROVIDER === "anthropic"
          ? await callAnthropic(messages, systemPrompt)
          : await callOpenAI(messages, systemPrompt);
        sendJson(res, 200, { reply });
      } catch (e) {
        console.error("chat error:", e?.message || e);
        sendJson(res, 502, { error: "assistant is unavailable right now" });
      }
    });
    return;
  }
  sendJson(res, 404, { error: "not found" });
});

server.listen(PORT, () => {
  console.log(`vibeproof proxy on :${PORT} (provider=${PROVIDER}, model=${MODEL})`);
});
