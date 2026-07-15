# Unity 3D and Serious-Game Feasibility

## Can the product be a 3D Unity game?

Yes. Unity can provide an immersive interface for the simulation, but the 3D environment is only the presentation layer. The assessment validity comes from the job-relevant scenario, the competency rubric, and the mapping between actions and evidence.

## Feasible Unity concept

### Patch & Ship: Incident Room

Create one low-poly software-team room with three interactive stations:

1. **Logs**: inspect error messages and customer impact.
2. **Code**: inspect the AI-generated patch and requirements.
3. **Deployment**: run tests, deploy, monitor, or roll back.

The candidate makes three or four important decisions within five to seven minutes.

## What Unity should not measure

Avoid mechanics involving:

- Fast movement
- Aiming or reflexes
- Complex camera control
- VR hardware
- Hidden observation through biometrics
- Gaming skill unrelated to software engineering

These can introduce construct-irrelevant variance: performance differences caused by gaming or hardware familiarity rather than engineering capability.

## Research limitations

A VR game-based assessment study with 103 participants found only moderate-to-weak relationships between a VR game and intelligence-test performance. The authors suggested VR as a supplementary or pre-screening tool rather than a replacement for validated assessments, and noted potential bias from gaming experience and hardware familiarity. [Simons et al., 2023](https://link.springer.com/article/10.1007/s10055-023-00752-9)

The game-based personnel-selection literature also emphasizes the need to establish reliability, construct validity, predictive validity, fairness, and applicant acceptance. [Systematic review](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2022.952002/full)

## Recommendation for this hackathon

Use Unity 3D only if at least one intermediate team member already knows Unity and C#.

If the team does not have Unity experience, build a browser-based 2D or 2.5D simulation. A polished decision flow is more valuable than an unfinished 3D world.

## Unity MVP implementation

- One scene
- One incident
- Three interactive stations
- One AI-generated pull request
- One hidden defect
- Three decision points
- Deterministic event logging
- Final report either inside Unity or in a simple web view

## Research positioning

Use:

> Unity provides the immersive environment for a research-informed behavioral simulation.

Avoid:

> Unity allows us to read the candidate's cognitive state.
