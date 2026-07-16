// Senior NPC proxy: keeps the API key server-side and gives the 3D office "senior"
// a live LLM voice. Zero dependencies — Node 18+ (global fetch). Run: npm start.
import http from "node:http";

const PROVIDER = (process.env.PROVIDER || "openai").toLowerCase();
const PORT = process.env.PORT || 8080;
const ALLOWED = (process.env.ALLOWED_ORIGINS || "*").split(",").map((s) => s.trim());
const MODEL = process.env.MODEL || (PROVIDER === "anthropic" ? "claude-sonnet-4-5" : "gpt-4o-mini");

const SYSTEM_PROMPT = [
  "You are Sam, a warm, encouraging senior on-call software engineer mentoring a newer",
  "engineer during a live incident. The incident: the homepage p95 latency jumped from",
  "180ms to 850ms right after a recent release. Your job is to help the player CLARIFY the",
  "task and their approach — never hand them the answer.",
  "Rules: reply in first person as Sam; keep it to 1-3 short sentences; be friendly and a",
  "little playful. Nudge them toward forming a hypothesis and reading the evidence at their",
  "desk (metrics, logs, request trace, orchestration source). If asked for the root cause,",
  "deflect with a guiding question instead of stating it. Stay in character.",
].join(" ");

function applyCors(res, origin) {
  const allow = ALLOWED.includes("*") ? "*" : ALLOWED.includes(origin) ? origin : ALLOWED[0];
  res.setHeader("Access-Control-Allow-Origin", allow || "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

async function callOpenAI(messages) {
  const key = process.env.OPENAI_API_KEY;
  if (!key) throw new Error("OPENAI_API_KEY is not set");
  const r = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: MODEL,
      messages: [{ role: "system", content: SYSTEM_PROMPT }, ...messages],
      max_tokens: 250,
      temperature: 0.7,
    }),
  });
  if (!r.ok) throw new Error(`OpenAI ${r.status}: ${await r.text()}`);
  const data = await r.json();
  return (data.choices?.[0]?.message?.content || "").trim();
}

async function callAnthropic(messages) {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY is not set");
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": key,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ model: MODEL, max_tokens: 250, system: SYSTEM_PROMPT, messages }),
  });
  if (!r.ok) throw new Error(`Anthropic ${r.status}: ${await r.text()}`);
  const data = await r.json();
  return (data.content?.[0]?.text || "").trim();
}

function sendJson(res, status, obj) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(obj));
}

const server = http.createServer((req, res) => {
  applyCors(res, req.headers.origin || "");
  if (req.method === "OPTIONS") return res.writeHead(204).end();
  if (req.method === "GET" && req.url === "/health") {
    return sendJson(res, 200, { ok: true, provider: PROVIDER, model: MODEL });
  }
  if (req.method === "POST" && req.url === "/api/senior/chat") {
    let body = "";
    req.on("data", (c) => {
      body += c;
      if (body.length > 100_000) req.destroy();
    });
    req.on("end", async () => {
      try {
        const parsed = body ? JSON.parse(body) : {};
        const messages = Array.isArray(parsed.messages) ? parsed.messages.slice(-12) : [];
        if (parsed.task) {
          messages.unshift({ role: "user", content: `(Task context: ${String(parsed.task).slice(0, 2000)})` });
        }
        if (messages.length === 0) return sendJson(res, 400, { error: "no messages" });
        const reply = PROVIDER === "anthropic" ? await callAnthropic(messages) : await callOpenAI(messages);
        sendJson(res, 200, { reply });
      } catch (e) {
        // Never leak the key or a stack trace to the client.
        console.error("chat error:", e?.message || e);
        sendJson(res, 502, { error: "senior is unavailable right now" });
      }
    });
    return;
  }
  sendJson(res, 404, { error: "not found" });
});

server.listen(PORT, () => {
  console.log(`senior-proxy listening on :${PORT} (provider=${PROVIDER}, model=${MODEL})`);
});
