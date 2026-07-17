# Senior NPC proxy

A tiny zero-dependency Node server that gives the 3D office **senior** NPC a live LLM voice
without ever exposing an API key to the game client. The Godot game POSTs the conversation
here; this server adds the senior's system prompt, calls the model with a **server-side** key,
and returns the reply.

## 1. Add your key (local)

The real key lives in `.env`, which is **gitignored** — it is never committed.

```powershell
cd apps/senior-proxy
Copy-Item .env.example .env   # if .env doesn't exist yet
```

Open `.env` and paste your key:

```
PROVIDER=openai
OPENAI_API_KEY=sk-...your key...
```

(For Claude instead: set `PROVIDER=anthropic` and `ANTHROPIC_API_KEY=sk-ant-...`.)

For DeepSeek's code assistant:

```text
PROVIDER=deepseek
DEEPSEEK_API_KEY=your-key
MODEL=deepseek-v4-flash
```

## 2. Run it locally

The senior proxy is still the LLM chat service. It is separate from the local Docker sandbox.

For local sandbox tests, run the code-runner Compose service from the repository root:

```powershell
docker compose up --build sandbox-proxy
```

The game can keep using the deployed senior proxy for chat:

```text
https://senior-proxy-production-82cf.up.railway.app/api/senior/chat
https://senior-proxy-production-82cf.up.railway.app/api/assistant/chat
```

Set the in-game test runner URL to:

```text
http://localhost:18080/api/assistant/test
```

The browser/game never talks to Docker directly; it only talks to the sandbox proxy. The sandbox
proxy creates a fresh no-network worker container for each test run. For local development, it
mounts the host Docker socket so it can create those workers; do not expose that socket over the
network.

No LLM key is required for the sandbox test endpoint. LLM provider variables are only needed when
you want `/api/senior/chat` or `/api/assistant/chat` to call a live model.

If `18080` is also occupied, choose any free host port without changing the container:

```powershell
$env:SANDBOX_PROXY_PORT=18180
docker compose up --build sandbox-proxy
```

Then point the test runner URL at `http://localhost:18180/api/assistant/test`.

To run the proxy without Compose:

```powershell
cd apps/senior-proxy
node server.js
```

Check it's up (no key needed for this):

```powershell
curl http://localhost:18080/health
# {"ok":true,"provider":"openai","model":"gpt-4o-mini"}
```

Try a real reply (needs your key in `.env`):

```powershell
curl -X POST http://localhost:18080/api/senior/chat -H "Content-Type: application/json" -d '{"messages":[{"role":"user","content":"where should I start?"}]}'
```

## 3. Deploy to Railway (to make it live for the deployed game)

Create a new service and set the key as a Railway **variable** (not a file):

```powershell
railway add --service senior-proxy
railway variables --service senior-proxy --set PROVIDER=openai --set OPENAI_API_KEY=sk-...
railway up apps/senior-proxy --service senior-proxy --ci
```

Then point the game at the service URL and lock CORS to the game's origin:

```powershell
railway variables --service senior-proxy --set ALLOWED_ORIGINS=https://vibeproof-web-production.up.railway.app
```

## Endpoints

- `GET /health` → `{ ok, provider, model }`
- `POST /api/senior/chat` → body `{ "messages": [{"role","content"}], "task": "optional context" }` → `{ "reply": "..." }`
- `POST /api/assistant/chat` → same body and response shape, for the in-workspace code assistant
- `POST /api/assistant/test` → body `{ "code": "..." }` → isolated scenario test result

## Sandboxed tests

Compose builds the worker image automatically. If you are running without Compose, build the
worker image on the same machine that runs this proxy:

```powershell
docker build -t vibeproof-code-runner:latest apps/code-runner
```

Set `TEST_RUNNER_IMAGE=vibeproof-code-runner:latest` and run the proxy on a free port, for example
`PORT=18080`. In the in-game Codex terminal, enter `test` or `npm test`; the proxy creates a fresh
restricted container and returns the hidden-test results. See [`../code-runner/README.md`](../code-runner/README.md)
for remote-machine deployment.

Important: the Docker image is not the always-running service. The always-running service is this
Node proxy. The Docker containers are short-lived workers created only while a test request is being
handled.

## Boundary

This proxy only powers the senior's *task-clarification* roleplay. It does not score the
candidate, persist data, or make any hiring decision — that stays in the game's unscored flow.
