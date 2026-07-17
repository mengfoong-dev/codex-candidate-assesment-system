# Evidence-First Evaluation Engine Complement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make the backend event log authoritative for AI-assisted assessment activity, then add evidence-safe LLM provenance and frozen regression cases without adding a second evaluator platform.

**Architecture:** Keep the three existing layers: deterministic rules decide scored criteria, the Cohere panel provides labelled qualitative analysis, and context indices remain non-scored. When a backend is configured, the Godot app starts one remote session before the assessment, writes candidate actions to it live, and sends assistant messages to the backend simulation endpoint. The simulation endpoint remains the only writer of backend-only AI events. Golden cases run against existing evaluator functions in tests; new metadata stays inside ScoringResult.detail JSON.

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy/SQLite, pytest, Cohere provider doubles, Godot 4.7, GDScript.

## Global Constraints

- Do not add Promptfoo, DeepEval, Langfuse, Opik, Ragas, or another runtime dependency.
- Keep Layer 1 deterministic and scored; Layer 2 as labelled AI analysis; Layer 3 never scored.
- Browser/client code must never post ai_prompt_submitted, ai_response_received, tool_invoked, or token usage.
- Retain the anti-forgery rule: a candidate disposition needs a server-recorded response ID.
- Keep the offline Godot summary unscored, and never use report text for an autonomous hire/reject decision.
- Keep calibration fixtures anonymised and backend-only. Do not call a real model in tests.
- Do not expose reviewer reports publicly until access control, retention, and PII redaction are designed.
- Preserve unrelated working-tree changes and stage only task files.

---

## Decision Record

### Evidence

1. The backend already has deterministic rules, an LLM rubric panel, non-scored indices, and evidence-bearing ScoringResult rows.
2. The simulation endpoint writes trusted prompt, response, tool, and token events. The current submit-time Godot replay starts a fresh session, replays only selected local events, and ignores replay failures. Its AI disposition references a response the backend never observed and is rejected.
3. CareerSphere's transferable pattern is deterministic computation with evidence-carrying explanations. Promptfoo and DeepEval support frozen cases and rubric judging. Langfuse and Opik are useful operational references but exceed MVP scope.

### Options

| Option | Benefits | Risks | Decision |
|---|---|---|---|
| Adopt a full evaluator platform | Dashboards, datasets, experiments | New service, PII/data-retention work, duplicate result store | Reject |
| Add a separate prompt-quality score | Fast visible feature | Competing score authority, opaque hiring pressure | Reject |
| Extend event log, panel, report, and tests | Reuses evidence model, auditable, smallest diff | Requires repairing client/server boundary first | Select |

**Conclusion:** Execute the five tasks below in order. Confidence: 9/10. The only material uncertainty is Godot web transport; the backend integrity contract is already clear.

## Planned Files

| Path | Responsibility |
|---|---|
| Create apps/incident-room/scripts/presentation/assessment_backend_client.gd | Own one live backend session and all HTTP/SSE calls |
| Modify apps/incident-room/scripts/presentation/main.gd | Start the remote session and surface degraded/offline mode |
| Modify apps/incident-room/scripts/presentation/browser_workspace.gd | Send assessment assistant prompts through the backend client |
| Delete apps/incident-room/scripts/presentation/backend_grader.gd | Remove unsafe submit-time replay |
| Create apps/incident-room/tests/test_assessment_backend_client.gd | Validate mapping and transport-failure behaviour |
| Create backend/tests/test_live_assessment_contract.py | Verify trusted AI turn to disposition to report |
| Modify backend/src/evaluation/panel.py, service.py, report.py | Filter citations and retain prompt provenance |
| Create backend/tests/fixtures/evaluation_cases/homepage_latency_v1.json | Hold anonymised frozen gold cases |
| Create backend/tests/test_evaluation_regression.py | Run deterministic and index regression checks |

## Task 1: Make the backend session canonical

**Files:**
- Create: apps/incident-room/scripts/presentation/assessment_backend_client.gd
- Modify: apps/incident-room/scripts/presentation/main.gd
- Modify: apps/incident-room/scripts/presentation/browser_workspace.gd
- Delete: apps/incident-room/scripts/presentation/backend_grader.gd
- Test: apps/incident-room/tests/test_assessment_backend_client.gd
- Test: apps/incident-room/tests/test_main_flow.gd

