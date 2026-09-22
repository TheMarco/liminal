# Environment behavior rollout assessment

**Current rollout:** breath and travelling pressure are integrated across all 11
themes, using clear visible walls and shared horror pacing. The historical
assessment below is followed by implementation
and validation notes.

Assessed September 21, 2026 against main `3aa66e7` and recovery snapshot
`b3792e9`. The initial ranking was a source assessment; the subsequent
cross-environment GPU feasibility pass is recorded below.
The five recovered cases are documented in that snapshot's
`docs/MANUAL_MOTION_TEST.md` (F1–F5). That baseline excluded their integration.

## Initial recommended order

| Order | Behavior | Relative effort from current main | Reason |
| --- | --- | --- | --- |
| 1 | Breathing wall | Lowest; still needs integration | One existing wall patch, pinned edges, original finish, sampled collision and an actor proximity limiter. No route changes or floor support changes. |
| 2 | Full hallway wave | Medium | Strongest recorded visual acceptance, but moves walls, floor, ceiling, fixtures and collision together. More geometry and actor-clearance obligations. |
| 3 | Migrating doorways | High | Needs safe opening/closing plus authoritative route changes, enemy path invalidation, protected passages and durable state. |
| 4 | Impossible return loop | Higher | Needs paired hidden passage traversal, camera/velocity continuity, enemy pursuit, two-sided streaming and persistent topology. |
| 5 | Growing corridor | Highest | Adds moving geometry, approach guards and saved final length on top of hidden-link traversal. The saved implementation enables crossing only after motion latches. |

These are relative engineering judgments, not measured time estimates. All five
have recoverable code; none should be treated as a switch currently ready to enable.
The recovered manual checklist records the corrected wave as user-approved and
the other four as awaiting manual acceptance.

## Initial campaign proposal (superseded by the rollout below)

Use an eligible ordinary Office corridor wall. Keep its existing material,
doors, props and layout. Play once when visible, then return to the original
surface. Skip placement when the wall is unsuitable. Office-only support is an
explicit first release boundary; other environments can opt in after their own
geometry and material checks.

Recover selectively from `b3792e9`:

- `scripts/office_breathing_wall.gd`, `scripts/breathing_wall_effect.gd` and the
  required material/shader pieces. The Office adapter already finds a clear
  patch, preserves the original wall and limits its bow around actors.
- Restore wall identification in `scripts/levels/office_level_builder.gd`:
  current wall creation no longer supplies the `office_wall_side` metadata.
- Adapt placement, witnessing, pacing, motion settings, consumed-state saving
  and chunk cleanup. The saved `ArchitecturalEffects` references the removed
  `SpatialWitnessTracker` and structural pacing APIs; it is not a drop-in file.
- Extract the relative-transform helper used from `WalkableCorridorWave`, so
  the first wall encounter does not require restoring the hallway-wave system.

Smallest meaningful visual check: one deterministic Office wall at rest, peak
bow and settlement; approach and hug it to check that it neither pushes the
player nor clips through them, and inspect its pinned edges and original finish.
Reuse the recovered `tools/audit_office_breathing_wall.gd` for collision/render
agreement and orientation coverage. Before campaign acceptance, also check
pause/disable settlement, enemy clearance, unload/reload, checkpoint replay and
an ineligible placement that safely skips. Adapt the existing focused audits
for persistence and campaign lifecycle; do not restore the full historical test
matrix just to assess this first slice.

## Evidence locations

All paths below refer to recovery snapshot `b3792e9` unless stated otherwise:

- `docs/ARCHITECTURAL_MOTION_PLAN.md`: implemented Office scope, superseded
  early concepts and recorded visual acceptance.
- `scripts/office_breathing_wall.gd:16`: wall attachment; `:94`: actor limiter.
- `scripts/walkable_corridor_wave.gd:26`: four-surface collision and actor support.
- `scripts/architectural_placement.gd:6`: Office-only placement and stable edges.
- `scripts/architectural_effects.gd:17`: removed witness dependency; `:102`:
  removed structural pacing dependency.
