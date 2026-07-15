# Evidence and Scoring

## Measurement boundary

VibeProof records observable work during a controlled engineering incident:

- evidence inspected;
- searches and tool actions;
- hypotheses and confidence ratings;
- AI prompts, responses, and subsequent candidate actions;
- tests and verification choices;
- technical and operational decisions;
- final explanations.

These events provide process evidence. They do not expose private cognition, diagnose personality or intelligence, establish code authorship, or prove future workplace performance.

The assessment should measure only behaviors supported by a job-related rubric. Final employment decisions remain with a human reviewer.

## Observable event model

Store events in an append-only, versioned session log.

| Event | Minimum data | Assessment purpose |
|---|---|---|
| `assessment_opened` | scenario version, attempt, timestamp | Establish context and reproducibility |
| `evidence_viewed` | artifact ID, evidence type, timestamp | Record investigation coverage |
| `search_performed` | query, scope, result count | Understand information-seeking strategy |
| `ai_prompt_submitted` | prompt, referenced context, timestamp | Record how AI is directed |
| `ai_response_received` | response ID, model, latency, status | Connect prompts to available output |
| `ai_suggestion_dispositioned` | response ID, accepted, modified, or rejected | Observe verification and ownership |
| `tool_invoked` | tool type, parameters, outcome | Record operational investigation |
| `hypothesis_recorded` | version, text, confidence, evidence references | Observe current explanation |
| `hypothesis_revised` | previous version, new version, trigger evidence | Observe adaptation |
| `test_executed` | test ID, expected result, actual result | Record verification behavior |
| `decision_recorded` | action, rationale, risk, timestamp | Observe technical and operational judgment |
| `final_submission` | diagnosis, evidence, remediation, risks, validation | Capture the final ownership claim |

Raw events should remain available for audit even when report generation fails.

## Assessment dimensions

| Dimension | Strong evidence | Weak evidence |
|---|---|---|
| Problem framing | Distinguishes symptoms, constraints, and success criteria | Restates a number without framing the problem |
| Investigation strategy | Chooses high-information evidence and explains why | Opens artifacts randomly or follows one clue blindly |
| Hypothesis quality | Forms plausible, testable explanations | Jumps directly to an unsupported conclusion |
| Evidence use | Connects metrics, traces, logs, and code to the diagnosis | Lists observations without showing relevance |
| AI direction | Provides context and asks specific, useful questions | Uses vague prompts or delegates the whole decision |
| AI verification | Checks assumptions and tests suggestions | Accepts a plausible answer without verification |
| Adaptability | Revises a hypothesis when evidence contradicts it | Ignores conflicting evidence |
| Technical conclusion | Identifies the root cause and proposes a safe change | Suggests broad rewrites or unrelated infrastructure changes |
| Communication | Explains evidence, risks, uncertainty, and validation | Gives an answer without a defensible evidence chain |

Weights should remain scenario-versioned and reviewable. The MVP can begin with equal or simple documented weights rather than presenting them as scientifically calibrated.

## Deterministic scoring principles

Start with transparent rules tied to events and scenario evidence.

Example rules for the homepage-latency scenario:

```text
+10  Reviews request timing or traces before recommending a code change
+10  Uses healthy CPU and downstream services to narrow the hypothesis
+10  Finds the sequential orchestration in the source code
+10  Confirms that calls are independent before proposing concurrency
+10  Describes both correctness and latency validation
+10  Revises an earlier hypothesis after contradictory evidence
-10  Recommends scaling CPU without evidence of saturation
-10  Accepts an AI recommendation without checking its assumptions
-15  Submits a diagnosis with no cited evidence
```

Rules must account for equivalent valid strategies. A candidate should not lose points solely because they inspected evidence in a different defensible order.

Every reported score must include:

- rubric criterion;
- contributing event or submission evidence;
- applied rule or constrained written-response rubric;
- scenario version;
- any unavailable evidence or scoring exclusion.

## Contextual metrics

Record but do not score in isolation:

- elapsed active time;
- number of iterations;
- evidence panels or stations visited;
- investigation order;
- prompt count;
- token count;
- tool-call count;
- files and folders searched;
- number of hypotheses.

A smaller number is not automatically better. Efficient investigation means reaching a defensible conclusion with appropriate evidence, not minimizing activity at any cost.

## Proof Replay

The recruiter report should contain:

1. Scenario, version, duration, and completion status.
2. Dimension-level scores with rubric-linked evidence.
3. A chronological investigation timeline.
4. Initial and revised hypotheses with confidence ratings.
5. Evidence viewed, searches, and tests.
6. AI prompts, relevant responses, and the candidate's follow-up actions.
7. Final diagnosis, remediation, risks, and validation plan.
8. Technical errors or unavailable evidence that affected scoring.
9. Suggested human-interview questions.
10. A visible limitation and human-review notice.

Do not present a raw prompt list as a proxy for reasoning quality. Pair a prompt with its context, purpose, result, and subsequent action.

## LLM usage boundary

An LLM may:

- summarize a recorded event timeline;
- identify evidence relevant to a predefined criterion;
- apply a constrained rubric to a written explanation;
- suggest follow-up interview questions;
- translate approved content where quality has been reviewed.

An LLM must not:

- invent events or evidence;
- create opaque capability scores;
- assign psychological traits;
- make the employment decision;
- penalize a candidate for a platform outage;
- freely generate an unreviewed high-stakes assessment.

Store the model, prompt version, output, and cited events for any AI-assisted report content. When AI analysis is unavailable, preserve the deterministic score and raw evidence for manual review.

## Privacy, fairness, and accessibility

### Notice and consent

Tell candidates what is collected, why it is collected, who can review it, how long it is retained, and how to request support or correction.

### Do not score unrelated behavior

- typing speed;
- mouse movement;
- gaming reflexes;
- facial expressions;
- voice accent;
- device performance;
- time lost to platform errors.

### Accessibility

- Provide keyboard-accessible controls.
- Avoid required game movement.
- Offer text alternatives to audio.
- Keep contrast, focus, and error messages clear.
- Validate language variants rather than assuming translations are equivalent.
- Allow reasonable additional time or accommodations without treating them as weaker performance.

### Scenario fairness

Use versioned, reviewed scenarios and common rubrics. Compare variant difficulty, reviewer agreement, language effects, device effects, accessibility needs, and AI familiarity before real hiring use.

## Human review

VibeProof is decision support. A human reviewer should:

- inspect the evidence behind unusual or low scores;
- consider technical errors and accommodations;
- use the report to ask targeted questions;
- avoid ranking candidates solely by one aggregate score;
- document the final decision independently of the platform.

The prototype should provide evidence and uncertainty, not an automated employment verdict.
