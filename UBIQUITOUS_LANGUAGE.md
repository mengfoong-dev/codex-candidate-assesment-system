# Ubiquitous Language

Shared vocabulary between the team, the AI assistants, and the (planned) code.
Grounded in `docs/decisions.md`, `docs/assessment/evidence-and-scoring.md`, and the
2026-07-15 backend kickoff session. Code identifiers marked **(planned)** don't exist
yet — they are the agreed names the backend will use.

## Product & assessment domain

| Term | Definition | Aliases to avoid |
| ---- | ---------- | ---------------- |
| **VibeProof** | The product: an AI-allowed engineering assessment that records how a candidate works, not just their answer. | the app, the system |
| **Ownership Challenge** | The assessment format: a candidate investigates a controlled incident and must defend their conclusion. | test, exam, challenge |
| **Candidate** | The person taking the assessment. Has no account in the MVP — just a display name on a session. | user, player, participant |
| **Recruiter** | The person who reads the results afterwards. Never interacts during the session. | reviewer, HR |
| **Scenario** | A versioned, pre-authored incident package: brief, evidence, faulty code files, scripted test results, and scoring rules. MVP has exactly one: *Homepage Latency Spike*. | question, problem, level |
| **Incident** | The fictional production problem inside a scenario (e.g. "homepage p95 latency jumped 180ms → 850ms"). | bug, issue |
| **Evidence artifact** | One inspectable piece of the scenario: a metrics panel, log excerpt, trace, or source file. Each has a stable ID. | station content, clue, panel data |
| **Hypothesis** | The candidate's current best explanation of the root cause, recorded with a confidence level; revisable as evidence accumulates. | guess, answer, theory |
| **Disposition** | What the candidate does with an AI suggestion: accept it, modify/verify it, or reject it. | reaction, choice |
| **Final submission** | The structured conclusion: root cause + evidence + fix + risks + validation plan + confidence. | answer, result |
| **Proof Replay** | The recruiter-facing report: chronological timeline + scores + cited evidence. **This is the product's core deliverable** — everything the backend stores exists to build it. | report, results page, replay |

## Backend architecture (decided 2026-07-15)

| Term | Definition | Aliases to avoid |
| ---- | ---------- | ---------------- |
| **Session** | One candidate's one attempt at one scenario — the root record every event, file, and score hangs off. | attempt, run, game |
| **Orphaned session** | A session whose browser tab was closed/reloaded: the frontend forgets its ID, but **all its rows stay in the database forever** so the Proof Replay still works. "Flush" = browser forgets, DB remembers. | flushed session, deleted session |
| **Event** | One append-only, sequence-numbered record of a meaningful action (`evidence_viewed`, `hypothesis_recorded`, `ai_prompt_submitted`…). The **source of truth** — every score and replay is derived from events. | log entry, action, activity |
| **Append-only event log** | The events table: rows are only ever added, never updated or deleted. Guarantees the replay can't be tampered with. | history, audit log |
| **Simulation Engine** | The backend service that gives the candidate a codex-like AI assistant: streams chat, reads/writes files in the Virtual Workspace, records its own events. | chat engine, AI wrapper, copilot |
| **Evaluation Engine** | The backend service that runs **once, at final submission**: computes all three scoring layers in parallel and stores the results. | grading engine, scorer, judge |
| **Virtual Workspace** | The candidate's "file system": plain database rows (path + content), **not** real files, **never executed**. The sandbox is data, not a computer. | sandbox, VM, container, file system |
| **Seeded faulty file** | A source file that ships inside the scenario (containing the planted root cause). Read-only scenario data shared by all sessions — sessions get copies, the original never changes. | static file, default file |
| **Scripted test result** | A pre-authored pass/fail outcome keyed by the candidate's chosen fix. "Running tests" looks up this table — no code is ever executed (decision D006). | test run, sandbox execution |
| **Grading panel** | The set of parallel, independent LLM calls (across Groq + NVIDIA NIM) that each apply a rubric to the same evidence; their median is the consensus. "Multi-agent" here means *parallel independent calls*, not a LangGraph-style agent framework. | multi-agent system, agent swarm |

