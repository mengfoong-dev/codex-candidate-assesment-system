# KerjaProof

> See capability in action.

KerjaProof is a research-informed capability assessment product for AI-assisted software engineering.

## The problem we are solving

Generative AI has changed how software is produced and how candidates present themselves. A candidate can use AI to generate a polished résumé, build a convincing prototype, or submit code that they do not fully understand.

This creates a hiring problem for Malaysian SMEs and startups:

> A résumé or code submission may show what was produced, but not whether the candidate can understand, verify, debug, test, and take responsibility for the result.

Traditional hiring signals are becoming weaker because:

- Résumés can be optimized with AI.
- Take-home projects can be generated with AI.
- Interviews can test explanation rather than real execution.
- Algorithm tests may not represent daily engineering work.

## Our solution

KerjaProof places a software-engineering candidate in a short, realistic AI-assisted production incident called **Patch & Ship**.

The candidate must:

- Inspect code, requirements, logs, and test results.
- Review an AI-generated pull request.
- Predict possible failure points.
- Run tests and investigate evidence.
- Decide whether to improve, deploy, or roll back.
- Adapt when a new incident appears.
- Explain the final technical decision.

The system produces a transparent capability profile showing evidence of:

- Technical correctness
- AI verification
- Error detection and correction
- Problem understanding
- Adaptability
- Confidence calibration

KerjaProof does not try to detect whether a candidate used AI. We allow AI and evaluate whether the candidate can responsibly direct, verify, debug, test, and own AI-assisted code.

## Product positioning

> AI can generate code. Can you own it?

KerjaProof is not an ATS, an AI-code detector, or an automatic hiring decision-maker. It is a human-review tool that exposes observable evidence from a controlled work simulation.

## Hackathon timeline

### Official event dates

- **8 July 2026, 11:59 PM MYT** — Confirmation deadline
- **11 July 2026** — Online kickoff, team formation, and project scoping
- **11–17 July 2026** — Online preparation week, mentor support, partner sessions, and build preparation
- **13 July 2026, 7:00–10:00 PM MYT** — Databricks workshop: Build and deploy AI agents on Databricks
- **18 July 2026** — Physical hackathon, demos, judging, and prize ceremony at Sunway University

### Project delivery plan

This plan assumes work begins on **14 July 2026**:

- **14 July** — Lock the software-engineering scenario, scoring rubric, and candidate simulation.
- **15 July** — Build event tracking, deterministic scoring, AI-generated pull request review, and capability report.
- **16 July** — Add employer view, seeded candidate profiles, bilingual labels, consent, and responsible-AI messaging.
- **17 July** — Deploy, test on another laptop, record a backup demo, freeze features, and rehearse.
- **18 July** — Run the live demo, explain the research basis, and present the product story.

Because the current date is 14 July 2026, the confirmation deadline, kickoff, and Databricks workshop have passed. If confirmation was not submitted, contact the organizers immediately through the provided Discord channel and request late confirmation and kickoff materials.

## Research and findings

All research findings, product decisions, research links, psychology/neuroscience notes, Unity feasibility analysis, branding, pitch language, and delivery planning are in:

- [Research findings index](docs/research/meng/README.md)
- [Problem and research validation](docs/research/meng/01-problem-and-research-validation.md)
- [Product concept and MVP scope](docs/research/meng/02-product-concept-and-mvp.md)
- [Vibe-coding assessment](docs/research/meng/03-vibe-coding-assessment.md)
- [Psychology and neuroscience foundation](docs/research/meng/04-psychology-and-neuroscience.md)
- [Unity 3D and serious-game feasibility](docs/research/meng/05-unity-3d-feasibility.md)
- [Branding and positioning](docs/research/meng/06-branding-and-positioning.md)
- [Hackathon delivery plan](docs/research/meng/07-hackathon-delivery-plan.md)
- [Pitch language and responsible claims](docs/research/meng/08-pitch-and-claims.md)

The original research document is available at [Research Validation & Industry Evidence](docs/research/meng/Research%20Validation%20%26%20Industry%20Evidence%20%281%29.pdf).

## Research limitation

KerjaProof is a research-informed hackathon prototype, not yet a scientifically validated psychometric hiring test. The prototype should not claim to read thoughts, measure brain activity, predict job performance, detect cheating, or automatically reject candidates.

The immediate goal is to demonstrate a credible and testable hypothesis:

> Observable behavior during a realistic AI-assisted engineering task can provide useful evidence that a résumé or unverified code submission cannot.
