# Liminal Codebase Audit

Date: 2026-08-07

## Executive summary

The game is in considerably better structural shape than its raw line count suggests. The deterministic world-generation contract, topology overlay, staged chunk replacement, live-mutation safety checks, world-hash coverage, and 39 registered audits provide a strong foundation. The complete registered audit suite passes.

The most important problem found is performance, not topology correctness: creating a Descent route and planning its mutation graph is synchronous and currently takes seconds. An isolated one-theme run took 11.36 seconds wall-clock; all eleven themes took 126.56 seconds. That work occurs on the main thread before the transition fade begins, so it can present as a freeze when starting or advancing a Descent.

Three concrete gameplay defects were also found: threats can resume roughly 0.7 seconds before the player regains control after a VCR tape; corner apparitions reason from the immutable base graph rather than the active mutable topology; and an interrupted Wander-mode flashlight charge can retain partial charge during a floor switch instead of rolling back. Sprint behavior is additionally inconsistent between the current design document, production code, and its audit.

The largest maintainability risks are concentrated in `scripts/chunk.gd` (7,842 lines) and `scripts/main.gd` (2,347 lines), untyped Dictionary protocols, duplicated room-membership logic, and the mutation transaction being distributed across several classes.

The pruning pass found at least 674 physical lines of strong candidates: 537 lines in repository-unreferenced root method blocks and 137 lines in three unreferenced shaders. There are also dependent helpers, unreferenced constants, a legacy anomaly branch, and stale documentation. No whole runtime script was found to be unreferenced. Archived video assets intentionally retained for future use are not deletion candidates.

## Remediation status — 2026-08-08

Every actionable finding below has been remediated. The original evidence and
recommendations remain in this document as the historical record; this section
describes the resulting implementation and verification state.

- Route construction now uses compact cached wall data, and topology planning
  is a pure cached graph operation rather than off-tree `Chunk` construction.
  Across the eleven-floor mutation audit, route planning is approximately
  198–225 ms and complete-reality planning approximately 266–326 ms on the
  reference machine, versus 11.36 seconds for one theme in the original audit.
  The unavoidable work runs behind an already-opaque transition fade.
- The streamer builds at most one ordinary chunk or staged mutation room per
  frame, prewarms the two heavy themes behind black, and renders a fog-bounded
  5×5 square with an invisible collision hysteresis ring. Annex prototype and
  material reuse removed its former constructor spikes. Bloom's overlapping
  shadowed omni lights were reduced to one true shadow source per fixture group
  while preserving visible fill: the measured Metal capture improved from
  39.8–42.3 FPS and 6,177–7,534 draws to a stable 60 FPS and 2,340–2,788 draws.
- VCR threat protection now ends only after player physics/input are restored.
  Corner apparitions consume the active mutable topology. Sprint is legal in
  Descent and charges attention. Interrupted Wander charging rolls back before
  teardown. Focused regressions cover all four contracts.
- Mutation persistence is generation-versioned and resolves a stable topology
  signature; unknown historical signatures fall back to the base reality.
  Complete realities can mutate back, and the exact selected reality persists
  until another mutation.
- Typed `TopologyState`, `TopologyDelta`, and `ChunkBuildSpec` contracts replace
  the cross-system Dictionary protocols. A floor-scoped mutation coordinator
  owns preflight, staged rebuild, commit, persistence, reveal, failure and exact
  rollback. Owning-room membership and cell size are centralized, production
  code no longer reaches into route/actor private collections, and topology
  planning no longer depends on scene construction.
- Theme builders now receive only immutable `ChunkBuildContext` facts and the
  typed `ChunkSceneWriter`; all direct builder-to-Chunk instance access has
  been removed. Mutable generated objects have deterministic semantic IDs and
  a versioned floor-scoped `ChunkRuntimeState`.
- A typed `WorldMutation` owns topology, before/after runtime state and object
  presence. Persistence happens only after the complete staged scene swap;
  forced commit failure restores topology history and runtime state exactly.
