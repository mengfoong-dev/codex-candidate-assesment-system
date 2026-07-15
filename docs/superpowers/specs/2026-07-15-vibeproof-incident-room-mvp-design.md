# VibeProof Incident Room MVP Design

## Status

Approved for implementation on 2026-07-15 after final user review.

Implementation priority was revised later on 2026-07-15. The [Godot-first candidate-flow design](2026-07-15-vibeproof-godot-first-candidate-flow-design.md) takes precedence for build order and defers scoring until after the complete unscored Godot journey is accepted.

The user approved:

- a single-player, stylized 3D role-playing experience;
- one hybrid software-office and diagnostics-lab room;
- three investigation stations;
- a fixed elevated three-quarter camera with minimal controls;
- automatic structured event capture and an end-of-session Proof Replay;
- Godot as the engine;
- a two-day focused implementation window.

During written-spec review, the user also approved:

- a zero-cost runtime-asset plan;
- a colorful toy-diorama presentation inspired by the general readability of cooperative cooking games and chibi exploration RPGs;
- an orthographic three-quarter room camera instead of a behind-player camera.

The user then requested implementation with suitable online resources gathered for the project.

## Purpose

Build a short, playable Godot prototype that presents VibeProof's controlled homepage-latency incident as an interactive office investigation. The player walks through a believable incident room, inspects operational evidence, revises a hypothesis, verifies a proposed change, and submits a defensible conclusion.

The prototype should demonstrate the complete evidence chain in three to five minutes. It is not intended to prove assessment validity or replace the canonical web workspace.

## Relationship to the canonical product

The repository's canonical MVP remains a focused web engineering workspace. The Godot project is an optional engagement experiment permitted by `docs/decisions.md` and `docs/product/user-scenario.md`.

The prototype must therefore:

- use the same homepage-latency scenario, observable events, and deterministic rules;
- keep navigation and presentation separate from the assessment domain;
- never score walking speed, camera skill, reflexes, or station proximity;
- provide quick-access controls so movement is not required to inspect evidence;
- avoid claims about private thought, personality, intelligence, or future job performance;
- produce evidence for human review rather than an automated employment verdict.

## Chosen approach

Create a standalone Godot 4.7.1 Standard project using GDScript and the Compatibility renderer. The primary target is a Windows x86_64 desktop build. A browser build is a stretch goal only after the desktop flow passes all acceptance tests.

The selected visual direction is an original, colorful low-poly toy diorama:

- one compact, office-first cutaway room with a smaller playful diagnostics corner;
- chunky desks, chairs, cabinets, plants, computers, consoles, and technical props;
- a bright but accessible palette with strong station colors and readable silhouettes;
- one small chibi employee character with idle, walk, and run animation;
- a large observability wall, developer desk, and release console that remain legible from the elevated view;
- an open ceiling, omitted front walls, low partitions, and wide paths that keep the player visible.

Colorful cooperative cooking games and chibi exploration RPGs are visual references only. The prototype must not use extracted assets, copied characters, franchise names in product branding, recognizable maps, proprietary UI, audio, logos, or other protected material from Overcooked, Pokémon, or any other commercial game.

This was selected over:

- Phaser 2D, which is safer for the schedule but does not provide the requested 3D diorama RPG presentation;
- a conventional web-only workspace, which remains the canonical product but does not test the engagement experiment;
- a behind-player, orbiting, or over-the-shoulder camera, which adds unnecessary input, clipping, and accessibility risk;
- a realistic office assembled from unrelated asset packs, which would reduce visual coherence and increase import work;
- a multi-room office, which adds level-design work without improving the evidence chain.

## MVP scope

### Build

- One Windows desktop Godot project.
- One hybrid incident room.
- One controllable employee character.
- Fixed elevated three-quarter orthographic camera.
- Mission briefing and initial-hypothesis capture.
- Observability wall with metrics, logs, and traces.
- Developer desk with source code and a scripted AI interaction.
- Hypothesis revision and confidence update.
- Release console with verification and structured submission.
- Append-only structured event capture.
- Deterministic evidence-based result.
- Automatically generated Proof Replay.
- Minimal input prompts and interface sound effects.
- Local persistence under Godot's `user://` directory.

