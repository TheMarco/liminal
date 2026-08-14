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
- `PostProcessController`: CRT/found-footage materials, corruption, glitches,
  and damage pulses;
- `LevelTransitionController`: transition lock, Wander saved positions, arrival
  policy, fade/teardown/build ordering, and live collision safety;
- `DescentMutationCoordinator`: blackout preflight and mutation transaction.

Controllers communicate through typed methods and narrow callback ports.
Gameplay-specific decisions such as Descent route creation remain in Main;
generic sequencing and persistent controller state do not.

## Verification gates

Run `tools/run_audits.sh -j 1` before accepting an architectural change. The
critical focused gates are:

- `audit_world_hash.gd`: exact generated-scene fingerprint;
- `audit_chunk_smoke.gd`: all representative styles and runtime identities;
- `audit_level_switches.gd`: teardown/build ordering and arrival safety;
- `audit_descent_mutation_graph.gd`: generated reversible realities and the
  designated furniture-witness/change contract;
- `audit_world_mutation_contract.gd`: door/furniture mutation round trips;
- `audit_descent_runtime.gd`: live camera witness/occlusion, commit, forced
  failure, and rollback;
- `audit_descent_progress.gd`: topology and runtime-state persistence.
