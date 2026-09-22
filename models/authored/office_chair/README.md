# Modern office task chair

One Scenario-generated chair replaces the CC0 FBX task chair on office
floors only: cubicle workstations, small-desk rooms, the break room, the
boardroom and the theme-1 meeting setpiece. School teacher chairs and
prison guard-desk chairs keep the old prop.

| Model | Design | Triangles | Meshes / materials |
|---|---|---:|---|
| office_chair | Grey fabric seat/back, tubular frame, armrests, 5-star caster base | 4,759 | 1 / 1 |

World bounds (after the file's own 0.90176 root scale and -90° root yaw)
are x -0.4060..0.4060, y -0.4500..0.4500 and z -0.4077..0.4077, centred on
the origin. Runtime placement lifts the instance 0.45m so the casters land
on the generated floor, with a 0.84 x 0.92 x 0.84m collider. The seat faces
+Z natively, so the instance carries a half-turn inside its pivot and the
seat faces the placement -Z exactly like the chair it replaces; the facing
audit and surface wear keep keying off the same `office_task_chair` meta.
Single PBR material, kept as generated (no flat override).

## Sources and rebuild

Generated 2026-09-21 via the Scenario MCP server (team "Marcovhv's Workspace",
project "Default Project"), model Tripo P1 image-to-3D
(`model_tripo-p1-image-to-3d`), job `job_kQgCJzuSVXuxyEXYfHVK4jt9`, asset
`asset_MWW8dNbwUcUXR7TmA1Gu4Gub` (105 CU). Reference: product photo of a
Blu-Dot-style desk chair (asset `asset_1jZcE9N964GwBz5ws5TQJEUz`), PBR on,
detailed textures aligned to the source image, real-world auto-sizing.

Import via Godot --headless --editor --path . --quit.

Post-process: vertex normals recomputed area-weighted (the export shipped corners opposing their faces, which rendered as black triangles); geometry and UVs untouched. Originals in /tmp/glb_bak/.