### Defer

- Multiplayer or networking.
- Accounts, authentication, cloud saves, APIs, databases, or a backend.
- A live LLM or external AI service.
- Arbitrary code execution or repository access.
- Multiple incidents, rooms, roles, or difficulty levels.
- Combat, inventory, quests, skill trees, NPC schedules, or dialogue trees.
- Voice acting, cutscenes, motion capture, facial animation, or complex character customization.
- Dynamic lighting systems, reflections, post-processing, or high-end shaders.
- A production recruiter dashboard.
- Validated hiring claims or automated employment decisions.
- Mobile builds.
- Web export until the desktop build is complete and stable.

## Player journey

### 1. Start and notice

The title screen identifies the experience as a VibeProof prototype and states that it records structured in-game actions for a Proof Replay. It also states that navigation speed is not scored.

Starting a session creates a unique session identifier and appends an `assessment_opened` event.

### 2. Mission briefing

The player spawns at the room entrance facing the mission screen. The briefing states:

> Users report that the homepage feels slow. Its p95 latency increased from 180 ms to 850 ms while CPU utilization remains at 35%. Identify the bottleneck, support the diagnosis with evidence, and propose a safe improvement. Rewriting the system is outside scope.

Before detailed evidence is available, the player selects an initial hypothesis and confidence level. Plausible hypotheses include Redis degradation, database slowdown, CPU saturation, sequential service calls, and insufficient evidence.

The game records `hypothesis_recorded` with the chosen hypothesis, confidence, and version.

### 3. Investigation

After the briefing, all investigation stations are available. The player may visit them in any order. Number keys provide equivalent quick access:

- `1`: observability wall;
- `2`: developer desk;
- `3`: release console.

Opening an artifact records `evidence_viewed`. Reopening the same artifact remains visible in the timeline but does not receive duplicate scoring credit.

### 4. Hypothesis revision

The player may revise the hypothesis at any time from the HUD. The revision records the previous and new values, confidence, and the evidence selected as the trigger.

### 5. Verification and submission

The release console asks the player to choose:

- root cause;
- supporting evidence;
- remediation;
- risks and assumptions;
- correctness and latency validation;
- rollback approach;
- final confidence.

An optional short rationale is captured for the replay but is not automatically scored. Submitting records `decision_recorded` and `final_submission`.

### 6. Proof Replay

The final screen shows:

- completion status and scenario version;
- initial and revised hypotheses;
- evidence viewed in chronological order;
- scripted AI interaction and the player's disposition;
- verification choice;
- final conclusion;
- deterministic criteria met or missed;
- a visible human-review and prototype-limitation notice.

The result is evidence support, not a pass/fail employment verdict.

## Station content

### Observability wall

The wall opens a modal panel with three tabs.

**Metrics**

- Homepage p95 latency: 850 ms, previously 180 ms.
- CPU utilization: 35%.
- Database: healthy.
- Recommendation service: healthy.
- Redis hit rate: 42%.

**Logs**

- Requests complete without application errors.
- Downstream services return successfully.
- No database timeout or CPU-exhaustion signal appears.

**Trace**

- Several independent downstream calls appear one after another.
- Their waiting times accumulate into the observed homepage latency.

Redis remains a plausible distraction. The UI must not label it as a trap.

### Developer desk

The code panel displays a short, readable GDScript-independent pseudocode or TypeScript-style orchestration example with multiple sequential `await` operations.

The scripted AI assistant offers a concurrency recommendation. The player must choose whether to accept it immediately, reject it, or verify that the calls are independent and consider failure handling first. This records `ai_prompt_submitted`, `ai_response_received`, and `ai_suggestion_dispositioned` without calling an external model.

### Release console

The correct conclusion is:

- independent API calls execute sequentially;
- only confirmed-independent calls should execute concurrently;
- required dependencies and ordering must remain sequential;
- correctness and p95 latency must both be tested;
- rollback should restore the original orchestration if correctness or reliability regresses.

The console permits incomplete or incorrect submissions so the deterministic rules and replay can demonstrate contrasting evidence paths.

