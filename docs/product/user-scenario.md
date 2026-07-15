# VibeProof User Scenario

## Actors

- **Candidate:** completes an AI-allowed engineering Ownership Challenge.
- **Recruiter:** sends the assessment and reviews the resulting evidence.
- **Technical interviewer:** uses the Proof Replay to prepare targeted follow-up questions.
- **Assessment system:** provides controlled evidence, records actions, applies deterministic rules, and prepares the report.

## Scenario: Homepage Latency Spike

The MVP uses one controlled incident.

### Candidate brief

> Users report that the homepage feels slow. Its p95 latency increased from 180 ms to 850 ms. CPU utilization is 35%. Identify the performance bottleneck, support the diagnosis with evidence, and propose a safe improvement. Rewriting the system is outside the task scope.

### Seeded system state

| Signal | Value |
|---|---|
| Homepage p95 latency | 850 ms |
| CPU utilization | 35% |
| Database | Healthy |
| Recommendation service | Healthy |
| Redis hit rate | 42% |
| Hidden root cause | Independent API calls executed sequentially |

The Redis value is a plausible distraction. The scenario rewards investigation, not guessing the most unusual number.

## Candidate journey

### 1. Invitation and notice

The candidate receives a link containing:

- role and expected duration;
- permitted AI usage;
- evidence that will be collected;
- privacy and human-review notice;
- language and accessibility options;
- session-resume policy.

### 2. Tutorial

A short tutorial explains how to inspect evidence, record a hypothesis, use the AI assistant, run a verification step, and submit a conclusion. Tutorial performance is not scored.

### 3. Mission briefing

The candidate reads the incident, scope boundary, available tools, success criteria, and remaining time. They record an initial hypothesis and confidence level before opening detailed evidence.

### 4. Investigation

The candidate can inspect evidence in any defensible order:

- metrics;
- application and service logs;
- distributed traces;
- relevant source code;
- an AI assistant.

They can search, ask questions, record a new hypothesis, revise an earlier hypothesis, and run or select a test.

### 5. Verification

A strong investigation might proceed as follows:

1. Confirm that the latency increase is real and that CPU is not saturated.
2. Check downstream health and avoid assuming the database is responsible.
3. Inspect traces and find cumulative waiting across several service calls.
4. Open the source code and confirm that independent calls are awaited sequentially.
5. Ask the AI assistant to explain possible concurrency changes and risks.
6. Verify that the calls are actually independent before recommending concurrent execution.
7. State how correctness and p95 latency should be tested after the change.

The assessment does not require this exact order. It requires a defensible evidence chain.

## Investigation application

The current implementation is the Godot Incident Room with:

- the incident description and task boundary;
- three stations exposing metrics, logs, traces, code, verification, and submission;
- an AI conversation panel;
- hypothesis and confidence controls;
- test or verification controls;
- an append-only local event record;
- a structured final-submission form.

The workspace records structured events. It does not score mouse movement, typing speed, gaming skill, facial expressions, voice accent, or unrelated stress behavior.

## Submission

The candidate submits:

- root cause;
- supporting evidence;
- proposed remediation;
- expected impact;
- risks and assumptions;
- validation or rollback plan;
- final confidence level.

Example conclusion:

> The homepage waits for several independent API calls sequentially. Traces show cumulative waiting time while CPU and downstream services remain healthy. Execute only the independent calls concurrently, preserve any required ordering, and validate correctness and p95 latency before deployment.

## Recruiter journey

After submission, the recruiter receives a Proof Replay containing:

- completion status and scenario version;
- dimension-level scores;
- initial and revised hypotheses;
- evidence viewed and searches performed;
- tests or verification steps;
- AI prompts, relevant responses, and subsequent candidate actions;
- final diagnosis and recommendation;
- rubric-linked evidence for every score;
- limitations and suggested interview questions.

The recruiter reviews the evidence and decides what to investigate in the human interview. VibeProof does not make the employment decision.

## Proof Replay example

```text
00:45  Recorded initial hypothesis: Redis cache degradation
01:30  Reviewed CPU and downstream-service metrics
02:10  Opened request trace and noticed cumulative service waits
03:05  Revised hypothesis: sequential independent calls
04:00  Inspected orchestration source code
05:15  Asked AI about safe concurrency and failure handling
06:20  Selected a latency and correctness verification step
07:30  Submitted diagnosis, remediation, risks, and validation plan
```

The timeline provides context. A shorter session is not automatically better than a careful, evidence-based session.

## Presentation-layer boundary

The Godot Incident Room is the first application. It must:

- expose the canonical tools and structured event model;
- remain accessible without game experience;
- avoid scoring navigation speed or spatial control;
- load and run reliably on candidate hardware;
- add engagement without changing the construct being assessed.

The presentation layer does not define the assessment signal. A future web client can use the same scenario and event contract without changing the evidence model.