**Interfaces:**
- Consume POST /api/sessions, POST /api/sessions/{id}/events, POST /api/sessions/{id}/tests/{test_id}, POST /api/sessions/{id}/messages, POST /api/sessions/{id}/submit, and GET /api/sessions/{id}/report.
- Produce an AssessmentBackendClient with start, record_candidate_event, run_test, request_assistant, submit, and fetch_report.
- request_assistant is the sole method that produces backend AI-turn events.

- [ ] **Step 1: Write the failing Godot client tests**

Test start followed by evidence_viewed. Test that ai_response_received returns ok false before an HTTP call. Test that a non-2xx response is returned as ok false with an error instead of being ignored.

~~~gdscript
var client := AssessmentBackendClient.new(fake_request)
assert_true((await client.start("https://backend.example", "Candidate")).ok, "session starts")
assert_true((await client.record_candidate_event("evidence_viewed",
    {"artifact_id": "homepage_trace"})).ok, "evidence posts live")
assert_false((await client.record_candidate_event("ai_response_received", {})).ok,
    "backend-only events cannot be forged")
~~~

- [ ] **Step 2: Run the Godot suite and confirm the test fails**

Run: powershell -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1

Expected: FAIL because AssessmentBackendClient is missing.

- [ ] **Step 3: Implement the client**

~~~gdscript
func start(base_url: String, display_name: String) -> Dictionary
func record_candidate_event(event_type: String, payload: Dictionary) -> Dictionary
func run_test(test_id: String, remediation_id: String) -> Dictionary
func request_assistant(content: String) -> Dictionary
func submit(submission: Dictionary) -> Dictionary
func fetch_report() -> Dictionary
~~~

start stores one remote session ID. record_candidate_event accepts only frontend-safe event types. request_assistant posts content to messages, parses the completed SSE stream into token/tool/file/done data, and returns the done payload. It must never replay local prompt/response events.

- [ ] **Step 4: Wire the client into the Godot flow**

In main.gd, create the remote session before enabling a configured-backend assessment. Write every locally accepted evidence, hypothesis, disposition, decision, and verification action immediately. In browser_workspace.gd, route assistant prompts to request_assistant and render its response. Replace submit-time replay with submit then fetch_report on the same remote session.

If remote setup or recording fails, show the existing warning, continue only with the local unscored summary, and do not attempt a late replay.

- [ ] **Step 5: Verify and commit**

Run: powershell -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1

Run: rg -n "BackendGrader|_grade_with_backend|senior-proxy" apps/incident-room

Expected: Godot checks pass and no assessment turn uses BackendGrader or senior-proxy.

~~~powershell
git add apps/incident-room/scripts/presentation/assessment_backend_client.gd apps/incident-room/scripts/presentation/main.gd apps/incident-room/scripts/presentation/browser_workspace.gd apps/incident-room/scripts/presentation/backend_grader.gd apps/incident-room/tests/test_assessment_backend_client.gd apps/incident-room/tests/test_main_flow.gd
git diff --cached --name-only
git commit -m "fix: record assessment events through backend session"
~~~

## Task 2: Prove the trusted AI-turn contract

**Files:**
- Create: backend/tests/test_live_assessment_contract.py
- Modify: backend/tests/test_report.py
- Test: backend/tests/test_events.py
- Test: backend/tests/test_simulation.py

**Interfaces:**
- Consume the existing simulation endpoint, event endpoint, submit endpoint, and report output.
- Produce a contract test proving one server-created response permits a candidate disposition and the report contains all events in order.

- [ ] **Step 1: Write a failing end-to-end contract test**

Create a session, monkeypatch src.simulation.service.get_llm with the existing FakeLLM pattern, and post one messages request whose fake response has response ID safe_concurrency_response_v1. Post a verify_then_adapt disposition for that ID, submit a valid result, then assert the timeline contains one ai_prompt_submitted, one ai_response_received, and one ai_suggestion_dispositioned in sequence order.

- [ ] **Step 2: Run the focused test**

Run: cd backend; uv run pytest tests/test_live_assessment_contract.py -q

Expected: FAIL until the full trusted provider path is wired.

- [ ] **Step 3: Preserve anti-forgery**

Make the test use the current simulation service. Do not add an endpoint that writes ai_response_received and do not relax record_frontend_event.