## Scoring — the three layers

| Term | Definition | Aliases to avoid |
| ---- | ---------- | ---------------- |
| **Layer 1 — Scored rules** | Deterministic (same input → same output, no AI involved) checks over events, each worth fixed points and citing the exact event that triggered it. The only layer that produces *the score*. | rubric, AI grading |
| **Rule** | One transparent if-this-then-points check, e.g. "+10 reviewed trace before recommending a code change". | criterion, metric |
| **Layer 2 — AI analysis** | LLM rubric grading of qualitative dimensions (communication, prompt precision, thinking style). Clearly labeled as AI opinion, quotes the events it judged, never mixed into Layer 1 points. | the score, objective grade |
| **Rubric** | The written grading guide an LLM grader must follow (dimension, anchors for each score band, required citations). | prompt, criteria list |
| **Dimension** | One assessed quality (e.g. *Investigation strategy*, *AI verification*) from `evidence-and-scoring.md`. | category, skill |
| **Layer 3 — Context indices** | Computed formulas displayed for context but **never scored** (decision D009: efficiency ≠ competence). | efficiency score, penalty |
| **Prompt Efficiency Index (E_p)** | Context index: code quality relative to prompt volume and retry failures — `E_p = Q_code / (1 + 0.05·P_total·(1+R_fail))`. Higher = got quality with fewer wasted prompts. | efficiency grade |
| **Evidence Coverage (EC)** | **Scored** (Layer 1): fraction of the scenario's pre-tagged relevant evidence the candidate viewed *before* concluding. Low EC = *premature closure* (concluding without checking the key evidence). | coverage metric |
| **Verification Discipline (VD)** | **Scored** (Layer 1): fraction of AI suggestions the candidate tested before relying on them, instead of accepting blindly. | trust ratio |
| **Investigation Entropy** | Context index: how spread-out the candidate's evidence viewing was (breadth vs tunnel vision). From Shannon entropy — a standard "how evenly distributed" formula. | exploration score |
| **Hypothesis Convergence** | Context index: 1 ÷ (position of the correct hypothesis in their list). Landed on the true cause 2nd → 0.5. | accuracy |
| **Premature closure** | The failure mode of concluding before gathering enough evidence — a validated concept from diagnostic-reasoning research; what EC detects. | rushing |

## Technical / infrastructure

