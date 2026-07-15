# VibeProof MVP Scope

## MVP outcome

The MVP demonstrates one complete evidence chain:

```text
Candidate receives a controlled incident
  -> investigates with code, operational evidence, and AI
  -> records and revises a hypothesis
  -> verifies the proposed conclusion
  -> submits a technical decision
  -> recruiter receives a transparent Proof Replay
```

The vertical slice should prove that VibeProof can collect useful ownership evidence. It does not need to prove predictive validity or product-market fit.

## Build

### Candidate experience

- One role: software engineer.
- One controlled homepage-latency scenario.
- Mission briefing with scope and success criteria.
- Metrics, logs, traces, source code, and AI-assistant tools.
- Initial and revised hypothesis capture.
- Confidence before and after key evidence.
- One verification or test decision.
- Structured final submission.
- Basic start-new and permitted-session-resume controls.

### Assessment system

- Versioned scenario data.
- Append-only structured event log.
- Deterministic rule-based scoring.
- Contextual recording of time and tool usage.
- Constrained analysis of written explanations when needed.
- Clear fallback when AI analysis is unavailable.

### Recruiter experience

- One candidate Proof Replay.
- Dimension-level scores with cited evidence.
- Investigation timeline.
- Hypothesis revisions.
- Final diagnosis and recommendation.
- Suggested human-interview questions.
- Responsible-use and limitation notice.

## Defer

- Full ATS functionality.
- Resume parsing and candidate sourcing.
- Billing and enterprise administration.
- Multiple roles, languages, and scenario libraries.
- Arbitrary candidate-repository execution.
- Fully generated assessments without manager approval.
- Proctoring, facial analysis, voice analysis, and AI-authorship inference.
- Employment-decision automation.
- Custom model training.
- Multiplayer or complex game mechanics.
- 2D or 3D navigation as an MVP dependency.

## Data flow

```text
Versioned scenario
  -> candidate workspace
  -> structured event collector
  -> append-only session log
  -> deterministic rubric evaluator
  -> optional constrained explanation analysis
  -> Proof Replay
  -> human reviewer
```

Every score must point to recorded evidence. Optional AI analysis may summarize or apply a constrained written-response rubric, but deterministic events remain the source of scoreable actions.

## Failure handling

### AI assistant unavailable

The candidate can continue with the supplied evidence. Record the outage, pause any AI-specific scoring rule, and avoid penalizing the candidate.

### Session interruption

Persist scenario version, event sequence, elapsed active time, hypotheses, and draft submission. Resume only when the configured assessment policy permits it.

### Evidence or test fails to load

Record the technical error, show a clear retry option, and exclude affected scoring criteria when the candidate could not access the required evidence.

### Scoring or report generation fails

Preserve the raw event log and final submission. Mark the report for manual review instead of returning a misleading partial score.

### Unexpected candidate action

Reject unsafe or out-of-scope execution, preserve the event, and provide a neutral explanation. The controlled MVP does not execute arbitrary repositories or commands.

## Demo success criteria

- A candidate can complete the scenario from briefing to submission.
- Metrics, logs, traces, source code, and AI interactions are available.
- The system records the defined observable events in order.
- The candidate can revise a hypothesis after new evidence.
- Deterministic scoring produces evidence for every scored dimension.
- A recruiter can understand the Proof Replay without reading raw logs.
- The core flow still completes when optional AI analysis is unavailable.
- The experience does not require game controls.
- The complete demo can be explained in under five minutes, even if the real candidate exercise is longer.

## Post-MVP validation

1. Interview at least five Malaysian technical recruiters or engineering managers.
2. Obtain repeated confirmation of the same ownership-verification problem.
3. Secure pilot commitments with representative candidates.
4. Ask independent senior engineers to rate the same sessions.
5. Compare automated rubric results with reviewer agreement.
6. Test equivalent scenario difficulty, language effects, accessibility, device differences, and AI familiarity.
7. Measure whether Proof Replay improves the consistency and quality of later interviews.
