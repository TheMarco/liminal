# Asylum cell door leaf

One Scenario-generated leaf joins the asylum door rotation (index 4 of 6):
a heavy green steel cell door with a small barred vision window, food
hatch, hinges and handle.

| Model | Design | Triangles | Meshes / materials |
|---|---|---:|---|
| asy_cell_door | Distressed green steel, barred window, hatch, rivets | 4,672 | 1 / 1 |

World bounds (after the file's own 2.10411 root scale and -90° root yaw)
are 0.958w x 2.100h x 0.481d, centred on the origin with the detail on +Z.
Cased runtime scale is 1.01 with a 1.0605m floor lift (0.97 x 2.12m);
sealed-wall facades use it at native scale with a 1.05m lift. Single PBR
material, kept as generated.

## Sources and rebuild

Generated 2026-09-21 via the Scenario MCP server (team "Marcovhv's Workspace",
project "Default Project"): reference front elevation with GPT Image 2.5
Sunburst (job `job_bYbTmmA7WiKhnkwTbZayXnjS`, asset
`asset_paG2dyzaVSkrv3jDRgSi7u5e`), then Tripo P1 image-to-3D
(`model_tripo-p1-image-to-3d`), job `job_o2U8eutwVxe4J1CppLwPekLn`, asset
`asset_Ddfg4n8FuJ2X1QAXQihFJ2cm` (105 CU). PBR on, detailed textures
aligned to the source image, real-world auto-sizing.

Reference prompt: "Orthographic front elevation product reference photo of
a heavy steel asylum cell door leaf: dark green chipped painted metal,
small square barred vision window near the top with dirty wired glass, food
hatch with steel flap at waist height, riveted edges, lever handle and lock
plate, scratches and rust, centered filling the frame, flat neutral
light-gray studio background, no frame, no wall, no perspective distortion,
no other objects."

Import via Godot --headless --editor --path . --quit.

Post-process: vertex normals recomputed area-weighted (the export shipped corners opposing their faces, which rendered as black triangles); geometry and UVs untouched. Originals in /tmp/glb_bak/.
