# VibeProof Incident Room

This Godot 4.7.1 Compatibility project is the primary candidate-facing application for the VibeProof Incident Room. A candidate investigates a scripted homepage-latency incident in a small 3D operations room, records and revises a hypothesis, handles a fixed offline assistant suggestion, validates a proposed remediation, and reviews a local session summary.

The current prototype is intentionally unscored. It records candidate choices and evidence chronology for later human review, but it does not calculate points, produce pass/fail outcomes, rank candidates, infer capability, or make a hiring recommendation.

## Pinned toolchain

Use Godot 4.7.1 Standard from:

```text
%LOCALAPPDATA%\VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe
```

Import project resources and generate stable script UID sidecars:

```powershell
& "$env:LOCALAPPDATA\VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe" --headless --path apps/incident-room --import
```

Run the headless test suite:

```powershell
& "$env:LOCALAPPDATA\VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe" --headless --path apps/incident-room --script res://tests/run_tests.gd
```

The fail-fast combined command is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
```

Launch the application from the repository root:

```powershell
& "$env:LOCALAPPDATA\VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe" --path apps/incident-room
```

## Candidate journey

1. Read the prototype and human-review notices, then begin the briefing.
2. Record an initial root-cause hypothesis and confidence.
3. Move through the cutaway Incident Room and review evidence at the Observability Wall and Developer Desk.
4. Record how the scripted offline assistant suggestion was handled.
5. Revise the hypothesis when the viewed facts support a change.
6. Use the Release Console to choose a cause, remediation, risks, assumptions, validation, rollback, confidence, and rationale.
7. Finish at an explicitly labelled `Unscored prototype summary` that preserves the session chronology and choices without evaluating them.

## Controls

`WASD` moves, `E` interacts with the nearest station, `1`/`2`/`3` open Observability, Developer, and Release directly, `H` opens hypothesis revision, and `Escape` closes the active panel. `Tab`, arrow keys, and `Enter` operate panel controls without a mouse. Navigation speed and game-control performance are not scored.

## Local session evidence

The runtime is offline and stores accepted events as newline-delimited JSON at:

```text
%APPDATA%\Godot\app_userdata\VibeProof Incident Room\vibeproof\sessions\<session-id>\events.jsonl
```

After final submission, the matching unscored summary is written to:

```text
%APPDATA%\Godot\app_userdata\VibeProof Incident Room\vibeproof\sessions\<session-id>\summary.json
```

If either write fails, the journey continues using in-memory events and shows a persistence warning. Stable scenario IDs—not display labels—form the event boundary intended for a future backend. The Godot runtime does not consume the scenario's deferred scoring configuration.

## Responsible-use and offline boundary

The complete core flow is offline. The assistant prompt and response are fixed scenario content labelled as a scripted offline assistant; the prototype never calls a network model and never executes arbitrary candidate code.

This prototype supports human review and does not make an employment decision. Results are scenario-specific evidence, not a validated psychometric judgment.

The scripted assistant response is fixed scenario content. There is no account system, network request, live language model, cloud persistence, arbitrary candidate-code execution, recruiter decision API, or backend scoring in this build.

## Acceptance evidence

Automated acceptance coverage exercises both an evidence-based sequential-call diagnosis and an unsupported CPU-scaling selection. Both routes complete and preserve the candidate's choices in the same unscored summary format. Separate fixtures verify local-write failure and restart isolation.

| Date | Environment | Path | Completion | Persistence |
| --- | --- | --- | --- | --- |
| 2026-07-15 | Godot 4.7.1, Windows 11 Pro for Workstations 10.0.26200 | Evidence-based sequential calls | Reached unscored summary | In-memory writer fixture succeeded |
| 2026-07-15 | Godot 4.7.1, Windows 11 Pro for Workstations 10.0.26200 | Unsupported CPU scaling | Reached unscored summary without evaluation | In-memory writer fixture succeeded |
| 2026-07-15 | Godot 4.7.1, Windows 11 Pro for Workstations 10.0.26200 | Persistence failure | Reached unscored summary | Warning shown; evidence retained in memory |
| 2026-07-15 | Godot 4.7.1, Windows 11 Pro for Workstations 10.0.26200 | Restart | Returned to title with a new session ID | Previous candidate state not reused |

## Windows export evidence

The ignored release build is generated at `apps/incident-room/dist/VibeProof-Incident-Room.exe` with the `Windows Desktop` preset:

```powershell
& "$env:LOCALAPPDATA\VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path apps/incident-room `
  --export-release "Windows Desktop" `
  apps/incident-room/dist/VibeProof-Incident-Room.exe
```

Build verification on 2026-07-15 produced:

- `VibeProof-Incident-Room.exe` — 109,290,480 bytes;
- `THIRD_PARTY_NOTICES.md` — 577 bytes;
- `GODOT_LICENSE.txt` — 1,149 bytes;
- `GODOT_COPYRIGHT.txt` — 100,108 bytes;
- exported executable startup smoke test with `--quit-after 3` — exit code `0`;
- clean-import automated candidate paths — `TESTS PASSED: 9 suites`.

The automated suites complete the candidate journeys in-engine. The exported executable smoke check verifies packaged startup; a human visual/control pass remains appropriate before distributing a hackathon demo build.

## Distribution notices

Distributions must ship `THIRD_PARTY_NOTICES.md`, `licenses/GODOT_LICENSE.txt`, and `licenses/GODOT_COPYRIGHT.txt` beside the executable. The notice and license inventory describe the pinned engine release and must not be omitted from a build handoff.
