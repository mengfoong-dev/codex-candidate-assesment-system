# VibeProof Incident Room

This Godot 4.7.1 Compatibility project is the independently loadable foundation for the VibeProof incident-room prototype.

## Pinned toolchain

Use Godot 4.7.1 Standard from:

```text
%LOCALAPPDATA%\VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe
```

Import project resources and generate stable script UID sidecars:

```powershell
& "$env:LOCALAPPDATA\VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe" --headless --path prototypes/godot-incident-room --import
```

Run the headless test suite:

```powershell
& "$env:LOCALAPPDATA\VibeProof\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe" --headless --path prototypes/godot-incident-room --script res://tests/run_tests.gd
```

The fail-fast combined command is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File prototypes/godot-incident-room/scripts/development/verify_project.ps1
```

## Controls

`WASD` moves, `E` interacts, `1`/`2`/`3` open the three stations, `H` opens the hypothesis panel, and `Escape` closes the active panel or opens pause controls. Navigation speed and game-control performance are not scored.

## Responsible-use and offline boundary

The complete core flow is offline. The assistant prompt and response are fixed scenario content labelled as a scripted offline assistant; the prototype never calls a network model and never executes arbitrary candidate code.

This prototype supports human review and does not make an employment decision. Results are scenario-specific evidence, not a validated psychometric judgment.

## Distribution notices

Distributions must ship `THIRD_PARTY_NOTICES.md`, `licenses/GODOT_LICENSE.txt`, and `licenses/GODOT_COPYRIGHT.txt` beside the executable. The notice and license inventory describe the pinned engine release and must not be omitted from a build handoff.
