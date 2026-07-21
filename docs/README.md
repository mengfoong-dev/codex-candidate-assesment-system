# VibeProof Documentation

This is the canonical documentation index for VibeProof. Active product guidance lives in the files below; superseded exploration is retained separately as historical context.

## Current direction

VibeProof is an AI-allowed Ownership Challenge for software-engineering candidates. The current application is the Godot Incident Room using the Homepage Latency Spike scenario. It completes the local candidate flow and evidence record first; backend scoring and recruiter-facing results follow later. Start with the product documents below and use `decisions.md` to resolve any ambiguity.

## Product

- [Product brief](product/product-brief.md) - problem, users, positioning, and non-goals.
- [User scenario](product/user-scenario.md) - candidate and recruiter journeys for the homepage-latency challenge.
- [MVP scope](product/mvp-scope.md) - the first complete vertical slice and success criteria.

## Assessment

- [Evidence and scoring](assessment/evidence-and-scoring.md) - observable events, rubric, Proof Replay, and human-review boundaries.

## Backend API

- [FastAPI API access guide](backend/API_ACCESS.md) - start the API, share it safely on a private network, configure CORS, and smoke-test it with peers.
- [API contract](backend/00-api-contract.md) - frozen endpoint, request, response, event-stream, and error-envelope contract.

## Research and decisions

- [Research, validation, and market](research/validation-and-market.md) - evidence, competitors, assumptions, and validation roadmap.
- [Product decisions](decisions.md) - settled choices, presentation-layer boundary, and open questions.

## Operational records

- [Startup playbook](STARTUP-PLAYBOOK.md) - one command to start the local FastAPI backend and Godot application.
- [Project final state](FINAL-STATE.md) - current whole-project runtime and verification handoff.
- [Agent usage records](hackathon/codex-usage/README.md) - generated session and outcome logs for the hackathon project.

## Godot application

- [Cozy Toy Office visual-overhaul design](superpowers/specs/2026-07-16-godot-cozy-toy-office-visual-overhaul-design.md) - approved CC0 asset, room, character, UI, licensing, and Web-performance direction.
- [Godot-first candidate-flow design](superpowers/specs/2026-07-15-vibeproof-godot-first-candidate-flow-design.md) - current implementation priority: complete local candidate flow and event logging before backend scoring.
- [Godot Incident Room design](superpowers/specs/2026-07-15-vibeproof-incident-room-mvp-design.md) - room, interaction, visual, and responsible-assessment constraints.
- [Godot-first implementation plan](superpowers/plans/2026-07-15-vibeproof-godot-first-candidate-flow.md) - current test-first delivery plan with scoring deferred.
- [Godot application README](../apps/incident-room/README.md) - current status, pinned toolchain, controls, verification, and licensing.

## Historical material

- [Pre-VibeProof archive](archive/2026-07-pre-vibeproof/README.md) - earlier branding, platform exploration, Miro material, research sources, and product debates.

Archived documents may contradict current decisions. Use this index and `docs/decisions.md` when determining the active product direction.
