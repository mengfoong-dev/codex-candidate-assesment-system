# Cohere runtime configuration

All live LLM flows use Cohere Command A+ with `COHERE_MODEL=command-a-plus-05-2026`:

- The FastAPI candidate simulation streams Cohere Chat V2 text and function calls.
- The senior and workspace-assistant proxy uses Cohere Chat V2 at `/v2/chat`.
- The Layer 2 rubric panel is one Cohere grader per dimension and records
  `consensus: "single"` with Cohere model provenance.

## Backend local configuration

Copy `backend/.env.example` to the ignored `backend/.env`, then set `COHERE_API_KEY`. Do not
commit the resulting file or place a real key in a terminal command that will be retained in
shell history.

`AI_PANEL_FALLBACK_ENABLED=false` is the default. When it remains disabled, a Cohere outage
leaves the panel unavailable and the deterministic grading/report safeguards continue as before.
When an operator explicitly enables it, Groq and NVIDIA NIM may be used only after the Cohere
panel is wholly unavailable; their existing provenance and median/single consensus behavior is
retained.

## Railway proxy configuration

Set `COHERE_API_KEY`, optional `COHERE_MODEL`, and `ALLOWED_ORIGINS` in the Railway service
variable UI for `apps/senior-proxy`. Do not put credentials in a tracked Railway command or
deployment script. `GET /health` confirms the resolved non-secret provider and model.
