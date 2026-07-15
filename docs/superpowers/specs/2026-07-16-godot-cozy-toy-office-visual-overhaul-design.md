# Godot Cozy Toy Office Visual Overhaul Design

**Date:** 2026-07-16

**Status:** Approved direction; written specification awaiting final review

## Goal

Transform the functional VibeProof Incident Room into a polished, colorful 3D game using free redistributable asset packs while preserving its tested candidate journey, unscored evidence boundary, Windows build, and Godot Web deployment.

The result should feel like a compact toy-diorama office game rather than a prototype assembled from primitive meshes. It must remain readable, performant, and easy to operate for candidates who are not experienced game players.

## Approved direction

The selected direction is **Cozy Toy Office**, chosen over a minimal Kenney-only office and a darker sci-fi command lab.

- Build a warm, colorful cutaway software office around KayKit's furniture style.
- Use an animated mini character instead of the current capsule mesh.
- Give the Observability Wall, Developer Desk, and Release Console distinct silhouettes, lighting, and effects.
- Reskin the title screen, interaction prompts, and investigation panels so the 2D interface belongs to the same visual world.
- Keep the fixed elevated orthographic camera and simple controls. Visual polish must not make navigation skill part of the assessment.
- Use only free assets whose redistribution terms are verified. Prefer CC0.

## Asset foundation

### Primary environment pack

Use the free tier of **KayKit: Furniture Bits** by Kay Lousberg as the primary furniture language. The source provides more than 50 low-poly models, a shared gradient atlas, GLTF files, Godot compatibility, and a CC0 license.

Source: <https://kaylousberg.itch.io/furniture-bits>

### Character pack

Use **Kenney Mini Characters** for the controllable employee. The pack provides animated miniature people and is CC0. Select one neutral modern character that reads as an office worker from the fixed camera.

Source: <https://kenney.nl/assets/mini-characters>

### Gap-fill pack

Use **Kenney Furniture Kit** only when Furniture Bits lacks a required office prop. Limit its use to pieces whose silhouette and scale can be made consistent with the KayKit set.

Source: <https://kenney.nl/assets/furniture-kit>

### Provenance and redistribution

Store selected runtime assets under creator-and-pack-specific directories in `apps/incident-room/assets/third_party/`. Do not commit unrelated models from a source archive. For each imported pack, record:

- creator and pack name;
- canonical source URL;
- downloaded filename and source version or retrieval date;
- license name and a local copy of the license evidence;
- the selected runtime files derived from the pack;
- any transformations applied during import.

Update `THIRD_PARTY_NOTICES.md` before either Windows or Web distribution. Retain creator attribution even where CC0 does not require it.

## Room composition

Keep one compact cutaway room and the current three-station journey. Rebuild its presentation as five visual layers:

1. **Architecture:** modular floor, rear and side walls, skirting, windows, doorway, rugs, and low partitions.
2. **Office dressing:** desks, ergonomic chairs, monitors, shelves, cabinets, lamps, plants, lounge furniture, mugs, books, and small personal objects.
3. **Investigation landmarks:** an oversized observability display, a developer workstation with code-focused screens, and a release console with a prominent deployment control surface.
4. **Guidance:** colored floor inlays, station signs, proximity rings, interaction icons, and subtle light trails.
5. **Atmosphere:** warm key light, cool window fill, emissive monitors, contact shadows, restrained particles, and a soft background color.

The center aisle remains clear. Furniture cannot hide the player, block station triggers, or make an evidence station ambiguous from the starting camera.

## Visual language

- Base palette: warm cream, navy, muted wood, and soft green.
- Observability accent: cyan.
- Developer accent: violet.
- Release accent: green, shifting to amber only for incident attention.
- Forms: chunky, rounded, readable from distance, and free of thin detail that aliases in the Web build.
- Materials: mostly matte with controlled emissive screens and small metallic accents.
- Branding: original VibeProof signs, screen graphics, station labels, floor symbols, and UI icons built in Godot rather than copied from an asset preview.

Do not mix untouched asset-pack palettes. Imported materials may be overridden with a shared VibeProof palette when the source format permits it without destructive editing.

## Player presentation

Replace only the visual child of the existing `CharacterBody3D`; retain its collision shape, movement contract, quick-access controls, and assessment independence.

The player presentation includes:

- one selected Kenney mini character;
- idle and walk animation driven from horizontal velocity;
- rotation toward movement;
- a soft blob shadow or contact shadow;
- a small selection marker when the player is near a station;
- no sprint, jump, combat, inventory, or character customization.

If the selected model's animation names differ from the expected contract, an adapter maps source clips to `idle` and `walk`. The runtime controller must not depend on pack-specific node paths.

## Station presentation

Each station keeps its stable `station_id` and trigger contract. Visuals live in station-specific presentation scenes so they can change without touching candidate state or evidence logging.

### Observability Wall

