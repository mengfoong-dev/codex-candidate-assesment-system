# Miro Board Synthesis and UX Flow

This document organizes the early ideas and wireframes from the exported [Miro board](<My First Board.pdf>) into a coherent assessment flow. It preserves the board's intent while aligning it with the project's current evidence-based positioning.

## Product hypothesis

Traditional technical screening relies heavily on resumes, keyword filtering, live coding, and proctoring. In an AI-assisted development environment, producing code alone is a weaker signal because candidates can delegate generation to an AI tool.

The product should instead observe whether a candidate can:

- understand a technical problem;
- investigate relevant evidence;
- form and revise hypotheses;
- direct an AI assistant effectively;
- verify AI output rather than accepting it blindly;
- identify a root cause;
- explain a defensible engineering decision.

The assessment does not claim to read a candidate's private thought process. It records observable actions, prompts, decisions, explanations, and responses to evidence for human review.

## Target users and hiring stage

Primary users:

- recruiters and hiring managers screening technical candidates;
- technical interviewers reviewing evidence from an assessment;
- candidates completing an AI-assisted engineering simulation;
- recruitment agencies or headhunters supporting technical hiring.

Suggested position in the hiring funnel:

```text
ATS / eligibility filtering
        ->
AI-assisted work simulation
        ->
Evidence-based recruiter review
        ->
Human technical interview
```

The product is a screening aid, not an automatic hiring or rejection system.

## Demonstration scenario

### Homepage Latency Spike

**Duration:** approximately five minutes for a demo; longer for a real assessment.

**Candidate brief:**

> Users report that the homepage feels slow. The p95 homepage latency increased from 180 ms to 850 ms. CPU utilization is 35%. Identify the performance bottleneck and propose an improvement. Rewriting the whole system is outside the task scope.

**Seeded system state:**

| Signal | Value |
|---|---|
| Homepage p95 latency | 850 ms |
| CPU utilization | 35% |
| Database | Healthy |
| Recommendation service | Healthy |
| Redis hit rate | 42% |
| Hidden root cause | Sequential API calls |

**Available evidence:**

- service and infrastructure metrics;
- application logs;
- distributed traces;
- relevant source code;
- an AI assistant that can answer questions or propose changes.

The scenario should include both relevant and irrelevant evidence so that investigation quality is observable. The distractors must remain plausible and job-relevant rather than arbitrary traps.

## Candidate experience

### 1. Start or resume

The candidate can start a new assessment or revisit an allowed past session. A real hiring assessment should clearly state whether resuming is permitted and what activity is retained.

### 2. Mission briefing

Display:

- problem title and difficulty;
- incident description;
- task boundaries and success criteria;
- remaining time;
- run and submit controls.

### 3. Investigation workspace

The original board explores two presentation models:

1. **Integrated engineering workspace:** code editor, evidence panels, AI conversation, output, and result areas.
2. **Gamified spatial workspace:** the candidate moves among stations representing metrics, logs, traces, code, and the AI assistant.

Both models should expose the same assessment actions and event schema. The interface should not reward gaming reflexes, navigation speed, or familiarity with 3D controls.

### 4. Hypothesis and verification

The candidate should be able to:

- record an initial hypothesis;
- inspect evidence in any order;
- ask the AI assistant targeted questions;
- run or request a test;
- revise the hypothesis after new evidence;
- submit a root cause and recommendation.

### 5. Submission

Require a structured final response:

- identified root cause;
- supporting evidence;
- proposed remediation;
- expected impact;
- risks or verification steps.

## Observable event model

Capture events rather than attempting to reconstruct private reasoning.

| Event | Example data |
|---|---|
| Assessment opened | scenario, timestamp, attempt |
| Evidence viewed | station or artifact, duration |
| Search performed | query and result count |
| AI prompt submitted | prompt, timestamp, context references |
| AI response received | response ID, latency, model |
| Tool invoked | tool type, parameters, outcome |
| Hypothesis recorded | text, confidence, timestamp |
| Hypothesis revised | previous and new version |
| Test executed | test name, result |
| Final answer submitted | diagnosis, evidence, remediation |

