// VibeProof proxy: keeps the API key server-side. Two roles behind one server:
//   POST /api/senior/chat     -> "Sam", the senior who briefs/clarifies the task (3D office)
//   POST /api/assistant/chat  -> the in-workspace engineering copilot ("ChatGPT but recorded")
// Zero dependencies — Node 18+ (global fetch). Run: npm start.
import http from "node:http";
import { randomUUID } from "node:crypto";
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  const raw = fs.readFileSync(filePath, "utf8");
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const equals = trimmed.indexOf("=");
    if (equals <= 0) continue;
    const key = trimmed.slice(0, equals).trim();
    let value = trimmed.slice(equals + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!process.env[key]) process.env[key] = value;
  }
}

const thisDir = path.dirname(fileURLToPath(import.meta.url));
loadEnvFile(path.resolve(process.cwd(), ".env"));
loadEnvFile(path.resolve(process.cwd(), "apps/senior-proxy/.env"));
loadEnvFile(path.resolve(thisDir, ".env"));

const PROVIDER = (process.env.PROVIDER || "openai").toLowerCase();
const PORT = process.env.PORT || 18080;
const ALLOWED = (process.env.ALLOWED_ORIGINS || "*").split(",").map((s) => s.trim());
const DEFAULT_MODELS = {
  anthropic: "claude-sonnet-4-5",
  deepseek: "deepseek-v4-flash",
  openai: "gpt-4o-mini",
};
const MODEL = process.env.MODEL || DEFAULT_MODELS[PROVIDER] || DEFAULT_MODELS.openai;
const TEST_RUNNER_IMAGE = process.env.TEST_RUNNER_IMAGE || "vibeproof-code-runner:latest";
const TEST_TIMEOUT_MS = Number(process.env.TEST_TIMEOUT_MS || 10_000);
const MAX_TEST_SOURCE_BYTES = 30_000;
const MAX_TEST_OUTPUT_BYTES = 64_000;

const SENIOR_PROMPT = [
  "You are Sam, a warm, encouraging senior on-call software engineer mentoring a newer",
  "engineer during a live incident. The incident: the homepage p95 latency jumped from",
  "180ms to 850ms right after a recent release. Your job is to help the player CLARIFY the",
  "task and their approach — never hand them the answer.",
  "Rules: reply in first person as Sam; keep it to 1-3 short sentences; be friendly and a",
  "little playful. Nudge them toward forming a hypothesis and reading the evidence at their",
  "desk (metrics, logs, request trace, orchestration source). If asked for the root cause,",
  "deflect with a guiding question instead of stating it. Stay in character.",
].join(" ");

const ASSISTANT_PROMPT = [
  "You are a general engineering copilot inside a candidate's incident-debugging workspace —",
  "like ChatGPT, but this session is recorded. The candidate is investigating why the",
  "homepage p95 latency rose from 180ms to 850ms after a release. Reason about any code,",
  "logs, or traces the candidate shares or asks about, exactly like a real assistant would.",
  "Be genuinely helpful and technical, but do NOT declare a single definitive root cause as",
  "settled fact and do NOT tell them exactly what to submit — guide their own reasoning:",
  "suggest what to check, discuss trade-offs (concurrency vs required ordering, partial-failure",
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

async function callDeepSeek(messages, systemPrompt) {
  const key = process.env.DEEPSEEK_API_KEY;
  if (!key) throw new Error("DEEPSEEK_API_KEY is not set");
  const r = await fetch("https://api.deepseek.com/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [{ role: "system", content: systemPrompt }, ...messages],
      thinking: { type: "disabled" },
      max_tokens: 600,
    }),
  });
  if (!r.ok) throw new Error(`DeepSeek ${r.status}: ${await r.text()}`);
  const data = await r.json();
  return (data.choices?.[0]?.message?.content || "").trim();
}

async function callProvider(messages, systemPrompt) {
  if (PROVIDER === "anthropic") return callAnthropic(messages, systemPrompt);
  if (PROVIDER === "deepseek") return callDeepSeek(messages, systemPrompt);
  if (PROVIDER === "openai") return callOpenAI(messages, systemPrompt);
  throw new Error(`Unsupported PROVIDER: ${PROVIDER}`);
}

