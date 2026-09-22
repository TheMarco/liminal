# Asylum bay portal frame

Wide sibling of the door frame, built for the 1.9-2.9m open corridor bays
that the narrow frame had to stretch up to 2.2x to cover. Same riveted
green steel language, same 1.1 height so lintels line up down a corridor.

| Model | Design | Triangles | Meshes / materials |
|---|---|---:|---|
| asy_bay_frame | Wide portal frame, heavy beams, rust and rivets | 4,452 | 1 / 1 |

World bounds (after the file's own 2.10411 root scale and -90° root yaw)
are 2.100w x 2.100h x 0.473d with a 1.804m opening and no bottom rail.
Runtime scale is ((width + 0.12) / 2.10, 1.1, 1.1) with a 1.155m floor
lift: 0.96-1.44x stretch across the bay range, the opening always inside
the wall cut. Single PBR material, kept as generated.

## Sources and rebuild

Generated 2026-09-21 via the Scenario MCP server (team "Marcovhv's Workspace",
project "Default Project"): reference front elevation with GPT Image 2.5
Sunburst (job `job_pcGR3D3aPPs1kwwBFBvMocVx`, asset
`asset_AgbqzURn4GRUmF9zW3ufLatd`), then Tripo P1 image-to-3D
(`model_tripo-p1-image-to-3d`), job `job_cooBZEYYhYhr8tMs3GEJWTtD`, asset
`asset_rFFccfjojYRpLnDA4zoGatCn` (105 CU). PBR on, detailed textures
aligned to the source image, real-world auto-sizing.

Reference prompt: "Orthographic front elevation product reference photo of
a WIDE institutional double-door portal frame only, large empty rectangular
opening with no door leaves: two heavy riveted steel jamb pilasters and one
long spanning lintel, roughly 2.5 meters wide by 2.3 meters tall overall,
dark green chipped paint over metal with rust streaks and scratches, 1930s
asylum hardware, centered, filling the frame edge to edge, flat neutral
light-gray studio background, no floor, no wall, no perspective distortion,
no other objects."

Import via Godot --headless --editor --path . --quit.

Post-process: vertex normals recomputed area-weighted (the export shipped corners opposing their faces, which rendered as black triangles); geometry and UVs untouched. Originals in /tmp/glb_bak/.
