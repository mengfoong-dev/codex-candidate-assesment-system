# Third-Party Notices

## Godot Engine 4.7.1

This project uses Godot Engine 4.7.1, copyright the Godot Engine contributors and copyright Juan Linietsky, Ariel Manzur.

Godot Engine is distributed under the MIT License. The pinned upstream sources are [LICENSE.txt](https://raw.githubusercontent.com/godotengine/godot/4.7.1-stable/LICENSE.txt) and [COPYRIGHT.txt](https://raw.githubusercontent.com/godotengine/godot/4.7.1-stable/COPYRIGHT.txt).

Distributors must keep both local files, `licenses/GODOT_LICENSE.txt` and `licenses/GODOT_COPYRIGHT.txt`, with the build.

## KayKit: Furniture Bits 1.0

Cozy Toy Office furniture uses props from KayKit: Furniture Bits 1.0 by Kay Lousberg (Kay Lousberg), released under CC0-1.0.

- Canonical source: <https://github.com/KayKit-Game-Assets/KayKit-Furniture-Bits-1.0> (revision `96d5930a8dbdb363409bbc2d3341718b00e17c9c`).
- Selected files only: a subset of GLTF/BIN models plus `furniturebits_texture.png` under `assets/third_party/kaykit-furniture-bits/`; the full pack and its Git history are not vendored.
- Local license copy: `assets/third_party/kaykit-furniture-bits/LICENSE.txt`.
- Regenerate with `scripts/development/acquire_art_assets.ps1`.

## Kenney Mini Characters 1.0

The animated employee uses `character-female-a.glb` from Kenney Mini Characters 1.0 by Kenney, released under CC0-1.0.

- Canonical source: <https://kenney.nl/assets/mini-characters>.
- Selected files only: `character-female-a.glb` under `assets/third_party/kenney-mini-characters/`; the full download is verified against a pinned SHA-256 but not vendored.
- Local license copy: `assets/third_party/kenney-mini-characters/LICENSE.txt`.
- Regenerate with `scripts/development/acquire_art_assets.ps1`.

## Low Poly 3D Office Set [VNB]

The office furniture (desks, computer, chairs, shelves, cabinet, lounge, plants, wall
deco) uses models from "Low Poly 3D Office Set [VNB]" by VNB, licensed **CC-BY 4.0**.

- Canonical source: <https://vnbp.itch.io/low-poly-3d-office-set-vnb> (VNB Low Poly Office Set V1.1.0).
- Attribution: **"Low Poly 3D Office Set [VNB]" by VNB — https://vnbp.itch.io/low-poly-3d-office-set-vnb — CC-BY 4.0.**
- Selected files only: a subset of the separated OBJ models plus their palette/screen textures under `assets/third_party/vnb-office-set/`; the full pack and the source `.zip` are not vendored.
- Used as in-game props only; the models are not re-sold as an asset pack, per the pack's terms.

## Office Room 15 (Low-poly)

The 3D office environment is "Office Room 15 Low-poly 3D model" by **Mnostva**, licensed **CC-BY 4.0**.

- Canonical source: <https://sketchfab.com/3d-models/office-room-15-low-poly-3d-model-0402e7c67e0e4a6abc51a7269f59600a>.
- Attribution: **"Office Room 15 Low-poly 3D model" by Mnostva — CC-BY 4.0.**
- Vendored as `assets/third_party/office-room-15/office_room_15.glb`.
- Used solely as an in-game environment asset. The model carries a Sketchfab "NoAI" flag, which restricts use in generative-AI *training/development*, not use as a game asset — no AI training is performed on it here.
