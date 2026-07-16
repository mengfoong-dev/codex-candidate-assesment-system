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

## 2. Run it locally

```powershell
cd apps/senior-proxy
node server.js
```

Check it's up (no key needed for this):

```powershell
curl http://localhost:8080/health
# {"ok":true,"provider":"openai","model":"gpt-4o-mini"}
```

Try a real reply (needs your key in `.env`):

```powershell
curl -X POST http://localhost:8080/api/senior/chat -H "Content-Type: application/json" -d '{"messages":[{"role":"user","content":"where should I start?"}]}'
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

## Boundary

This proxy only powers the senior's *task-clarification* roleplay. It does not score the
candidate, persist data, or make any hiring decision — that stays in the game's unscored flow.
