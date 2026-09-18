# Performance review — September 16, 2026

## Fixed in this pass

- Enemy local pathfinding previously completed up to 900 collision-tested A* nodes in one physics tick. It now works in slices of at most 24 expansions, with a 650-microsecond soft time budget checked between expansions. This applies to all levels and both enemy presentations. Physics queries themselves cannot be interrupted mid-call.
- Existing safe routes remain usable while replacement paths are calculated. Moving targets do not repeatedly cancel unfinished searches, and completed replacements join near the actor's current position. Per-tick corner shortcut checks are bounded; established final-route smoothing is preserved. Unreachable destinations have a longer retry delay.
- Normal monster spawning now polls threaded model loading and only retrieves completed requests. Unfinished models defer the spawn without consuming the selected design, forced encounter, or spawn notification. Loaded scenes are retained for reuse; direct standalone visual previews still permit synchronous loading.
- Four abandoned headless game audits had been running for 9–27 hours and consuming CPU. Their working directories and commands were verified, then those exact processes were stopped. No game save or project files were removed.

No graphical-quality, draw-distance, enemy-count, or spawn-frequency settings were reduced. Pool deck support, collision sweeps, peer separation, and smooth steering remain authoritative.

## Measurements

Deterministic `tools/profile_enemy_navigation.gd` fixtures, 420 simulated frames each, same Mac and Godot 4.6.1 for before/after comparison. Values measure enemy movement CPU work only, **not whole-game frame time or GPU rendering**. Background-test cleanup was also performed during this session. Final functional checks use the project's Godot 4.7.2 engine.

| Fixture | Before worst tick | After worst tick |
| --- | ---: | ---: |
| Dry furniture detour, one enemy | 2.42 ms | 0.69 ms |
| Player in water, one enemy on shore | 32.99 ms | 0.78 ms |
| Moving shoreline target | 8.87 ms | 1.47 ms |
| Player in water, three enemies | 97.24 ms | 4.67 ms |

No navigation tick exceeded 16.7 ms in the final run. Measurements fluctuate with host load and generated scenery; this does not establish a whole-game FPS guarantee. The benchmark reports waypoint, incremental-search slice, movement, and aggregate frame timings and has a timeout.

## Regression coverage

- `audit_navigation_budget.gd`: work slicing, moving-target search starvation, collision-safe detours, and replacement-route handover.
- `audit_walker_spawn_loading.gd`: deferred model readiness, retained shuffle-bag order, no partial or duplicate encounters, and cached scene reuse.
- Existing pursuit, pool-ground, legacy ghost-room, and discovery/spawn-hold audits.

The two new functional audits are registered in `tools/run_audits.sh`. The performance benchmark is deliberately separate so concurrent tests do not contaminate measurements. Rendered GPU/streaming performance still needs in-game testing; no release binaries were rebuilt in this session.

## Follow-up: monster arrivals and office fixtures

- Shared immutable particle resources and cached looping animation clips replace per-spawn resource rebuilding. The manager prepares particle resources during setup. Each monster still owns its animation playback, materials, emitter, and fog state.
- Removed the 3D emitter's 0.9-second particle preprocessing burst. Mist now builds naturally with the arrival, instead of simulating that history in one render frame.
- Monsters begin facing and walking toward the player while materializing over 0.8 seconds. Their reveal and reality-warning beats no longer freeze locomotion. Arrival grace prevents premature contact kills, but does not prevent torch defense. Legacy 2D behavior and enemy spawn frequency/count are unchanged.
- The office's rare broken-fixture roll used to disable every panel and omit the room light, even though ambient/neighbor lighting kept the room bright. It now breaks one fixture and retains proportionate room illumination.

`profile_enemy_spawn.gd`, Godot 4.7.2: repeated CPU construction fell from approximately 5.1–5.5 ms to 0.22–0.42 ms. The cold first constructor still measured 5.53 ms; background model decoding took 263 ms outside spawn construction. These are CPU construction timings, not proof that all in-game/GPU hitches are eliminated.

Verified: moving-arrival and loading audits, obstacle/peer pursuit, pool avoidance, and office ceiling coverage (147 cells, 1,096 fixtures, zero failures). GPU captures checked partial/full manifestation and torch burning on Metal. The legacy approach-warning audit also passed, though its existing transient scare-audio cleanup reported a resource warning on exit.