- Three or more large screens with stylized latency, CPU, log, and trace graphics.
- Cyan underlighting and a slow monitor pulse.
- A clear wall-scale silhouette visible from spawn.

### Developer Desk

- Desk, chair, computer, keyboard, task lamp, notes, and a secondary display.
- Violet monitor glow and an animated code-scroll impression that never replaces the readable investigation panel.

### Release Console

- Raised console or standing desk, deployment display, confirmation control, and status tower.
- Green ready state and restrained amber incident pulse.
- No flashing frequency that creates an accessibility concern.

## Interface polish

Create one reusable Godot `Theme` for title, briefing, hypothesis, investigation, release, and summary panels.

- Use rounded cards, consistent spacing, larger headings, and the same three station colors as the room.
- Add short fades and panel scale transitions without delaying input.
- Replace raw text interaction prompts with a compact icon-plus-label prompt.
- Preserve full keyboard navigation, focus visibility, readable contrast, and existing notices about evidence capture and the unscored prototype.
- Do not reduce the amount or accuracy of assessment content to make the interface look cleaner.

## Architecture and boundaries

The visual overhaul remains in the presentation layer:

```text
CandidateSession / EventLogger / ScenarioLoader
                    |
                    v
       Existing main-flow coordinator
                    |
       +------------+-------------+
       |            |             |
  Room visuals  Player visual  Shared UI theme
       |            |             |
  CC0 props     animation map  panels/prompts
```

- Domain and persistence scripts do not load 3D assets.
- Station IDs, scenario IDs, event payloads, and summary behavior remain unchanged.
- Collision and trigger nodes remain separate from decorative meshes.
- Third-party models are wrapped in local scenes rather than referenced throughout coordinator code.
- Asset paths and expected animation mappings have explicit contract tests.

## Web and performance budget

The same source must continue to export to Windows and single-threaded Web using Godot 4.7.1 Compatibility.

- Import only selected models and textures.
- Keep source textures at 1024 pixels or below unless a measured readability need proves otherwise.
- Reuse shared materials and atlases.
- Prefer static props and simple collision primitives.
- Use one shadow-casting directional key light; additional station lights do not cast shadows.
- Do not add real-time global illumination, screen-space reflections, volumetric fog, or high-cost transparent shaders.
- Target stable 60 FPS on the development Windows machine and at least 30 FPS in a current integrated-GPU browser at the existing room view.
- Keep the additional compressed Web download below 20 MB unless measured visual evidence justifies a documented exception.

## Asset acquisition failures

- A source must not enter the project until its license and canonical source are recorded.
- If an official download is unavailable or its terms differ from the researched terms, skip that pack rather than obtaining it from a mirror.
- If a selected model imports incorrectly, first try another official format from the same pack, then substitute another verified model. Do not patch generated `.godot` import data.
- Missing required asset files, animation clips, provenance records, or notices fail verification before export.
- The current primitive collision and trigger structure remains available while visuals are assembled, preventing art changes from breaking the candidate flow.

## Verification

### Automated

- Existing domain, persistence, flow, acceptance, panel, room, and Web-export suites remain green.
- New asset-contract tests verify required source records, wrapper scenes, stable station IDs, UI theme assignment, player animation mappings, and distribution notices.
- A clean Godot import reports no missing dependencies or parser errors.
- Windows and Web exports both complete with nonempty artifacts.
- Automated acceptance paths still reach the same explicitly unscored summary with the same structured candidate choices.
- Local and deployed HTTP checks still return the Godot page, WebAssembly, and pack files correctly.

### Visual and interaction

- Capture the title screen, room overview, all three stations, and final summary at the reference viewport.
- Confirm that the player is visible throughout the walkable area and no prop obstructs a trigger.
- Play the full keyboard-only journey in Windows and a current browser.
- Check monitor glow, station pulse, and transitions for flicker and reduced readability.
- Compare the Web frame rate and download size with the pre-overhaul build.

## Non-goals

- No backend scoring, authentication, cloud save, analytics, or live model.
- No new incident scenario or evidence logic.
- No multi-room level, NPC schedule, dialogue tree, combat, inventory, quest system, or character editor.
- No paid, attribution-unclear, ripped, marketplace-restricted, or AI-generated third-party assets.
- No change from the fixed orthographic camera in this milestone.

## Acceptance criteria

1. The room reads as a cohesive colorful software office rather than primitive geometry.
2. A rigged character visibly idles, walks, and faces movement while retaining current controls and collision.
3. Each investigation station is recognizable from the default camera before its label appears.
4. The title, prompts, panels, and room use one consistent VibeProof visual language.
5. The complete candidate journey and recorded evidence remain behaviorally unchanged and unscored.
6. Every distributed third-party file has verified source and license evidence.
7. Windows and Web builds pass automated, visual, keyboard, and artifact checks.
8. The deployed Railway build remains usable on a current desktop browser without an undocumented download-size or performance regression.
