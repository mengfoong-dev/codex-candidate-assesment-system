# VibeProof

> Build with AI. Prove you know why it works.

VibeProof is an AI-allowed engineering assessment that helps hiring teams verify whether a candidate can understand, investigate, test, adapt, and take responsibility for software work.

## Current status

The product direction and documentation are consolidated around VibeProof. The baseline MVP is a focused web engineering workspace using the Homepage Latency Spike scenario. Earlier branding, game-engine, Miro, and debate material is preserved in the archive and is not active guidance.

The next delivery goal is to implement the candidate investigation flow, structured event log, deterministic rubric, and recruiter Proof Replay described in the [MVP scope](docs/product/mvp-scope.md).

An optional [Godot Incident Room prototype](prototypes/godot-incident-room/README.md) now provides the independently loadable scenario and validation foundation. It is an in-progress presentation experiment, not a completed replacement for the canonical web workspace.

## What we are building

VibeProof presents a short, realistic engineering **Ownership Challenge**. The candidate works through an incident using code, metrics, logs, traces, tests, and an AI assistant. The platform records observable evidence from the investigation and produces a **Proof Replay** for a human reviewer.

VibeProof is positioned between a portfolio, take-home exercise, or baseline assessment and a human technical interview. It complements existing hiring tools instead of replacing the interview or becoming a full applicant-tracking system.

## User scenario

The MVP uses a **Homepage Latency Spike**:

1. A candidate receives an incident briefing: homepage p95 latency increased from 180 ms to 850 ms while CPU remains at 35%.
2. The candidate inspects metrics, logs, traces, source code, and AI-assisted explanations.
3. They record and revise hypotheses, verify assumptions, and identify sequential independent API calls as the root cause.
4. They submit the diagnosis, supporting evidence, remediation, risks, and validation plan.
5. A recruiter receives a chronological Proof Replay and rubric-linked evidence for human review.

See the complete [candidate and recruiter scenario](docs/product/user-scenario.md).

## What VibeProof measures

VibeProof evaluates observable evidence of:

- problem framing;
- investigation strategy;
- hypothesis quality and revision;
- evidence use;
- responsible AI direction and verification;
- debugging and adaptation;
- technical and operational judgment;
- communication and confidence calibration.

Time, prompt count, token count, and tool-call count are context. They are not direct measures of competence.

## MVP

The first complete vertical slice includes:

- one controlled homepage-latency incident;
- one focused engineering workspace;
- metrics, logs, traces, source code, and AI-assistant tools;
- hypothesis capture and revision;
- structured final submission;
- deterministic scoring;
- one recruiter Proof Replay.

An immersive or spatial interface may be explored later, but it is not required for the MVP and cannot affect the engineering score.

## Documentation

Start with the [documentation index](docs/README.md), then read:

- [Product brief](docs/product/product-brief.md)
- [User scenario](docs/product/user-scenario.md)
- [MVP scope](docs/product/mvp-scope.md)
- [Evidence and scoring](docs/assessment/evidence-and-scoring.md)
- [Research, validation, and market](docs/research/validation-and-market.md)
- [Product decisions](docs/decisions.md)
- [Godot Incident Room design](docs/superpowers/specs/2026-07-15-vibeproof-incident-room-mvp-design.md)
- [Godot Incident Room implementation plan](docs/superpowers/plans/2026-07-15-vibeproof-incident-room-mvp.md)

Historical product explorations and source material are preserved in the [archive](docs/archive/2026-07-pre-vibeproof/README.md).

## Responsible-assessment boundary

VibeProof records candidate actions, prompts, tests, decisions, explanations, and responses to evidence. It does not claim access to private thoughts, reliably determine who generated code, or predict future job performance without validation.

Final hiring decisions remain with people. The prototype provides transparent evidence for a human reviewer and requires future reliability, fairness, accessibility, and job-related validation before high-stakes use.
