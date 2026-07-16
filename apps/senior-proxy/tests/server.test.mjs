import assert from "node:assert/strict";
import http from "node:http";
import test from "node:test";

import { createServer } from "../server.js";

function requestJson(server, path, body) {
  return new Promise((resolve, reject) => {
    const address = server.address();
    const request = http.request(
      {
        host: "127.0.0.1",
        port: address.port,
        path,
        method: "POST",
        headers: { "Content-Type": "application/json" },
      },
      (response) => {
        let raw = "";
        response.on("data", (chunk) => { raw += chunk; });
        response.on("end", () => resolve({ status: response.statusCode, body: JSON.parse(raw) }));
      },
    );
    request.on("error", reject);
    request.end(JSON.stringify(body));
  });
}

async function withServer(run) {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  try {
    await run(server);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
  }
}

test("senior chat sends Cohere V2 auth, model, and system message", async () => {
  const originalFetch = globalThis.fetch;
  const captured = [];
  process.env.COHERE_API_KEY = "cohere-test-key";
  process.env.COHERE_MODEL = "command-a-plus-05-2026";
  globalThis.fetch = async (url, options) => {
    captured.push({ url, options });
    return new Response(JSON.stringify({ message: { content: [{ type: "text", text: "Start with the trace." }] } }), { status: 200 });
  };

  try {
    await withServer(async (server) => {
      const response = await requestJson(server, "/api/senior/chat", {
        task: "Investigate homepage latency",
        messages: [{ role: "user", content: "Where should I begin?" }],
      });
      assert.equal(response.status, 200);
      assert.equal(response.body.reply, "Start with the trace.");
    });
  } finally {
    globalThis.fetch = originalFetch;
    delete process.env.COHERE_API_KEY;
    delete process.env.COHERE_MODEL;
  }

  assert.equal(captured.length, 1);
  assert.equal(captured[0].url, "https://api.cohere.com/v2/chat");
  assert.equal(captured[0].options.headers.Authorization, "Bearer cohere-test-key");
  const payload = JSON.parse(captured[0].options.body);
  assert.equal(payload.model, "command-a-plus-05-2026");
  assert.equal(payload.messages[0].role, "system");
  assert.match(payload.messages[0].content, /You are Sam/);
  assert.match(payload.messages[1].content, /Workspace context/);
});

test("proxy health reports Cohere and provider errors never expose upstream detail", async () => {
  const originalFetch = globalThis.fetch;
  process.env.COHERE_API_KEY = "cohere-test-key";
  globalThis.fetch = async () => new Response("upstream credential: do-not-expose", { status: 401 });

  try {
    await withServer(async (server) => {
      const address = server.address();
      const health = await new Promise((resolve, reject) => {
        http.get({ host: "127.0.0.1", port: address.port, path: "/health" }, (response) => {
          let raw = "";
          response.on("data", (chunk) => { raw += chunk; });
          response.on("end", () => resolve({ status: response.statusCode, body: JSON.parse(raw) }));
        }).on("error", reject);
      });
      assert.equal(health.body.provider, "cohere");
      assert.equal(health.body.model, "command-a-plus-05-2026");

      const response = await requestJson(server, "/api/assistant/chat", {
        messages: [{ role: "user", content: "Help me investigate." }],
      });
      assert.equal(response.status, 502);
      assert.deepEqual(response.body, { error: "assistant is unavailable right now" });
    });
  } finally {
    globalThis.fetch = originalFetch;
    delete process.env.COHERE_API_KEY;
  }
});
