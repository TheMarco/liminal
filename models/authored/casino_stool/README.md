# Casino slot stool

One Scenario-generated stool replaces the CC0 `bar_chair_round_01` at slot
machines in the vegas level (both the authored-cabinet and procedural-fallback
placements). Card-table, lounge and mall seating keep the old prop.

| Model | Design | Triangles | Meshes / materials |
|---|---|---:|---|
| casino_stool | Worn red-vinyl tufted seat, chrome pedestal, trumpet base, footrest ring | 7,951 | 1 / 1 |

Imported bounds are x -0.7297..0.7297, y -0.9513..0.9513 and z -0.7320..0.7310,
centred on the origin. Runtime scale is 0.34 with centre (0, -0.9513, -0.0005),
so the stool stands 0.65m tall and 0.50m wide with its base on the generated
floor, inside the existing r=0.25/h=0.8 stool collider. Single 2K PBR material
(albedo, metallic, roughness, normal); no emission map.

## Sources and rebuild

Generated 2026-09-21 via the Scenario MCP server (team "Marcovhv's Workspace",
project "Default Project"), model Meshy 7 Text-to-3D (`model_meshy-7-txt23d`),
job `job_CZS9sAe4xxJ6EF7Y6tDdBnTD`, asset `asset_b8bwFucHtzczzqtAHu1axSbt`
(240 CU). Remeshed to 8,000 target polygons, triangle topology, PBR enabled.

Geometry prompt: "Worn 1980s Las Vegas casino slot-machine stool, single
object: round padded deep-red vinyl seat cushion with button tufting and
cracked patina, central scuffed chrome pedestal column, round flat trumpet
base, circular chrome footrest ring. Game-ready low-poly 3D prop, centered, no
background, no other objects."

Texture prompt: "worn deep-red vinyl upholstery with cracks, creases and edge
wear; scuffed polished chrome metal with scratches and dull patches".

Import via Godot --headless --editor --path . --quit.

Post-process: vertex normals recomputed area-weighted (the export shipped corners opposing their faces, which rendered as black triangles); geometry and UVs untouched. Originals in /tmp/glb_bak/.