| Term | Definition | Aliases to avoid |
| ---- | ---------- | ---------------- |
| **SSE (Server-Sent Events)** | A one-way stream from server to browser over normal HTTP — how chat tokens appear word-by-word like ChatGPT. Simpler than WebSocket (which is two-way and needs connection management we don't need). | WebSocket, polling |
| **asyncio fan-out** | Python's built-in way to fire many async calls at once and wait for all (`asyncio.gather`) — how the grading panel runs in parallel with zero extra dependencies. | multi-threading, LangGraph |
| **OpenAI-compatible API** | An API that copies OpenAI's request format. Groq and NVIDIA NIM both do, so one client library talks to both by changing only the server address (**base URL swap**) — which is why LiteLLM (a translation library for *incompatible* APIs) isn't needed. | — |
| **SQLAlchemy** | The Python library that maps Python classes to database tables, letting us start on SQLite (a zero-setup, single-file database) and switch to Postgres later by changing one connection string. | ORM (fine, but say SQLAlchemy) |
| **Middleware** | Code that runs on every request before it reaches a route — MVP has only CORS (the browser permission header that lets the frontend's domain call our API), error handling, and logging. No auth. | auth layer |
| **Frozen IDs** | The stable identifier vocabulary from the Godot plan (`homepage_latency`, `observability_wall`, `sequential_independent_calls`…) reused verbatim by the backend so both presentation layers share one scenario. | constants, enums |

## Code identifiers ↔ domain terms

| Identifier (where) | Domain term | One-line gloss |
| ------------------ | ----------- | -------------- |
| `scenarios` (planned table) | Scenario | Versioned incident package incl. seeded files |
| `sessions` (planned table) | Session | One attempt; `display_name` = the candidate |
| `events` (planned table) | Event log | Append-only, seq-numbered actions; source of truth |
| `session_files` (planned table) | Virtual Workspace | Current file state per session |
| `scoring_results` (planned table) | Scoring layers | One row per criterion × layer, with evidence refs |
| `SessionService` (planned service) | — | Creates sessions, ingests frontend events |
| `SimulationEngine` (planned service) | Simulation Engine | Chat + file tools + SSE streaming |
| `EvaluationEngine` (planned service) | Evaluation Engine | Runs all 3 layers at submit |
| `RubricPanel` (planned, inside EvaluationEngine) | Grading panel | Parallel LLM rubric calls, median consensus |
| `homepage_latency_v1.json` (Godot plan §Task 1; backend reuses) | Scenario | The one MVP scenario, frozen IDs inside |
| `ai_suggestion_dispositioned` (event type, evidence-and-scoring.md) | Disposition | Candidate accepted/modified/rejected an AI suggestion |
| `results_by_remediation` (Godot plan scenario JSON) | Scripted test result | Pass/fail lookup keyed by chosen fix |
| `layer` column: `deterministic` / `llm_rubric` / `context_index` (planned) | Layers 1/2/3 | Which scoring layer a result row belongs to |

## Relationships

- A **Scenario** is shared by many **Sessions**; a **Session** belongs to exactly one **Scenario** version.
- A **Session** owns many **Events** (append-only), many **Virtual Workspace** files, and many **scoring_results** rows.
- The **Simulation Engine** *writes* events during the session; the **Evaluation Engine** *reads* them once at submission.
- Every **Layer 1 rule** result cites ≥1 **Event**; **Layer 2** quotes events; **Layer 3** is computed from event counts.
- The **Proof Replay** is assembled from Events + scoring_results — nothing else.

## Example dialogue

> **Dev:** "The candidate reloaded the page — do we delete their **session**?"
> **Domain expert:** "Never. It becomes an **orphaned session**: the browser forgets the ID, but the recruiter's **Proof Replay** reads those rows later."
>
> **Dev:** "When they click *Run tests*, what executes?"
> **Domain expert:** "Nothing executes. We look up the **scripted test result** for their chosen fix — the **Virtual Workspace** is database rows, not a computer."
>
> **Dev:** "Is the **Prompt Efficiency Index** part of their score?"
> **Domain expert:** "No — it's a **Layer 3 context index**, displayed with its formula. Only **Layer 1 scored rules** produce points, and each one cites the **event** that triggered it."
>
> **Dev:** "And the **grading panel** — is that LangGraph agents?"
> **Domain expert:** "Just parallel LLM calls via **asyncio fan-out**, one **rubric** each, median as consensus."

## Flagged ambiguities

- **"flush"** — you used it meaning *delete on reload*; canonical meaning is **orphan** (browser forgets, DB remembers). A literal flush would destroy the Proof Replay.
- **"sandbox"** — suggests an execution environment (Docker, VM). Ours never executes anything; canonical term is **Virtual Workspace** to keep that boundary visible.
- **"metrics"** is dangerously overloaded: (1) the **Metrics evidence artifact** (CPU %, latency — scenario content the candidate inspects) vs (2) assessment measurements. For (2), say **rule** (Layer 1), **rubric dimension** (Layer 2), or **context index** (Layer 3) — never bare "metrics".
- **"grading criteria"** — split it: deterministic **rules** score, LLM **rubrics** analyze, **indices** contextualize. One umbrella word hides the D007 boundary.
- **"multi-agent"** — in this codebase it means *parallel independent LLM grader calls*. It does not imply an agent framework, memory, or inter-agent communication.
- **"static files"** — the seeded faulty files are *scenario data* (versioned, shared, read-only), not per-session state and not web-server "static assets".
- **"user"** — avoid entirely: no accounts exist. Say **Candidate** (person) or **Session** (the record).
