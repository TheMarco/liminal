# Pool equipment

Original low-poly Blender props based on the supplied pool equipment photographs.
Coordinates are metres, +Y up, +Z toward water. The pool lip is Z=0 and the dry
deck is Y=0. Each GLB is one mesh with three PBR material surfaces. Each slide is
an explicitly sampled, closed fiberglass shell, with no high-poly decimation.

Editable Blender sources and front/reverse render previews live under
`art/pool_equipment/`. Rebuild with Blender's background mode and
`tools/blender/build_pool_equipment.py`.

`collision.json` describes inner trough centerlines, ladder endpoints, and support
primitives for lightweight game collision, independently of the render mesh.
`mesh_stats.json` records exact triangle counts and Godot-coordinate bounds.
