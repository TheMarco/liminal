# Persistent enemy pursuit

September 15, 2026.

- Active enemies lease collision around their current and next route cells. Leaving the player's render neighbourhood no longer removes their floor.
- Removed the three-room expiration and the unseen close-range parking rule. Unseen rushes ease to a slower approach rather than stopping.
- Room routing uses bounded goal-directed search and can advance toward goals beyond the former 32-cell cutoff. Local routing uses actual furniture, doorway and floor collision.
- Turning has angular acceleration and a maximum yaw rate. Ground movement follows the model's forward axis; speed reduces for tight turns. A small forward clearance probe leaves room to turn beside walls.
- Predictive peer avoidance includes turning aside/back to yield in bottlenecks. Swept separation is the final collision guard. Temporary queues can form in narrow openings; enemies continue replanning rather than pushing through each other.
- Contact and torch visibility no longer ignore walls within 1.2 metres of the target.
- Manager suspension now suppresses existing actors, not just new spawns. Scripted approach warnings, pauses, torch warding and death animations remain deliberate exceptions to movement.
- Campaign speed is `base × (1 + 0.03 × completed levels)`: 100% on the first floor, 103% on the second, up to 130% on the eleventh. This does not change spawn frequency. Realm encounters inherit the source campaign progression and selected monster presentation.
- The 3D walking clip rate is proportional to measured ground velocity, including turn slowdown and level progression; stationary actors do not march in place.
- The current Hollow Watcher prototype uses its measured stance-foot speed (1.98 m/s at playback 1.0), replacing the guessed shared 2.9 m/s. Animation advances on the movement update, including clamped hitch frames; `tools/measure_walker_stride.gd` verifies planted-foot drift against the imported clip. This is stride calibration, not terrain-aware foot IK.

Poolrooms enemies spawn and walk only on supported dry deck at the authored deck height. Their footprint cannot cross a basin lip, submerged floors are rejected, and connected-room crossings select a dry section of the opening. When the player is in a pool, local routing approaches the nearest reachable dry shore and resumes the chase when a dry route becomes available.

Regression coverage: `audit_pool_enemy_ground.gd` (deck-height spawning, basin/lip rejection, dry detours, shoreline pursuit, bridges, connected pools and other-level compatibility); `audit_enemy_pursuit.gd` (3D finite/U obstacles, forward-only bounded turns, crowd convergence, head-on passing, narrow-door followers at final-floor speed, distant routing, through-wall catches); `audit_enemy_streaming.gd` (leases, priority, release and modal holds); `audit_ghost_room_contract.gd` (legacy movement and progression); `audit_shadow_walker_prototype.gd` (current model and animation speed); existing discovery and reality-warning contracts.

These are deterministic headless checks, not a guarantee for every procedural seed. Visual feel and uncommon generated furniture arrangements still need ordinary playtesting. No release binaries were built for this change.
