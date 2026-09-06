# Unmarked twin-engine airliner

Original Blender geometry based on the supplied white passenger-aircraft
photograph. No reference pixels, airline branding or third-party models are
embedded.

- **8,952 triangles, one mesh, one material**, with shared 1024 × 1024
  base-color, normal and packed roughness/metallic maps.
- Shaped nose and cockpit glazing, oval cabin windows, curved door outlines,
  swept wings, tail fin and horizontal stabilizers, two recessed turbofan
  intakes, engine pylons, and deployed nose/main landing gear.
- Cockpit windshields wrap across the forward brow with a narrow center pillar.
  Their shapes and roughness are baked directly into the fuselage surface, so
  separate glass overlays cannot intersect the nose or flicker at lower LODs.
  The nose receives extra area within the same 1K atlas. Projection UVs and
  the authoring mask are removed from the exported material/UV set.
- Full-depth source bounds: approximately **10.505 × 3.39 × 8.90 m** (X/Y/Z).
  Nose points toward -X and landing tires meet Y=0.
- The game uses a forced-perspective exterior behind the terminal glass.
  `_air_docked_plane` instances the asset at `(0, 0.025, 5.275)`, rotates it
  180° to face the jetway cab, scales depth to 0.115, and fits its height below
  the room soffit. In-game depth is about 1.024 m; the Blender source retains
  the full aircraft for reuse elsewhere.
- The complete model shares one imported mesh/material across gates. It adds
  no collision and does not cast distorted shadows from its compressed
  geometry. The original 60% aircraft placement chance is preserved.
- Replaced the old procedural fuselage, scattered primitives and their
  dedicated mesh cache. The scene uses the normal authored-prop preload path.

Editable source: `art/airport_plane/airport_plane.blend`, with packed textures.
Its `.gdignore` keeps authoring files out of game imports. Preview floor,
camera and lights are excluded from the GLB; Godot generates LODs on import.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/blender/build_airport_plane.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/audit_airport_jetway.gd
godot --headless --path . --script tools/audit_doorways.gd
godot --path . --audio-driver Dummy --disable-render-loop \
  --script tools/capture_procedural_props.gd -- \
  --filter=airport-plane --both-sides --out=/tmp/airport-plane-review
```

The combined airport-jetway audit includes aircraft material/resource sharing,
triangle budget, ground and ceiling fit, no exterior colliders, separation
from the jetway, and apron/backdrop containment. The full-depth Blender model
and Godot scenery views were visually inspected.

Validation on 2026-09-05: the combined jetway/aircraft audit passed all 20
orientation/height cases and 121 generated chunks. The full doorway audit
passed 6,476 rooms, with 22 airport apron setpieces and zero overflow meshes.
