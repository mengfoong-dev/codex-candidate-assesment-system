# In-game story + demo flow — design

**Date:** 2026-07-17
**App:** `apps/incident-room` (Godot 4.7, VibeProof Incident Room)

## Goal

Make the game legible to a first-time player and demo-ready for a booth:

1. Players don't know who "Sam" is or why to "sit at your desk" — fix wording and
   deliver the backstory **in-game** as a Pokémon-style dialogue box (Sam delegates
   the latency incident), framing the assessment in-character.
2. Let a facilitator reset for the next player mid-session (not only from the end
   screen), and add minimal audio.

## Locked decisions

- Title-screen story card **stays**; the in-game dialogue is **added** on top.
- Backstory narrated by **Sam** (the senior handing off the task), with a **portrait**.
- Portrait = **pre-rendered PNG** of the actual Sam model (Kenney `character-male-b`),
  not a live 3D render.
- Sam Q&A stays **flavor/context** — scoring unchanged. The dialogue only *frames*
  the "gather facts + verify the AI" expectation in words.
- Audio: **mute toggle + 2 SFX** (Kenney CC0 text-blip + UI-click). No full settings screen.

## What the game already provides (reused, not rebuilt)

- `main.gd :: restart_session()` — fresh session id, cleared state, back to title.
  Tested. Today only reachable via the report's "Start another session" button.
- Per-session data: `event_logger` writes events + `summary.json` to
  `user://vibeproof/sessions/<session_id>/`; backend grading submits with the email.
  Restart mints a new id; prior players' data stays on disk.
- `office_layer.gd :: open_senior()` — live Sam chat (unchanged; the intro is separate).
- Floating labels are `Label3D.text` from `station_title` in `incident_room.tscn`.

## Components

### 1. Wording (trivial)
Edit `scenes/room/incident_room.tscn` `station_title` strings:
- `"Talk to Sam"` → `"Sam · your senior — talk (E)"`
- `"Sit at your desk"` → `"Your desk — investigate (E)"`

### 2. DialogueBox overlay — `scripts/presentation/dialogue_box.gd` (+ under `$UI`)
Reusable, self-contained presentation node.
- **API:** `play(lines: Array)` where each line = `{ "speaker": String, "text": String,
  "portrait": Texture2D|null }`; signal `finished`.
- **Layout:** bottom panel; portrait square (left) + speaker name label + `RichTextLabel`
  body; a small "▾ Space / click / E" advance hint.
- **Behavior:** typewriter reveal (Timer accruing chars). Advance input (Space / click /
  `interact` / `ui_accept`): if still typing → reveal full line instantly; else → next
  line; after last line → hide + emit `finished`.
- **Isolation:** knows nothing about sessions/scenario — pure "show these lines". Caller
  supplies content and reacts to `finished`. Null-safe so headless/domain tests that
  don't build UI are unaffected.

### 3. Intro content + trigger
- Content in scenario JSON: new optional `intro_dialogue: [{speaker, text}, ...]`, with a
  hardcoded fallback in `main.gd` if absent. Speaker `"Sam"` → Sam portrait.
- Draft lines (Sam's voice): greet → the p95 180→850ms symptom → "I'm handing this
  incident to you, you're on-call now" → "don't guess, dig up the facts (wall/logs/
  trace/source), ask me anything" → "there's an AI copilot — use it, but verify it before
  you trust it; I want to see *how* you check it" → "back your cause with evidence, propose
  a safe fix + rollback + validation; head to your desk when ready".
- **Trigger:** once per session, when entering the office at `briefing`. Fires from the UI
  side (`main.gd` `_update_presentation`/`begin_session` reaction), guarded by a
  `_intro_shown` flag and a null-check on the dialogue node. While active, player movement
  is locked (add `_dialogue_active` to the `_update_player_input()` gate). Domain phase
  logic is untouched, so existing headless tests still pass.

### 4. Sam portrait — `assets/ui/portrait_sam.png`
Pre-rendered once from `character-male-b.glb` (headshot framing) via a throwaway offline
Godot render script (same pattern as prior font probe), then vendored. Covered by existing
Kenney CC0 attribution.

### 5. Pause / reset menu — `scripts/presentation/pause_menu.gd` (+ under `$UI`)
- Esc during `briefing`/`room` (when no lower modal and dialogue not active) opens an
  overlay: **Resume**, **Restart (new candidate)**, **Mute: on/off**.
- Restart emits a signal → `main.gd` calls existing `restart_session()`.
- Overlay only (no `get_tree().paused` — avoids stalling camera glide / HTTP). Disables
  player movement via the same input gate.
- Esc coordination: `office_layer` already consumes `ui_cancel` to close its own modal;
  pause opens only when that modal is closed.

### 6. Audio — `scripts/presentation/sfx.gd` (autoload singleton)
- Two `AudioStreamPlayer`s: `text_blip` (throttled, on typewriter chars) and `ui_click`
  (buttons). `set_muted(bool)` flips the Master bus mute; mute state read by the pause menu.
- Sounds vendored to `assets/third_party/kenney-ui-audio/` (CC0) + LICENSE; add a
  `THIRD_PARTY_NOTICES.md` entry and a line in `acquire_art_assets.ps1`.

## Out of scope / follow-ups
- Full settings screen (resolution, volume sliders, key rebinding).
- Ambient office audio / music.
- Scoring the quality of Sam Q&A (backend grading change).
- Trimming the (now somewhat redundant) title story card — left as-is per decision.

## Testing
- `tests/test_dialogue_box.gd`: `play()` a 3-line list, simulate advances, assert it
  reaches the last line and emits `finished` exactly once; assert an advance mid-typewriter
  reveals the full current line rather than skipping.
- Reuse existing `restart_session` tests for the reset path (no new domain logic).
- Manual: run the app, confirm intro plays once, movement locks/unlocks, Esc pause
  resets to a fresh session, mute silences SFX, labels read clearly, emoji still render.
- Full existing suite must stay green (dialogue/pause are presentation-only, guarded).