## Controls and camera

- `W`, `A`, `S`, `D`: move along the camera-aligned screen axes.
- `E`: interact with the nearest active station.
- `1`, `2`, `3`: open each station directly.
- `H`: open or revise the current hypothesis.
- `Esc`: close the current panel or pause.

The room uses one orthographic `Camera3D` at a fixed elevated position and three-quarter rotation. It frames the complete playable room and does not follow the player, orbit, zoom, or accept mouse-look. Its orthographic size remains constant across normal window sizes; the viewport adds letterboxing when needed rather than revealing unintended space.

The environment uses a cutaway shell with no front walls, low furniture, and no tall objects in the room center. Interactive stations use floor rings, emissive accents, and floating prompts so they remain recognizable from the fixed view.

The character rotates toward movement. Jumping, sprinting, crouching, aiming, and physics interactions are absent.

## Repository boundary

Create the standalone prototype under:

```text
prototypes/godot-incident-room/
|-- project.godot
|-- README.md
|-- .gitignore
|-- THIRD_PARTY_NOTICES.md
|-- assets/
|   |-- first_party/
|   `-- third_party/
|-- data/
|   `-- scenarios/
|       `-- homepage_latency_v1.json
|-- scenes/
|   |-- main/
|   |-- player/
|   |-- room/
|   |-- stations/
|   `-- ui/
|-- scripts/
|   |-- domain/
|   |-- persistence/
|   `-- presentation/
`-- tests/
```

This location preserves the project's documented status as an optional presentation experiment. The runtime must not read from `docs/`, `tools/`, `skills/`, `.codex/`, or `docs/archive/`.

Implementation may add a short optional-prototype link to the root `README.md` after the game is verified. Canonical product, assessment, decision, research, and archive documents remain unchanged.

## Component design

### Domain layer

`scripts/domain/` contains engine-light logic that can be tested headlessly:

- `scenario_state.gd`: current hypothesis, confidence, viewed artifacts, and final submission;
- `event_schema.gd`: event construction and required fields;
- `scoring_rules.gd`: transparent deterministic criteria;
- `replay_builder.gd`: chronological replay view model.

This layer has no dependency on room geometry, camera state, animation, or frame timing.

### Persistence layer

`scripts/persistence/event_logger.gd` owns the current session ID and event sequence. Every meaningful action is appended immediately as one JSON object per line to:

```text
user://vibeproof/<session-id>/events.jsonl
```

On final submission it also writes:

```text
user://vibeproof/<session-id>/summary.json
```

If disk writing fails, the session continues using the in-memory event list and displays a non-blocking recording warning. The final screen clearly marks the persistence failure.

### Presentation layer

`scripts/presentation/` and `scenes/` contain:

- player movement and fixed-camera presentation;
- reusable station trigger behavior;
- interaction prompts;
- modal evidence panels;
- environment animation and visual feedback;
- title, briefing, HUD, submission, and replay screens.

Presentation components emit domain actions. They never calculate scores directly.

## Automatic event capture

The player never presses a record button. Each meaningful interaction calls the event logger through the domain state.

The minimum event set is:

| Event | Required data |
|---|---|
| `assessment_opened` | session ID, scenario version, timestamp |
| `evidence_viewed` | artifact ID, evidence type, timestamp |
| `hypothesis_recorded` | version, hypothesis, confidence, evidence references |
| `hypothesis_revised` | previous value, new value, confidence, trigger evidence |
| `ai_prompt_submitted` | scripted prompt ID, referenced context, timestamp |
| `ai_response_received` | response ID, scripted model label, status |
| `ai_suggestion_dispositioned` | response ID, accepted, modified, or rejected |
| `test_executed` | test ID, expected result, displayed result |
| `decision_recorded` | proposed action, rationale, risk, timestamp |
| `final_submission` | diagnosis, evidence, remediation, risks, validation |

Elapsed time, movement, station order, prompt count, and interaction count may appear as context. They are never scored in isolation.

The prototype does not capture video, audio, facial expressions, voice, raw operating-system input, unrelated keystrokes, mouse movement, or private reasoning.

## Deterministic rules

