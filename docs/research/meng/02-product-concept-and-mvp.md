# Product Concept and MVP Scope

## Product

**KerjaProof: Vibe-to-Production Challenge**

KerjaProof is a serious-game assessment that places a software-engineering candidate in an AI-assisted production incident. The candidate must understand the situation, evaluate AI-generated code, test decisions, manage risk, and explain what should be shipped.

## Target user

- Malaysian SME or startup hiring team
- Junior or intermediate software-engineering recruitment
- Teams that use AI coding tools but need engineers who can still own the result

## Candidate experience

1. Give consent and select English or Bahasa Melayu.
2. Read a short engineering incident briefing.
3. Inspect code, logs, requirements, and test results.
4. Review an AI-generated pull request.
5. Predict possible failure points.
6. Run tests or request additional information.
7. Choose whether to deploy, improve, or roll back.
8. Respond to a new production event.
9. Explain the final technical decision.

## Core scenario

> An AI-generated checkout feature has been deployed. Customers are receiving duplicate orders, a new feature is due soon, and the team must decide whether to patch, deploy, or roll back.

The AI-generated patch should appear plausible but contain a hidden retry or edge-case failure. The candidate should be rewarded for verifying it, not for refusing to use AI.

## Main product screens

### Mission briefing

Shows the task, user impact, constraints, and success criteria.

### Engineering workspace

Provides access to code snippets, logs, tests, requirements, and AI suggestions.

### Decision points

The candidate chooses an action, records a short rationale, and can request evidence.

### Incident update

New information changes the situation and tests cognitive flexibility and adaptation.

### Capability report

Shows capability scores, evidence from actions, confidence calibration, and areas for human review.

## Capability profile

Recommended initial weights:

| Capability | Weight |
|---|---:|
| Technical correctness | 25% |
| AI verification | 20% |
| Error detection and correction | 20% |
| Problem understanding | 15% |
| Adaptability | 10% |
| Confidence calibration | 10% |

Example evidence:

```text
AI Verification: Strong

Observed evidence:
- Inspected the generated patch before accepting it.
- Predicted a retry-related failure.
- Tested the suspected edge case.
- Rejected the patch after the test failed.
```

## MVP features

Must have:

- One role: software engineer
- One production incident
- One AI-generated pull request
- One hidden edge-case bug
- Structured decisions and short explanations
- Event tracking
- Rule-based scoring
- Capability report with evidence
- Three seeded candidate profiles
- Consent and human-review disclaimer
- English and Bahasa Melayu labels where practical
- Deployed demo and offline backup

Stretch features:

- Simple Unity 3D environment
- Interactive code editor
- Secure AI endpoint for response analysis
- Databricks analytics or model deployment
- Additional scenarios

Do not build for the hackathon:

- Full ATS functionality
- Resume parsing
- Authentication and billing
- Multiple job families
- Custom model training
- AI-use detection
- Automatic hiring or rejection