- `main.gd` no longer owns developer benchmark/screenshot state, post-process
  shader state, or the level-transition transaction. Those responsibilities
  live in focused controllers with narrow ports.
- Every strong dead-code candidate was removed, including the legacy kind-2
  anomaly path, its orphaned helpers/constants, the final uncalled pool stair
  builder, and the three unreferenced shaders. The archived previous short-tape
  pool remains intentionally preserved. Reserved tapes 06–09 remain excluded
  from the Dr. Cross catalogue.
- Documentation now agrees on eleven floors, sprint/attention behavior, intro
  playback, the ten long and 21 current short tapes, reserved assets, persistent
  reversible mutations, and CLI ranges.
- The runner now gates ordinary engine errors through a narrow explicit
  allowlist and fails script errors, leaked objects/resources, and every other
  `ERROR:`. All 49 registered audits run through the same gate; no pool or in-flight audit is
  exempt. Construction-heavy audits share explicit cache/RID teardown.
- The 522-chunk, three-seed, eleven-theme world fingerprint was intentionally
  regenerated only for Annex material sharing and Bloom shadow flags; affected
  node counts and transforms remain unchanged.

Godot's Metal backend reports `0.0 ms` for its GPU timestamp profile, so the
rendered capture records FPS, process/physics worst frame, draw calls,
primitives, collision pairs, memory/object deltas and video memory instead of
claiming a numeric GPU time the backend does not provide. A manual complete
eleven-floor playthrough remains a playtest task, not a code-audit blocker.

## Scope and method

The audit covered:

- 64 runtime GDScript files: 37,285 physical lines
- 36 shaders: 3,400 physical lines
- 69 Godot tool scripts, including 48 `audit_*.gd` files
- The scene/project bindings, dynamic calls, signals, metadata access, and asset-name references
- Descent topology planning, mutation persistence and transactions, streaming, AI, VCR playback, player interactions, and Wander transitions
- Exact-name repository reference scans for dead-code candidates
- The complete registered audit suite
- Isolated Descent route/topology timings and the existing generation profiler

The runtime GDScript and shader total is 40,685 physical lines. This is a physical-line count, not a normalized logical-line or generated-code count.

Limitations:

- This was a headless and static audit, not a rendered GPU capture.
- GPU findings are workload estimates and profiling targets, not measured frame costs.
- There was no manual eleven-floor playthrough during this audit.
- “Unreferenced” means unreferenced inside this repository. An out-of-repository development tool could still call a public method.
- Headless runs emit some environment and teardown noise, discussed under test infrastructure.

## Prioritized findings

### P1 — Descent route and mutation planning blocks the main thread for seconds

Severity: High

Evidence:

- `Main._create_descent_route()` constructs a route and immediately calls `DescentTopology.plan_floor()` in `scripts/main.gd:395-411`.
- That path runs before the fade in both the lift transition (`scripts/main.gd:953-956`) and initial Descent preparation (`scripts/main.gd:2235-2241`).
- The route scanner uses Dictionary-heavy breadth-first searches in `scripts/descent_route.gd:572-668`; the source itself identifies this as a hot path.
- Furniture-state planning constructs complete off-tree `Chunk` instances to test candidate viability in `scripts/descent_topology.gd:602-650`, tightly coupling pure graph planning to scene geometry construction.

Measured on this checkout with Godot 4.6.1:

| Profile | Planned result | Wall time | CPU user time |
| --- | ---: | ---: | ---: |
| Theme 0 only | 6 alternate states, 49 probes at the slowest plan | 11.36 s | 11.08 s |
| All 11 themes | 66 alternate states, 84 probes at the slowest plan | 126.56 s | 124.86 s |

The timings include process startup, but the nearly all-CPU result and linear all-theme scaling show that topology construction dominates. This is the same route-plus-plan path used by production.

Recommended order of work:

