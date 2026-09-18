# Chase readability and caught feedback

September 13, 2026; caught presentation revised September 14. The September 14
Windows/macOS release rebuild includes the floor-fall sequence and leaning ghost
below. The later opt-in reality-aftershock prototype remains source-only.

- School desk stations retain their real 0.80 × 0.96 m collision footprints.
  The new 2 m pitch leaves 1.20 m lateral gaps and 1.04 m between rows. Four
  columns replace five; doorway clearance may remove additional stations.
- Cafeteria tables use an orientation-aware grid with 4.15 × 3 m spacing.
  The 2.9 × 1.6 m footprints leave 1.25 / 1.40 m passages. Servery and doorway
  reservations remain in force.
- Data Center rack rows have 2.5 m spacing, including merged halls. Compact
  fields have three banks rather than five, with a central crossing and
  traversable aisles. Cabinet pairs still form solid banks; the player is not
  expected to squeeze through their joints. Collision geometry was not shrunk.
- Data Center (theme 10, not Poolrooms theme 9) keeps the baseline charging
  lattice and adds one deterministic maintenance charger in every third 3×3
  macro-cell, preferably in a service room. Added poles use the same cabinet,
  standing-space and doorway checks, and this floor never marks them broken.
  The 9×9-cell audit measured 9 baseline + 3 extra stations for all three seeds;
  an unsafe candidate elsewhere may still be omitted. Target-room poles and
  arrival exclusions are unchanged.
- All seven hostile figures get a small cloth brightness lift only against
  dark opaque scenery. No outline, light source, opacity increase, through-wall
  rendering, or bright-room lift was added. Existing approach audio is retained.
- A fatal visible catch ends run rules immediately, freezes input/movement/other
  figures, finishes any in-flight photograph, and plays a 2.5-second sequence:
  loss of balance, an accelerating fall to floor level, a brief view up at the
  actual catching figure leaning overhead, then a smooth fade to black.
  Its forward lean is approximately 24 degrees so the body visibly bends over
  the fallen eye, rather than remaining an almost upright cutout.
  The camera eases toward the catcher from its actual direction, with a small
  sideways roll and one settling recoil. No actor teleports in front of it.
  The collision body stays fixed; a swept camera sphere protects the fall
  from walls/props and actual support/water heights bound the landing point.
  Blackout catches retain the short 0.82-second unseen slump/cut.
- Head-motion strength scales the camera movement and reorientation; zero leaves position,
  orientation and FOV unchanged. There are no added flash/glitch pulses, and
  the selected VHS mode is never enabled or changed. Emergency flash saves
  and nonfatal foreign-realm returns retain their existing behavior.
- Results begin on the black backdrop instead of briefly showing the room
  again. Camera processing and pose are restored for retry/continue, and stale
  interaction/event HUD messages are hidden during death.

## Verification

- `tools/audit_chase_clearance.gd`: 18 fixtures / 3 seeds, 0.8 m capsule
  entrance connectivity and inter-desk gaps, plus measured 1 m compact-rack
  central and row crossings.
- `tools/audit_datacenter_charging.gd`: 3 seeds / 9×9 cells, deterministic
  counts, negative coordinates, working poles, cabinet and standing clearance.
- `tools/audit_caught_sequence.gd -- --mode=descent --nologo`: production catch
  signal, saved flash, photo wait, frozen movement, exact actor, camera comfort,
  blackout, results, interruption and continue. Optional `--capture-caught`
  writes GPU grab/floor/loom/fade/black/results frames under `/tmp` (requires a rendering device).
- `tools/audit_ghost_readability_render.gd`: GPU comparisons for all seven
  bodies against dark/bright scenery and opaque walls, plus VHS review images.
  It excludes moving particle wisps and temporal AA from exact pixel comparisons.
- `tools/audit_caught_floor.gd`: all seven actors, front/rear/side catches,
  extreme pitch, zero/partial motion, elevated floors, obstacles, pool edges,
  camera clearance and interrupted restoration.
