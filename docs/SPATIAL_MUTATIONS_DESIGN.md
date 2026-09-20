# Spatial mutations: implementation design

Status: proposed implementation, not implemented. September 19, 2026.

This document specifies three effects and a replacement selection/presentation
policy for architectural blackouts. It is an engineering handoff: values marked
**tuning** are starting points, while rules marked **invariant** must survive
tuning. New class, method, signal, and test names below are proposed interfaces.
Do not assume those APIs already exist.

## 1. Product decisions

The building changes relationships between recognizable places. The player
should be able to explain the contradiction: “the clock stayed there, but the
door moved,” “that corridor grew while I walked,” or “this is the room I left.”

Implement these in order:

1. A two-layout junction: reliable blackout change, then visible doorway migration.
2. A bounded, bidirectional hidden connection: the impossible return loop.
3. A growing corridor whose exit uses that same connection.

The corridor comes last because a retreating, still-usable exit cannot be made
correctly by stretching a mesh. It needs a connection to the fixed destination.
We will not move the entire downstream world, alter player speed, change FOV to
fake distance, or make the exit an inaccessible prop until an animation ends.

Use real geometry for local transformations. For nonlocal connections, use
matching, opaque dogleg passageways that conceal the coordinate transfer. Do
not build arbitrary see-through portals, recursive rendering, room rotation,
moving water, gravity changes, or endlessly generated corridors for this feature.

**Invariants:**

- The player retains movement and look control during lit transformations.
- The existing stand-still rule remains in force during blackouts. A mutation
  must never require movement to escape crushing or enclosure.
- Every offered traversal works for the player and all active enemy types.
  No player-only link, enemy despawn, catch-up teleport, or hidden AI wall.
- Geometry never moves through an actor. Actor safety outranks finishing an effect.
- Objectives, needed evidence, and the floor exit remain reachable throughout,
  not just in the two endpoint layouts.
- Photographed passages remain open. Evidence and mutable props keep their identities.
- No forced camera turn, new interaction button, explanatory tutorial, or mandatory
  extra puzzle is introduced.
- A local site owns its own state. Activating it must not undo a previous change
  on the other side of the floor.

The visual goal is ordinary architecture behaving incorrectly: recognizable
materials, continuous lighting, and restrained structural sound. These effects
do not use the realm excursion's glyphs, dissolution, or loading fades.

### 1.1 V1 enemy and visual coverage

For this specification, “all active enemy types” means `ShadowFigure`'s seven
behavior variants (`REVENANT`, `DROWNED`, `PILGRIM`, `TRAILING`, `GAOLER`,
`REACHER`, `DRIFTER`) and all twelve entries in
`ShadowWalkerVisual.MODEL_PATHS`, including Pool Girl's walking/running clips
and both shadow and ghost body/halo render paths. Behavior `variant` and visual
`walker_model_index` are independent; do not treat them as the same enumeration.

Pin this visual manifest to the source-and-asset snapshot used for implementation:

| Model index | Visual identity / asset directory | Required locomotion |
| --- | --- | --- |
| 0 | Hollow Watcher / `hollow_watcher` | Walk |
| 1 | Existing unnamed visual / `model2` | Walk |
| 2 | Alternate Hollow Watcher / `model3` | Walk |
| 3 | Existing unnamed visual / `model4` | Walk |
| 4 | Ashen Trenchwalker / `trenchwalker` | Walk |
| 5 | Hooded Harlequin / `harlequin` | Walk |
| 6 | Plague Surgeon / `plague_surgeon` | Walk |
| 7 | Silent Visitor / `silent_visitor` | Walk |
| 8 | Veiled Matron / `veiled_matron` | Walk |
| 9 | Hound / `hound` | Walk |
| 10 | Pool Girl / `horror_girl` | Walk, run, and transitions between them |
| 11 | Faceless Enforcer / `faceless_enforcer` | Walk |

The exact file paths come from `MODEL_PATHS` and `RUN_MODEL_PATHS`, not inferred
display names. Entries 0–3 currently use the shadow body/halo shaders; 4–11 use
the ghost body/halo shaders. Clipping must cover every skinned mesh surface and
every halo pass, including manifestation, normal movement, fading and burning.

Test all seven behaviors with a reference visual, all twelve visuals with a
reference behavior, and the actual campaign spawn combinations in integration
tests. Include Pool Girl's model-specific running branch and the hound's distinct
presentation scale. A missing model, animation or shader is a failed coverage
preflight, not a skipped test. Changes to the roster require updating the manifest
and coverage explicitly. `PassingShadows` and `CornerApparitions` remain ambient
systems excluded from site envelopes under section 6.4, not omitted pursuers.

## 2. Current implementation and boundaries

Source is authoritative where older documentation differs.

| Existing component | Reuse | Required change |
| --- | --- | --- |
| `DescentTopology` | Seeded edge resolver, reservations, connectivity checks, signatures | Reserved local sites, independently saved site states, topology revision; later nonlocal neighbours |
| `DescentMutationCoordinator` / `DescentMutationTransaction` | Preflight, rollback discipline, durable completion | Separate blackout scheduling from mutation execution; support module transitions rather than requiring whole-chunk replacement |
| `ChunkManager` | Streaming, runtime state registry, hostile collision leases | Lease all cells of an active site and both sides of a connection; prepare modules before showing them |
| `PhotoDoorSeal` | A real prebuilt aperture and independent physical seal | New module with safe closing and physics-timed movement; do not change photographed-door semantics |
| `HorrorDirector` | Prevent unrelated events from competing | One spatial-event hold, mutual exclusion with realm visits and photo review |
| `Player` | Actual movement and manual camera interpolation | A distinct seam-crossing path; existing `teleport()` clears velocity and traversal state |
| `ShadowFigure` / `EnemyLocalPath` / `EnemyTraversal` | Collision-aware pursuit and traversal | Explicit revision invalidation; region/link navigation; identical seam crossing |
| `DescentProgress` | Versioned floor checkpoint and atomic config writes | Allowlisted spatial-site state and migration; do not serialize scene nodes |
| `RealmExcursion` | Reference for mapping view orientation between frames | Do not reuse its faded world swap: it suspends input and despawns source enemies |

Existing blackout selection relaxes line of sight to frustum-only, then removes
the visibility ranker after two unsuccessful attempts (`descent_run.gd`,
`_begin_blackout`). Its live validator excludes the player's whole rebuilt room.
The reveal expires after 2.5 seconds regardless of whether it is seen. Replace
these policies for architectural beats; raising their frequency is not the fix.

The preceding investigation ran the existing state contract successfully. The
broader mutation graph audit tested 66 alternate states and failed its furniture
requirement for the sampled Office floor. Treat that as a known baseline issue,
not as proof that these proposed effects or the old noticeability policy work.
Specifically, the assertion was `theme 1 generated no furniture reality` in
`tools/audit_descent_mutation_graph.gd` with `BASE_SEED = 20260807`. This is a
missing furniture-variant assertion, not an objective-connectivity failure.
The baseline policy in Package 2 separates it from the new fixture's mandatory
safety checks; fixing it is not a dependency for constructing the junction.

## 3. Shared ownership and data

### 3.1 Keep the implementation small and staged

Add a floor-owned `SpatialMutationDirector`. It selects and sequences events;
it does not construct meshes, move actors, or become a second save system.
`HorrorDirector` still owns pacing. The topology resolver still owns which
connections exist. A site node owns its moving visuals and collision.

Initially implement only `MigratingDoorSite` plus `SpatialWitnessTracker`.
Introduce the region/link adapter only when implementing the return loop. Do not
refactor all navigation before the first doorway can be evaluated in-game.

