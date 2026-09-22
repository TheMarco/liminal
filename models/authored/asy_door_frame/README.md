# Asylum door frame

One Scenario-generated riveted steel frame replaces the three flat boxes
that cased every asylum corridor door and open bay. Door casings use it at
fixed scale; open bays stretch it horizontally to the passage width.

| Model | Design | Triangles | Meshes / materials |
|---|---|---:|---|
| asy_door_frame | Riveted green steel jambs + lintel, rust and chips | 4,412 | 1 / 1 |

World bounds (after the file's own 2.10411 root scale and -90° root yaw)
are 1.245w x 2.100h x 0.579d with a 0.949m opening. Runtime scale is 1.1
with a 1.155m floor lift: the 1.044m opening clears every 2.12m leaf and
the 1.37m shell overlaps the 1.22m wall cut on both sides. Single PBR
material, kept as generated.

## Sources and rebuild

Generated 2026-09-21 via the Scenario MCP server (team "Marcovhv's Workspace",
project "Default Project"): reference front elevation with GPT Image 2.5
Sunburst (job `job_HhjQx3szR9VxHjrgoNjAVHQJ`, asset
`asset_X1fc3pfLmZsSPj3CUJ9w923R`), then Tripo P1 image-to-3D
(`model_tripo-p1-image-to-3d`), job `job_5zH3ytcUtwKj5sPuvfLaeuzG`, asset
`asset_N45eKfpEufydUrrKFT6umhJM` (105 CU). PBR on, detailed textures
aligned to the source image, real-world auto-sizing.

Reference prompt: "Orthographic front elevation product reference photo of
a heavy institutional door frame only, empty opening with no door leaf: two
riveted steel jambs and a lintel, dark green chipped paint over metal with
rust streaks and scratches, 1930s asylum hardware, centered, filling the
frame, flat neutral light-gray studio background, no floor, no wall, no
perspective distortion, no other objects."

Import via Godot --headless --editor --path . --quit.

Post-process: vertex normals recomputed area-weighted (the export shipped corners opposing their faces, which rendered as black triangles); geometry and UVs untouched. Originals in /tmp/glb_bak/.