1. Add a production timing marker around route construction and `plan_floor()` to establish target hardware baselines.
2. Replace `edge_info()` Dictionary creation in graph searches with a compact boolean/enum adjacency API.
3. Separate topology/state planning from `Chunk` scene construction. Furniture viability should consume cached footprint/clearance data rather than instantiate rooms.
4. Cache deterministic plans by generation/version, floor theme, and seed when practical.
5. Begin the transition/fade before unavoidable work. Pure graph work may be moved to a worker only after it is made thread-safe; Godot node construction must stay on the main thread.

### P2 — Bloom and Annex chunks can greatly exceed the streaming budget

Severity: High

`ChunkManager._process()` had a nominal three-chunk / 6,000 μs budget, but checked elapsed time only after a complete `_build()`. A single expensive build therefore stalled the frame. `warm_up()` synchronously created a 3×3 area, and the original mutation rebuild synchronously constructed every replacement before its swap. The remediation replaced that path with budgeted `stage_rebuild_cells()` and removed the obsolete synchronous method.

Measured steady-state generation results:

| Theme | Average | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Office | 1.57 ms | 2.29 ms | 3.17 ms |
| Annex | 14.50 ms | 37.47 ms | 37.58 ms |
| Airport | 2.93 ms | 6.81 ms | 6.95 ms |
| Asylum | 1.93 ms | 3.90 ms | 4.09 ms |
| Hotel | 1.83 ms | 2.52 ms | 2.58 ms |
| School | 2.32 ms | 4.68 ms | 4.72 ms |
| Mall | 1.86 ms | 2.85 ms | 3.08 ms |
| Prison | 1.82 ms | 3.81 ms | 3.97 ms |
| Poolrooms | 4.61 ms | 7.90 ms | 8.99 ms |
| Monolith | 1.46 ms | 2.27 ms | 2.91 ms |
| Bloom | 20.99 ms | 111.68 ms | 113.37 ms |

First-use maxima also reached roughly 90 ms for Annex, 111 ms for Bloom, and 57 ms for School. One Bloom chunk can consume many frame budgets by itself, while a mutation rebuilding multiple owning-room cells can compound that hitch.

Recommendation: profile the expensive builder stages, cache reusable geometry/materials, split or defer decorative work, and make the streaming budget interruptible at sub-build stages. Preserve the current off-tree staging and atomic replacement semantics because they are valuable for mutation safety.

### B1 — Threats resume before the player regains control after a VCR tape

Severity: High

`VhsRitual._end_watch()` calls `descent_tape_watch(false)` immediately, then begins a 0.7-second camera tween (`scripts/vhs_ritual.gd:229-245`). Player physics/input are restored only in the tween callback (`scripts/vhs_ritual.gd:248-252`). The main callback marks the run as no longer watching (`scripts/main.gd:609-627`), which allows passive protection to clear (`scripts/descent_run.gd:526-533`) and figures to be unsuppressed (`scripts/main.gd:1193-1199`).

An existing hostile can therefore move or contact the player for about 0.7 seconds while the player is still frozen, on both completion and cancellation.

Recommendation: keep the watch/passive/threat lock active through camera restoration, then clear it in the same callback that restores player control. Add an audit asserting that threat suppression cannot end before player control is enabled.

### B2 — Corner apparitions use the base graph instead of the active mutable topology

Severity: Medium

`CornerApparitions._connected_cells()` queries `WorldGen.edge_info()` (`scripts/corner_apparitions.gd:197-215`), and its static candidate construction is likewise based on immutable generation data (`scripts/corner_apparitions.gd:106-139`). Unlike chunks, the route, and shadow figures, it has no `DescentTopology` dependency.

After a blackout mutation, candidate reachability can include a newly sealed neighbor or omit a newly opened one. A final raycast prevents many visually impossible placements, but scheduling and reachability are still inconsistent with the world the player occupies.

Recommendation: inject the active topology/edge resolver and use it for candidate graph traversal. Extend the apparition audit with one closed-edge and one opened-edge mutation state.

### B3 — Sprint behavior contradicts the current design contract

Severity: Medium; product decision required