Use a new `SpatialSiteTransaction` for module phases. Do not pass an empty or
fabricated `TopologyDelta` into the current chunk-rebuild transaction, whose
preflight requires real rebuild cells. Factor shared actor-safety/connectivity
checks into small reusable functions, retain the legacy transaction unchanged
for legacy events, and give the director one explicit completion/failure result
from either executor. This avoids weakening existing rollback guarantees just
to fit a different kind of animation into the old interface.

Proposed shared records:

| Record | Fields and meaning |
| --- | --- |
| `SpatialSiteSpec` | `id`, schema/generation version, theme, kind, owning/reserved cells, anchor object IDs, endpoint transforms, allowed phases, swept bounds, witness points, protected routes, specification signature |
| `SpatialSiteState` | Stable phase, bounded animation progress if active, activation/completion flags, loop-exit state, last seen-after flag; keyed by spec ID/signature |
| `SpatialTransitionPlan` | Expected topology revision, before/after site states, every intermediate edge set, swept volumes, required leases, witness identity, selected presentation mode |
| `SpatialWitness` | Feature ID, observed state signature, last visible time, accumulated visible time, projected size, visible sample count; never a pointer to a disposable mesh |
| `TraversalLink` | Stable ID, source/destination region IDs, paired frames, aperture/clearance volume, reverse link, enabled state, approach waypoints, occupancy tokens |

Use deterministic IDs such as `floor:2/site:door:17:23:0`, derived from the seed,
site kind and accepted placement. Never key state by scene instance IDs or the
order in which streamed chunks happened to appear.

### 3.2 Generation and composition

During floor planning:

1. Reserve existing arrivals, objectives, photo doors/obstructions, realm entries,
   recordings, chargers, stairs, water transitions and other protected content.
2. Search a bounded set of candidate footprints near the route. Reject sites
   that overlap those reservations, unsupported floor heights, or each other.
3. Assign one ordinary anchor prop to the site. Reserve its position and identity;
   do not repurpose an existing quest or photographic object as a moving part.
4. Validate all site layouts, intermediate connections and sightline requirements.
5. Reserve the entire footprint before furnishing. Builders emit the prepared
   module, not a normal wall plus an overlapping replacement wall.
6. Generate legacy blackout alternatives with these cells excluded. New-site
   state overlays must not fight the old seven-state floor snapshots.

Resolver precedence: protected photographed opening; then its non-overlapping
spatial-site owner; then legacy blackout override; then seeded base geometry.
Reject conflicting ownership during planning instead of resolving it visually
at runtime. Sites do not reserve an already photographed edge in the first place.

Use bounded placement failure: keep the ordinary world and omit the site.
For the first showcase floor, admission can try a bounded list of alternative
seeds and a validated fallback, as photographic discovery already does. Never
search indefinitely or delete normal content to force a fit. The test fixture
must guarantee a site; a production seed must not guarantee the player looks at it.

### 3.3 Scene construction

Add named operations to `ChunkSceneWriter` and immutable site facts to the build
context. Respect the existing builder boundary: theme builders must not receive
a mutable `Chunk` or call arbitrary runtime methods on it.

Instantiate each site once under the floor root, registered by stable ID. Chunks
provide attachment/ownership information, not independent copies of the moving
wall. This prevents both sides of an edge creating duplicate colliders.

Prebuild full visual meshes, collision bodies, materials and sounds before the
site is eligible. A live transition must not synchronously construct a `Chunk`,
load a GLB, compile a new shader variant, or scan the whole floor.

Use simple box collision for moving wall leaves and fixed floor collision.
Drive motion in physics time. `AnimatableBody3D` is intended for moving doors
and estimates body velocity; it can affect other bodies, so it does not replace
our explicit sweep/occupancy checks. Do not combine its `sync_to_physics` mode
with `move_and_collide()` on the same moving body. See the
[official moving-body contract](https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html).

Prototype the chosen physics update path on the installed engine before applying
it to campaign geometry. Do not resize arbitrary concave collision every frame.

### 3.4 Event lifecycle and failure rules

| Phase | Required action | Failure behavior |
| --- | --- | --- |
| Dormant | Register spec; no animation or rendering cost beyond normal geometry | Invalid spec disables this site |
| Preparing | Acquire leases; warm resources; validate all endpoints and collisions | Stay in original layout, release temporary work |
| Armed | Obtain witnessed-before evidence and pacing permission; recheck revision | Wait without blackout or visible cue |
| Presenting | Start blackout or lit onset; obtain occupancy protection | If not yet changed, cancel quietly |
| Transitioning | Advance geometry and graph through validated phases | Stop/reopen safely; do not snap geometry over an actor |
| Settling | Reach a safe stable state; persist it; release temporary locks | Retain leases until consistency verified |
| Awaiting recognition | Track the actual changed feature after visibility returns | No forced camera or hidden-change success claim |
| Complete | Consume encounter budget; stable geometry remains | Normal streaming reconstructs the same state |

One structural event per floor is active at a time. A nonlocal link can remain
enabled after its presentation ends; that is persistent topology, not an event
that monopolizes the pacing director forever.

Once the player can occupy newly exposed space, the old state is not necessarily
a safe rollback. Before exposure, rollback to A is allowed. After exposure,
prefer the validated both-open/intermediate state or complete to B. Reversal
requires a fresh sweep and connectivity check. A failure is never permission to
restore walls through occupants.

## 4. Effect A: the migrating doorway

### 4.1 Visual composition

Office prototype: an approximately 8-by-8-metre junction within a reserved room.
A wall clock remains on a fixed pillar. Opening A is beside it; opening B is on
the adjacent wall. A fixed entrance C remains usable throughout. A and B connect
to actual neighbouring rooms; this is not a portal or a duplicate-room trick.

The aperture does not slide like an elevator door. Plain wall surfaces and
skirting advance over A while an aperture develops at B. Use the same wallpaper,
wear and light response as the surrounding room. No rails, pistons, sparks or
energy outline. Keep the clock, floor tiles and nearby furniture motionless.

In the lit version the player should see the end of one passage and the birth
of the other within one ordinary view. In the blackout version only the before
and after need to be visible. Furnish the view to frame both possibilities without
placing an arrow, light trail or new UI marker.

### 4.2 Geometry

Build both final apertures up front, each initially 3.2m wide by 2.7m high
(tuning; adapt to the theme). The room shell excludes those holes. Each hole has
two wall leaves, a fixed header, and jamb reveals that hide leaf thickness.
Leaves translate parallel to the wall into reserved pockets. They do not scale
their wallpaper or collision shapes.

Wall UVs use room-anchored coordinates so patterns remain fixed while the edge
of the solid wall advances. Skirting on the leaves uses the same alignment.
This makes the wall appear to overwrite the aperture rather than reveal a
mechanical sliding panel. Inspect oblique views and reverse-side lighting; a
thin, unlit plane is not acceptable wall geometry.

The module supplies current aperture bounds to both traversal and witness code.
Do not keep the old edge midpoint as a waypoint after moving the passage.

### 4.3 Sequence

Initial tuning, excluding safety pauses:

| Time | Presentation | Authoritative connections |
| --- | --- | --- |
| 0–0.4s | A light buzz localizes toward B; clock/furniture unchanged | A and C open; B closed |
| 0.4–1.6s | B opens across its full width | A/C remain open; B becomes traversable only at shared safe clearance |
| 1.6–1.9s | Both openings briefly coexist | A/B/C open; validate this intermediate state |
| 1.9–3.5s | A closes; sound moves with its leading wall edge | B/C remain open; A retires only under the safe-closure protocol |
| 3.5–4.0s | Sound decays; ordinary room lighting remains | B/C open; state B durable |

Do not reverse A/B as soon as the player looks away. One event is enough for the
first prototype. A later return to A is a separately paced, witnessed event.

### 4.4 Safe closure and route parity

