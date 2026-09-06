# White retail garment rack

Original Blender geometry based on the user-supplied retail-rack photograph.
No photo pixels or downloaded third-party models are embedded.

- White square-tube ladder uprights, T feet, rubber caps, projecting hanging
  arms, wooden hangers, a raised shelf and soft folded garments.
- Two deterministic arrangements: **formal coats: 6,248 visible triangles**;
  **casual shirts: 5,816 visible triangles**. The casual shelf includes a hat.
- Each game instance has **two mesh surfaces sharing one material**. The
  base-color, normal and packed roughness/metallic maps are **1024 × 1024**.
- The GLB contains `RackFrame`, `ClothesFormal` and `ClothesCasual`. The mall
  builder removes the unused clothing mesh immediately after instantiation.
  Do the same when instancing it elsewhere; the two alternatives occupy the
  same space. Geometry and textures are shared between repeated racks.
- Rail runs along local X, with a centered footprint and the feet at Y = 0.
  Width is 1.568 m and depth is 0.607 m; height is about 1.81–1.86 m by outfit.
  Collision is a rotated 1.60 × 1.94 × 0.64 m box, grouped with the visible rack
  so doorway cleanup removes the complete furnishing.
- Godot generates mesh LODs and shadow meshes on import. Existing mall rack
  locations and yaw choices are preserved; outfit uses the placement's seed/salt.

Editable source: `art/mall_garment_rack/garment_rack.blend`. It opens with the
formal outfit visible. Hide `ClothesFormal` and show `ClothesCasual` to inspect
the alternative. The source folder has `.gdignore`; preview lights, floor and
camera never enter the runtime GLB. Packed textures make the blend portable.

Rebuild and validate from the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/blender/build_mall_garment_rack.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/audit_mall_garment_rack.gd
godot --path . --audio-driver Dummy --disable-render-loop \
  --script tools/capture_procedural_props.gd -- \
  --filter=mall-garment-rack --both-sides --out=/tmp/mall-rack-review
```

Validation on 2026-09-05: import and the 32-placement rack audit passed,
including both variants, the triangle budget, shared mesh/material resources,
collider coverage and atomic furnishing metadata. Front/back Godot captures
were inspected. A broader `audit_new_levels.gd -- 2 4` run covered 288 chunks
with zero unsupported assemblies and zero doorway overlaps; that limited run
was not wholly green, reporting four mall fountain-fixture violations and
missing style/enrichment coverage from the reduced seed count.
