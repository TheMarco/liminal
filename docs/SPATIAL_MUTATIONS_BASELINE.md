# Spatial mutations: handoff preflight baseline

Recorded September 19, 2026, before Package 1 implementation.
Companion to `SPATIAL_MUTATIONS_DESIGN.md` (Handoff preflight section).

## Snapshot identity

- Engine: Godot 4.7.2.stable.official.ed1daf0bf (`/opt/homebrew/bin/godot`)
- Commit: `1503a2c47a348076ade6c18880e37552bbe47fc5`
  ("Massive update. Numerous new 3D models, new monsters, too much to mention.")
- Tracked patch: 31 files changed, 839 insertions, 644 deletions
  (reproduce with `git diff` against the commit above)
- Required untracked source (sha256 at record time):
  - `scripts/enemy_local_path.gd`: `ac4a66ea...8571e`
  - `scripts/enemy_traversal.gd`: `e15ab760...3129ce`
  - plus their `.uid` files and untracked audit tools
- Required untracked assets (present, 76M + 45M):
  - `models/provided/horror_girl/` (Pool Girl, manifest index 10)
  - `models/provided/faceless_enforcer/` (manifest index 11)

## Baseline results

Command: `godot --headless --path . --script tools/audit_descent_mutation_graph.gd`

- Result: 11 themes, 66 alternate states, 66 openings (33 doors),
  33 closures, 59 furniture variants; slowest plan 216ms/0 probes
- Single known failure (the Package 2 baseline exception):
  `FAIL theme 1 generated no furniture reality`
- No connectivity failures. Suite exit code nonzero due to that one assertion.

Command: roster load probe (12 `MODEL_PATHS` + `RUN_MODEL_PATHS[10]` + 4
body/halo shaders, this checkout, project already imported)

- Result: PASS, all 17 resources load.

## Notes

- The separate-checkout verification was done in this workspace only; anyone
  reproducing elsewhere must include the untracked source and assets above,
  since a committed-only checkout lacks Pool Girl, Faceless Enforcer,
  `enemy_local_path.gd`, and `enemy_traversal.gd`.
- Re-run the mutation graph audit on this snapshot before accepting any
  Package 2 regression gate claim.

## Package 2 exit gate (2026-09-19, post-review)

Feature gate: PASS. Canonical `spatial_witness`, `migrating_door`,
`spatial_placement`, `enemy_topology_invalidation`, and
`spatial_campaign_event` audits are green. The fifth gate boots the real
`main.tscn` campaign (`--mode=descent --seed=900393 --descent-floor=3`), uses
the ordinary director and witness tracker rather than fixture occupancy, and
observes a complete A-to-B migration commit to `b_open`.

The headless A to both to B geometry proof is exact (openness 1/0, 1/1, 0/1;
clear width 3.2; leading edges travel). Placement sampled 20 deterministic
Office seeds, admitted six sites, and proved every scanned cell connected to
the target in `a_open`, `both_open`, and `b_open`. The live placement case uses
a real `Camera3D` and a non-empty physics occupancy feed.

The review fixes are part of this gate: A must replace a generated opening and
B a generated wall; photo evidence cannot occupy a site footprint; every live
enemy drops stale navigation caches on each passability flip; transitions write
a safe active checkpoint before motion and report failed final saves or topology
publication; malformed/incompatible site records are discarded in isolation;
and blackout recognition starts only after visibility returns. `descent_progress`,
`enemy_traversal`, `world_mutation_contract`, `horror_director`,
`incremental_streaming`, and canonical `photo_obstruction` also pass.

Visual A/B contrast: PASS by manual visit (`tools/visit_spatial_door.gd`,
seed 1, Office floor 3). Door A open reads as an open hole into the next
room; door A closed reads as a flat wall-matching panel with clean jambs.
No z-fighting, stretched UVs, or ArrayMesh corruption on Metal. Automated
capture (`tools/capture_spatial_door.gd`, same seed) exists but was not
used for the verdict after repeated sandbox framing failures.

## Follow-up baseline repairs (2026-09-19)

The five unrelated findings recorded during review are now resolved rather
than exempted:

- The Office topology planner admits safe sparse `OFFICE_EMPTY` rooms for the
  clearance-tested reality-chair fallback. The full mutation-graph audit now
  reports furniture variants for all 11 themes with no connectivity failures.
- The photo-doorway audit now starts its documented realm-visit fixture and
  waits for `RealmExcursion.Phase.WAITING`/`realm_preview_ready` before checking
  seals. It no longer races the asynchronous preview build or forces readiness.
- The aftershock audit now matches the current walker contract: the 1.25-second
  perception pulse starts once without freezing either walker. The obsolete
  legacy-apparition hold expectation and unused constant were removed.
- Surface navigation refreshes its safe partial route as each time-sliced
  search advances, instead of retaining the first host-timing-dependent prefix.
  The narrow-door two-follower case passes under concurrent load while keeping
  the 650-microsecond gameplay search budget and capsule/peer assertions.
- Scene-aware writing placement now proves player capsule clearance and a full
  eye-height sightline to the fitted phrase rectangle. If authored furniture
  blocks every candidate, the stable anomaly ID/quota uses the existing compact
  ceiling-photo fallback. The coverage audit now drives Player's owned pitch
  and reports legal stance count separately from successful captures.

These repairs are regression hardening around the Package 2 gate; they do not
change its topology safety invariants or waive any audit requirement.