The largest supported actor traversal envelope, plus a tested margin, defines
the common doorway-clearance threshold. Derive it from actual colliders, not
model mesh width or a guessed Pool Girl radius. Currently `ShadowFigure` and
`EnemyTraversal` use the player's body dimensions; retain this intentional
parity. Figures are `Node3D` actors with explicit sweeps, not CharacterBodies.
Do not assume every participant can supply a physics-body RID.

Before closing A, check its complete leaf sweep and both approaches. Inflate
the protected approach by maximum supported movement speed multiplied by the
time needed to stop/reopen, plus the largest actor radius and a margin. Each
physics tick checks previous-to-current swept actor motion, not just positions.

If any actor enters that approach, stop closing before the aperture becomes
too small and reopen fully. Grant the actor a traversal token until its whole
body clears the opposite approach. Apply this to the player, every enemy, and
other moving collision participants. No invisible reservation wall may stop
the player while an enemy gets a special exemption.

This guard must prevent a player exploiting a narrowing gap too small for an
enemy. Validate it at maximum sprint speed and low frame rates. If the guard
cannot be made reliable, do not ship continuous closure: retain the both-open
state and complete only when all approaches are empty. Never weaken parity.

Do not let an occupied doorway stall the game. After 6 seconds of safety hold
(tuning), settle into the valid both-open state, persist it, and end the effect.
The building made a new route even if it could not close the old one. Do not
retry closure immediately behind the same actor.

On each passability change, update collision and graph in the same controlled
physics transaction, bump topology revision, refresh objective routing, and
invalidate all relevant enemy caches before their next movement decision.
Endpoint safety alone is insufficient: prove A/C, A/B/C, and B/C independently.

## 5. Revised architectural blackouts

### 5.1 Witness selection

`SpatialWitnessTracker` observes named features, not merely visited cells.
For the initial junction, track the opening A, the future wall position B,
and the stationary anchor. Bound work to the nearest four prepared sites.

Initial tuning:

- Sample at 10Hz, at most three occlusion rays per selected feature per sample;
  amortize across frames rather than firing every site's rays at once.
- A useful doorway occupies at least 5% of viewport width and 8% of height.
- At least two of three samples are unobstructed and within the central 80%
  of the view. Use the real camera, including its current FOV.
- Accumulate 0.8 seconds of visibility within the preceding 8 seconds for the
  before-state. A stable nearby anchor must also have been visible.
- Reject while charging, on a ladder/slide, reviewing a photo, watching a tape,
  crossing a realm, switching floors, dying, or inside another spatial transition.

These thresholds estimate attention; they do not prove human recognition.
Logging must call the result `witness_eligible`, not `player_noticed`.

A blackout due time is a request to find a good beat, not permission to lower
the quality threshold. Never fall back from line of sight to merely nearby.
If candidates fail, defer and let the player continue. The first intended
showcase can use existing environmental composition and a single positional
sound to attract attention; never repeatedly ping or lock the player's view.

### 5.2 Scheduling and commit

Prepare and validate the small module before lights go out. Ask `HorrorDirector`
for a structural beat and revalidate all state in the same admission step.
Preserve the current stand-still grace and blackout danger behavior.

During darkness, perform the same A → both-open → B physical transition. The
torch still works: if the player catches part of the motion in its beam, that
is valid and desirable. Do not depend on perfect darkness to hide illegal pops.

The blackout timer is bounded independently from construction. Never prolong
darkness indefinitely to finish a mutation. At the configured lights-on time:

- If B is committed, reveal B.
- If the safe both-open result is committed, reveal that actual result.
- If no change could be made, restore lights normally, log cancellation, and
  do not consume the promised architectural-change encounter or claim success.

The director must handle the transaction's result; do not ignore `begin()` or
failure callbacks as the current top-level path can.

### 5.3 Lights-on presentation

Use a small delay between local light banks returning, no rapid strobe. Restore
ordinary lighting so the new wall and opening are readable. A final plaster
creak comes from the changed architecture, not from the player's head.

Track the after-state for 0.75 seconds of useful visible time. If looking away,
the world stays changed; an optional low-intensity material residue waits until
the feature is visible, then fades over 2.5 visible seconds, with a 10-second
wall-clock expiry. One directional cue is allowed; repeated nagging is not.
The geometry must work with the residue and all text disabled.

Remove “FOLLOW THE GLOW” for these events. “POWER RESTORED” can remain as the
ordinary rule status. Furniture nudges may remain ambient changes but must not
count as the principal architectural payoff.

Keep an unseen-after outcome in telemetry. Do not launch another mutation to
force recognition, and do not reverse the first one while its payoff is pending.

## 6. Shared hidden-connection system

This section is a prerequisite for both the return loop and the full growing
corridor. It is the highest-risk work and must pass a standalone test scene
before either effect enters procedural campaign generation.

### 6.1 Constrained visual construction

Use two congruent passage interiors, each with opaque bends before and after
the crossing plane. From the central transfer area the player can see ordinary
walls and corners, but neither outside room. The overlapping visible interiors
match exactly in shape, material, lighting and noninteractive decoration.

The passage is at least 2.4m wide and 2.7m high (tuning), with lengths derived
from sightline validation, not a hard assumption that one corner always hides
a destination. Outer openings and signage sit beyond the bends. Do not put a
unique chair, changing screen, photographable anomaly, water surface, mirror,
or other distinctive world reference inside the matching interior.

At crossing, mapping the camera to the second interior produces the same view.
After rounding the next corner the player sees the genuinely different external
connection. The effect does not require a screen-space portal, separate World3D,
or rendering the whole world a second time.

**Admission invariant:** from every legal head position in the crossing band,
for the supported FOV range and both travel directions, the mapped geometry
must match and both unmatched exteriors must be occluded. Test looking backwards,
diagonally, down and up. If any view leaks, lengthen/rebuild the template or reject
that placement. Do not hide the flaw with a forced blink or a camera snap.

### 6.2 Logical regions and graph adapter

Do not pretend a remote destination is `cell + DIRV[dir]`. Introduce
`TraversalGraph` as a narrow adapter over existing topology:

- Ordinary regions have IDs `grid:x:y` and retain the current cardinal edges.
- A reserved site can replace its owned grid-space navigation with a few named
  regions and ports, such as `site:id/approach_a` and `site:id/approach_b`.
- `locate(position)` first tests reserved authoritative site volumes, then falls
  back to the ordinary grid. Decorative continuation across a seam is not a
  second walkable branch in the logical graph.
- `neighbors(region)` returns explicit `TraversalStep` records: destination,
  link ID or ordinary edge ID, approach/exit waypoints, kind, clearance and cost.
- `world_cell(position)` remains available for streaming, theme sampling and
  ordinary terrain queries. Do not change the seeded WorldGen coordinate system.

Convert room-path selection in `ShadowFigure` and reverse objective routing in
`DescentRoute` to consume this adapter. Site-owned terrain queries must use the
site's actual floor/collision contract rather than unrelated generated props
that were suppressed in its reserved footprint.

Use nonnegative traversal costs. When nonlocal links are present, Manhattan
distance is not an admissible A* heuristic; use Dijkstra/zero heuristic initially.
Keep a measured expansion budget, but a partial route must target a valid
frontier step, not the player's far-away raw coordinates through a wall.

Keep room-count guidance and metre readouts semantically distinct. The current
HUD normally shows horizontal coordinate distance to the lift, ignoring walls;
its temporary honest room-count window follows an optional recording. Update
the room count from the extended graph. For the normal metre number, extend the
existing distance metric through enabled links while continuing to ignore ordinary
walls; do not accidentally turn it into walking-route guidance. Compare direct
distance with the sum of straight segments through each valid link aperture,
using the mapped crossing point. Minimize over the aperture width rather than
always snapping the measurement to its centre. With one active link this is a
small bounded one-dimensional minimization; 16 convex-search iterations at 10Hz
are sufficient as an initial implementation. Both directions participate.
Quantize only the final displayed number. This keeps crossing distance continuous
without displaying an arbitrary jump caused by the coordinate mapping.

