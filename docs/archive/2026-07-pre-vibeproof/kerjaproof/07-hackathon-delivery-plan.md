# Hackathon Delivery Plan

## Team structure

### Intermediate member 1: Product and pitch

- User problem
- Malaysian SME persona
- Scenario and research
- Presentation
- Responsible-AI explanation

### Intermediate member 2: Technical lead

- Application structure
- Data flow
- Deployment
- Integration
- Backup demo

### Intermediate member 3: Frontend or Unity experience

- Candidate experience
- Simulation interface
- Employer report
- Visual polish

### Intermediate member 4: Scoring and AI

- Competency rubric
- Event schema
- Rule-based scoring
- Optional AI evaluation
- Evidence generation

### Entry-level member: QA and content

Pair this person with the frontend or scoring lead. Own:

- Scenario wording
- Test cases
- English and Bahasa Melayu review
- Seeded candidate profiles
- User-flow testing
- Demo checklist

## Four-day schedule

### Day 1: Lock the vertical slice

- Confirm the software-engineering scenario.
- Write the competency rubric.
- Build the mission briefing.
- Build the first code/logs/test interaction.
- Define the event schema.

Checkpoint: a candidate can begin and complete the core mission.

### Day 2: Add scoring and evidence

- Implement deterministic scoring.
- Add the AI-generated pull request.
- Add the hidden edge case.
- Add confidence calibration.
- Generate the capability profile.

Checkpoint: one completed mission produces a report with evidence.

### Day 3: Add employer value and polish

- Add three seeded candidate profiles.
- Add candidate comparison.
- Add human-review disclaimer.
- Add bilingual labels.
- Add error states and responsive layout.

Checkpoint: a judge understands the employer value within one minute.

### Day 4: Freeze and rehearse

- Deploy the demo.
- Test on another laptop.
- Record a backup video.
- Prepare screenshots.
- Rehearse the live flow.
- Freeze new features.

Checkpoint: the complete demo works in under five minutes.

## Technical recommendation

If no one already has Unity experience, use a browser prototype with React, Vite, and TypeScript. Store the scenario and seed data in JSON, use local storage for session state, and keep scoring deterministic.

The demo should not depend on an external AI API. AI can be used for the explanation layer, but the core assessment must still work if the API is unavailable.

## Definition of done

- Candidate completes one mission in five to seven minutes.
- The system records decisions and timestamps.
- A score appears in under 30 seconds.
- Every capability score has evidence.
- Three candidate profiles show different strengths and weaknesses.
- The product works in a live demo and offline backup.
- The team can explain what is measured and what is not measured.