- `scripts/migrating_door_site.gd:3`: moving leaves and guarded closure.
- `scripts/hidden_link_site.gd:153`: paired streaming requirements.
- `scripts/growing_corridor_site.gd:3`: motion, latch and traversal contract.
- Current `scripts/horror_director.gd`: quiet-event/blackout pacing remains,
  but the saved structural event API is absent.

No campaign code changed. The initial source review did not run runtime tests.

## Cross-environment feasibility preview

The user's next instruction made **all-environment visual review the first
gate**, before deciding campaign rollout. Added only a preview harness:

```sh
godot --path . --script tools/preview_breathing_environments.gd
godot --path . --audio-driver Dummy --script tools/preview_breathing_environments.gd -- --capture
```

N/P changes environment; Space pauses; R shows rest; B shows peak;
left/right arrows change angle; F toggles the flashlight. All 11 active
themes are included. Optional `--theme=9` or `--themes=0,9` narrows a pass;
`--out-dir=/absolute/path` changes the default `/tmp/liminal-breathing-environments`.

The harness uses actual generated chunks at seed `980712989`, searches up to
nine cells per theme, and avoids intersecting props, wear and trim. It reuses
SurfaceWear's structural face discovery. It does not run or save a campaign.
The local displacement shape is the original pinned sine-squared bow; this is
a new isolated compatibility probe, not a restoration of the old event system.

| Environment | Sample result / adaptation |
| --- | --- |
| Casino | 3.0 × 1.4 m patch above wood trim; preserve wallpaper coordinates. |
| Office | 3.0 × 2.2 m original painted wall; bow reads through shading. |
| Annex | 3.0 × 2.2 m native QuadMesh face; BoxMesh-only support is insufficient. Framing and dark lighting need review. |
| Airport | 3.0 × 2.2 m native wall; preserve material's height/panel coordinates. |
| Asylum | 3.0 × 2.2 m tiled sample; displacement is readable under flashlight. Native sample is very dark. |
| School | 3.0 × 1.4 m patch above trim; shader variant retains its pattern. |
| Mall | 3.0 × 2.2 m patch above trim; plain plaster makes the bow subtle. |
| Prison | 3.0 × 1.4 m patch above dado; retain finish and fixed trim. |
| Poolrooms | 3.0 × 2.2 m patch above lower geometry. Naive deformed-world mapping produced rings; native vertex coordinates are now evaluated before deformation, removing the artifact. |
| Data Center | 3.0 × 2.2 m clear concrete patch; subtle in dark lighting. |
| Upside Down | 3.0 × 2.2 m clear wall patch, avoiding growth/wear; subtle in dark lighting. |

All eleven representative samples passed 132 ray probes (three horizontal
positions at rest, half, peak, and restored rest), with no misses and a worst
error of **3.31 mm** against the analytic surface. Each original mesh and
material resource was restored. Captured 44 images: rest/half/peak using the
player's flashlight settings, plus peak under native lighting. Inspected the
rendered samples, including the corrected Poolrooms mapping.

Evidence: `/tmp/liminal-breathing-environments/report.json`, its adjacent PNGs,
and `/tmp/liminal-breathing-final.log`. An image comparison gallery is saved as
`/tmp/liminal-breathing-environments/index.html` and served locally on port 8767.

**Limits:** one material/room sample per environment is not every style or seed.
The inspection camera can rise to a clear patch; normal player-eye readability
still needs checking. No player/enemy contact, navigation, save/load, or campaign
scheduling acceptance is implied. The CPU mesh/collider updates are preview
machinery and are not a production performance solution. The captured runs
reported seven texture RIDs at shutdown; cleanup remains a preview limitation.
The user visually approved the original eleven samples, then requested varying,
often larger bulges.

## Variable bulge sizes