The current design document says sprint is enabled/legal and contributes `SPRINT_ATTENTION_RATE` (`CLAUDE.md:68,82-83`). Production comments agree (`scripts/main.gd:246-249`), and the attention code exists in `scripts/descent_run.gd:64-67,474-476`.

However, normal Descent setup disables sprint in `scripts/main.gd:2226` and again at every floor start in `scripts/main.gd:848`. `tools/audit_descent_runtime.gd:48` explicitly asserts that sprint is disabled. `docs/DESCENT.md` contains both claims.

If `CLAUDE.md` is authoritative, the runtime and audit are wrong and sprint-attention logic is unreachable in normal play. If sprint was deliberately retired again, its attention branch and enabling comments are stale and should be removed. Resolve the intended behavior first, then make code, audit, and documentation agree.

### B4 — Interrupted Wander charging can retain partial charge across a floor jump

Severity: Medium

Interrupted charge rolls back only when `Player.stop_charging()` sees a still-valid charging station (`scripts/player.gd:235,247-259`). Charge accumulates while held (`scripts/player.gd:274-282`). Wander floor switching frees the old level without first stopping the charge session (`scripts/main.gd:1540-1557`).

If the player changes floors while charging, charge can accumulate during the fade; when the old station becomes invalid, `is_charging()` becomes false and the partial gain is never returned to `_charge_session_start`.

Recommendation: explicitly cancel/rollback charging before any level teardown or make charge-session state independent of station validity. Add a transition-during-charge audit.

### R1 — Numeric mutation state IDs are unsafe across future generation changes

Severity: Medium upgrade-safety risk; not a same-build failure

Mutation persistence stores numeric state and visited IDs under save version 1 (`scripts/descent_progress.gd:15-18,82-118,150-171`). On load, current code replans the floor and restores the numeric ID (`scripts/main.gd:401-410`); topology only clamps the value (`scripts/descent_topology.gd:175-182`).

Any future change to candidate ordering, builder clearance, assets, or planning rules can make a historical ID describe a different physical state. Current same-build persistence is deterministic and passes its audits.

Recommendation: introduce a generation/schema version plus a stable state signature or topology hash. If a signature cannot be resolved after an upgrade, safely fall back to the base state rather than reinterpret the number.

### T1 — The audit runner ignores general engine errors

Severity: Medium test-infrastructure gap

All registered audits pass, but `tools/run_audits.sh:174-176` treats `SCRIPT ERROR` as a failure and does not fail on ordinary `ERROR:` output. For example, the arrivals audit passes while its headless log contains repeated dummy-renderer `Parameter "material" is null` errors during teardown. The Descent runtime audit also reports leaked ObjectDB instances at exit.

These messages are likely headless renderer/resource cleanup noise rather than demonstrated gameplay failures, and existing documentation already acknowledges that class of warning. The issue is that the harness cannot distinguish expected noise from a newly introduced engine error.

Recommendation: maintain a small explicit allowlist for known headless-only messages and fail registered audits on any other `ERROR:` line. Separately investigate the ObjectDB leak warning. Register performance smoke thresholds independently; the current generation profiler is not part of the main suite.

## Performance risks requiring rendered profiling

These are static risk findings, not measured GPU/frame-time defects:

- Each live shadow figure raycasts toward the player every physics tick and can perform multiple sight/movement shape queries; blocked movement can fan out to roughly thirteen queries. The system is capped at three figures and caches path waypoints, which bounds the cost (`scripts/shadow_figure.gd:356-559`, `scripts/shadow_figures.gd:10`).
- Corner-apparition scans run every 0.16 seconds and allocate query shapes while doing bounded depth-two graph/raycast work (`scripts/corner_apparitions.gd:81-215,423`).
- CRT is enabled by default. The post shader performs roughly twelve screen samples per output pixel, though rendering at 480 vertical pixels significantly mitigates it (`scripts/main.gd:73,1775`; `shaders/post.gdshader:38-80`).
- Pool water reads screen and depth textures and can create significant transparent overdraw (`shaders/pool_water.gdshader:104`).
- Terrazzo, wallpaper, and ghost shaders contain dense sampling/FBM paths. Ghost interpolation can double its thirteen-sample alpha work.
- The player interaction raycast runs every rendered frame (`scripts/player.gd:382-402`).
- `ChunkManager` scans a bounded 7×7 neighborhood and repeatedly allocates/sorts key arrays each frame (`scripts/chunk_manager.gd:79-100`).
- `DescentHUD._process()` rewrites strings/layout state every frame (`scripts/descent_hud.gd:105-133`), a low-level allocation target.
- Current themes all use recorded ambience beds, so the procedural scary-loop generator exits early and is dormant in normal current content (`scripts/ambience.gd:38-45`).

