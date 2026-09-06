# Airport luggage trolley

Original Blender geometry based on the user-supplied airport trolley photograph.
No photo pixels or downloaded third-party geometry are embedded.

- Stainless tubular frame, bowed push handle with blue end caps, open wire
  basket, two blank sign panels, slatted luggage platform and four swivel casters.
- **3,228 triangles, one mesh, one material**, with shared 1024 × 1024 base-color,
  normal and packed roughness/metallic textures. Godot generates mesh LODs and
  shadow meshes on import.
- Floor-centered origin, +Z toward the nose. Bounds are approximately
  **0.63 m wide × 1.11 m high × 0.99 m deep**.
- Airport placements keep their position, yaw and 0.55 m nesting pitch. A rank
  shares one box collider and one furnishing group, so doorway cleanup removes
  it as a complete unit. Repeated instances share their mesh and material.
- An optional existing airport backpack sits on the frontmost cart, with its
  contact height and tilt matching the sloped platform. The authored trolley
  itself contains no luggage.

Editable source: `art/airport_trolley/airport_trolley.blend`. Textures are packed.
The source folder has `.gdignore`; studio lights, floor and camera are excluded
from the runtime GLB. `preview_front.png` and `preview_reverse.png` are Blender
studio renders.

Rebuild and validate from the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/blender/build_airport_trolley.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/audit_airport_trolley.gd
godot --headless --path . --script tools/audit_airport_luggage.gd
godot --headless --path . --script tools/audit_airport_colliders.gd -- 2 4
godot --path . --audio-driver Dummy --disable-render-loop \
  --script tools/capture_procedural_props.gd -- \
  --filter=airport-trolley --both-sides --out=/tmp/airport-trolley-review
```

Validation on 2026-09-05: 108 ranks across three counts and three yaw angles,
including 45 supported backpack loads, passed the targeted audit. The full
luggage audit passed with 327 pieces and 75 complete carousels. The collision
audit passed across 2,270 body-height colliders. Godot front, reverse and nested
row captures were inspected.