- [ ] **Step 4: Add report membership assertions**

In test_report.py, assert every AI-analysis citation is present in report timeline event IDs.

- [ ] **Step 5: Verify and commit**

Run: cd backend; uv run pytest tests/test_live_assessment_contract.py tests/test_events.py tests/test_simulation.py tests/test_report.py -q

Expected: PASS with no external model call.

~~~powershell
git add backend/tests/test_live_assessment_contract.py backend/tests/test_report.py
git diff --cached --name-only
git commit -m "test: cover trusted AI turn assessment contract"
~~~

## Task 3: Validate citations and record prompt provenance

**Files:**
- Modify: backend/src/evaluation/panel.py
- Modify: backend/src/evaluation/service.py
- Modify: backend/src/evaluation/report.py
- Modify: backend/tests/test_panel.py
- Modify: backend/tests/test_report.py

**Interfaces:**
- Consume event IDs passed to rubric_panel.
- Produce valid cited_event_ids, invalid_citation_count, and prompt_version on each scored panel row, stored in ScoringResult.detail.

- [ ] **Step 1: Write failing panel tests**

Make a fake grader return known and invented event IDs for an event list containing only known. Assert the row keeps only known, records invalid_citation_count equal to 1, and has a non-empty prompt_version.

- [ ] **Step 2: Run the focused test**

Run: cd backend; uv run pytest tests/test_panel.py -q

Expected: FAIL because unknown citations are currently preserved.

- [ ] **Step 3: Implement boundary filtering**

In panel.py, define PANEL_PROMPT_VERSION as panel-v1. Build the valid event-ID set inside rubric_panel, pass it to _rows_from_results, keep only known IDs, and count discarded IDs. Never guess a replacement citation or invoke the model again.

- [ ] **Step 4: Persist and expose fields without a migration**

In service.py, add prompt_version and invalid_citation_count to the current LLM-rubric detail JSON. In report.py, return them beside rubric_version, graders, and cited_event_ids. Do not change ScoringResult columns.

- [ ] **Step 5: Verify and commit**

Run: cd backend; uv run pytest tests/test_panel.py tests/test_report.py -q

Expected: PASS and no report contains an invented event ID.

~~~powershell
git add backend/src/evaluation/panel.py backend/src/evaluation/service.py backend/src/evaluation/report.py backend/tests/test_panel.py backend/tests/test_report.py
git diff --cached --name-only
git commit -m "feat: validate rubric evidence provenance"
~~~

## Task 4: Add frozen evaluation cases and a regression gate

**Files:**
- Create: backend/tests/fixtures/evaluation_cases/homepage_latency_v1.json
- Create: backend/tests/test_evaluation_regression.py
- Modify: backend/tests/test_rules.py
- Modify: backend/tests/test_indices.py

**Interfaces:**
- Consume immutable JSON cases with case_id, scenario_id, scenario_version, events, submission, and expected.
- Produce test-only assertions for rule_grade and compute_indices; no production table, endpoint, or evaluator-run model.

- [ ] **Step 1: Write the fixture loader and failing test**

~~~json
{
  "case_id": "strong-evidence-led-v1",
  "scenario_id": "homepage_latency",
  "scenario_version": "1.0.0",
  "events": [],
  "submission": {},
  "expected": {
    "deterministic_total": 80,
    "normalized_q": 100.0,
    "criterion_statuses": {"trace_before_change": "met"},
    "context_available": {"ai_reliance_ratio": true}
  }
}
~~~

Load each case, call get_scenario, rule_grade, and compute_indices, then compare the listed expected values exactly.

- [ ] **Step 2: Run before the corpus exists**

Run: cd backend; uv run pytest tests/test_evaluation_regression.py -q

Expected: FAIL because the fixture and loader do not exist.

- [ ] **Step 3: Add 20–30 human-labelled anonymised cases**

Cover strong evidence-led work, weak/un-cited diagnosis, blind AI acceptance, verified adaptation, no AI use, technical outage/exclusion, contradiction-driven revision, forged-event rejection, missing validation, and prompt-injection-style candidate text. Keep role, competency, and difficulty metadata in the backend fixture only. Review every deterministic expectation before committing.

- [ ] **Step 4: Keep LLM evaluation deterministic in tests**