Recommended rendered capture scenarios are: Bloom streaming, Annex streaming, a multi-room blackout mutation, three active figures plus a corner apparition, Poolrooms with full CRT, and ghost interpolation. Capture CPU frame, GPU frame, physics-query count, allocation count, and worst-frame time rather than averages alone.

## Architecture and maintainability

### What is working well

- `WorldGen` remains seed-pure, while `DescentTopology` centralizes the mutable overlay.
- Topology states are complete snapshots, which naturally supports exact mutation-back behavior.
- `ChunkManager.stage_rebuild_cells()` builds replacements off-tree across the
  frame budget, retains typed runtime state, and swaps only a complete set.
- Live mutation preflight checks player, figures, passers, charging, VCR state, and moving doors before committing (`scripts/main.gd:1261-1310`).
- World-hash and route audits provide meaningful deterministic-regression protection.
- Eleven theme builders are separated behind a documented base contract.

### Main structural risks

1. `scripts/chunk.gd` is a 7,842-line kernel covering primitives, resources, theme bridges, furniture metadata, doors, Descent rigs, blackout behavior, mutation furniture, and audit hooks. The split builders help, but `scripts/levels/chunk_level_builder.gd:14` documents roughly 3,000 `chunk.*` accesses, leaving very high coupling.
2. `scripts/main.gd` is 2,347 lines and owns boot, game modes, streaming, UI, audio, postprocessing, persistence, mutation transactions, and safety. It also reaches into private collections such as `_figures._figs` and `_passers._live` (`scripts/main.gd:1276`).
3. Core contracts use untyped Dictionaries: topology states (`scripts/descent_topology.gd:70`), topology deltas (`scripts/descent_topology.gd:254`), and the large Chunk configuration protocol (`scripts/chunk.gd:946`). Misspelled fields become runtime failures and cross-file changes are hard to validate.
4. The topology planner depends on scene construction to test furniture, binding graph architecture to the heaviest rendering/build class.
5. Production topology code reads private route internals such as `_origin_distance` (`scripts/descent_topology.gd:728`).
6. The mutation transaction spans `DescentRun`, `Main`, and `ChunkManager` (`scripts/descent_run.gd:653+`, `scripts/main.gd:1218+`, `scripts/chunk_manager.gd:242+`). Preflight and staging are strong, but there is no explicit transaction result or rollback contract if a later phase fails.
7. Owning-room membership logic is duplicated in topology, main mutation expansion, and Chunk (`scripts/descent_topology.gd:484-499`, `scripts/main.gd:1312+`, `scripts/chunk.gd:6675+`). Divergence could rebuild an incomplete room.
8. Cell size `12` is repeated across several runtime systems instead of being a single world constant.

Recommended refactor sequence:

1. Introduce typed `TopologyState`, `TopologyDelta`, and `ChunkBuildSpec` data objects without changing behavior.
2. Extract a pure topology/clearance model from `Chunk`; make both planning and builders consume it.
3. Centralize owning-room membership and edge resolution behind public APIs.
4. Move the mutation sequence into a small transaction coordinator with explicit `preflight`, `stage`, `commit`, `rollback/fail`, and `persist` results.
5. Split `Main` by ownership only after those contracts exist; otherwise the same coupling will merely move files.
6. Continue peeling theme/resource responsibilities out of `Chunk` after builders no longer require broad access to its internals.

## Stale and dead code ledger

