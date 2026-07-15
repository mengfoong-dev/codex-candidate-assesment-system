# Godot App Repository Layout Design

## Status

Approved by the user on 2026-07-15.

## Decision

Move the active Godot project from:

```text
prototypes/godot-incident-room/
```

to:

```text
apps/incident-room/
```

The `prototypes` name was correct while the Godot experience was an optional experiment. It is no longer accurate now that the Godot candidate flow is the primary application being built and scoring is planned as a separate later backend.

## Target repository structure

```text
apps/
`-- incident-room/
    |-- project.godot
    |-- export_presets.cfg
    |-- README.md
    |-- THIRD_PARTY_NOTICES.md
    |-- assets/
    |-- data/
    |-- licenses/
    |-- scenes/
    |-- scripts/
    `-- tests/
docs/
skills/
tools/
```

Do not create an empty `services/` tree during this migration. When backend scoring begins, its separately approved design may introduce:

```text
services/scoring/
```

The Godot app and future service will communicate through the versioned event contract, not through Godot scene or movement state.

## Ownership boundaries

`apps/incident-room/` owns:

- Godot project and export configuration;
- game scenes, scripts, assets, and tests;
- controlled scenario data used by the game;
- local JSONL event recording and unscored summary presentation;
- app-specific verification and licensing files.

Repository-level `docs/` owns product, assessment, architecture, and implementation documentation. Repository-level `tools/` and `skills/` remain operational support and are not read by the running game.

Future `services/scoring/` will own scoring policy, rubric evaluation, service APIs, and scored-result persistence. It will not own candidate movement, camera behavior, Godot UI, or local scene state.

## Migration scope

The migration must:

1. move the complete Godot directory without changing file contents unnecessarily;
2. preserve Git rename history;
3. update root README and documentation-index links;
4. update active specs, plans, commands, and repository path examples;
5. update the Godot project README and verification commands;
6. describe `apps/incident-room` as the current application, not a disposable prototype;
7. leave raw historical session rows unchanged;
8. remove the empty `prototypes/` directory after the move;
9. avoid creating backend folders or scoring implementation.

## Error handling

- Abort if `apps/incident-room/` already exists.
- Abort if the source project is missing `project.godot` or its verification script.
- Compare the source and destination tracked-file sets before committing.
- Treat any remaining active `prototypes/godot-incident-room` reference as a migration failure.
- Do not rewrite references inside the dated archive or immutable session CSV when they describe historical work.
- If Godot import or tests fail after the move, fix path assumptions before continuing feature work.

## Verification

The migration is accepted only when:

1. `apps/incident-room/project.godot` exists and `prototypes/godot-incident-room/` does not;
2. all tracked Godot files are represented as renames or intentional documentation edits;
3. active non-archive documentation contains no old project path;
4. all rendered local Markdown links resolve;
5. this command passes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File apps/incident-room/scripts/development/verify_project.ps1
```

6. Godot reports version `4.7.1.stable` and all discovered suites pass;
7. `git diff --check` passes;
8. the move is committed on `main` and pushed to `origin/main`.

## Result

The repository becomes an application-oriented monorepo foundation: the Godot candidate experience lives under `apps/incident-room`, while future backend scoring can be added under `services/scoring` without moving the game again.
