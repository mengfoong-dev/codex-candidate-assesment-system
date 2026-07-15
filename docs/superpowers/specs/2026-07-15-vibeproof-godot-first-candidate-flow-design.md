# VibeProof Godot-First Candidate Flow Design

## Status

Approved by the user on 2026-07-15.

This design changes the implementation order for the Godot Incident Room application. It preserves the room, camera, controls, scenario, visual direction, evidence boundaries, and offline constraints in the [Incident Room MVP design](2026-07-15-vibeproof-incident-room-mvp-design.md). Where the earlier design schedules deterministic scoring before or alongside the playable flow, this document takes precedence: finish the candidate-facing Godot experience and local event record first; add scoring as a later backend integration.

## Goal

Deliver a complete, playable candidate journey in Godot for the Homepage Latency Spike scenario:

```text
Title and notice
  -> mission briefing and initial hypothesis
  -> playable Incident Room
  -> three investigation stations
  -> hypothesis revision
  -> verification and structured submission
  -> unscored session summary
```

The milestone proves that a candidate can complete the assessment experience and produce structured evidence. It does not calculate rubric points, capability scores, hiring recommendations, or pass/fail outcomes.

## Product boundary

The canonical VibeProof product remains an AI-allowed Ownership Challenge with a human-reviewed Proof Replay. The Godot project is its first candidate-facing application for the controlled scenario.

The Godot-first milestone must:

- run locally without a backend, account, network connection, or live model;
- record meaningful assessment actions automatically;
- keep movement speed, route choice, camera skill, and interaction count unscored;
- permit technically incorrect choices so later review can distinguish evidence paths;
- label its final output as an unscored prototype session summary;
- avoid employment recommendations or claims about private cognition;
- preserve a stable event contract that a later scoring backend can consume.

## Chosen implementation approach

Build a vertical slice around a stable event contract. Godot owns the candidate experience, current session state, local persistence, and chronological summary. Presentation components emit candidate intent; they do not calculate assessment results.

This approach was selected over:

- a UI-only walkthrough, which would be faster initially but would discard the evidence needed for later scoring;
- the original domain-first order, which provides scoring infrastructure early but delays the playable experience;
- a local scoring engine embedded into the first Godot milestone, which would couple the presentation prototype to policy that the user has explicitly deferred.

## Candidate journey

### 1. Title and notice

The title screen identifies the experience as a VibeProof prototype and explains:

- structured in-game assessment actions are recorded locally;
- navigation performance is not assessed;
- the current build produces an unscored summary for human review;
- starting the experience creates a new local session.

Confirming the notice creates the session and records `assessment_opened`.

### 2. Briefing and initial hypothesis

The briefing presents the Homepage Latency Spike: p95 increased from 180 ms to 850 ms while CPU remains at 35%. The candidate selects an initial hypothesis and confidence level before entering the investigation room.

The candidate cannot continue until both fields are selected. Confirmation records `hypothesis_recorded` with version `1`.

### 3. Incident Room investigation

The fixed orthographic room contains the observability wall, developer desk, and release console. The candidate may walk to a station and press `E`, or open it through `1`, `2`, or `3`. Quick access and physical interaction produce equivalent assessment events.

Stations may be visited in any order and revisited without restriction. Every artifact opening records `evidence_viewed`; repeated views remain visible in the chronology.

### 4. Scripted AI interaction

The developer desk displays the existing scripted prompt and offline response. The candidate chooses whether to accept immediately, reject, or verify independence and failure handling first.

The interaction records `ai_prompt_submitted`, `ai_response_received`, and `ai_suggestion_dispositioned`. It never calls an external model.

### 5. Hypothesis revision

The candidate may press `H` to revise the hypothesis and confidence. The revision panel lists only facts from artifacts already viewed. A revision records the previous hypothesis, new hypothesis, confidence, and selected trigger evidence as `hypothesis_revised`.

The flow does not require a revision because failing to revise may itself be relevant evidence later. The summary distinguishes an unchanged hypothesis from a revised one without judging either.

### 6. Verification and submission

The release console allows the candidate to select a root cause, evidence references, remediation, risks or assumptions, validation tests, rollback approach, and final confidence. Incorrect and incomplete-evidence paths remain available.

Submission is enabled when the candidate has selected a root cause, remediation, at least one validation test, a rollback approach, and final confidence. Evidence references and rationale may be empty, but the summary shows that explicitly. Confirmation records `decision_recorded`, selected `test_executed` events, and `final_submission`.

### 7. Unscored session summary

The final screen displays:

- scenario and session identifiers;
- whether the local event file was saved successfully;
- initial and final hypotheses with confidence;
- artifacts viewed in chronological order;
- scripted AI disposition;
- selected verification actions;
- final diagnosis, remediation, risks, rollback, and evidence references;
- a prominent `Unscored prototype summary` label;
- a human-review notice and a statement that no employment decision was made.

The screen must not display points, criteria met or missed, candidate rank, capability labels, pass/fail status, or a hiring recommendation.

## Architecture

### Scenario loading

The existing `ScenarioLoader` remains the only runtime entry point for `homepage_latency_v1.json`. The scoring configuration may remain in scenario data for future compatibility, but the Godot-first runtime does not read it after scenario validation.

### Candidate session

`CandidateSession` owns the current in-memory session state:

- session and scenario identifiers;
- current screen or phase;
- initial and current hypothesis;
- confidence and hypothesis version;
- viewed artifact identifiers and chronology;
- scripted AI disposition;
- verification selections;
- final submission;
- completion and persistence-warning state.

