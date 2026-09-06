# Procedural model review

This pass reviews the active procedural prop recipes in all eleven world
builders and the shared Chunk recipes. It improves construction and silhouettes
while keeping the existing palettes, understated wear, lighting and VHS effect.
The comparison baseline is commit `bc0d3e0`.

## Coverage

| Area | Procedural models improved |
| --- | --- |
| Shared | Filing-cabinet label holders and plinths; terminal vents, feet and beveled keyboard keys; shelving lips, cross braces and carton seams; desk modesty panels and feet. |
| Vegas | Service-cart tray rims, bent handle, caster forks and stemware; fuller curtain folds, stage nosing and microphone fittings; flush-light retaining collar. |
| Office | File folders and tabs; door/sign/directory mounts; desk construction; coffee-counter panels and machine/carafe fittings; boardroom-table apron, cable ports and display trim. |
| Annex | Doors, pulls and brackets on the generated cabinet/bookcase in the furniture pile; generated lamp neck. |
| Mall | Shaped garments and hangers; display-table garment layers and apron; shelf/gondola brackets and lips; checkout, kiosk, food-vendor and cinema counter panels; fountain fittings and poster-stand braces. |
| Airport | Open trolley basket and caster forks; stanchion reel fittings; shaped aircraft hull and engine; jetway service fittings; gate-desk controls; travelator and escalator end details; baggage-carousel/chute access panels; column collars. |
| Asylum | Restraint-table legs and bracing, head pad and buckles; ECT paddles and curved cables; generated tub rim, taps and drain; straitjacket layers and buckles; noticeboard frame; dayroom-table apron and chemistry-counter fittings. |
| School | Chalk tray and eraser; projector-screen fittings; cupboard fronts and plinth; braced cafeteria tables and servery details; stall hardware and mirror trim; round basketball hoop, net and target; bleacher supports; shelving ends, splayed laboratory stools, noticeboards and trophy-case fittings. |
| Prison | Gate locks and mounts; table frames; serving-counter details; shower valves, face perforations and bench slats; guard-console bezels and key-cabinet trim; workbench vise and bracing; visitation dividers and stool bases. |
| Pool | Retaining rings and fittings on generated ceiling/wall lights; handrail flanges and fasteners. |
| Data Center | Gallery brackets; suspended cable-tray hangers and clamps; protective beacon cage and mounting; pipe couplings and supports. |
| Bloom | Fuller incubator pod and shaped cradle; smoother procedural vines; bleacher frames; basketball-board supports and net. |

## Scope boundaries

Downloaded models and their instances are excluded. In mixed assemblies, new
geometry belongs only to the generated furniture or fixture. This includes
leaving downloaded school desks, terminals, chairs, medical furniture, crutches,
bunks, toilets, phones, pool furniture, server racks and organic assets alone.
No files under `models/` or `textures/` are edited.

The approved ghosts are unchanged. Existing detailed elevators and structural
wall/floor systems were reviewed and retained. Legacy fallback models that are
superseded by shipped downloaded assets were not rewritten merely to increase
the number of changed functions.

## Rendering and generation

`ProceduralDetails` combines static fittings into one cached ArrayMesh per
material. Small parts therefore do not each require a separate MeshInstance3D.
The detail cache is bounded at 192 designs and cleared with the game's other
runtime caches. Keyboard keycaps replace 49 individual meshes with one batch.
The changes add no lights, textures, physics bodies or update loops.

Detail batches are excluded from surface-wear discovery: their combined bounds
include empty space, so treating them as a large furniture surface would steal
existing overlays from original meshes. A regression check covers this case.

These improvements still add geometry and some draw submissions. Passing the
generation-performance gate does not establish an unchanged gameplay frame rate.

## Visual review tools

`tools/capture_procedural_props.gd` renders a catalog of 78 prop/assembly cases.
Use `--both-sides` to inspect both faces, `--filter=substring` for a focused case,
and `--out=PATH` for the output directory. Each manifest includes mesh, surface
and triangle counts. The optional `--baseline` mode uses source snapshots from
`build/procedural-review/source-before/`: `chunk.gd.txt` and the original
`*_level_builder.gd.txt` files. Keep those snapshots as text with a `.gdignore`
file so Godot cannot register duplicate global script classes.

`tools/capture_visual_review.gd` checks the same models in complete generated
rooms with production lighting and clean/VHS views. Review artifacts are local,
under the ignored `build/procedural-review/` directory.

## Validation

- All 64 audits passed, including compilation, generation performance, doorway
  clearance, furnishing overlap, surface wear, and the reviewed world hash.
- The final 522-chunk comparison preserved 12,334 physics nodes, 1,006 lights,
  445 scripted interaction nodes, and 482 labels, including ancestor transforms.
- All 2,778 identified imported model roots matched their original subtrees,
  material signatures, wear metadata, and ancestor transforms.
- The full comparison contains 1,135 additional mesh instances across 522
  chunks (49,647 to 50,782, about 2.3%). This is scene-graph accounting, not an
  FPS measurement; the increase varies by room.
- Isolated before/after captures cover 78 cases from two sides. Examples:
  the keyboard falls from 51 to 3 mesh surfaces, the school hoop from 14 to 4,
  and the Bloom pod from 7 to 3. Triangle counts may still increase where the
  shapes are improved.
- Full GPU captures cover 86 room styles across all eleven worlds, with VHS,
  clean, and reverse clean views. The reviewed rooms retain their existing
  lighting and atmosphere. No script or rendering errors were logged; Godot
  reported seven texture RIDs at capture-tool shutdown, so this run is not a
  claim of leak-free renderer teardown.
- The independent final fingerprint still matches the audited golden after
  removing the aircraft's hidden, redundant fairing mesh.
- Baseline and final headless fingerprints emit the same known Godot dummy
  renderer material warning. GPU prop captures contain no rendering errors.


## Casino slot replacements — 2026-09-05

Four original Blender cabinets now replace the two downloaded machines in Level 1: Royal Sevens, Fortune Wheel, Buffalo Sunset and Sapphire Palace. They use original illustrated game screens, metallic trim, closed service backs and animated multicolor light guides. Cabinet budgets are 2,620 / 5,030 / 3,056 / 3,430 triangles respectively, with four or five merged surfaces. Existing rows, stools and room lighting remain integrated through the casino builder.

Gallery entries: vegas-slot-classic, vegas-slot-wheel, vegas-slot-dual, vegas-slot-triple. The gallery header links to an in-game bank screenshot with both clean and tape-filtered views. Source, rebuild steps, illustration prompts and validation are documented in models/authored/casino_slots/README.md.