The preview now defaults to Large and exposes three fitted profiles:

- **Small:** up to 1.8 × 1.2 m, 18 cm depth.
- **Medium:** the previously reviewed wall patch, 30 cm depth.
- **Large:** expands toward 6.0 × 3.6 m and 65 cm depth, bounded by the
  existing wall face and surrounding meshes. When space is restricted, it
  reduces size/depth; it does not remove trim, props, wear or doors.

Press **1/2/3** to compare profiles. **V** varies the profile between breaths,
using deterministic non-repeating choices and changing only at the rest point.
Both CPU collision and GPU deformation receive the selected size and depth.
The material mapping correction remains in place.

Rebuild all comparisons with:

```sh
godot --path . --audio-driver Dummy --script tools/preview_breathing_environments.gd -- --capture --all-sizes
python3 tools/write_breathing_gallery.py
```

`--size=small`, `--size=medium`, or `--size=large` selects one profile. The gallery
has independent size and pose selectors and displays actual fitted dimensions.
Larger profiles were first checked in Office and Poolrooms before expanding the
capture matrix. Campaign integration and actor-contact validation remain outside
this preview.

All 33 environment/size combinations passed the capture checks: 396 ray probes,
no misses, maximum sampled error 7.16 mm, and original resources restored.
Large reaches 6.0 m width in School and Prison and 4.8 m in Casino, Mall,
Poolrooms, Data Center and Upside Down. Depth reaches 65 cm in ten samples;
the Data Center sample is restricted to 30 cm by neighbouring geometry.
Logs: `/tmp/bulge-size-all.log`; report and size-labelled images are in the
existing capture directory. The seven-texture shutdown warning persists.

## Ceiling and opposing-wall motion previews

`tools/preview_breathing_surfaces.gd` previews two additional Office cases.
Muse implemented the isolated harness; primary review corrected the pass check
before cleanup, inward-facing wall selection, aligned patch centers, and camera
visibility ray endpoints. No campaign code changed.

- Ceiling: 3.0 × 2.5 m patch, 45 cm downward displacement, 2.30 m remaining height.
- Opposing walls: two 3.0 × 2.0 m patches, each 55 cm inward, sharing a seven-second
  breath. The sampled 3.78 m lane retains 2.68 m at peak.
- GPU captures passed: 27 ray probes across rest, peak and returned rest, zero
  misses, maximum error 4.32 mm; original meshes and materials restored.

Run `godot --path . --script tools/preview_breathing_surfaces.gd -- --case=ceiling`
and press **1/2** for ceiling/paired walls, **Space** pause, **R/B** rest/peak,
**F** flashlight. `--capture --case=paired --out-dir=…` writes 24 frames plus the
rest/peak images and report. The gallery shows seven-second animated WebP loops
in `ceiling/preview.webp` and `paired/preview.webp`; these are sampled animation
previews, not a runtime frame-rate measurement. Local ffmpeg has a missing x265
library, so Pillow encoded the existing frames instead.

New cases are visually checked in Office only. Other environments, travelling
bulges, player/enemy contact and production performance remain pending.

## Projected-texture ring correction

The Office ceiling and Asylum tiles exposed a second mapping path: native
StandardMaterial3D triplanar projection was sampling the bent position and normal,
blending extra tile grids into the slopes. Poolrooms already anchors its custom
shader coordinates before deformation.

The probe now bakes the original flat-face UV projection and tangent basis for
StandardMaterial3D UV1 triplanar surfaces, preserving source scale/offset, textures
and material settings in a temporary duplicate. This matches the axis/sign
conventions in Godot 4.7's `scene/resources/material.cpp`. Only the duplicate
disables triplanar; the original mesh/material returns at rest. This path is
explicitly limited to axis-aligned flat primitive faces, as used by these samples.

