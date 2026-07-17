import http from "node:http";
import { randomUUID } from "node:crypto";
import { spawn } from "node:child_process";

const PORT = process.env.PORT || 18080;
const ALLOWED = (process.env.ALLOWED_ORIGINS || "*").split(",").map((s) => s.trim());
const TEST_RUNNER_IMAGE = process.env.TEST_RUNNER_IMAGE || "vibeproof-code-runner:latest";
const TEST_TIMEOUT_MS = Number(process.env.TEST_TIMEOUT_MS || 10_000);
const MAX_TEST_SOURCE_BYTES = 30_000;
const MAX_TEST_OUTPUT_BYTES = 64_000;

function applyCors(res, origin) {
  const allow = ALLOWED.includes("*") ? "*" : ALLOWED.includes(origin) ? origin : ALLOWED[0];
  res.setHeader("Access-Control-Allow-Origin", allow || "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

function sendJson(res, status, obj) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(obj));
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

const server = http.createServer((req, res) => {
  applyCors(res, req.headers.origin || "");
  if (req.method === "OPTIONS") return res.writeHead(204).end();
  if (req.method === "GET" && req.url === "/health") {
    return sendJson(res, 200, {
      ok: true,
      service: "vibeproof-sandbox-proxy",
      test_runner_image: TEST_RUNNER_IMAGE,
      routes: ["/api/assistant/test"],
    });
  }
  if (req.method !== "POST" || req.url !== "/api/assistant/test") {
    return sendJson(res, 404, { error: "not found" });
  }

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
  console.log(`vibeproof sandbox proxy on :${PORT}`);
});