Do not infer quality from token count, prompt count, or speed in isolation. Those values are contextual indicators, not direct measures of competence.

## Assessment dimensions

Recommended dimensions for the homepage-latency scenario:

| Dimension | What strong evidence looks like |
|---|---|
| Problem framing | Restates the symptom and distinguishes latency from resource saturation |
| Investigation strategy | Checks high-information evidence in a defensible sequence |
| Hypothesis quality | Forms plausible, testable explanations |
| Evidence use | Connects metrics, traces, logs, and code to the diagnosis |
| AI direction | Uses specific prompts and provides relevant context |
| AI verification | Challenges suggestions and verifies proposed changes |
| Adaptability | Revises a hypothesis when evidence contradicts it |
| Technical conclusion | Identifies sequential calls and proposes a suitable improvement |
| Communication | Explains the decision, trade-offs, and validation plan clearly |

Example deterministic signals:

```text
+ Inspects traces or request timing before changing code
+ Connects low CPU utilization with a likely waiting or orchestration problem
+ Finds sequential independent calls in the source
+ Proposes concurrency only where calls are independent
+ Describes validation using latency and correctness checks
- Changes infrastructure without evidence of resource saturation
- Accepts an AI recommendation without inspecting its assumptions
- Submits a diagnosis unsupported by observed evidence
```

## Recruiter report

The recruiter-facing conclusion should contain:

- overall assessment status;
- dimension-level scores;
- a chronological investigation timeline;
- evidence viewed and tests executed;
- hypotheses and how they changed;
- candidate prompts alongside the relevant AI responses;
- final diagnosis and recommendation;
- rubric-linked evidence for every score;
- limitations and items requiring human review.

Avoid presenting a raw prompt list as a proxy for thought quality. Pair each prompt with its context, purpose, resulting evidence, and subsequent candidate action.

## Technical instrumentation

The board proposes capturing activity through hooks or a wrapper around the coding environment and AI assistant. A suitable MVP architecture is:

```text
Candidate workspace
    -> structured event collector
    -> append-only assessment event log
    -> deterministic rubric evaluator
    -> optional constrained LLM analysis of written explanations
    -> recruiter evidence report
```

The evaluator should score only documented rubric criteria. An LLM may summarize evidence or grade constrained written responses, but it should not invent psychological traits or make the final hiring decision.

## Presentation-layer decision

The Miro board's spatial or railway-style concept can make the experience memorable, but it should remain a replaceable presentation layer.

For an immersive 3D direction, Godot is a reasonable choice for a prototype built from a template. For the first validation, keep the scope to one room and five stations: Metrics, Logs, Traces, Code, and AI Assistant. The same backend event model and recruiter report should work with a conventional web workspace.

Validate the 3D layer against four criteria:

- candidates can complete the scenario without learning game controls;
- browser loading and runtime performance are acceptable;
- the team can integrate dashboards, code, and AI interactions reliably;
- the environment adds engagement without changing what is measured.

## MVP scope derived from the board

Build:

- one homepage-latency scenario;
- one candidate workspace;
- metrics, logs, traces, source code, and AI-assistant tools;
- hypothesis capture and revision;
- structured final submission;
- complete event logging;
- deterministic scoring;
- one recruiter evidence report;
- start-new and permitted-session-resume controls.

Defer:

- broad ATS functionality;
- multiple job families;
- automatic hiring decisions;
- personality or cognitive-state inference;
- complex 3D navigation;
- model training based only on prompt or token counts.

## Open decisions

1. Is the first validated interface a conventional engineering workspace or a Godot 3D room?
2. Is the assessment intended for junior, intermediate, or senior candidates?
3. Is five minutes only a demo constraint, or the intended assessment duration?
4. Which candidate actions are permitted during a resumed session?
5. What evidence must be visible to recruiters, and what should be redacted for candidate privacy?
6. How will scoring reliability and fairness be evaluated before real hiring use?