Verified the ring-free ceiling animation and Asylum/Poolrooms large renders,
then refreshed 18 profiles (all sizes in Annex, Asylum, Mall, Prison, Data Center
and Upside Down). All 18 passed collision/restoration checks; maximum sampled
error remains 7.16 mm. Large renders were visually inspected in all six; Office
ceiling and Poolrooms also passed. Captures: `/tmp/liminal-rings-ceiling`,
`/tmp/liminal-rings-focus`, `/tmp/liminal-rings-standard`. The existing gallery
contains the corrected captures. Muse provided a read-only material inventory;
the primary agent diagnosed, implemented and verified the correction.

## Wall bands bend with the wall

The probe supports companion BoxMesh/QuadMesh surfaces sharing the backing
wall's exact patch frame, amplitude and phase. Known generated horizontal strips
are eligible only when their backing plane, width and shallow depth match the
wall; props and unrelated meshes remain placement blockers. The selector covers
Casino trim, Airport kick guards, Asylum wainscot, School stripe/base, Mall
rail/base and Prison dado/base. Decorative companions retain their original
non-colliding behavior; the backing wall still supplies the deformed collider.

Muse implemented companion lifecycle/propagation in the isolated worktree;
primary review integrated it and added selection, geometry checks and cleanup.
The triplanar mapping correction is retained on every companion.

School was rendered first, followed by all three sizes across these six themes.
All 18 profiles passed; sampled wall collision error was at most 2.91 mm,
companion vertex displacement error below 0.0003 mm, and all original mesh,
material and cull-margin values restored. Large renders in all six were visually
inspected. School, Mall and Prison now reach 6.0 × 2.5 m at 65 cm depth across
their bands. Asylum now selects a mixed plaster/tiled-panel wall in cell (0, 0).

Captures/report: `/tmp/liminal-bands-all`; command:
`godot --path . --audio-driver Dummy --script tools/preview_breathing_environments.gd -- --capture --themes=0,4,5,6,7,8 --all-sizes --out-dir=/tmp/liminal-bands-all`.
The gallery includes these captures and direct links to School, Mall and Prison.
Campaign integration and actor-contact/performance validation remain pending.

## Gameplay integration

The new `scripts/environment_breath_{profile,placement,surface,director}.gd`
system integrates wall breaths in Wander and Descent. It starts after a quiet
35–55 second window, then waits 65–115 seconds between completed/cancelled
encounters. The first two encounters are breaths; later encounters have a 22%
chance of travelling pressure. Sizes vary within a clear patch, with a 20–35 cm
live depth. Crowded rooms can use a smaller, higher patch; unsuitable rooms skip.
The private RNG leaves procedural generation randomness untouched.

Main supplies the presentation gate and HorrorDirector supplies shared pacing.
Photo use, scripted holds, hostiles, blackouts, transitions and realm visits
suppress the effect. Actor approach (including predicted movement) immediately
restores the wall before contact. Each effect belongs to its streamed room and
restores original mesh, material and cull margin during cancellation/teardown.

Geometry now uses prepared GPU morphs. Native shader coordinates and triplanar
UV/tangent baking stay anchored at rest, preserving the earlier ring correction.
Known wall bands share the backing wall's frame. Preparation advances one work
unit per physics frame before installation; the small collider updates at 15 Hz.
The original flat wall collider stays in place behind the bow.

The hand experiment was rejected during visual review and removed from the
runtime profiles, debug controls and gallery. At this stage, `--breathing` + F6
cycled only breath and travelling pressure. The ceiling rollout below supersedes
that limitation; paired-wall experiments remain preview-only.

Validation on the local M3 Max / Godot 4.7.2:

- `tools/audit_environment_breath.gd`: profile/normal math, collision rays,
  wall/band deformation and exact restoration; both live shapes pass on real
  generated samples in all 11 themes.
- `tools/audit_breathing_runtime.gd`: real Main startup, automatic visible-wall
  search, pacing attachment, actor withdrawal, photo suppression, partial
  preparation cleanup during room unloading, and floor-transition teardown.
