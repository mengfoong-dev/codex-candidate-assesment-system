# VibeProof senior proxy

This small Node 18+ service keeps `COHERE_API_KEY` off the Godot client. It provides both Sam's
office chat and the recorded workspace assistant through Cohere Chat V2, using
`command-a-plus-05-2026` by default.

## Local setup

Copy `.env.example` to `.env`, set `COHERE_API_KEY` in that ignored file, then run:

```powershell
npm start
```

Check the non-sensitive deployment status with `GET /health`; it returns `{ ok, provider, model,
routes }`. Both chat endpoints return `{ "reply": "..." }` and sanitize all upstream errors to
`{ "error": "assistant is unavailable right now" }`.

## Railway

Create or select the `senior-proxy` service, then set `COHERE_API_KEY`, optional
`COHERE_MODEL`, and `ALLOWED_ORIGINS` as Railway service variables in the Railway dashboard.
This avoids recording a credential in a tracked file or shell history. Deploy the
`apps/senior-proxy` directory normally; Railway supplies `PORT`.

## Endpoints

- `GET /health` -> `{ ok, provider: "cohere", model, routes }`
- `POST /api/senior/chat` -> `{ messages, task? }` -> `{ reply }`
- `POST /api/assistant/chat` -> `{ messages, task? }` -> `{ reply }`

The proxy is limited to task clarification and workspace assistance. It does not score a
candidate, persist events, or make a hiring decision.
