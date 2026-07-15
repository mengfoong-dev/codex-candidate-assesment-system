# VibeProof Product Decisions

This file is the canonical decision record. Historical debates and superseded product directions are preserved in the [pre-VibeProof archive](archive/2026-07-pre-vibeproof/README.md).

## Settled decisions

### D001 - Use VibeProof as the product name

Primary tagline:

> Build with AI. Prove you know why it works.

Use **Ownership Challenge** for the assessment format and **Proof Replay** for the recruiter evidence report.

### D002 - Allow AI and assess ownership

Do not attempt to infer code authorship. Evaluate whether the candidate can explain, investigate, test, challenge, adapt, and take responsibility for the result.

### D003 - Position VibeProof as a verification layer

Use this hiring flow:

```text
Application or ATS
  -> portfolio, take-home, or baseline assessment
  -> VibeProof Ownership Challenge
  -> Proof Replay
  -> targeted human technical interview
```

VibeProof complements existing assessment platforms and interviews. It does not rebuild their full infrastructure.

### D004 - Require observable work actions

The product is not a text questionnaire. Candidates must inspect evidence, form and revise a hypothesis, use or challenge AI, run or select a verification step, make a technical decision, and explain the outcome.

### D005 - Report evidence, not private cognition

Approved language:

> VibeProof records evidence of how a candidate investigates, verifies, adapts, and explains software work.

Clicks, prompts, tests, decisions, explanations, and confidence ratings are observable behavior. They do not establish private mental states or stable psychological traits.

### D006 - Use controlled scenarios for the MVP

Start with the homepage-latency scenario and a fixed evidence set. Do not execute arbitrary candidate repositories during the MVP.

Artifact-grounded challenges may be explored later through secret scanning, scope controls, audited challenge archetypes, manager approval, and isolated execution.

### D007 - Use deterministic scoring first

Apply transparent rules to structured events. Use an LLM only for constrained explanation analysis, evidence summaries, and interview-question suggestions.

Every score must cite recorded evidence. When AI analysis is unavailable, preserve deterministic results and route the report to human review.

### D008 - Keep employment decisions human

VibeProof provides evidence and suggested follow-up questions. A recruiter or technical interviewer reviews the context and makes the employment decision.

### D009 - Treat efficiency metrics as context

Time, prompts, tokens, tool calls, files viewed, and iteration counts are contextual. Do not score any of them as a direct proxy for competence.

## Presentation-layer decision

The baseline MVP is a focused web engineering workspace because code, logs, traces, tests, and AI conversations are the work surfaces being assessed.

A Godot 3D office, Phaser 2D map, or other spatial interface is an optional engagement experiment. It may proceed only when it:

- uses the same scenario, event model, and rubric;
- remains accessible without gaming experience;
- does not score navigation speed or controls;
- performs reliably on candidate hardware;
- does not delay the complete assessment and Proof Replay flow.

The presentation layer is replaceable and cannot become part of the engineering signal.

## Assessment boundaries

VibeProof will not:

- attribute source code to a person or model;
- diagnose intelligence, personality, workload, or neural activity;
- treat a fast answer as inherently better;
- penalize candidates for platform failures or accommodations;
- present the prototype as a validated psychometric test;
- claim established demand before customer discovery;
- make the final employment decision.

## Open decisions

1. Which first buyer segment should be prioritized: recruitment agency, graduate programme, startup, or mid-sized technical employer?
2. Should the first pilot use only a controlled artifact, or also accept a tightly scoped candidate artifact?
3. What is the target real-assessment duration beyond the five-minute demo?
4. Which six to ten events form the first scoring rubric?
5. Which evidence should recruiters see, and what should be redacted for candidate privacy?
6. What session-resume policy is fair and operationally practical?
7. Is Databricks required for the demo or only part of the future evidence architecture?
8. Which customer and assessment-validation thresholds must be met before a live hiring pilot?

## Change policy

- Update this file when a product decision changes.
- Move superseded rationale to the dated archive rather than leaving conflicting active guidance.
- Record open questions separately from settled decisions.
- Update affected canonical documents and links in the same change.
- Preserve responsible-assessment and human-review boundaries unless new validated evidence and governance justify a revision.