### 6.3 Crossing math and physics order

Each endpoint stores a rigid transform with unit scale. Its local +Z points
outward toward its approach. With endpoint transforms A and B and a 180-degree
local yaw turn H, define `M = B * H * inverse(A)`. Reverse mapping is `inverse(M)`.
All templates are upright; only translation and yaw rotations are supported.
No scale, reflection, pitch rotation, or change of gravity is allowed.

**Endpoint frames and geometry roots are distinct.** Store A and B on dedicated
endpoint nodes with the +Z convention above. They never include a mesh's extra
half-turn. For canonical template-local point `q`, source geometry is `A * q`
and its paired geometry is `B * H * q`, equivalently `M * (A * q)`. Implement
the latter with a geometry child rotated by H under endpoint B. Do not also
rotate endpoint B, apply H again to the mesh vertices, or use that geometry
child's global transform as B. Actors receive M exactly once per crossing.

Add these pure-math assertions before testing collision or animation, using
epsilon 0.05m and approximate equality within 0.0001m:

- `M * (A * Vector3(0, 0, -epsilon))` equals
  `B * Vector3(0, 0, +epsilon)`: just beyond the source plane becomes the
  destination's approach side, not its non-authoritative continuation.
- `M.basis * (A.basis * Vector3(0, 0, -1))` equals
  `B.basis * Vector3(0, 0, +1)`: forward crossing motion emerges away from B.
- `inverse(M) * (M * p)` equals `p`, and the same round trip holds for
  orientation and velocity. Geometry satisfies `M * (A * q) == B * H * q`.

Run the assertions for translated endpoints and every supported relative yaw.
A double application of H must fail the signed-side/direction assertions even
if a forward-and-reverse round trip happens to cancel the same mistake.

For these constrained flat interiors, use a **collision-equivalent overlap**
instead of replacing the entire player movement controller. Build collision on
both sides of each local plane for at least the maximum possible per-tick motion
plus the full capsule radius and a margin. Start with a 2m overlap band on each
side; derive/assert its required size from actual maximum velocity and the
largest supported physics delta. No floor discontinuity, stair, moving leaf or
unmatched static collider may occupy that band.

The half beyond the plane is a local collision/visual continuation, not another
route to the outside world. It is exactly congruent to the authoritative mapped
destination. Paired dynamic occupancy/contact queries must also be congruent:
query mapped actors, not just physical bodies in the local World3D.

For each near-seam physics tick:

1. Acquire a paired occupancy token before motion could reach the crossing band;
   confirm both scene leases and the overlap-equivalence assertion.
2. Run the actor's normal movement once. Player keeps `move_and_slide()`; figures
   keep their swept `EnemyTraversal` movement. Both consult paired actor
   occupancy in the band. No new global character-controller implementation.
3. Examine previous-to-result motion for a signed plane crossing. Solve the
   segment intersection and verify full-capsule aperture clearance. An Area3D
   signal alone is not an adequate crossing detector.
4. If crossed, map the result position/orientation by M and rotate velocity by
   M's rotation. The overshoot after the intersection is transformed too; do
   not snap the actor to the centre of the exit or lose this tick's travel.
5. Replace the navigation location, transform interpolation history, notify
   listeners once and update the paired token. Do not run movement a second time.

This is safe only because the collision that resolved the entire step is proven
identical to destination collision under M. An unconstrained “move then teleport”
is not the design. Use a debug assertion to compare the mapped result capsule and
contact normals with the destination, and test an intentionally mismatched
collider to ensure the site is rejected before admission. If matching overlap
cannot be established, this implementation cannot enable the link.

Require a transit to finish inside the overlap band for every supported tick;
raise the overlap size rather than silently dropping collision at high speed.
Out-of-band external repositioning uses the normal explicit teleport path and
must not be interpreted as a crossing. Hysteresis is 5cm initially: suppress
numeric boundary chatter, not a deliberate reverse crossing after clearing it.

Preserve mouse input, yaw/pitch, sprint state, bob phase, animation time, torch
charge and velocity. Transform or rebase the player's `_prev_pos`, `_curr_pos`
and current camera in the same transaction. Do not call `Player.teleport()`;
it deliberately resets movement/water state. Preserve manual camera interpolation
without interpolating across the physical distance between the two interiors.
Godot's [camera interpolation guidance](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html)
explains why this needs its own treatment rather than ordinary node motion.

First version admits only supported dry, grounded actors at equal floor height.
No link is generated on a ladder, slide, stair flight, pool edge or underwater.
If a later version supports those, its traversal state transformation is a new
explicit contract, not a call to clear the state and hope.

Process order is explicit: site safety/lease readiness; actor movement; all
crossing transfers; navigation-location/revision notifications; contact/torch/
observation decisions; render-proxy and audio sync. Coordinate this through
physics priorities or an orchestrated traversal phase. Do not depend on incidental
SceneTree insertion order, and do not evaluate a catch halfway through a transfer.

### 6.4 Actors, collisions and perception across the seam

Matching architecture alone is insufficient: a pursuing enemy must not disappear
when the player crosses while looking backwards.

Within the matching passage envelope, create a render-only mapped proxy for
each actor visible from the paired side. One actor owns AI, collision, health,
animation and sound. Its proxy samples the same skeleton pose and material
state; it is not a second enemy. Clip the original and proxy visuals against
the appropriate seam plane while they straddle it, including all clothing/hair
surfaces and any halo. Reuse the existing ghost shader path with per-instance
clip-plane parameters and implement the same contract for the shadow body/halo
path; test the complete pinned roster in section 1.1. No silhouette may double.

As the actor leaves the matching envelope, the bend must hide the proxy before
it is removed. This is why the template occlusion contract is mandatory.

Provide a bounded, one-link `SpatialQuery` path for:

- player observation of an enemy and the enemy's sight of the player;
- torch influence and fatal-contact checks;
- peer separation and destination occupancy;
- positional footsteps and structural cues.

A query tries the direct physical path and valid one-link paths. For a link,
map the target into source space, intersect the aperture, verify the source ray
to the plane, then the mapped destination ray to the target. Both segments must
be unobstructed. Use their summed length for range. A portal visible only around
two opaque corners does not let a torch burn an enemy through those corners.

Apply peer separation to mapped collision proxies near the seam. Do not permit
two actors to occupy the same paired volume from opposite sides. Use the same
physical movement admission for player and AI; yield naturally in the 2.4m
passage. Do not open a link before its landing region is clear and leased.
Once open, preserve collision readiness until all users and proxies clear it.

Render-only proxies have no independent audio. A positional audio bridge chooses
the shortest audible direct or one-link path, placing a mapped emitter at the
appropriate apparent position or aperture and attenuating by total distance.
Crossfade that emitter on crossing without restarting the underlying footstep
or hum. Do not switch global ambience/music: these effects stay on one floor.

The first templates permit at most one nonlocal seam in any line of sight or
contact range. Reject combinations that need recursive visual or ray traversal.
This constraint is part of generation, not an undocumented renderer limitation.
Initially admit at most one hidden-link site per floor, whether loop or corridor.
Also exclude `PassingShadows` and `CornerApparitions` placements from the whole
site/matching envelope: those ambient systems have separate grid and LOS logic.
Do not retrofit them into the first seam implementation. Existing instances
must have cleared the site before admission; do not delete one in view.

### 6.5 Streaming, revisions and recovery

