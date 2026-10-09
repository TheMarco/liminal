# White tiles

- **Creator:** [Alex Filip](https://sketchfab.com/filip.alecsandru)
- **Source:** <https://sketchfab.com/3d-models/freebie-game-art-white-tiles-3c9fe794746847d8bf634eb61870e4e7>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Local file:** `white_tiles.glb`
- **Verification:** Creator and CC BY 4.0 license confirmed against both the
  embedded `asset.extras` and the source model's Sketchfab API record on
  2026-10-08. The previous Kless Gyzen attribution was incorrect.
- **Modifications:** Only the embedded PBR sheet is used. Its three 1024x1024
  maps were extracted verbatim to `white_tiles_albedo.png`, `white_tiles_orm.png`
  and `white_tiles_normal.png` and are mapped in world space by
  `shaders/pool_tile.gdshader`, which adds the Poolrooms' waterline darkening
  and caustics on top. The bundled meshes are unused.
