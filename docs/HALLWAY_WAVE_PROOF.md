# Hallway wave: conservative gameplay integration

The approved inward travelling swell is an occasional choice in the shared
architectural event manager, in Wander and normal Descent exploration. It shares
one cadence and recent-history policy with wall/ceiling breaths and supernatural
doorways. Its long-run selection target is 18%, subject to eligible visible
rooms and quiet pacing. The wave effect retains its own final safety gates.

Native meshes/materials/fixtures are deformed, not replaced by a synthetic room.
GPU shapes and static collision share phase keys, updated before player movement.
Preparation and rest-pose mesh installation are spread over frames with a 2 ms
soft slice budget; an individual engine upload can exceed it. Time-independent
vertex coefficients are cached. Preparation times out at 45 seconds or cancels
if the player leaves the neighborhood. Pacing is reserved when motion starts.

## Eligibility and safety

- Straight native corridors: Casino, Office, Annex, Asylum, School, Mall, Prison,
  Data Center and Upside Down. Annex bends/intersections are skipped. Data Center
  uses its 3.45 m inner tunnel, not the exterior shell height.
- Airport: ordinary single-cell halls only. No transit/concourse moving walkways.
- Poolrooms: dry single-cell alcoves without Jacuzzi or water surfaces. Water
  channels, swimming, ladders and slides are not adapted.
- Rooms containing interaction/traversal Areas (including charging stations),
  portals, objectives/arrivals, landmarks, optional discoveries, active bleed or
  anomalies are excluded. Unsupported collision bodies/shapes fail closed.
- Wave displacement is zero at and outside all four horizontal chunk boundaries.
  Wide-room side motion fades near the boundary; narrow-corridor motion is retained.
- Hostiles nearby, approaching a narrowing side wall, camera/recording states,
  blackouts, realm visits, transitions and chunk replacement/unload cancel it.
  Cancellation restores original mesh/material/shape identities and attachments.
  The inward-only warp restores walls outward and ceilings upward; a raised floor
  drops at most 35 cm back to its original position. Monsters are not modified.

## Manual testing

From the project root, launch actual streamed Office gameplay without campaign saves:

```sh
godot --path . -- --nologo --level=1 --seed=980712989 --pos=-78,-87 --yaw=0 --flashlight --hallway-wave
```

This test launch waits for you: **F6 always plays/replays the wave**, rather than
cycling effects or firing an automatic one-shot before you focus the window.
Wait for “PLAYING NOW”, then walk/sprint through it and cross into the adjoining
room. Turn away and back to check the audio fade. Requests still obey safety
gates, with cancellation/waiting reasons shown and logged. With `--breathing`
instead, F6 retains the four-effect cycle. Use Fn/Globe+F6 if macOS intercepts it.

For a short **GPU capture of actual timed gameplay**, including the player camera,
streaming and director (not a forced static pose):

```sh
godot --path . --script tools/audit_hallway_wave.gd -- --nologo --level=1 --seed=980712989 --pos=-78,-87 --yaw=0 --flashlight --hallway-wave --capture-live-wave
```

This exits after saving `/tmp/liminal-live-wave-0.05.png`, `-3.50.png` and
`-5.00.png`. The capture harness ignores keyboard input and resumes focus-loss
pauses only for this automated run; normal gameplay pause behavior is unchanged.
The Office captures visibly show bowed doorways/ceiling and the rising floor.
This verifies that sample, not every camera position or streamed hallway.

Isolated multi-level visual preview (not a streamed world):

```sh
godot --path . --script tools/preview_hallway_wave.gd -- --theme=4
```

N/P switches levels; WASD/mouse moves; Shift sprints; F toggles flashlight. Stay
inside the single room. Preview selection now skips interactive-mechanism rooms,
matching the gameplay exclusion. Themes: 0 Casino, 1 Office, 2 Annex, 4 Airport,
5 Asylum, 6 School, 7 Mall, 8 Prison, 9 Poolrooms, 10 Data Center, 11 Upside Down.
The isolated preview is visual/collision-only; audition audio in gameplay.

## Supernatural sound layer

Visible breathing/waves also reuse the existing reality-aftershock blur/RGB
separation at half the enemy-warning strength (0.35). Its visibility fade follows
the sound envelope. The existing photo/enemy pulse takes exclusive priority in
the same rendering pass; their timings/strengths are unchanged. Reduced-flashing
and motion settings continue to apply, and HUD rendering stays unaffected.

The six user-supplied `sn1`–`sn6` MP3 loops live in `sounds/supernatural/`.
`supernatural_audio.gd` selects one per breathing/wave event without immediate
repeats. Camera frustum plus collision ray checks gate audibility. Gain fades in
over 0.8 seconds and out over 1.2 seconds at −22 dB through the Game bus; it stops
when inaudible. No layers accumulate. Looking back resumes the same event's sound;
the next event draws a new one. Level teardown stops playback. Music, monster
voices, photo anomalies and hostile-warning effects are unchanged.

## Focused evidence and limits