Both endpoint sites and their approach/exit collision cells are leased before
the connection becomes traversable. Leases are based on the site footprint,
not just the player-centred load radius. Add enemy lookahead leases at the next
link waypoint. Keep both ends alive while either side is occupied, viewed through
the matching envelope, or holds a traversal token.

Emit a topology revision for changes in connectivity and a geometry revision
for changed approach transforms. Enemy invalidation clears the room route,
cached direct-clear flag, local path, stale doorway waypoint and failure timers.
Do not clear a valid in-flight crossing token or strand an actor between phases.

If preparation fails, leave the old ordinary route in place. If an enabled link
loses a required resource, retain the last valid scene and stop retiring it;
do not drop its floor. Treat unresolved consistency loss as a reported invariant
failure, not permission to relocate actors invisibly. Include fault injection
tests before using this system during pursuit.

## 7. Effect B: the impossible return

### 7.1 Experience

Use one real landmark room, not copies. In the Office it contains an ordinary
crooked chair, wall clock and table stain. The player leaves through a side
passage, follows the paired doglegs, and returns through a different door into
that exact room. Taken items remain taken; photographs and moved props agree.

After the reveal, a separate onward passage opens where it is plainly visible.
There is no instruction to repeat the loop or solve an exit condition. The
player can retreat through the original entrance at every point.

### 7.2 Graph and activation

Name the room R, its entrance E, the departure corridor S, the return corridor
D, and the onward connection O. E is always connected. A bidirectional link
pairs the hidden portions of S and D. D physically opens into another side of R.
The route through the link therefore returns to the same R object instance.

Do not retarget the pairing for each actor or each lap. Once activated, S↔D
remains fixed for the rest of this floor state. Every actor sees the same graph.

Arm after the player has seen the room's anchor and both relevant wall/door
relationships. Activate while the actual link installation is unoccupied and
occluded; preserve a valid ordinary route or E bypass during preparation.

Detect one completed player return as a stateful sequence: left R through S,
crossed the designated link, then reentered R through D. Boundary jitter and
walking backwards across the seam do not increment it. Enemies crossing never
advance the player's encounter counter.

On that return, open O using the safe opening module. O's placement and lighting
make onward progress available without a search. S↔D stays connected, so a
pursuer already following still follows. No link closes behind the player.
Further optional loops are allowed but produce no repeated reward or new scare.

If the player retreats instead, permit it. A 25-second active encounter cap
(tuning) opens O anyway; do not force recognition by imprisoning the player.
If R is offscreen at that time, the opening still persists for the next visit.

### 7.3 Presentation

No black flash or teleport sound at the seam. Footsteps keep cadence. The room's
clock tick becomes audible naturally as the return corridor reaches R. Let
recognition precede the small sound of O opening by approximately one second.

The same chair and stain, at the same positions, are the evidence. Do not move
them during this event or change the lighting enough to obscure that it is the
same room. The return should be a spatial contradiction, not a duplicate-room
spot-the-difference puzzle.

The seam itself is not an extra physical room crossed for encounter-retirement
purposes. Update `ShadowFigure._update_chase_lifetime()` to use logical region
transitions, and never retire a figure because its coordinates jumped or while
its paired passage is occupied/visible. Normal encounter retirement may resume
after leaving the site under the usual conditions; do not reset the entire
enemy's encounter timer as a side effect of crossing.

## 8. Effect C: the corridor that refuses to end

### 8.1 Physical layout

Reserve a straight sleeve plus the complete swept footprint of a dogleg exit
module. Initial visible length is 12m; maximum is 24m (tuning). The floor is
fixed, level, and fully built to maximum length. Walls, ceiling panels and lights
exist behind the end module before activation. No ground is generated underfoot.

At distance L, a full-width end wall with a real aperture leads into a short
dogleg module. Its hidden connection leads to a fixed destination vestibule.
The moving module includes the opaque bends needed for the seam's visual contract.
Its source frame translates with the end wall; the destination frame stays fixed.
Reserve the whole module's swept footprint, not just the 12m extension of the wall.
Keep floor collision stationary across that whole footprint, including the bends;
only the wall/ceiling assembly and its link frame translate. Do not parent the
support floor to a moving body and accidentally carry an actor along with it.

The ordinary route can pass through the exit at every stable L. This is a real
linked exit, not a door painted on a wall. Once an actor approaches or enters
either vestibule, freeze module movement before granting a crossing token.
All crossings therefore use stationary frames and ordinary velocity rotation;
we do not introduce moving-portal momentum physics.

### 8.2 Motion and trigger

Arm only after the far doorway has been visibly established. Trigger when the
player advances into the sleeve, the structural pacing slot is free, and all
moving-module/paired-vestibule safety volumes are clear.

Initial algorithm, running in physics time:

1. Measure the player's positive displacement along the corridor's axis since
   the previous tick. Ignore teleport/seam relocation, lateral motion and retreat.
2. Add `1.15 * forward_displacement` to desired extension, capped at 12m.
3. Smooth actual L toward that target with bounded speed/acceleration; initial
   maximum speed 6m/s, acceleration 8m/s². These are tuning, not shipped balance.
4. Stop extension when the player stops advancing. Retain the attained length.
5. If the player or any enemy approaches the moving assembly within the
   predictive safety guard, stop and latch the current length permanently.
6. At maximum extension, or after 12 seconds of active presentation, latch the
   current length. Never force completion to maximum when an actor is nearby.

Thus walking initially fails to close the gap, but running can catch the exit
and end the effect. Retreat is always allowed. The effect never resets the
player backwards, scales input, or enforces a minimum time spent walking.

Use a minimum 4m approach guard (tuning), increased if required by the proven
maximum-speed stopping distance and full swept assembly geometry. The guard
on the destination side also freezes the source assembly: an enemy entering
from the far side cannot arrive in a moving vestibule.

Do not start during an active hostile encounter in the first release. If an
already active actor nevertheless reaches the area, the safety and path rules
still apply; safety cannot depend on the pacing director being perfect.

### 8.3 Visual and audio behavior

The end wall and its exit sign move away. The floor beneath the player does not.
Light bays emerge from behind the retreating wall at normal spacing. Tile size,
wallpaper scale, player FOV and footstep speed remain unchanged. This preserves
the evidence that the space grew rather than the camera zooming.

A localized ceiling rattle follows the end wall; the lights newly uncovered
settle with a low electrical buzz. Avoid a dramatic rising pitch or a loud sting
that announces the trick before the player notices. Reverb can crossfade between
two prepared corridor profiles; do not require a new dynamic acoustic simulation.

The bend hides the fact that the onward room stayed at its fixed coordinates.
No visible viewport texture or portal border appears in the opening.

### 8.4 Routing and stable outcome

Represent the sleeve as one site navigation region with entrance and movable
exit ports. Local routing uses the actual L and collision, not the original
12m grid-cell centre. Suppress ordinary generated edges within its reserved
footprint that would bypass the end wall.

Connectivity stays constant while L changes, so do not rebuild the whole-floor
graph every animation frame. Update the exit waypoint, region travel cost,
geometry revision and relevant local caches. Recompute distance presentation
at a bounded rate; crossing and collision always use current physics transforms.

When latched, save the actual finite L. Keep that length for the floor; do not
shrink the corridor behind a follower or recreate the short version on re-entry.
Once nobody leases it, streaming may remove it and reconstruct the identical L.

## 9. Persistence, interruption and compatibility

`DescentProgress` currently saves floor progress, not an exact suspended player
position: Continue starts from the deepest floor's arrival with reset player
resources. Preserve that behavior.
Do not expand this feature into a general save-anywhere implementation.

Add a versioned `spatial_sites` floor map containing allowlisted values only:
site ID, spec signature, generation version, stable phase, finite corridor L,
door A/B openness, link activation, loop onward-exit state, and consumed event
flags. Validate enums, IDs, finite numeric ranges and maximum counts on load.
Store graph and geometry state together through the existing atomic save path.

