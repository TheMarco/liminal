# Runtime architecture

This document describes the current construction, transition, and mutation
boundaries. The deterministic world hash and `tools/run_audits.sh` are the
regression contract for changes to these systems.

## Procedural construction

`WorldGen` is pure: cell, room, edge, style, and topology facts are functions of
seed and coordinates. `ChunkManager` converts those facts into streamed
`Chunk`s. Theme builders do not receive the live Chunk node:

1. `ChunkBuildSpec` carries mutable assembly input from the manager.
2. `Chunk` snapshots it into immutable `ChunkBuildContext` facts.
3. A theme `ChunkLevelBuilder` receives that context and a
   `ChunkSceneWriter`.
4. The writer is the typed capability boundary for geometry, collision,
   authored props, furnishing identity, and the few ordered Annex registries.

No `scripts/levels/*_level_builder.gd` file may access a `Chunk` instance.
Shared immutable assets remain class constants; new construction behavior must
be added as a named writer operation or a context fact. Do not add a generic
`call`, `callv`, root-node escape hatch, or mutable Dictionary proxy.

## Runtime object state

Mutable generated objects use deterministic semantic keys:

`cell:x:y/kind:local_id`

`ChunkRuntimeState` is an allowlisted, versioned value object. Chunks capture
and restore it during streaming and rebuilds, while `ChunkManager` retains the
floor-scoped registry even when an object is temporarily absent. This is what
allows a later reality to restore a removed door or furniture group with its
previous state intact.

Adding a mutable generated object requires:

- a deterministic local identity;
- registration in `Chunk`;
- an allowlisted payload in `ChunkRuntimeState`;
- capture and restore behavior;
- a round-trip audit covering unload/rebuild or mutation-away/mutation-back.

## Blackout mutation transaction

`WorldMutation` is the durable mutation record. It contains the topology delta,
affected cells, before/after runtime state, object-presence descriptors, and
typed object deltas.

The commit order is deliberately strict:

1. `DescentMutationCoordinator` performs live actor/interaction preflight.
2. `DescentMutationTransaction` records the before-state.
3. `ChunkManager.stage_rebuild_cells()` constructs every replacement off-tree.
4. The topology advances while old collision remains authoritative.
5. Only a completely valid staged set swaps into the scene.
6. Runtime state is reconciled and the transaction is finalized.
7. Persistence and the visible reveal occur only after the scene swap.

Before step 1, production transition selection applies a live witness gate.
`DescentMutationCoordinator` tests real edge planes and designated furnishing
samples against `Player.cam` with both frustum and physics-ray occlusion. A
visible door/wall change has absolute priority. If none is visible, the target
reality's designated set piece—or its exact prevalidated appearing-chair
position—must be visible. If neither qualifies, the blackout is postponed.
The designated furnishing is guaranteed to move or safely disappear; it is not
merely an arbitrary object from the same room.

Any failure compensates back to the exact topology history and runtime state.
Incomplete replacement sets never remove installed collision. A later mutation
may select any generated reality, including a previous one.

## Main-scene controllers

`main.gd` remains the mode/session orchestrator, but focused state lives in:

- `BenchmarkDevController`: CLI benchmark, partition audit, screenshots;
- `PostProcessController`: independent VHS-signal and CRT-display stages,
  corruption, glitches, and damage pulses;
- `LevelTransitionController`: transition lock, Wander saved positions, arrival
  policy, fade/teardown/build ordering, and live collision safety;
- `DescentMutationCoordinator`: blackout preflight and mutation transaction.

Controllers communicate through typed methods and narrow callback ports.
Gameplay-specific decisions such as Descent route creation remain in Main;
generic sequencing and persistent controller state do not.

## Temporary architectural motion

`architectural_event_director.gd` belongs to Main and owns the shared cadence,
recent-history and long-run variety for wall breath, travelling pressure,
ceiling breath, hallway wave and supernatural doorways. Its memory survives
floor changes. After 3–5 seconds of active exploration it tries one of the player's room or
eight neighbouring rooms per physics tick. Starting at 6 seconds, it
also checks every half-second for a hallway wave in the player's current room and
for visible doorways in nearby resident prepared walls, so crossing a rare site does not
depend on the broader search timer. Opportunistic waves respect their share
of the mix and leave the first ordinary search alone; the normal search still
allows them as a fallback. This keeps long wave preparations from continually
displacing quicker wall and ceiling effects. It counts an event only when the effect
becomes visible, uses 6–10 seconds between wall/ceiling opportunities
(8–12 after waves, 9–14 after doorways), and
gives cancelled preparations a short retry. Doorways have
an additional 30–45 second repeat delay and at most six reveals per Descent floor.
Camera use and encounters let the waiting time expire while preventing effect
starts. Menus, scripted presentations and realm visits pause that clock.
An interrupted doorway preparation does not consume that floor's reveal.
Wall, ceiling and wave motion counts as a sighting only while its central
animation is in view with a clear line of sight. Preparation, the nearly flat
first frames and offscreen motion do not spend the long cooldown. An unseen
cancelled breath also leaves the attempted wall eligible for the short retry.
Architectural motion retains exclusive pacing through its full animation, followed
by a one-second recovery instead of the generic four-second visual recovery.
Eligibility can delay any kind; the manager never forces an unsafe event.

