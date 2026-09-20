# Package 3 review fixes

September 20, 2026. Applied on top of the engineer's uncommitted Package 3
implementation and the separate baseline cleanup. No procedural Package 4
effect is enabled by these changes.

## Movement and blocked landings

`SpatialTraversal.bind_actor()` connects Player and ShadowFigure to the same
pre-motion paired-capsule sweep. Player motion/transfer has explicit priority
before figure decisions. Transfers occur inside each actor's movement tick;
Player transfers before recording breadcrumbs and finalizing camera history.
Callers must bind all participating actors, not only the player.

An occupied destination constrains motion before the seam. A post-move refusal
(such as a link disabled after readiness) restores this tick's safe approach
position, resets crossing-side memory and permits a later retry. It no longer
leaves an actor in the decorative continuation. Existing tests that expected
the unsafe, already-crossed position were corrected to assert the approach.
Teleporting explicitly clears crossing memory. Camera orientation, velocity,
interpolation history, gait and input state survive successful transfers.

## Observation and encounter lifetime

Enemy observation and first-sighting frustum tests use verified mapped poses.
Distance-dependent pursuit uses the mapped distance. The approach halves of a
link share an encounter-region identity, so the seam itself spends no room
budget. Ordinary entry and exit remain real region changes. The live walk and
room-to-room tests retain the normal enemy lifetime limit.

## Navigation ports

`TraversalGraph.register_port(region, outside, inside_path)` creates explicit
bidirectional ordinary-room/site edges. The inside path runs from the seam
approach through bends to the real doorway. Link traversal follows its reverse;
exiting follows it forwards. Figures choose the furthest physically clear
waypoint, not the distant player's coordinate through a wall. Grid steps also
provide physical waypoints; exhausted routes stop at a valid frontier.

Ports stay walkable when their nonlocal link is disabled. The continuation
half is excluded from authoritative site regions. An installer must use
`reserve_cells()` for its suppressed, owned grid footprint; registration never
invents openings from AABB overlap. The fixture's `graph_for()` demonstrates
the ports and bend paths. Campaign site composition remains Package 4 work.

## Actual bent template and visual gate

The fixture now has a 2.4m-wide, 2.7m-high S passage, with bends at z=+/-8m,
open doors into distinct exterior rooms, and matching interiors placed by
A and B*H. Perimeter walls are generated around the union; no wall spans an
internal join or exterior doorway. Leases and occupied-release checks cover
the full matched envelope, including bends, rather than only the 2m band.

`audit_seam_occlusion.gd` checks 5,400 rays toward dense samples of both exterior
openings and 10,800 paired ray-hit position/normal comparisons. Samples include
both transfer directions, straight/quarter-turn endpoints, lateral head
positions, multiple heights, and upward/downward directions. The full angular
sampling is independent of camera FOV. Separate open-door checks prevent sealed
end caps from falsely passing the occlusion gate.

`capture_hidden_link.gd` explicitly draws the offscreen viewport before
reading it; its old process-frame-only wait could save stale images, and a
post-draw signal wait could stall when the desktop window was minimized.
Its live actors use the same in-motion hooks as the walk tests. It captures
crossing, look-back pursuit, paired silhouettes and both exterior approaches.
Output: `/tmp/liminal-hidden-link-hardened/`.

## Verification

Focused gates: traversal_math, traversal_actors, hidden_link,
hidden_link_pursuit, spatial_witness, spatial_placement,
spatial_campaign_event, spatial_query, spatial_roster, spatial_streaming,
spatial_revisions, seam_walk, seam_meeting, seam_safety, seam_occlusion,
ghost_room_contract, survivability, handheld_camera,
enemy_topology_invalidation.

The new safety gate covers blocked landing/retry, pre-motion paired separation,
look-at/look-away classification, zero seam room-budget cost, ordinary ports,
disabled-link escape, and live ordinary-room-to-ordinary-room pursuit through
both straight and quarter-turn mappings.

These focused checks pass (including reruns of the updated suspension tests).
This is not a claim that the entire 165-entry suite was rerun after the review
fixes. The prior complete baseline run is recorded separately.

Key logs: `/tmp/p3-fixed-seams.out`, `/tmp/p3-fixed-safety-final.out`,
`/tmp/p3-fixed-traversal.out`, `/tmp/p3-fixed-hidden.out`,
`/tmp/p3-fixed-spatial.out` (the two old suspension expectations failed here),
then `/tmp/p3-fixed-streaming.out` and `/tmp/p3-fixed-revisions.out` (both pass).
Legacy checks: `/tmp/p3-fixed-legacy-room.out`,
`/tmp/p3-fixed-survivability.out`, `/tmp/p3-fixed-camera.out`,
`/tmp/p3-fixed-invalidation.out`.

The final headed capture completed without script/engine errors:
`/tmp/p3-hardened-capture.out`. Inspected the crossing pair (`cross_04/05`),
look-back pursuer, figure-crossing, two-actor meeting and distinct exterior-room
captures. The checker geometry and silhouette remain continuous at the seam;
the blue/red exterior rooms are revealed only beyond the bends.
`git diff --check` and shell syntax validation pass. Changes remain uncommitted.
