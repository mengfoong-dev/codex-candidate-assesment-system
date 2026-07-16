# Cohere runtime configuration

All live LLM flows use Cohere Command A+ with `COHERE_MODEL=command-a-plus-05-2026`:

- The FastAPI candidate simulation streams Cohere Chat V2 text and function calls. It disables
  Command A+ thinking for this bounded candidate-facing turn so its response budget is available
  for visible assistant text and workspace tool calls. Cohere receives strict `read_file` and
  `write_file` functions only; the TSX client obtains the sandbox inventory from the deterministic
  `POST /sessions` response and `GET /sessions/{id}/files` endpoint.
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

The Cohere rubric uses Chat V2 JSON object mode and disables thinking before parsing visible JSON
content. Application-level validation enforces the rubric object shape, citations, and score bounds;
this avoids Command A+'s current JSON Schema-mode endpoint rejection and its unsupported numeric
range keywords.

## Railway proxy configuration

Set `COHERE_API_KEY`, optional `COHERE_MODEL`, and `ALLOWED_ORIGINS` in the Railway service
variable UI for `apps/senior-proxy`. Do not put credentials in a tracked Railway command or
deployment script. `GET /health` confirms the resolved non-secret provider and model.