function runSandboxedTests(source) {
  return new Promise((resolve, reject) => {
    const containerName = `vibeproof-test-${randomUUID()}`;
    const args = [
      "run",
      "--rm",
      "--name", containerName,
      "-i",
      "--network", "none",
      "--memory", "256m",
      "--cpus", "0.5",
      "--pids-limit", "64",
      "--read-only",
      "--tmpfs", "/tmp:rw,noexec,nosuid,size=32m",
      "--cap-drop", "ALL",
      "--security-opt", "no-new-privileges",
      TEST_RUNNER_IMAGE,
    ];
    const startedAt = Date.now();
    const child = spawn("docker", args, { windowsHide: true, stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    let finished = false;

    const finish = (fn) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      fn();
    };
    const stopContainer = () => {
      const cleanup = spawn("docker", ["rm", "-f", containerName], {
        windowsHide: true,
        stdio: "ignore",
      });
      cleanup.unref();
    };
    const appendOutput = (current, chunk) => {
      const next = current + chunk.toString("utf8");
      if (Buffer.byteLength(next, "utf8") > MAX_TEST_OUTPUT_BYTES) {
        stopContainer();
        finish(() => reject(new Error("Test output exceeded 64 KB")));
      }
      return next;
    };
    const timer = setTimeout(() => {
      stopContainer();
      finish(() => reject(new Error(`Test run exceeded ${TEST_TIMEOUT_MS} ms`)));
    }, TEST_TIMEOUT_MS);

    child.stdout.on("data", (chunk) => {
      stdout = appendOutput(stdout, chunk);
    });
    child.stderr.on("data", (chunk) => {
      stderr = appendOutput(stderr, chunk);
    });
    child.on("error", (error) => finish(() => reject(error)));
    child.on("close", (exitCode) => {
      finish(() => {
        try {
          const parsed = JSON.parse(stdout.trim());
          resolve({
            ...parsed,
            exit_code: Number.isInteger(exitCode) ? exitCode : parsed.exit_code,
            duration_ms: Date.now() - startedAt,
            stderr: stderr.slice(0, MAX_TEST_OUTPUT_BYTES),
          });
        } catch {
          reject(new Error(`Runner returned invalid output: ${stderr || stdout}`));
        }
      });
    });
    child.stdin.on("error", () => {});
    child.stdin.end(source);
  });
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
    return sendJson(res, 200, {
      ok: true,
      provider: PROVIDER,
      model: MODEL,
      test_runner_image: TEST_RUNNER_IMAGE,
      routes: [...Object.keys(ROUTES), "/api/assistant/test"],
    });
  }
  if (req.method === "POST" && req.url === "/api/assistant/test") {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (Buffer.byteLength(body, "utf8") > MAX_TEST_SOURCE_BYTES * 2) req.destroy();
    });
    req.on("end", async () => {
      try {
        const parsed = body ? JSON.parse(body) : {};
        const source = typeof parsed.code === "string" ? parsed.code : "";
        if (!source.trim()) return sendJson(res, 400, { error: "code is required" });
        if (Buffer.byteLength(source, "utf8") > MAX_TEST_SOURCE_BYTES) {
          return sendJson(res, 413, { error: "code exceeds 30 KB" });
        }
        sendJson(res, 200, await runSandboxedTests(source));
      } catch (error) {
        console.error("test runner error:", error?.message || error);
        sendJson(res, 503, { error: "sandboxed test runner is unavailable" });
      }
    });
    return;
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
        const reply = await callProvider(messages, systemPrompt);
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

server.on("error", (error) => {
  if (error.code === "EADDRINUSE") {
    console.error(`Port ${PORT} is already in use. Set PORT to a free value, for example PORT=18080.`);
    process.exit(1);
  }
  console.error(error);
  process.exit(1);
});

server.listen(PORT, () => {
  console.log(`vibeproof proxy on :${PORT} (provider=${PROVIDER}, model=${MODEL})`);
});
