# Open Questions and Validation Plan

## Unvalidated assumptions

1. Malaysian engineering hiring teams receive enough AI-assisted portfolios or take-home work for ownership verification to be a meaningful problem.
2. A 10- to 15-minute challenge is acceptable to candidates.
3. Recruiters and engineering managers understand and trust a Proof Replay more than a single score.
4. Employers will use the evidence to change who reaches an interview or what they ask during it.
5. Artifact-grounded questions can remain comparable across candidates.
6. Local context, bilingual support, and small-team pricing materially influence purchasing.
7. Employers will pay for a verification layer rather than use a short live call.

## Customer discovery questions

Ask employers about the last real engineering hire rather than asking whether the idea sounds interesting.

1. How many applications and technical submissions did you review?
2. How many engineering hours were used before making an offer?
3. Which assessment, take-home, interview, or portfolio process did you use?
4. What did that process fail to reveal?
5. Have you interviewed or hired someone who could produce code but could not explain or maintain it?
6. How do you currently handle AI-assisted candidate work?
7. Would you send a 10- to 15-minute ownership challenge before an engineer interview?
8. Which evidence would make the resulting report trustworthy?
9. What would make you refuse to use the product?
10. Would you pay per candidate, per vacancy, or through a subscription?

## Initial validation threshold

Before claiming product-market demand:

- Interview at least five Malaysian technical recruiters or engineering managers.
- Obtain at least three confirmations of the same painful workflow problem.
- Obtain at least two commitments to test a pilot with real or representative candidates.
- Record current screening time and compare it with the pilot workflow.

These are early discovery thresholds, not proof of product-market fit.

## Assessment validation questions

- Do senior engineers agree on what strong evidence looks like?
- Do equivalent challenge variants have similar difficulty?
- Can reviewers reach similar ratings from the same Proof Replay?
- Do novice and experienced engineers produce meaningfully different evidence patterns?
- Does language choice alter the score?
- Does device, accessibility need, or AI familiarity create irrelevant disadvantage?
- Does the report improve the quality or consistency of later interviews?

## Product risks and controls

| Risk | Initial control |
|---|---|
| Generated question is incorrect | Use audited archetypes and require manager approval |
| Candidate artifacts contain secrets | Limit scope, scan files, redact, and require explicit consent |
| Arbitrary code is unsafe | Use a preloaded artifact for the MVP and isolated execution later |
| Adaptive tasks are unequal | Apply one common rubric and calibrated variants |
| LLM scoring is inconsistent | Use deterministic rules for scores and AI only for summaries |
| Candidate is disadvantaged by language | Provide English and Bahasa Malaysia where validated |
| Automated score affects employment unfairly | Require human review and provide an evidence trail |
| Assessment becomes too long | Keep one artifact, one incident, and three proof moments |

## Hackathon success criteria

The prototype succeeds if judges can understand and observe this sequence:

```text
Candidate claims an artifact
  -> VibeProof introduces a relevant failure
  -> candidate investigates and uses AI
  -> candidate verifies or fails to verify the output
  -> employer receives a transparent Proof Replay
```

The prototype does not need to prove predictive validity during the hackathon. It must demonstrate a credible, testable hypothesis and clearly state the future validation work.

## Immediate decisions still required

- Confirm the first buyer segment: startup, recruitment agency, graduate programme, university, or mid-sized technical employer.
- Confirm whether the MVP begins with a candidate artifact or a controlled sample artifact presented as a portfolio submission.
- Finalise the six to ten observable events used in scoring.
- Finalise the human-readable capability rubric.
- Decide whether Databricks is required for the core demo or shown as the analytics architecture.
- Treat ElevenLabs as optional unless the core ownership flow is already complete.
