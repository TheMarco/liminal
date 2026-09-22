# Asylum ward door leaf

One Scenario-generated leaf joins the asylum door rotation (index 5 of 6):
a cream-painted ward door with a wired-glass vision panel, brass handle
and kick plate.

| Model | Design | Triangles | Meshes / materials |
|---|---|---:|---|
| asy_ward_door | Aged cream paint, wired-glass panel, brass, kick plate | 4,469 | 1 / 1 |

World bounds (after the file's own 2.10411 root scale and -90° root yaw)
are 0.834w x 2.100h x 0.292d, centred on the origin with the detail on +Z.
The generated leaf is narrow, so cased runtime scale stretches it to
(1.20, 1.01, 1.0) with a 1.0605m floor lift (1.00 x 2.12m); sealed-wall
facades use (1.20, 1.0, 1.0) with a 1.05m lift. Single PBR material, kept
as generated.

## Sources and rebuild

Generated 2026-09-21 via the Scenario MCP server (team "Marcovhv's Workspace",
project "Default Project"): reference front elevation with GPT Image 2.5
Sunburst (job `job_GGruA5diZiD2vuiQ4p9wwvWY`, asset
`asset_EwutWMEg9k5kY8rw48JPdZ6J`), then Tripo P1 image-to-3D
(`model_tripo-p1-image-to-3d`), job `job_Q4jzjWzfm23hhJVHC9o3fv4e`, asset
`asset_pe1bp1j7iGwP9G2DmdMPkmT1` (105 CU). PBR on, detailed textures
aligned to the source image, real-world auto-sizing.

Reference prompt: "Orthographic front elevation product reference photo of
a tall painted ward door leaf from a 1930s hospital: aged cream-white
chipped paint over wood and metal panels, large frosted wired-glass vision
panel in the upper half, brass lever handle, kick plate, hinges, wear and
grime, centered filling the frame, flat neutral light-gray studio
background, no frame, no wall, no perspective distortion, no other objects."

Import via Godot --headless --editor --path . --quit.

Post-process: vertex normals recomputed area-weighted (the export shipped corners opposing their faces, which rendered as black triangles); geometry and UVs untouched. Originals in /tmp/glb_bak/.
