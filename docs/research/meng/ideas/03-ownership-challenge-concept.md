# VibeProof Ownership Challenge

## Product statement

> Bring the work you built. Prove you can own it.

VibeProof is a short verification challenge that asks a candidate to demonstrate understanding, verification, adaptation, and responsibility for a software artifact they claim as their work.

It does not attempt to prove who typed every line. It asks whether the candidate can safely own the result.

## Position in the hiring journey

```text
Application
  -> portfolio, take-home, pull request, or baseline assessment
  -> VibeProof Ownership Challenge
  -> Proof Replay for the hiring team
  -> targeted human interview
```

## Candidate journey

1. Receive an HR link containing the role, duration, AI policy, privacy notice, and accessibility options.
2. Complete a short interface tutorial.
3. Review the selected artifact and incident briefing.
4. State an initial hypothesis and confidence level.
5. Inspect relevant code, logs, requirements, and tests.
6. Use the built-in AI assistant if helpful.
7. Respond to new evidence or a changed requirement.
8. Run or select a meaningful verification step.
9. Choose whether to fix, roll back, deploy, or escalate.
10. Explain the final decision and supporting evidence.

## Proof moments

Every challenge contains three required moments.

### Explain

The candidate explains what a selected component does, why it exists, and which assumptions it makes.

### Break

VibeProof introduces or reveals a realistic failure that challenges those assumptions.

### Adapt and verify

The candidate changes the solution or recommendation, then demonstrates why it is safer.

## Demonstration scenario

A candidate submits an AI-assisted e-commerce checkout project. The selected artifact contains payment retry logic.

Initial event:

> Customers are reporting duplicate orders after a deployment.

Available evidence:

- Payment service code diff
- Request and provider logs
- Existing unit tests
- Customer incident timeline
- AI assistant
- Rollback and deployment decisions

New condition:

> The provider may process a payment successfully but return a timeout before the application receives the response.

Expected ownership evidence includes recognising the retry and idempotency risk, reproducing or testing it, selecting a safe operational action, and explaining the final decision.

## Evidence captured

- Initial hypothesis and confidence
- Artifacts inspected
- Order of investigation
- Tests run or requested
- AI prompts and responses
- Suggestions accepted, modified, or rejected
- Decision changes after new evidence
- Final technical and operational decision
- Final explanation and confidence

## Initial scoring rubric

| Dimension | Weight |
|---|---:|
| Artifact understanding | 25% |
| AI-output verification | 25% |
| Debugging and adaptation | 25% |
| Risk and operational judgment | 15% |
| Explanation and confidence calibration | 10% |

Time is context, not the primary score. A fast but unverified answer should not automatically beat a slower, evidence-based answer.

## Employer output: Proof Replay

Example:

```text
01:12  Identified payment retry as a possible cause
02:03  Asked AI to explain retry behavior
03:14  Accepted the initial recommendation
04:30  Ran the duplicate-payment test; it failed
05:02  Revised the hypothesis
06:15  Added idempotency protection
07:20  Re-ran the test; it passed
08:10  Recommended rollback before redeployment
```

The report summarises evidence and suggests human follow-up questions. It does not make the hiring decision.

## Safe generation architecture

```text
Selected artifact
  -> secret and scope checks
  -> static analysis
  -> audited challenge-archetype selection
  -> manager review and approval
  -> fixed candidate workspace
  -> event log and deterministic rules
  -> evidence summary for human review
```

The system should select from tested challenge archetypes instead of freely inventing an assessment. This reduces hallucination, inconsistent difficulty, and unsafe execution.

## Hackathon scope

Build:

- One preloaded checkout artifact
- One retry and idempotency incident
- Explain, break, and adapt proof moments
- One built-in AI interaction
- A small set of observable events
- Rule-based scoring
- One Proof Replay and capability report

Do not build:

- Arbitrary GitHub repository execution
- Multiple languages or roles
- Full IDE infrastructure
- Proctoring or identity verification
- Automatic hiring decisions
- 3D navigation
- Direct cognitive-load measurement