`tools/audit_hallway_wave.gd -- --nologo --level=1` boots real Main/ChunkManager,
checks boundary invariance, unchanged neighboring meshes, automatic wave search,
walking floor agreement, audio loading/fades, hostile cancellation and unload
during preparation. Run it via `godot --headless --path . --script`.
`tools/audit_breathing_runtime.gd -- --nologo` covers the existing shared runtime
gates and breathing teardown. No full suite is required for these changes.

Integrated Office runs after collision-grid tuning recorded 4.3–23.3 ms maximum
preparation slices, 7.2–9.7 ms maximum wave ticks and 2.72 cm maximum feet/profile
error. Airport GPU capture recorded a 22.7 ms preparation slice and 1.8–3.0 ms
sampled collision updates, with no renderer errors after preview selection was
corrected. Dry Poolrooms walking measured 0.78 cm error and restored resources.
These are local observations, not frame-time guarantees: **startup is not yet
proven hitch-free**. Engine calls can exceed the soft slice budget. Older
prototype bulk-swap spikes are not measurements of this path.

The user approved the eleven environment previews, including revised Airport.
That approval is visual, not exhaustive collision/gameplay certification. Runtime
restrictions and pinned side boundaries are newer; variant layouts, low-poly
fixtures, sprinting and performance on target hardware still warrant playtesting.
No water/travelator integration or new monsters are included.

### Combined-effect level review (2026-09-22)

One eligible streamed room per environment, run seed `980712989`. Office was
already approved in gameplay. The other ten used actual Main/ChunkManager,
timed wave playback, native lighting/materials, matching collision, the six-track
audio layer and 0.35-strength perception pass. For comparable captures the
viewpoint and unrelated pacing were held still; this was not a walking audit.

| Environment | Cell | Result |
| --- | --- | --- |
| Casino | (-2, -6) | Combined presentation visually checked |
| Office | (-7, -8) | Prior live capture and user approval |
| Annex | (-6, -7) | Combined presentation visually checked |
| Airport | (-4, -8) | Ordinary hall; combined presentation visually checked |
| Asylum | (-5, -4) | Combined presentation visually checked |
| School | (-3, -8) | Combined presentation visually checked |
| Mall | (5, -8) | Preparation fixed; combined presentation visually checked |
| Prison | (-3, -8) | Combined presentation visually checked |
| Poolrooms | (0, 1) | Dry room; review lifecycle fixed, combined presentation visually checked |
| Data Center | (-1, -8) | Combined presentation visually checked |
| Upside Down | (-1, -8) | Combined presentation visually checked |

All ten other environments now have successful wave captures with audio playback and 0.35 blur/color
strength. This checks audio activation, not a separate listening/mixing review.
Bright fixtures show stronger perceived color separation than dim surfaces;
no new obvious geometry gaps were observed in the captured samples. This is
sample coverage, not certification of every layout, camera position or effect.

Poolrooms initially emitted four null-material renderer errors **before the F6
request**, including on a direct-start repeat. The review harness installed
unsupported candidate rooms into the live renderer before rejecting them. It now
checks new candidates before installation; a matched direct-start capture passed
without those errors. Production Poolrooms geometry, materials and water were
not changed. Preparation took 10.65 gameplay seconds in that repeat, with a
19.04 ms maximum preparation slice; this is not a performance guarantee.

Mall initially exceeded the 45-second preparation limit. Profiling found dense
native plant meshes being transformed for every phase key, including keys with
zero displacement. Preparation now reuses exact rest arrays for meshes outside
the pulse and skips unchanged vertices. Geometry, moving-vertex calculations,
wave amplitude and the 45-second cap are unchanged. The same Mall sample now
prepares and plays successfully. The existing shared Office audit also passed
walking, boundary, audio, cancellation and unload checks after this optimization
(2.72 cm maximum feet/profile error).

Several capture processes still emitted texture-RID warnings during teardown;
these have not been diagnosed and are separate from the resolved material errors.

The first Casino review attempt had a harness-only streaming-focus bug after
teleporting from the initial spawn; releasing that old focus fixed the capture.
Airport initially tripped an overly strict test assertion requiring >50% of the
visibility fade at exactly 3.5 seconds: observed weight was 0.438 then and 1.0 at
5 seconds, with audio playing in both. The harness now checks engagement across
the sequence rather than that arbitrary instant. Its initial failure log remains
evidence of that assertion, not a clean exit-code pass.

Reproduce one level (substitute its theme number):

```sh
godot --path . --script tools/audit_hallway_wave.gd -- --nologo --level=6 --seed=980712989 --flashlight --hallway-wave --capture-live-wave --review-level-wave
```

Captures: `/tmp/liminal-wave-level-review/theme-N-0.05.png`, `-3.50.png`,
`-5.00.png`. Original review logs: `/tmp/liminal-wave-review-N.log`; initial
Poolrooms repeat: `/tmp/liminal-wave-review-9-direct.log`. Follow-up fix evidence:
`/tmp/liminal-wave-mall-fix.log`, `/tmp/liminal-wave-pool-fix.log` and
`/tmp/liminal-wave-shared-optimization-check.log`. The original review changed
only the capture harness; the follow-up also optimized shared wave preparation.

Native SDFGI remains enabled. The inward swell avoids the observed outward-wave
dark patch; it does not make static GI dynamically accurate. Godot documents
[SDFGI's dynamic-occluder limitation](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_sdfgi.html).