Do not snapshot real model scores. Use provider doubles for panel schema, provenance, citation filtering, fallback, and report shape. Use future human double scoring only to calibrate rubrics, not to create a live consensus score.

- [ ] **Step 5: Verify and commit**

Run: cd backend; uv run pytest tests/test_evaluation_regression.py tests/test_rules.py tests/test_indices.py tests/test_panel.py tests/test_report.py -q

Expected: PASS. A rubric/model change must update the rubric version and receive human review of all changed golden results.

~~~powershell
git add backend/tests/fixtures/evaluation_cases/homepage_latency_v1.json backend/tests/test_evaluation_regression.py backend/tests/test_rules.py backend/tests/test_indices.py
git diff --cached --name-only
git commit -m "test: add frozen evaluation regression cases"
~~~

## Task 5: Make Proof Replay a clear internal reviewer aid

**Files:**
- Modify: backend/src/evaluation/report.py
- Modify: backend/tests/test_report.py
- Modify: docs/backend/01-evaluation-engine.md
- Modify: docs/assessment/evidence-and-scoring.md

**Interfaces:**
- Consume the existing timeline and ScoringResult rows.
- Produce a report connecting each result to known event IDs, formulas/inputs, rubric/prompt versions, and the existing human-review notice.

- [ ] **Step 1: Add failing report assertions**

Assert that each AI-analysis dimension includes rubric_version, prompt_version, invalid_citation_count, and citations contained in timeline IDs. Keep the label AI analysis — model opinion, human review required.

- [ ] **Step 2: Run the report test**

Run: cd backend; uv run pytest tests/test_report.py -q

Expected: FAIL until Task 3 fields are exposed.

- [ ] **Step 3: Document the operating boundary**

Update docs/backend/01-evaluation-engine.md with canonical event production, golden-corpus gating, version/change review, and the invalid-citation discard rule. Update docs/assessment/evidence-and-scoring.md to state that reports support human review and never make employment decisions.

- [ ] **Step 4: Run final verification and commit**

Run: cd backend; uv run pytest tests/test_events.py tests/test_simulation.py tests/test_rules.py tests/test_indices.py tests/test_panel.py tests/test_report.py tests/test_live_assessment_contract.py tests/test_evaluation_regression.py -q

Run: powershell -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1

Expected: both commands PASS. Manually verify one configured-backend attempt records a prompt, response, disposition, deterministic result, and report provenance under one session ID.

~~~powershell
git add backend/src/evaluation/report.py backend/tests/test_report.py docs/backend/01-evaluation-engine.md docs/assessment/evidence-and-scoring.md
git diff --cached --name-only
git commit -m "docs: define evaluation provenance and regression policy"
~~~

## Deferred Until Evidence Justifies Them

- Self-hosted observability, production dashboards, or an experiment UI.
- A persistent eval_run database model; fixtures and current result provenance are sufficient first.
- Multi-model live consensus; it increases cost and obscures the single-primary-grader policy.
- Automated hiring thresholds, ranking, or opaque composite scores.
- Public reviewer-report access before access control and PII policy exist.

## Final Acceptance Checklist

- [ ] A configured-backend attempt never uses submit-time local-event replay.
- [ ] Real AI turns are recorded only by the backend simulation path.
- [ ] A disposition succeeds only after its server-recorded response and fails closed otherwise.
- [ ] Every persisted LLM citation is a known event ID; discarded IDs are counted.
- [ ] Every LLM result identifies rubric and prompt versions.
- [ ] The corpus contains 20–30 labelled cases and runs without a real model.
- [ ] Rubric/model changes require review of golden-case deltas.
- [ ] Proof Replay remains a human-review aid and never states an employment decision.

## Plan Self-Review

- **Coverage:** Tasks 1–2 repair canonical evidence production; Task 3 hardens provenance; Task 4 adds repeatable regression evidence; Task 5 exposes reviewer-safe output.
- **Scope:** No platform adoption, schema migration, or new score authority is introduced.
- **Consistency:** The simulation endpoint remains the only writer of backend-only AI events; all new metadata uses existing detail JSON.
- **Verification:** Each task has a focused failing/passing check; the final task runs backend and Godot verification together.

## Execution Handoff

Execute sequentially. Do not start Tasks 3–5 until Task 2 proves that one live backend session receives the full trusted AI-turn chain.