In-memory streaming keeps the exact live phase/progress. Active or occupied
sites stay leased. Pause freezes the shared physics-time event clock; it does
not spend reveal visibility time, change loop counters or advance wall motion.

For disk checkpoints during presentation, derive a safe persistent layout:

- Doorway: preserve the real stable phase; if between endpoints, store a validated
  both-open layout, not a wall that could recreate an inaccessible route.
- Corridor: store current L as latched, with a usable exit.
- Return loop: preserve its fixed pairing; if interrupted after activation,
  persist the onward exit open so Continue cannot strand the route.

Do not apply this normalization visibly to a running occupied scene. It is the
reconstruction policy for arrival-based Continue. Flush the final real outcome
when the event settles. Save failure uses the existing error reporting and must
not be called a successful durable commit.

On death/floor teardown, release leases/proxies after actors stop using them;
clear queued callbacks using a floor/session generation token. An asynchronous
callback from a previous floor must not mutate the new floor's matching site ID.

Old saves with no site data load with no active new events until normal admission.
If a generation/spec signature changes, discard only incompatible site state and
revalidate the ordinary arrival route while retaining photo, tape and progress
records. Never apply a saved doorway or link to newly unrelated coordinates.

Development fixtures write isolated save paths, as current test modes do.

## 10. Campaign placement, art variants and pacing

Start in the Office for implementation and player testing. Do not deploy all
effects across all themes at once. A single junction proves the main concept.

| Theme | Fixed recognition anchor | Mutation treatment | Restrictions |
| --- | --- | --- | --- |
| Office | Clock, stained carpet, crooked chair | Wallpaper overwrites an opening; repeated fluorescent corridor; return to same meeting room | No concurrent rearrangement of the anchor props |
| Airport | Gate number, seating bank, luggage scuff | Boarding passage shifts bays; long service corridor extends | Never animate an escalator, security interaction, glass-dependent occlusion template or exterior window |
| Poolrooms | Stopped clock, unique tile repair, pool shape | Dry doorway changes the route around an unchanged pool; dry return passage | No moving basin, lip, ladder, water height or slide; wet traversal is out of scope |
| Annex | Isolated pillar and a single fixture | Bare opening migrates across otherwise empty architecture | Use real shadow/contact detail so closure reads as a wall, not a black rectangle |

Initial campaign tuning:

- Early floors establish a clear blackout before/after before introducing a lit
  transformation. Preserve the existing first photographic discovery's priority.
- At most one major lit spatial event on an eligible floor, with at least 90
  seconds since another major spatial presentation. A floor may have none.
- Start with at most one main-route return-loop encounter per run, always with
  retreat and bounded release. Place it after the player has learned the world.
- Do not begin lit effects during active pursuit, recording playback, realm
  excursions, arrival presentation or photographic review.
- Existing enemies remain real actors; the director can postpone new spawns,
  but the effect cannot delete, immobilize or relocate an inconvenient pursuer.
- An effect uses the structural-event slot; it does not add a simultaneous
  whisper, screen glitch, enemy rush or furniture scare.

Reduced-flashing mode removes incidental light dips, not topology changes.
Respect camera-motion settings: these features add no camera roll or FOV pulse.
The baseline must be legible with sound off and without colour discrimination.

## 11. Implementation work packages

Complete and validate each package before starting its dependent package.
The filenames are an ownership map, not permission to rewrite unrelated code.

### Handoff preflight — establish a reproducible baseline

Before implementation, identify the exact source revision and asset manifest.
If handing over uncommitted work, include the tracked-file patch and every
required untracked source/asset with content hashes in a named snapshot; a commit
ID alone does not describe this workspace. Verify the snapshot in a separate
checkout and load every manifest model, required clip and shader there.

At this specification review, the local Pool Girl and Faceless Enforcer asset
directories are untracked and their registrations are in modified source files.
Pool Girl therefore exists in the working tree but may be absent from a
committed-only checkout. Do not silently narrow v1 coverage to what another
checkout happens to contain. Reconcile the handoff before implementation.

Record engine version, commands, seeds/themes, source/asset snapshot identity
and assertion-level baseline results. Re-run the mutation graph audit on that
snapshot; the historical result in section 2 is not a permanent waiver.

### Package 1 — Instrument existing blackouts

Files: `descent_run.gd`, `descent_mutation_coordinator.gd`, `main.gd`, new
`spatial_witness_tracker.gd`, focused audits.

Record request, selected witness, retry/failure reasons, committed geometry,
lights-on time and observed-after time. Remove the hidden-change fallback for
the new architectural path. Handle begin/commit failures explicitly. Keep the
old path isolated until the replacement fixture passes; do not silently alter
all live events during initial debugging.

Exit gate: forced visibility failure cannot start a purported architectural
success; no outcome is reported committed before scene/graph agreement.

### Package 2 — Build the junction fixture and new execution path

New: `spatial_site_spec.gd`, `spatial_site_state.gd`,
`spatial_mutation_director.gd`, `spatial_site_transaction.gd`,
`migrating_door_site.gd`.
Integrate: topology, transaction/coordinator, scene writer/build context,
chunk manager, horror director, progress, player/enemy cache notifications.

Build one deterministic flat fixture with three real connections, anchor props,
both-side lighting and an optional pursuing enemy. Implement opening first,
then safe closure, then blackout and lit presentation, then save/streaming.
Only after the fixture passes, implement bounded Office placement.

Give the fixture explicit anchor props, required-content nodes and connections.
Its assertions must not depend on the legacy generator finding a random Office
furniture variant. This isolates the fixture setup; it does not exempt the
fixture from any collision, connectivity, objective or witness requirement.

There are two separate exit gates:

1. **New feature gate:** readable A/B contrast without HUD effects; every fixture
   collision/objective/reachability assertion passes at every transition phase;
   actor blocking settles both-open safely. New generated-site integration tests
   must also pass once bounded Office placement is introduced.
2. **Regression gate:** no new failures against the exact pre-change snapshot.
   The existing furniture assertion may remain a separately reported baseline
   issue only if reproduced before the feature changes on the same test inputs.
   Record the exact assertion, seed/theme, command and source identity. Do not
   ignore the whole audit's exit code or suppress all Office failures. Any added
   or changed failure, including connectivity, blocks this gate.

Track the furniture issue separately; it is not a prerequisite for this package.
When fixed, remove its baseline exception and require the audit to pass. Never
describe a suite retaining the known failure as entirely green. Any newly failing
seed or assertion needs its own before/after investigation, not this exception.

### Package 3 — Build and prove hidden traversal independently

New: `traversal_graph.gd`, `traversal_link.gd`, `spatial_traversal.gd`,
`spatial_query.gd`, `hidden_link_site.gd`, actor visual/audio proxy support.
Integrate: route graph, player movement/interpolation, enemy movement/LOS/torch/
contact/peer queries, traversal/local routing, hostile leases, HUD distance.
Also integrate caught-presentation coordinates and heartbeat proximity; exclude
ambient passers/corner apparitions from these site volumes in version one.

Use two distant identical passageways with a marked debug plane. No horror
effects yet. Prove dry bidirectional crossing, reverse crossing, high-speed
collision, look-back pursuit, transformed actor collision and streaming first.
Then remove the debug marks and validate the seam visually.

Exit gate: it is impossible to tell which physics tick crossed by camera motion,
footstep cadence, missing enemy, duplicated silhouette or input loss. Frame-by-
frame captures must show correct architecture and actor continuity.

### Package 4 — Compose the impossible return

New: `return_loop_site.gd`; extend site planning and persistence.
Use one actual room instance, fixed paired links, a counted return sequence and
a separate safe onward opening. Implement timeout/retreat paths before pacing.

