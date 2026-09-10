# Airport moving walkway (8.4m)

Original low-poly Blender model using the user-supplied moving walkway shape reference. No reference-image pixels used.

- Editable source: `art/airport_walkway/standard/airport_walkway.blend`
- Builder: `tools/blender/build_airport_walkway.py`
- Runtime: `airport_walkway.glb`
- 3,576 triangles, three material surfaces: shared 1K PBR body atlas, transparent glazing, animated belt.
- Local +X travel axis, 1.15m belt width, 0.13m deck height; total footprint 9.52 × 1.836m including ramps.
- Closed eight-sided rubber handrail meshes with tangent elliptical returns. No duplicated closure seam.
- Rounded ends retain their size; cached centre-length fitting supplies the airport's 9.4m variant. The 10.4m variant is exported directly.
- Godot uses `Mats.belt()` on `WalkwayBelt`, with per-instance signed speed 0.75m/s. Existing `Travelator` player movement is retained.
- Five simple colliders: deck, two ramps and two side barriers. Glass uses alpha 0.18 with its opaque rail/housing frame verified by the airport collision audit.
- Checked by `tools/audit_authored_hero_meshes.py` and `tools/audit_airport_walkway.gd`.