`environment_breath_director.gd` belongs to the current level root and uses
Main's presence/presentation gate plus `HorrorDirector.try_start_visual()`.
It chooses a visible, clear wall or ceiling, with its own seeded RNG. It does
not consume world-generation randomness or persist changes. The doorway director
likewise retains its native geometry and final safety gate; both directors defer
automatic timing to the shared manager in normal gameplay. Preview modes keep
their manual controls.

`environment_breath_surface.gd` belongs to that surface's streamed Chunk. Preparation
is incremental and leaves the original resources installed until complete.
Prepared GPU morphs retain native materials and rest-space texture coordinates;
known attached wall bands share the same deformation frame. A small collision
grid updates at 15 Hz while the original room collider remains present. Actor
approach, presentation changes, room retirement and floor teardown restore the
original mesh/material/cull margin and disable the temporary collider.

The manager targets a long-run mix of wall breath (31%), travelling pressure
(19%), ceiling breath (19%), hallway wave (18%) and doorway (13%), adjusting
for recent sightings and preferring a different type or surface. Repeated kinds
and walls remain available as fallbacks when they are the only safe visible site.
These are selection targets, not guaranteed observed frequencies: nearby safe,
visible surfaces still determine which effects can play. `--breathing`/F6 cycles
the four surface effects for review.
`tools/audit_architecture_cadence.gd -- --nologo --level=7` checks automatic
first and repeat sightings in a furnished Mall room, including camera use,
without overriding cooldowns or directly starting an effect.
`tools/audit_office_hallway.gd -- --test-mode --seed=1021555651 --descent-floor=3`
walks back and forth through a real Office corridor with the normal camera,
streaming, Descent rules and automatic scheduler. The walker uses its torch
against visible encounters, then resumes walking. `--capture` saves rendered
motion frames. Visible faces are filtered before filling the candidate limit;
the narrow corridor's walls remain eligible, with swept-body clearance retained.
Selection accounts for walking past a surface before the bow develops. Unseen
walls passed during motion release their quiet slot. Waves reserve quiet time
during preparation, wait briefly if they finish behind the viewer, and space
attempts so a failed preparation cannot starve wall effects. Random room-exit
encounters respect these reservations; authored tape/charger encounters retain
priority. Room-exit events no longer permanently extinguish a whole chunk;
legacy dead-light requests are ignored and genuine blackouts remain reversible.
Ceiling selection excludes fixtures/overlays and junctions, leaves at least 2.25m
headroom at maximum depth, and uses a vertically oriented swept-body exclusion.
No safe patch means no event; it does not move ceiling fixtures or replace finishes.
Paired-wall prototypes remain outside this runtime system.
These effects are temporary visual events, not
persistent generated-object mutations or topology transactions.

Route landmarks are spatial setpieces, not timed architectural events. Descent
plans one on-route setpiece per non-Casino floor and three on the Casino route;
the first Casino landmark is placed within three room transitions. A true
rare native hall is preferred where the generated route already contains one,
but the on-route furniture or clock composition is the fallback. Wander has
no fixed objective route, so landmark exposure is not guaranteed there.

## Verification gates

Run `tools/run_audits.sh -j 1` before accepting an architectural change. The
critical focused gates are:

- `audit_environment_breath.gd` and `audit_breathing_runtime.gd`: profile/normal math,
  collision, real materials/bands across all themes, automatic selection and cleanup;
- `audit_world_hash.gd`: exact generated-scene fingerprint;
- `audit_chunk_smoke.gd`: all representative styles and runtime identities;
- `audit_level_switches.gd`: teardown/build ordering and arrival safety;
- `audit_descent_mutation_graph.gd`: generated reversible realities and the
  designated furniture-witness/change contract;
- `audit_world_mutation_contract.gd`: door/furniture mutation round trips;
- `audit_descent_runtime.gd`: live camera witness/occlusion, commit, forced
  failure, and rollback;
- `audit_descent_progress.gd`: topology and runtime-state persistence.