### Strong repository-unreferenced method candidates

The following root methods have no call, callable, signal, scene, or string-based reference elsewhere in this repository. Their method blocks total approximately 537 physical lines before counting helpers that become dead with them.

| File | Method(s) |
| --- | --- |
| `scripts/title.gd:367` | `_menu_button` |
| `scripts/levels/pool_level_builder.gd:898` | `_pool_deck` |
| `scripts/levels/pool_level_builder.gd:985` | `_pool_stairs` |
| `scripts/levels/pool_level_builder.gd:1584` | `_pool_island_clear_of_layout` |
| `scripts/levels/pool_level_builder.gd:1609` | `_pool_sector_colliders` |
| `scripts/levels/pool_level_builder.gd:1728` | `_pool_side_walk` |
| `scripts/levels/pool_level_builder.gd:1758` | `_pool_bridge` |
| `scripts/levels/pool_level_builder.gd:1914` | `_pool_channel_fill` |
| `scripts/levels/pool_level_builder.gd:2177` | `_pool_underwater_lights` |
| `scripts/shadow_figures.gd:372` | `has_close_figure` |
| `scripts/shadow_figures.gd:389` | `_same_room_as_player` |
| `scripts/corner_apparitions.gd:444` | `_shuffle` |
| `scripts/descent_run.gd:361` | `tape_assignment_count` |
| `scripts/descent_run.gd:593` | `mark_helpful_doorway_created` |
| `scripts/descent_topology.gd:217` | `remove_shortcut` |
| `scripts/chunk.gd:5318` | `reset_descent_tape` |
| `scripts/chunk.gd:6150` | `terminal_readout_violations` |
| `scripts/player.gd:500` | `submersion` |
| `scripts/world_gen.gd:195` | `_forced_open` |
| `scripts/sfx.gd:146` | `scare_count` |
| `scripts/sfx.gd:181` | `whisper_count` |
| `scripts/sfx.gd:201` | `death_count` |
| `scripts/sfx.gd:235` | `player_death_count` |
| `scripts/pool_corner_mesh.gd:270` | `rounded_rect_ring` |
| `scripts/pool_corner_mesh.gd:406` | `quarter_sector` |
| `scripts/pool_corner_mesh.gd:445` | `rounded_rect_surface` |
| `scripts/vhs_tape_library.gd:96` | `shuffled` |

Dependent candidates include `WorldGen._base_wall`, which is only used by `_forced_open`, and `PoolCornerMesh._rounded_rect_perimeter` / `_surface_rect`, which are only used by the dead public roots above.

### Strong unreferenced shader candidates

No runtime script, scene, project setting, or dynamic filename construction references these files:

- `shaders/sewer_water.gdshader` — 56 lines
- `shaders/slot_screen.gdshader` — 43 lines
- `shaders/water_stream.gdshader` — 38 lines

Total: 137 physical lines.

### Unreferenced constants

Exact-name scans found no consumers for these constants:

- `scripts/chunk.gd`: `ART_OFFICE`, `ART_ANNEX`, `ART_AIRPORT`, `ART_ASYLUM`, `ART_SCHOOL`, `ART_MALL`, `ART_PRISON`, `BANK`, and `CH_HW`

These appear consistent with leftovers from the builder split and retired sewer content, but should be removed in the same narrow patch as their dependent code so compilation catches any hidden relationship.

### Likely stale compatibility branch

`Chunk._anomaly_rearrange()` is reachable only through `activate_anomaly(kind == 2)` (`scripts/chunk.gd:5650,5673`). Current production anomaly selection generates only kinds 0 and 1. Furniture mutation now uses the generated topology graph and `_apply_furniture_variant()` directly. No repository tool invokes kind 2.

This makes the wrapper/legacy branch a strong pruning candidate, but it is classified separately because `activate_anomaly()` is public and could be used by an external development console. The actual furniture-variant implementation remains live and must not be removed.

### Items intentionally not classified as dead