Exit gate: a follower takes the identical connection and arrives naturally;
returning cannot duplicate props/evidence or reset doors; onward progress is
available after one return or timeout.

### Package 5 — Compose the growing corridor

New: `growing_corridor_site.gd`; reuse package 3, do not write a second teleport
system. Add moving-source-frame leases, stationary-crossing interlock, moving
end-module sweep checks, finite L persistence and distance updates.

Exit gate: the exit is usable at every latched length, entering from either side
halts motion safely, sprint/stop/retreat work normally, and no actor is left on
unloaded or newly shortened floor.

### Package 6 — Campaign and theme rollout

Update builders through typed writer operations, event priority, reservations,
settings behavior, QA fixtures and campaign telemetry. Add a second theme only
after the Office has passed player recognition and performance testing.

Keep Wander unchanged initially. Expose explicit per-effect development flags
and an isolated spatial test mode; proposed flags are `--spatial-test=door`,
`--spatial-test=loop`, and `--spatial-test=corridor`, not current commands.

## 12. Acceptance tests and measurements

### 12.1 Automated invariants

| Proposed test | Cases that must pass |
| --- | --- |
| `audit_spatial_roster.gd` | Exact behavior/visual manifest; required source assets and walk/run clips load; both body/halo shader families covered; missing entries fail rather than skip |
| `audit_spatial_site_generation.gd` | Deterministic IDs/specs; bounded search failure; no reservation overlap; every intermediate graph connects required content; photo routes remain open |
| `audit_spatial_witness.gd` | Occluded, offscreen, too-small and fleeting views rejected; actual before signature tracked; after time only accumulates visibly; no hidden fallback |
| `audit_migrating_door.gd` | Both directions; player camping either aperture; enemies at both approaches; sprint entry during closure; low-rate physics; safe both-open timeout |
| `audit_spatial_revisions.gd` | Existing direct/room/local/waypoint caches invalidated; actor already crossing retains valid token; no stale old-floor callbacks |
| `audit_hidden_link.gd` | Quarter-turn and straight mappings; signed-side/emerging-direction and geometry-frame assertions; position/orientation/velocity round trip; collision-overlap equivalence; mismatched collider rejection; high-speed overshoot; reverse crossing; anti-jitter hysteresis |
| `audit_hidden_link_pursuit.gd` | Section 1.1 behavior/visual coverage, including Pool Girl walk/run and hound scale; close pursuit while looking backwards; opposite-side meeting; all body/halo passes clip; peer separation; wall-blocked torch/catch tests |
| `audit_spatial_streaming.gd` | Source/destination outside normal render radius; enemy-only leases; occupied teardown rejection; unload/reload same link and state |
| `audit_return_loop.gd` | Same room/object identities; single completion counter; reverse seam jitter ignored; timeout/retreat; onward exit opening with enemy in old corridor |
| `audit_growing_corridor.gd` | Walk/run/stop/retreat; finite extension; arrival from far side; no motion under occupied module; current-length exit usable; no platform carry or FOV change |
| `audit_spatial_progress.gd` | Every stable phase; save during transition; missing/invalid signature; older saves; isolated dev saves; photo/tape/object-state retention |

Add fault injection for failed resource preparation, lost pacing permission,
revision change after arming, save failure, cancellation before exposure and
failure after exposure. Assert the resulting geometry and graph, not just that
a callback was emitted. Audit connectivity from every occupied region as well
as the arrival and objective; include needed evidence/recording sites.

Run existing world-hash, chunk, route, photo-door, mutation, enemy pursuit,
Airport traversal, Poolrooms traversal, level-switch and progress regressions.
Update expected world fingerprints only for reviewed generation changes.
Apply Package 2's assertion-level baseline policy to these regressions; no
baseline exception applies to the new spatial tests or permits a safety failure.

### 12.2 Visual capture matrix

Capture before, onset, intermediate, completed and reverse-side views for each
effect. Repeat with CRT on/off, torch on/off, reduced flashing, supported FOV
extremes and low/high frame rates. Capture slow wall-edge contact and an enemy
straddling the seam frame-by-frame. Inspect:

- no UV stretching, thin-wall backfaces, duplicate jambs or lighting discontinuity;
- no stale room after streaming and no full-chunk pop during lit motion;
- no camera smear, changed stride, reset animation or missing pursuer at crossing;
- doorway closure actually looks like architecture changing, not a normal door;
- the anchor stays recognizable and the changed route dominates the composition.

The hidden link needs special adversarial captures: walk backwards, strafe across,
stand astride the plane, turn 180 degrees while crossing, and let two enemies
approach from opposite sides. If it fails, keep it out of the campaign; do not
ship with a note that players probably will not look that way.

### 12.3 Performance gates

Measure on the actual target hardware/renderers; the following are acceptance
targets, not claims about current performance:

- Idle site processing should be negligible and bounded by resident candidates.
- No synchronous asset loading, whole-Chunk construction or unbounded route
  rebuild during a visible transformation.
- Aim for less than 1ms additional main-thread work at the 95th percentile for
  one active local site; investigate any event-attributable stall above 4ms.
- Bound proxy count by actors inside one matching envelope, not every actor on
  the floor. Reuse resources; proxies do not run AI or independent animation logic.
- Compare frame-time traces for the same fixture with the event enabled/disabled,
  including lower graphics settings. Record memory before/after repeated stream
  cycles and ensure site leases/proxies are released.

A performance miss disables admission or postpones preparation; it must not
degrade into incomplete collision, a low-resolution fake exit, or an enemy-only
route restriction.

### 12.4 Human recognition gate

Use at least five fresh players for the first junction, with no explanation of
the trick. Ask after the encounter, “Did anything about the space change? What?”
Do not ask whether they saw a moving door. A provisional target is four of five
accurately describing the relationship change without the glow or caption.
This is a small usability check, not a statistical success-rate claim.

Log separately: eligible before view, transition completed, useful after view,
and participant recognition. If technically visible but unnoticed, improve
composition, anchors and magnitude before adding frequency or louder effects.

The first release gate is a convincing junction. The loop and corridor have
separate approval gates; none is required to justify shipping the simpler,
successful blackout improvement.

## 13. Source-reading map

Relevant current code, for implementation orientation:

- `scripts/descent_run.gd`: `_begin_blackout`, `_end_blackout`, first-event scheduling.
- `scripts/descent_topology.gd`: `plan_floor`, `state_delta`, `find_transition`,
  `_edge_info_with`, protected cells and `_state_reaches_all`.
- `scripts/descent_mutation_coordinator.gd`: `begin`, `_prepare_commit`,
  `_finish_commit`, `can_commit`, `visibility_rank`, `rebuild_cells`.
- `scripts/descent_mutation_transaction.gd`: staged commit and rollback contract.
- `scripts/chunk_manager.gd`: `set_hostile_cells`, `_process_staged_rebuild`,
  `_commit_staged_rebuild`; this full-chunk path is not the lit-animation path.
- `scripts/photo_door_seal.gd` and `scripts/photo_director.gd`: prebuilt aperture,
  independent collision seal, reciprocal opening and streaming reconciliation.
- `scripts/player.gd`: `teleport`, `_physics_process`, `_process`, pool/slide state.
- `scripts/shadow_figure.gd`: `_route_target`, `_clear_route`, `_next_route_cell`,
  direct travel and actual observation/contact queries.
- `scripts/shadow_figures.gd`, `scripts/enemy_local_path.gd`,
  `scripts/enemy_traversal.gd`: actor leases, local movement and terrain contracts.
- `scripts/passing_shadows.gd`, `scripts/corner_apparitions.gd`: exclude ambient
  placements from site envelopes until their independent LOS/routing is adapted.