The prototype begins with six positive evidence rules and three warnings:

```text
+ Reviews trace or request timing before recommending a code change
+ Uses healthy CPU and downstream services to narrow the hypothesis
+ Finds sequential orchestration in the source code
+ Confirms independence before proposing concurrency
+ Selects both correctness and p95 latency validation
+ Revises an earlier hypothesis after contradictory evidence

- Recommends scaling CPU without evidence of saturation
- Accepts the scripted AI recommendation without checking assumptions
- Submits a diagnosis without cited evidence
```

Every displayed result cites the event or final-submission field that triggered it. Equivalent valid investigation orders receive equivalent credit.

## Online resource plan

Only zero-cost resources with a clear license and a direct original source may enter the repository unless the user separately approves a purchase. Each downloaded pack must retain its license file where supplied and receive an entry in `THIRD_PARTY_NOTICES.md` containing source URL, version or retrieval date, license, included files, and any changes.

### Required resources

| Resource | Use | License | Source |
|---|---|---|---|
| Godot 4.7.1 Standard | Engine and matching Windows export templates | MIT | [Official release](https://godotengine.org/article/maintenance-release-godot-4-7-1/) |
| KayKit Furniture Bits, free tier | 50+ colorful low-poly office and interior props in glTF, FBX, and OBJ formats | CC0 | [Original pack](https://kaylousberg.itch.io/furniture-bits) |
| KayKit Space Base Bits, free tier | 48+ matching technical props used to dress the diagnostics-lab area | CC0 | [Original pack](https://kaylousberg.itch.io/space-base-bits) |
| Chibi Characters v1.0 | Godot-ready student-character trial with idle, walk, and run animations | CC0 | [Godot Asset Store](https://store.godotengine.org/asset/styloo/chibi/) |
| Kenney Input Prompts | Keyboard interaction icons | CC0 | [Original pack and guide](https://kenney.nl/knowledge-base/game-assets-2d/using-input-prompts) |
| Kenney Interface Sounds | Button, panel, and confirmation sounds | CC0 | [Original pack](https://kenney.nl/assets/interface-sounds) |

The two KayKit packs are the primary environment source because they share a creator, gradient-atlas construction, scale family, and colorful low-poly language. Only the free tiers are in scope. Import the smallest useful selection rather than the complete packs.

The observability wall, screen content, server-rack details, release-console controls, room shell, floor markers, and warning lights are constructed from Godot primitives and first-party materials. This keeps the scenario-specific objects original and readable while avoiding a third environment style.

### Optional office gap-fill

If the free KayKit tier lacks a necessary computer, monitor, keyboard, printer, or related workstation prop, use at most five models from the CC0 [Office Low Poly Pack](https://mreliptik.itch.io/office-low-poly-pack). Match their scale and material colors to the room. Do not use this secondary pack for general furniture or room construction, and skip it entirely when KayKit already covers the need.

### Character resource trial

The preferred player trial uses the `student` model from the CC0 Chibi Characters pack. Only idle, walk, and run animations are needed. The character receives a simple first-party color adjustment or removable accessory only if the supplied files permit it without source-art repair.

The trial receives at most 30 minutes. If the add-on structure, scale, materials, collision, or animation playback does not work cleanly in Godot 4.7.1, the MVP uses a first-party chibi employee assembled from capsule and sphere meshes with a procedural walking bob. Character polish must not block the investigation flow.

### Reference resources only

The official [first 3D game tutorial](https://docs.godotengine.org/en/stable/getting_started/first_3d_game/index.html), [CharacterBody3D documentation](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html), [Area3D documentation](https://docs.godotengine.org/en/stable/classes/class_area3d.html), [Camera3D documentation](https://docs.godotengine.org/en/stable/classes/class_camera3d.html), and [3D format guide](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) are implementation references.

The official Third Person Shooter demo is not used as a project foundation because it is substantially larger and more complex than this prototype.

Prefer self-contained `.glb` files. Avoid `.blend` delivery dependencies, and do not use OBJ for animated characters.

## Failure handling and cut order

### Resource import failure

If an external model has broken materials, scaling, pivots, or collisions and cannot be corrected within 20 minutes, replace it with a Godot primitive. Do not spend the schedule repairing source art.

### Character or animation failure

Use a primitive chibi employee character. Preserve collision, movement, and camera behavior. Animation is cosmetic.

### Camera framing failure

Adjust the orthographic size or camera height, or lower or remove the obstructing prop. Do not add camera collision, player-controlled camera motion, dynamic zoom, or per-station camera transitions.

### Persistence failure

Keep the in-memory event list, show a warning, allow the session to finish, and mark the replay as not saved to disk.

### Schedule pressure

Cut in this order:

1. character animation and imported character;
2. nonessential office decoration;
3. sound effects;
4. environment animation and lighting polish;
5. web export;
6. optional written rationale field.

Do not cut the briefing, three evidence surfaces, hypothesis capture and revision, verification, final submission, automatic event log, or Proof Replay.

## Two-day delivery schedule

### Day 1: playable greybox and domain spine

1. Download Godot and verified resources; create the Compatibility project and local ignore rules.
2. Add the headless test runner and write failing domain tests.
3. Implement scenario state, event schema, event logger, and deterministic rules.
4. Build the primitive room, player controller, fixed orthographic camera, and interaction triggers.
5. Connect mission briefing and all three station shells.
6. End the day with a complete greybox walk from title screen to an unpolished final submission.

### Day 2: scenario content, replay, assets, and export

1. Add the canonical metrics, logs, trace, code, scripted AI, and submission choices.
2. Complete hypothesis revision, persistence, scoring evidence, and Proof Replay.
3. Import the selected KayKit props and attempt the time-boxed Chibi Characters integration.
4. Add prompts, minimal sounds, lighting, station highlights, and visual status changes.
5. Run automated tests, headless import validation, and the manual playthrough matrix.
6. Export and smoke-test the Windows build; attempt web export only if all desktop criteria pass.

## Testing strategy

Avoid adding a large testing plugin to the two-day prototype. Use a small GDScript headless runner under `tests/` for domain and persistence behavior.

Automated coverage must include:

- valid event construction and required fields;
- monotonic event sequence numbers;
- JSONL serialization and persistence-failure fallback;
- hypothesis versioning and revision linkage;
- idempotent scoring credit for repeated evidence views;
- correct and incorrect scoring paths;
- replay ordering and cited evidence;
- final-submission completeness checks.

Required engine checks:

```text
godot --headless --path prototypes/godot-incident-room --import
godot --headless --path prototypes/godot-incident-room --script res://tests/run_tests.gd
```

Manual checks cover:

- movement, rotation, fixed-camera framing, and continuous player visibility;
- `E` interaction and `1`/`2`/`3` quick access;
- modal focus, keyboard navigation, and escape behavior;
- evidence available in any investigation order;
- an evidence-based correct path;
- a plausible incorrect path;
- session file creation and final replay;
- restart into a clean new session;
- Windows export startup and full playthrough.

## Acceptance criteria

The Incident Room MVP is complete when:

1. A new user can launch the Windows build and finish the scenario without setup instructions.
2. The complete demo takes three to five minutes.
3. The player can inspect metrics, logs, traces, code, and the scripted AI interaction.
4. The player can record and revise a hypothesis with confidence.
5. The player can select verification and submit a structured conclusion.
6. Every meaningful action appears in an append-only JSONL event file.
7. The Proof Replay is generated automatically and cites evidence for each deterministic result.
8. Repeated evidence views do not produce duplicate scoring credit.
9. Movement speed and game-control performance do not affect results.
10. The core flow works without a network connection or external service.
11. Automated domain tests pass.
12. Headless project import exits successfully.
13. A packaged Windows build completes the full playthrough without an error.
14. `THIRD_PARTY_NOTICES.md` accounts for every externally sourced runtime file.

## Completion outcome

A stakeholder should be able to launch a small, visually coherent three-quarter-view incident room, guide a chibi employee through the documented latency problem, make technically meaningful decisions, and immediately view a transparent Proof Replay. The prototype should demonstrate whether a playful spatial presentation can add engagement while leaving VibeProof's underlying evidence model and responsible-assessment boundaries intact.