- `add_shortcut` and `find_blackout_doorway` remain exercised by the older blackout-shortcut compatibility audit.
- The archived previous short-tape pool is intentionally retained for possible future use and must not be deleted as “unused.”
- `tape06` through `tape09` are reserved converted game assets, not Dr. Cross tapes; their exclusion from the Cross pool is intentional.
- No complete runtime GDScript class was found to be unreferenced.

### Documentation drift to prune or correct

- `CLAUDE.md:136-138` describes the retired kind-2 post-blackout furniture nudge rather than the generated reality graph.
- `scripts/main.gd:2` says ten endless floors; the game has eleven.
- Sprint is described inconsistently across `CLAUDE.md`, `docs/DESCENT.md`, production code, and its audit.
- `CLAUDE.md:121-124` still describes 38 short tapes. The current Cross library is 21 shorts and 10 eligible long tapes; tapes 06–09 are reserved assets.
- `docs/DESCENT.md:413` documents `--descent-floor` as 1–8 rather than 1–11.
- `docs/GAME_LOOP_AUDIT.md:550` says the story intro is still needed even though intro playback is implemented.
- `scripts/chunk.gd:5909-5914,5974-5977` contains duplicated explanatory comments.

## Test results and coverage gaps

`./tools/run_audits.sh` completed successfully: all 39 registered audits passed.

Passed groups include world generation and hashes, corridors/doors/zones, every level family, survivability and overlaps, arrival and transition behavior, Descent routes and progression, topology/mutation graphs, intro playback, Cross review, VCR ritual/optional VHS, ghost-room contracts, hostile systems, title/fonts, geometry seams, Wander mode, pool geometry/lighting, and chunk smoke.

Additional checks:

- Godot import/compile path passed through the suite.
- `git diff --check` passed.
- Mutation graph audit: one theme produced 6 valid alternate states; all themes produced 66.

Coverage gaps worth closing:

- The mutation graph audit uses one derived seed/theme path per requested theme. It strongly validates contracts for that topology but does not explore rare seed shapes.
- There is no audit for the VCR threat-release ordering defect.
- Corner apparition audits do not exercise active topology deltas.
- There is no floor-transition-during-charging audit.
- Performance profiles and thresholds are not registered in the main runner.
- There is no rendered GPU regression capture.
- The runner's error policy can hide new non-script engine errors.

## Recommended execution plan

### First: correctness and player fairness

1. Fix VCR threat-release ordering and add its regression audit.
2. Route corner-apparition connectivity through active topology and test opening/closure states.
3. Resolve the sprint design decision and make code, audit, and docs agree.
4. Roll back charging before Wander teardown and add a transition audit.

### Second: eliminate the largest stalls

1. Instrument production route/topology construction.
2. Decouple graph planning from Chunk instantiation and replace Dictionary adjacency in hot BFS paths.
3. Profile and split Bloom/Annex builders; make streaming/rebuild budgets interruptible.
4. Add non-flaky performance smoke ceilings on controlled hardware or CI classes.

### Third: protect future mutations

1. Version/sign persisted topology states.
2. Create typed topology/build contracts.
3. Centralize owning-room and edge resolution.
4. Introduce an explicit mutation transaction coordinator and failure contract.

### Fourth: prune safely

Remove the strong dead-code set in one focused change, including newly orphaned helpers and imports, then run:

1. Godot import/compile
2. The complete 39-audit suite
3. World-hash audit
4. Generation profiler
5. A manual pass through Poolrooms and the archived/current VCR review UI

Keep the legacy anomaly-kind branch as a separate decision/patch because it has a public entry point. Correct documentation drift after the sprint decision so the documentation does not preserve another contradiction.

## Conclusion

The changing-topology architecture is viable and already has several unusually careful safety properties. The generated full-state graph and mutation-back behavior are not the weak point. The immediate risks are the synchronous cost of producing that graph, two systems that do not fully respect transition/topology state, and concentrated coupling that will make future mutation types progressively harder to add.

Addressing the four concrete gameplay issues, extracting planning from scene construction, and pruning the confirmed dead set would materially improve the game without abandoning the current topology design.