- `scripts/descent_route.gd`: graph access and reverse guidance construction.
- `scripts/descent_hud.gd`: room-distance versus metre display semantics.
- `scripts/realm_excursion.gd`: view-transform reference; not an actor-followable
  seamless traversal implementation.
- `scripts/descent_progress.gd`, `scripts/chunk_runtime_state.gd`,
  `scripts/main.gd`: arrival checkpoint, object state, floor wiring and persistence.
- `docs/ARCHITECTURE.md`: typed builder/writer boundaries and mutation discipline.

Review the current dirty-worktree versions before editing. Some older design
documents describe enemy water limitations and blackout visibility guarantees
that no longer match the source. Preserve unrelated work.

## 14. Concrete interface and fixture contracts

### 14.1 Minimal public surface

The following signatures describe responsibilities, not copy-paste production
code. Implement typed records; avoid a new set of unvalidated Dictionary messages.

| Owner | Proposed method/signal | Contract |
| --- | --- | --- |
| Site planner | `plan_sites(route, reservations) -> Array[SpatialSiteSpec]` | Pure, bounded, deterministic; no scene construction or actor queries |
| Site registry | `acquire(site_id, reason) -> SiteLease` | Idempotent reference-counted leases over exact cells; releasing a token twice is harmless |
| Site node | `prepare(spec, state) -> PreparationResult` | Build once, verify collision and matching geometry, then declare ready |
| Site node | `current_clearance() -> SiteClearance` | Actual installed geometry, not intended animation endpoint |
| Site node | `advance_physics(dt, occupancy) -> PhaseResult` | Only changes this site's geometry; reports passability/pose changes explicitly |
| Site transaction | `begin(plan, expected_revision) -> BeginResult` | Checks ownership, revision, leases, reachability and actor safety; no visible change on rejection |
| Site transaction | `settle(result) -> CommitResult` | Publishes a validated stable state and persistence outcome once |
| Witness tracker | `sample(camera, site_features, dt)` | Bounded work and stable feature IDs; independent before/after accumulators |
| Traversal graph | `locate(position) -> NavLocation` | Logical region plus physical cell/local site coordinate |
| Traversal graph | `neighbors(region) -> Array[TraversalStep]` | Real ordinary edges and explicit links; never a hidden coordinate shortcut |
| Traversal helper | `before_motion(actor, dt) -> TransitPermit` | Checks paired readiness and updates projected peer occupancy |
| Traversal helper | `after_motion(actor, previous_pose, permit) -> CrossingResult` | At most one crossing per supported tick; maps full result and motion history atomically |
| Spatial query | `sight(observer, target) -> SightResult` | Direct or one-link segments, apparent target pose, distance and occluder result |
| Spatial query | `contact(a, b) -> ContactResult` | Actual capsule/ward/catch conditions in one frame; identifies authoritative actor and presentation pose |
| Revision bus | `topology_changed(revision, affected_regions)` | Connectivity notification before consumers next decide movement |
| Revision bus | `geometry_changed(revision, affected_regions)` | Waypoint/shape pose update without a full graph rebuild |

`NavLocation` has `region_id`, `physical_cell`, `site_id` or empty, and local
coordinates. `TraversalStep` has `from_region`, `to_region`, `kind`, `link_id`
or empty, `approach`, `exit`, clearance dimensions, nonnegative metre cost and
room-transition cost. Keeping both costs avoids turning a 12m corridor extension
into an invented extra room or using Manhattan cells as metres.

Expose one `SpatialActorAdapter` for the player and one for figures. It supplies
the authoritative capsule, previous/current transform, movement velocity,
render pose, and callback for mapped state. This is necessary because Player
is a CharacterBody and ShadowFigure is a Node3D with explicit collision queries.

For the player, apply the crossing hook after physical movement and before
`_record_traversal_sample()` and camera history finalization. Preserve existing
world-bucketed traversal samples; do not transform the entire historical map.
Record the destination sample normally and reset only the last-sample sentinel
if needed. Never fabricate a walkable sample segment connecting the distant
coordinates. A link belongs to the traversal graph, not the breadcrumb map.

For figures, map `_walker` heading and cached turn targets as well as the root;
preserve scalar angular speed and animation phase. Invalidate long/local/direct
routes, then target the valid exit-side waypoint before chasing raw player
coordinates. Transform any local avoidance direction stored in world space.

`ContactResult` supplies a mapped presentation pose for catches spanning a seam.
`CaughtSequence` must frame the visible local proxy/pose, not fly the camera
toward the actor's distant authoritative coordinate. Emergency flash and damage
still address the original figure exactly once. Heartbeat proximity and torch
aim use the same mapped distance/pose; otherwise a nearby visible enemy could
sound far away or become unburnable. Add these to pursuit regression fixtures.

### 14.2 A reproducible hidden-passage template

Start with a deliberately generous template; optimize footprint after the
correctness and visual gates pass. Work in metres, Y up, seam at local Z = 0.
Use a 2.4m-wide, 2.7m-high flat passage with this centreline:

| Control point | X | Z | Meaning |
| --- | --- | --- | --- |
| P0 | -5 | 8 | Approach-side exterior beyond the first bend |
| P1 | 0 | 8 | First opaque right-angle bend |
| P2 | 0 | 0 | Transfer plane; 2m collision-overlap band on either side |
| P3 | 0 | -8 | Second opaque bend |
| P4 | 5 | -8 | Other exterior beyond the second bend |

These are canonical template-local points, not the endpoint transforms A and B
defined in section 6.3.

Build joined rectangular floor/wall strips with filled outside corners and
sealed ceilings; do not just overlap wall boxes and leave diagonal cracks.
The full matched visual envelope includes the central straight section and
the inside faces of both bends. End matching decoration before the outside
exteriors P0/P4 become visible. Source template-local geometry `q` is placed by A;
the paired geometry is placed by `B * H`, including its UV frame and local
lighting. Equivalently, apply M to the already world-space source geometry, not
to raw template-local vertices. The geometry child under B supplies H exactly
once; endpoint B itself does not contain that extra turn (section 6.3).
Separately randomized wear, flicker or world-coordinate noise would reveal
the switch.

Only the approach half of each endpoint is authoritative for actor residency;
the counterpart half is the congruent visual/collision continuation. An actor
never reaches that continuation's external exit locally: it has already crossed
to the paired authoritative space at P2. Do not publish the continuation as an
ordinary cardinal route, spawn location or interaction candidate.

The standalone test scene places the two copies at least 100m apart so ordinary
distance/streaming errors become obvious. Test relative endpoint yaw of 0, 90,
180 and 270 degrees. Use a checkerboard floor in debug, then the intended
material: checker cells, shadows and actors must align across crossing.

The dimensions above are a starting fixture, not proof of occlusion. Sample the
whole capsule-width crossing band and legal camera heights/FOVs, then capture
free-look traversal. The template is not production-ready until the exterior
occlusion and mapped collision-equivalence tests pass.

### 14.3 Debug view and event log

Provide a developer-only overlay toggled in the spatial fixture. Show site ID,
phase, current L/open widths, graph/geometry revisions, leased cells, witness
before/after dwell, active tokens and cancellation reason. Draw swept volumes,
paired frames, authoritative region boundaries and navigation waypoints in
different labelled styles, not colour alone.

Write one structured log record on each state change, not every frame. Include
seed, floor, site/signature, elapsed active time, transition mode, from/to phase,
actor occupancy count, committed outcome and failure reason. Sample timings
separately for witness rays, safety sweeps, graph updates, proxies and scene work.
This lets a junior implementer distinguish “never eligible,” “prepared too late,”
“actor blocked closure,” “committed but unseen,” and an actual broken transition.

Do not write player-identifying data or capture screenshots automatically during
normal play. Debug capture and player-study recordings are explicit test actions.
