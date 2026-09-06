# Glass airport jetway

Original Blender geometry based on the supplied boarding-bridge photograph.
No reference pixels or downloaded models are embedded.

- **5,080 triangles**, two meshes/materials: `JetwayStructure` with a shared
  1024 × 1024 PBR atlas, plus `JetwayGlazing` with 24 transparent triangles.
- Glazed corridor with diagonal braces, blue lift frame and wheel bogie, open
  service stairs and railings, telescoping sleeves, cab doors, HVAC grille,
  accordion docking hood and red beacon lenses.
- Source bounds: approximately 6.865 × 3.386 × 1.846 m (X/Y/Z). Docking cab is
  +X and service stairs face -Z. Geometry is grounded at Y=0.
- The terminal exterior is a sealed, shallow diorama. `_air_jetway` stages the
  model at `(0.55, 0.024, 4.4)`, compresses Z to 0.42, and uses a Y scale of
  `0.76 * min(1, (ceiling_height - 0.18) / 3.41)`. This keeps the bridge below
  the aircraft window line and below low room soffits. The editable asset
  retains full depth and height.
- Geometry/material resources are shared across gates. The existing terminal
  glass supplies collision; the exterior model adds none. Both exterior
  assets have `airport_apron_setpiece` metadata for boundary audits.

Editable source: `art/airport_jetway/airport_jetway.blend`; its textures are
packed. The source folder has `.gdignore`, and studio objects are excluded
from the exported GLB. Godot generates LODs and shadow meshes on import.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/blender/build_airport_jetway.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/audit_airport_jetway.gd
godot --path . --audio-driver Dummy --disable-render-loop \
  --script tools/capture_procedural_props.gd -- \
  --filter=airport-jetway --both-sides --out=/tmp/airport-jetway-review
```

The combined jetway/aircraft audit checks five ceiling heights and all four
gate orientations, shared resources, budgets, aircraft separation, ground
contact, rear backdrop clearance, and generated airport chunks. Studio and
Godot front/reverse views, plus a combined terminal-window view, were inspected.

Validation on 2026-09-05: the combined audit passed 20 orientation/height cases
and 121 generated chunks. The full doorway audit passed across 6,476 furnished
rooms, including 22 airport apron setpieces with zero overflow meshes. The
airport collider audit also passed across 2,270 body-height colliders.
