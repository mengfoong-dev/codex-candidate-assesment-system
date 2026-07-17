# Third-Party Notices

## Godot Engine 4.7.1

This project uses Godot Engine 4.7.1, copyright the Godot Engine contributors and copyright Juan Linietsky, Ariel Manzur.

Godot Engine is distributed under the MIT License. The pinned upstream sources are [LICENSE.txt](https://raw.githubusercontent.com/godotengine/godot/4.7.1-stable/LICENSE.txt) and [COPYRIGHT.txt](https://raw.githubusercontent.com/godotengine/godot/4.7.1-stable/COPYRIGHT.txt).

Distributors must keep both local files, `licenses/GODOT_LICENSE.txt` and `licenses/GODOT_COPYRIGHT.txt`, with the build.

## Kenney Mini Characters 1.0

The animated characters use the `character-female-{a-f}.glb` and `character-male-{a-f}.glb` models (12 variants) from Kenney Mini Characters 1.0 by Kenney, released under CC0-1.0. The player is female-a, the senior NPC (Sam) is male-a, and the seated office coworkers use the remaining variants for a diverse workspace.

- Canonical source: <https://kenney.nl/assets/mini-characters>.
- Vendored: all 12 `character-*.glb` models plus the shared `Textures/colormap.png` under `assets/third_party/kenney-mini-characters/`; the full download is verified against a pinned SHA-256.
- Local license copy: `assets/third_party/kenney-mini-characters/LICENSE.txt`.
- Regenerate with `scripts/development/acquire_art_assets.ps1`.
- The dialogue portrait `assets/ui/portrait_sam.png` is a still render of `character-male-a` (CC0), produced by `scripts/development/render_sam_portrait.gd`.

## UI sound effects

`assets/ui/sfx/text_blip.wav` and `ui_click.wav` are original procedurally-generated
tones (no third party), produced by `scripts/development/generate_sfx.gd`.

## Noto Sans + Noto Emoji (UI font)

The project-wide UI font (`assets/ui/default_font.tres`, wired via `gui/theme/custom_font`)
is a `FontVariation` combining **Noto Sans** (base, normal/Latin text) and **Noto Emoji**
(monochrome, fallback) so the emoji used as icons in labels — e.g. `💻 Open PC`,
`📝 Notepad`, `⬆ Get up` — render as glyphs instead of "tofu" boxes. Both fonts are
embedded with `allow_system_fallback` disabled so rendering is identical on Desktop and
Web (the Web export has no system fonts to borrow).

- Sources: Google Fonts / `google/fonts` — `ofl/notosans/NotoSans[wdth,wght].ttf` and
  `ofl/notoemoji/NotoEmoji[wght].ttf`, copyright Google LLC.
- License: SIL Open Font License 1.1 (both).
- Vendored as `assets/third_party/fonts/NotoSans.ttf` and `assets/third_party/fonts/NotoEmoji.ttf`.
- Local license copy: `assets/third_party/fonts/OFL.txt`.

## JetBrains Mono (Codex IDE console font)

The in-game "Codex" IDE console (`scenes/ui/ide_console.tscn`) renders its code editor,
terminal, and title in **JetBrains Mono** so source code shows in a fixed-width, VS-Code-like
face instead of the proportional project UI font.

- Source: JetBrains / `JetBrains/JetBrainsMono` — `fonts/ttf/JetBrainsMono-Regular.ttf`,
  copyright 2020 The JetBrains Mono Project Authors.
- License: SIL Open Font License 1.1.
- Vendored as `assets/third_party/fonts/JetBrainsMono-Regular.ttf`.
- Local license copy: `assets/third_party/fonts/OFL.txt` (shared with Noto Sans/Emoji).

## Isometric Office (open-plan)

The active 3D office environment is "Isometric office" by **Companion_Cube**, licensed
**CC-BY** (Creative Commons Attribution; commercial use allowed, author must be credited).

- Source: Sketchfab ("Isometric office" by Companion_Cube).
- Attribution: **"Isometric office" by Companion_Cube — CC-BY.**
- Vendored as `assets/third_party/isometric-office/isometric_office.glb`.
- Used solely as an in-game environment asset.
