# Abandoned Hospital: part two — extracted props

- **Creator:** [Veterock](https://sketchfab.com/windofglass)
- **Original title:** `Abandoned Hospital: part two`
- **Source:** <https://sketchfab.com/3d-models/abandoned-hospital-part-two-c4c2546533fd4ee2a87ddd642f33f446>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Downloaded format:** GLB (69 MB, whole building)

## Modifications

The source is a complete multi-storey hospital, not a prop set. Its architecture
is batched into per-material meshes spanning the entire building, so only the
separately-modelled objects can be lifted out cleanly. Seven were taken; the
building itself is not redistributed.

| Local file | Source node | Size | Notes |
|---|---|---|---|
| `ward_door.glb` | `door3_SM` | 1.12 × 2.44 × 0.22 m | cream leaf, barred vision panel |
| `cell_door.glb` | `door4_SM` | 1.14 × 2.44 × 0.30 m | teal leaf, barred slot, red handle |
| `service_door.glb` | `door5_SM` | 1.12 × 2.44 × 0.25 m | rust red, mesh vent and louvre |
| `vision_door.glb` | `door0_SM` | 1.12 × 2.44 × 0.23 m | white leaf, tall vision panel |
| `scrub_sink.glb` | `Hospital_02_97m_0` | 0.86 × 1.27 × 2.22 m | steel trough on legs |
| `hydro_bath.glb` | `Hospital_02_92m_0` | 0.93 × 1.32 × 2.66 m | one tub cut from a row of three |
| `pinned_notices.glb` | `Hospital_02_103m_0` | 2.13 × 0.99 × 0.07 m | loose paper on a wall |

Each extraction carries its source node's ancestor transform so it arrives at
the original scene's real-world scale, is re-origined to its own floor and
centre, and keeps only the accessor ranges and images it actually references.
Embedded textures were re-encoded at 1024 px. `hydro_bath.glb` was additionally
clipped to a single tub and is placed at 0.80 scale in game, which brings its
rim to 0.68 m. Meshes and materials are otherwise unchanged.