It exposes intent methods such as `open_assessment`, `record_initial_hypothesis`, `view_evidence`, `record_ai_disposition`, `revise_hypothesis`, `record_verification`, and `submit_final`. Each accepted intent updates state and emits one or more structured events. Rejected intents return a validation result without mutating state or writing events.

### Event contract

Every event uses this envelope:

```text
schema_version
session_id
sequence
event_type
recorded_at_utc
scenario_id
scenario_version
payload
```

`sequence` starts at `1` and increases monotonically. `recorded_at_utc` is an ISO 8601 UTC timestamp. Payloads contain stable scenario identifiers rather than display text wherever an identifier exists.

The Godot-first event set is:

- `assessment_opened`;
- `hypothesis_recorded`;
- `evidence_viewed`;
- `ai_prompt_submitted`;
- `ai_response_received`;
- `ai_suggestion_dispositioned`;
- `hypothesis_revised`;
- `test_executed`;
- `decision_recorded`;
- `final_submission`.

The event contract contains no score, criterion result, capability label, or recommendation field.

### Persistence

`EventLogger` appends one JSON object per line to:

```text
user://vibeproof/<session-id>/events.jsonl
```

Events are also retained in memory for the current session. If directory creation or writing fails, the candidate can continue; the HUD displays a non-blocking recording warning and the final summary reports that the disk record is incomplete.

On final submission, `UnscoredSummaryBuilder` produces a deterministic view model from `CandidateSession` and its ordered events. The runtime may write this model to `summary.json`, but that file is evidence presentation, not an assessment result.

### Presentation

Presentation scenes are responsible for rendering and input only:

- title and notice screen;
- briefing and initial-hypothesis panel;
- primitive office room, fixed camera, player, and station prompts;
- observability, developer, AI, hypothesis, and release panels;
- HUD, pause behavior, recording warning, and unscored summary.

Panels emit intent signals to the main session coordinator. They do not access files, assign sequence numbers, mutate shared dictionaries directly, or interpret scoring configuration.

### Future scoring backend

The later scoring system consumes the event envelope and scenario version after a session completes. Its contract begins at the persisted event list; it does not depend on room nodes, UI scenes, movement data, or panel implementation.

Backend work is outside this milestone. No network client, scoring endpoint, retry policy, authentication flow, result cache, or local scoring substitute is added now.

## Error handling

- Invalid scenario data prevents session start and displays a clear local configuration error.
- Invalid candidate intents leave state and event sequence unchanged and keep the relevant panel open.
- Persistence failure switches to in-memory recording and remains visible without blocking completion.
- Missing optional display text falls back to stable identifiers; missing required scenario fields are rejected by `ScenarioLoader`.
- Closing a panel does not discard already confirmed actions.
- Starting a new session resets all candidate state and generates a new session identifier.

## Testing strategy

Use the existing first-party headless test runner. New production behavior follows test-driven development.

Automated tests cover:

- event envelope validation and monotonic sequence numbers;
- valid and rejected session intents;
- initial-hypothesis gating;
- evidence chronology and repeated views;
- scripted AI event order;
- hypothesis revision linkage;
- submission completeness rules;
- JSONL append behavior and in-memory persistence fallback;
- unscored summary contents and absence of scoring fields;
- clean new-session state;
- main-scene loading and required screen or station wiring where practical headlessly.

Manual verification covers:

- complete keyboard flow from title to summary;
- fixed-camera room framing and player visibility;
- `E` and quick-access equivalence;
- modal focus and `Esc` behavior;
- station access in different orders;
- technically correct and incorrect submission paths;
- visible persistence warning behavior;
- a second clean session after completion.

## Implementation order

1. Add the event schema, local logger, and persistence-fallback tests inside the Godot project.
2. Add `CandidateSession` and test the complete unscored candidate-state flow.
3. Build the title, briefing, investigation, hypothesis, release, and summary panels with primitive styling.
4. Build the primitive room, fixed camera, player movement, station interactions, and quick access.
5. Wire the complete flow through the main scene and pass automated and manual greybox playthroughs.
6. Add the approved free diorama assets, character trial, prompts, sound, and visual polish without changing the event contract.
7. Export and smoke-test the Windows build.
8. Design and implement scoring as a separate backend milestone after the Godot candidate flow is accepted.

## Acceptance criteria

The Godot-first candidate-flow milestone is complete when:

1. A candidate can complete the full journey from title screen to unscored summary without a backend or network connection.
2. The room supports player movement, `E` interaction, `1`/`2`/`3` quick access, `H` hypothesis revision, and `Esc` panel handling.
3. Metrics, logs, trace, code, scripted AI, verification, and final-submission content are available from scenario data.
4. Initial hypothesis, evidence views, AI disposition, hypothesis revision, verification, and final submission produce ordered structured events.
5. Events are appended to JSONL when storage is available and retained in memory when it is not.
6. The final summary accurately reflects the session chronology and final submission.
7. No runtime screen or persisted event contains a score, pass/fail result, rank, capability label, or hiring recommendation.
8. Navigation and presentation behavior are absent from assessment evidence except for non-evaluative operational diagnostics.
9. Automated tests and headless Godot import pass.
10. A Windows build completes both a technically correct and a technically incorrect manual path.
11. The approved licensing and responsible-assessment notices remain intact.

## Deferred scoring milestone

After the Godot flow is accepted, scoring work begins from the persisted event contract. That milestone will define backend ownership, rubric versioning, evidence citations, API behavior, failure handling, human-review presentation, fairness checks, and the boundary between deterministic rules and constrained AI analysis.

Until that design is separately approved, the Godot candidate flow remains intentionally unscored.
