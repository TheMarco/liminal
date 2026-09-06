# Hanging straitjacket

Original project mesh authored in Blender from the user's `jacket.jpg` visual
reference. The photograph is not embedded or redistributed. This is not a
downloaded CC0/CC BY asset.

- **4,454 triangles**, one mesh, one material surface.
- Three embedded **1024 × 1024** maps: base color, tangent normal, and packed
  roughness/metallic. Canvas wear and fine wrinkles are baked into the maps.
- Approximately **0.96 m wide × 1.18 m tall × 0.27 m deep**, including loose
  sleeves and the wall hook. Front faces Godot **+Z**; the back clears Z = 0.
- `_asy_straitjacket` mounts the mesh at Y = **0.92 m**, preserving the existing
  procedural wall positions and spawn frequency. No collider or animation.
- Godot generates distance LODs and a shadow mesh on import. Instances share
  the cached scene's geometry and textures.

Editable source: `art/straitjacket/straitjacket.blend`. The studio and render
camera are excluded from the runtime GLB. That source folder has `.gdignore`
so Godot imports only the game export.

Rebuild from the repository root (Blender 5.2):

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/blender/build_straitjacket.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/audit_straitjacket.gd
godot --path . tools/preview_prop.tscn -- \
  --prop=_asy_straitjacket --screenshot=/tmp/straitjacket.png
```

The builder recreates the model, UV atlas, materials, source file and two studio
renders. It exports only the selected game mesh; the native Blender geometry
is directly editable. `mesh_stats.json` is regenerated with each export.
