# Hackathon Work Outcomes

This file is the human-readable summary for the final hackathon explanation. The detailed activity log is in `sessions.csv`; recorded duration is reported there, while account-level spend and usage units remain manual when available.

## Current VibeProof outcome

VibeProof is now the canonical product direction:

- Product format: **Ownership Challenge**
- Primary scenario: **Homepage Latency Spike**
- Candidate environment: focused web engineering workspace
- Prototype experiment: optional Godot Incident Room scaffold
- Evidence output: **Proof Replay**
- Assessment boundary: observable work evidence with human review
- Historical material: preserved in the [pre-VibeProof archive](../../archive/2026-07-pre-vibeproof/README.md)

Current documentation:

- [Product brief](../../product/product-brief.md)
- [User scenario](../../product/user-scenario.md)
- [MVP scope](../../product/mvp-scope.md)
- [Evidence and scoring](../../assessment/evidence-and-scoring.md)
- [Product decisions](../../decisions.md)

The older discovery notes below describe the sequence that led to the current direction. Mentions of `Patch & Ship` and the former `docs/research/meng/` path are historical, not current guidance.

## Recorded sessions

| Session | Agent | Duration | Focus |
| --- | --- | ---: | --- |
| `S-20260714-111244` | Codex | 2.7 minutes | Product direction, assessment design, and delivery planning |
| `S-20260714-115252` | Codex | 0.1 minutes | Skill and usage-tracking setup |
| `S-20260714-115920` | Codex | 0.5 minutes | Usage summary and CSV update |
| `S-20260714-130800` | Codex | 0 minutes | Codex lifecycle-hook implementation |
| `S-20260714-131501` | Codex | 0 minutes | Stale-session recovery implementation |
| `S-20260714-140301` | Codex | 2 minutes | Full worktree verification and commit |
| `S-20260714-162520` | Codex | 0.9 minutes | Included-plan usage-log update |
| `S-20260715-110517` | Codex | 1.1 minutes | Session CSV diagnosis |
| `S-20260715-111800` | Codex | 6.6 minutes | Miro board review and research synthesis |
| `S-20260715-112832` | Codex | 0.9 minutes | Documentation-structure audit |
| `S-20260715-113308` | Codex | 2.2 minutes | Documentation-organization design |
| `S-20260715-113622` | Codex | 3.3 minutes | Documentation-migration plan |
| `S-20260715-114543` | Codex | 10.6 minutes | VibeProof documentation migration |
| `S-20260715-115920` | Codex | 4.6 minutes | Repository-wide VibeProof reference update |
| `S-20260715-152642` | Codex | 5.8 minutes | Single-player office-incident concept |
| `S-20260715-153826` | Codex | 4.4 minutes | Office-layout and camera comparison |
| `S-20260715-154348` | Codex | 2.1 minutes | Third-person room and interaction design |
| `S-20260715-155226` | Codex | 1.7 minutes | Incident-room environment comparison |
| `S-20260715-155837` | Codex | 0.5 minutes | Hybrid Incident Room architecture |
| `S-20260715-160737` | Codex | 9.3 minutes | Incident Room MVP design and resource plan |
| `S-20260715-162841` | Codex | 3.9 minutes | Free diorama art-direction specification |
| `S-20260715-163403` | Codex | 171.1 minutes | Godot MVP implementation plan |
| `S-20260715-194007` | Codex | 91.4 minutes | Godot scaffold and scenario-loader checkpoint |
| `S-20260715-212631` | Codex | 3.6 minutes | Godot-first candidate-flow design |
| `S-20260715-213054` | Codex | 7.9 minutes | Godot-first candidate-flow implementation plan |
| `S-20260715-214140` | Codex | 6.7 minutes | Godot event, persistence, and session-state implementation |
| `S-20260715-215438` | Codex | 0.9 minutes | Godot app repository-layout decision |

## 14 July 2026 - Historical product discovery

Goal: turn the research and hackathon brief into a credible, feasible product direction.

Outcomes:

- Selected the working brand `VibeProof`.
- Defined the product promise: `Build with AI. Prove you know why it works.`
- Defined the early `Patch & Ship` assessment concept, later superseded by the VibeProof Ownership Challenge.
- Defined the `Proof Loop`: Plan -> Build -> Verify -> Break -> Fix -> Explain.
- Reframed the problem from detecting AI use to assessing responsible AI-assisted engineering.
- Designed a candidate journey from HR invitation through consent, tutorial, incident simulation, decisions, and final explanation.
- Compared VibeProof with LeetCode and defined the complementary capability gap: realistic debugging, verification, prioritization, risk management, and explanation.
- Established a defensible evidence boundary: observe behavior and explanations; do not claim to read thoughts or measure neuroscience without sensors.
- Designed a feasible fixed game shell with manager-generated scenario configuration instead of regenerating a new game for every role.
- Created the initial research tree under `docs/research/meng/`; that material now lives in the dated archive.

## 15 July 2026 - Documentation consolidation

Outcomes:

- Made VibeProof the only active product direction.
- Defined the Homepage Latency Spike candidate and recruiter scenario.
- Consolidated the product brief, MVP scope, evidence model, research, and decisions.
- Archived earlier KerjaProof, Miro, game-engine, and debate material.
- Preserved both research PDFs without changing their file hashes.
- Verified active local links, terminology, claim boundaries, and archive completeness.

## Evidence to show judges

The strongest demo evidence is not the number of prompts used. It is the chain:

```text
Problem framing -> research validation -> Ownership Challenge -> observable candidate evidence -> Proof Replay -> human interview
```