- Real-room audit: maximum preparation step 10.29 ms; collider update 0.402 ms.
  These are scoped CPU samples, not a whole-game frame-rate guarantee.
- GPU captures at rest/peak/returned rest inspected in all 11 environments;
  Office breath/travel loops are in the local gallery. Asylum tiles and
  School/Mall/Prison bands retain their corrected appearance.

Capture roots: `/tmp/liminal-runtime-themes` and
`/tmp/liminal-breathing-environments/{breath,travel}`. Focused results:
`/tmp/breath-final-audit.log` and `/tmp/breath-auto.log`.

### Ceiling runtime integration — 2026-09-21

Ceiling breath now uses the same prepared GPU morph/collision implementation as
walls, not the old preview renderer. It bends a clear patch of the existing native
ceiling, leaving lights, vents, beams, overlays and junctions untouched. Maximum
depth is 0.35m, with at least 2.25m standing headroom. The actor withdrawal volume
accounts for body height along the ceiling normal, including predicted movement.
Automatic selection includes ceilings after the first two wall breaths; F6 cycles
wall breath, travel and ceiling. Unsuitable rooms skip rather than force a patch.

Focused verification (not a full release gate):

- Extended environment audit passes: horizontal GPU geometry, collision rays,
  exact restoration, fixture exclusion and standing/swept-head clearance.
  Safe ceiling patches found in nine themes in five cells each; Poolrooms and
  Data Center had none in this sample and safely skipped. This is not evidence of
  ceiling coverage in those two themes. Maximum preparation step was 17.68ms on
  this machine, not a frame-rate guarantee.
- Runtime audit passes using `-- --nologo`: real gameplay ceiling search, peak
  deformation, swept-head withdrawal, existing presentation gates and teardown.
- Rest/peak/rest GPU captures inspected for Office and Asylum. Other themes have
  mechanical coverage, not new visual approval. User ceiling approval is pending.

Evidence: `/tmp/liminal-ceiling-audit.log`,
`/tmp/liminal-ceiling-runtime-audit.log`, `/tmp/liminal-ceiling-runtime-check`,
and `/tmp/liminal-ceiling-asylum-check`. The earlier full-suite failures are not
resolved by these focused checks.

### Release-gate follow-up — 2026-09-21

The Office furniture failure was a local-search starvation bug: supported storage
rooms existed on the scanned floor, but not near the six sampled route centres.
The planner now falls back to a cached floor-wide candidate list, retaining the
same supported-style, owning-room protection and reconstruction/clearance rules.
Generation version is 12 so prior numeric reality states are not misinterpreted;
existing seed/tape progress remains separate. The mutation-graph audit passes all
11 themes (66 alternate states and 66 furniture variants, maximum planning 529ms
in this run). The affected descent-progress persistence audit also passes.

Fingerprint attribution: clean HEAD `3aa66e7` reproduces the existing reference
exactly. Current asset edits change 66 of 522 chunk samples: Casino 8, Office 10,
Asylum 45, School 3. A separate HEAD snapshot containing only the six asset-related
source edits reproduces the current fingerprints exactly; breathing is not the
source of these changes. Per user decision, School retains its original chairs:
the shared small-desk helper now uses the modern chair only in Office. The golden
reference was refreshed for the remaining 63 verified Casino/Office/Asylum changes.
All 522 samples pass the world-hash comparison, including unchanged School samples.
The School mutation-graph check was rerun after restoring its chair and passes.

Evidence: `/tmp/liminal-gates-mutations.log`, `/tmp/liminal-gates-progress.log`,
`/tmp/liminal-gates-world-base.txt`, `/tmp/liminal-gates-world-current.txt`, and
`/tmp/liminal-gates-asset-check.log`, `/tmp/liminal-gates-world-final.log`, and
`/tmp/liminal-gates-school.log`. Both reported gating failures are resolved.
This follow-up does not claim a new full-suite
pass; it covers the two reported gates and the affected persistence dependency.
