# Temporary realm visits

Realm visits are part of normal Descent runs. Floors 1–10 each reserve an
entrance on the first half of the procedural route, leading to the next actual
campaign realm. The final realm has no onward visit. The casino reuses its
introductory photo doorway; later floors have their own doorway, separate from
photographic obstructions. Existing room builders and models supply each visit.

The entrance and preview survive streaming out and back in. Entering consumes
that floor's visit for this run. Returning alive, voluntarily leaving, or being
caught all keep it spent; there is no second attempt on the same floor. Merely
taking the doorway photograph does not consume the visit. A fresh run resets
visits. Normal checkpoints persist this state (save format 6; older saves
migrate).

Destination models begin loading through background resource requests at floor
arrival. Preview chunks are then constructed in stages, and reward placement
yields between batches of collision checks. These use two-millisecond budgets
between indivisible stages/queries; they are not hard frame-time guarantees.
The preview renders only while the lens exposes it or the photographed doorway
is open, at the source world's 3D resolution (480 lines with CRT). This avoids
rendering an invisible second world behind the sealed wall.
Add `--perf-log --chunktime` to a play session to record frame and build timings
without the automatic movement enabled by `--bench`.

The discovery prototype prefers a wall ahead of the player's approach into an
early route room. Placement uses the actual incoming opening and room ownership;
when no central candidate exists, it chooses the best available facing wall.
Within 18 metres on the approach side, an irregular eye-height patch of
blue-violet glyphs pulses through the sealed wall for 1.8 seconds, with faint
glyph residue left visible during the six seconds between pulses. The signal
begins on approach, even when looking away or during the movement-enabled
arrival grace. It also works from an adjacent room with a clear sightline through
an opening. A directional hum (-12 dB, six-metre unit distance) helps locate the
wall. Solid intervening walls still block the cue from other rooms. There is
no explicit HUD instruction to use the camera. The destination itself remains
visible only through the camera until photographed.

The first actual view of the glyphs delays fresh ghost arrivals for 4.5 seconds.
An offscreen pulse does not consume this opportunity. Existing
attackers keep moving normally, and later pulses grant no further delay. The
hold clears when encounters are despawned. The clue pauses during rule holds,
videos and blackouts, hides while the camera is raised or the seal is unloaded,
and stops once photographed. Reduced flashing lowers its brightness.

Test discovery from the ordinary mall arrival (not directly at the wall):

```sh
godot --path . --log-file /tmp/discovery-play.log -- --mode=descent --nologo --seed=21 --descent-floor=2
```



For a quick Casino → Mall test, start facing the entrance:

```sh
godot --path . --log-file /tmp/realm-play.log -- --realm-visit --seed=21
```

Raise the camera with **C**, photograph with **Space**, then walk through after
the print lowers. The viewfinder shows a live, perspective-correct view of real
generated mall geometry. The photograph makes that view visible to the eye.
Crossing the threshold transfers the player into those rooms.
Aim into the visible opening: close-up shots also work, without requiring all
four frame corners to fit. Facing away or aiming through an intervening wall
does not register.

The visit lasts **30 seconds of active play**. The first five seconds allow
orientation; existing attackers then spawn in legal, visible, clear positions
7–12 metres away, with a two-second reaction grace. The encounter allows one,
then two, then three simultaneous attackers. Normal torch and sprint behavior
remain in effect. Contact fails the one-shot visit without ending the Descent
run. The exact attacker owns the ordinary first-person caught presentation
inside the temporary realm; only after its cut to black does the controller
restore the unchanged source floor. A photographed flash is lost.

An emergency flash appears as a floating 3D lightning bolt, 2.05 metres tall,
1.15 metres wide, and 0.32 metres deep, made entirely of tiny blue-violet glyphs.
The code stays attached to its front, back, and sides as it gently turns and
bobs. It is visible to the bare eye as well as the camera. A bounded search
checks real capsule clearance and sight from a reachable approach, preferring
furnished locations in the entry view. It places the bolt beside the furniture
in clear space, checks the full motion envelope against geometry, and confirms
sight from both the entrance and photo approach. Existing furniture remains
intact. A blue light and directional hum help locate it. Photograph it
within 4.5 metres, then survive the full visit
to bank one charge. Repeated pictures do not award more, and an early exit or
death does not bank the bounty. The source floor's evidence is unchanged.

While searching inside the visit, the top-centre instrument reads **FLASH 14m**
(with the live distance) in place of the source-floor lift and evidence. Like
those instruments, it measures horizontal straight-line metres through walls,
without an arrow or walking-route guidance. It hides during camera use and quit
confirmation, disappears after photographing the bolt, and restores the normal
floor objectives on return. A recording's room-count timer stays frozen while
visiting.

The stored flash automatically burns **only the particular attacker making a
fatal catch**. It does not kill other figures, grant invulnerability, refund the
normal torch, or protect against the separate blackout-ambush rule. The player
continues in place. The top-right lightning icon beside the battery is filled
while holding a flash and an outline when empty. **SAVED BY THE FLASH** takes
priority over ordinary hints for three seconds. The album retains the bounty
photograph and records whether its flash is ready, spent, or lost. A maximum of
one charge is held; it persists with normal checkpoints and clears for a new
run. The quick-test CLI start does not write the normal checkpoint.

The default final 2.5 seconds use a separate **wireframe / voxel** treatment:
solid surfaces drain into tiny electric-blue and violet characters, retaining
the actual shape of the room and its objects. Bright rows of code trace its
structure while illumination travels down dense columns across the surfaces.
Cells disappear from top to bottom and hollow 3D glyph-edged cubes fall
in narrow streams, shrink, and vanish. Glyphs are fixed per world cell, with
smoothly travelling illumination rather than rapidly randomized text.
The 0.45-metre lattice is anchored in
world space; turning the camera does not slide it across the room. A low digital
hum and erasure noise accompany the transition. No green palette, vortex, dust,
or fracture particles are used in this version. The default wireframe collapse
lasts 2.5 seconds; attacker motion stops 0.75 seconds into it, when the solid
picture disappears. Collision stays intact.

All surfaces and former structural gridlines are drawn from tiny blue and violet
code glyphs. Surface glyph spacing is 0.1125 metres, with brighter rows every
0.45 metres. Hollow cube edges are made from glyphs spaced 0.05625 metres apart.
There are no continuous wire lines underneath either effect.

The previous fracture-and-particle version is preserved in its original effect
and shaders. Add **`--realm-collapse=fracture`** to the play command to compare it;
`--realm-collapse=wireframe` explicitly selects the new default. The style flag
only selects the presentation style. The older version retains its cyan-violet
fractures, 160 surface chips, up to 3,840 sparks and 480 dust wisps, structural
audio, and protection during the last 1.2 seconds.

On a completed wireframe visit, the retained source room **reconstructs in
reverse over 1.3 seconds**: scattered cubes rise into place, its wireframe and
code traces reconnect, then its solid surfaces return. The source is reattached
behind opaque black; its own effect starts fully dissolved before the fade
opens, preventing an ordinary-room flash between the two animations. Player
actions, source rules, and events stay suspended until reconstruction completes.
Caught failures and early quits skip reconstruction. The shelved fracture version keeps
its short return fade.

Both versions honor reduced flashing, pause with the encounter, and clean up
their effects on return. The collapse returns the player to
a collision-checked position in front of the entrance. The foreign view and all
visiting attackers disappear; the doorway now opens into an ordinary casino
room. The original photographic shortcut remains open. Five seconds of ordinary
arrival grace give the player time to look at the room.

The source floor's scene, route, run object, lift/tape state and evidence remain
intact. Its scene is detached during the visit, and its normal rules and blackout
clock are suspended. The next realm is streamed separately. Healthy charging
pods work during the visit with the ordinary **E** connection, partial charging,
and **E/F** disconnection. Any charge gained is retained when returning, and
world transitions disconnect the pod immediately. Preview pods, lifts, and
tapes remain inactive. The visit cannot advance the campaign. Pause,
album browsing, and the quit confirmation freeze the encounter. Cancelling quit
does not reactivate the source floor's rules while the player is still away.

Photos taken inside are real images saved to the current session's album, labelled
with the actual destination realm. Visiting supplies no future-floor evidence
credit. CLI sessions never write the normal checkpoint or on-disk album.

The debug command still jumps directly to the first doorway. Restart that
command for another isolated attempt. Ordinary New Game and Continue use the
same controller with normal entrance placement and persistence. The reward bolt
uses its existing procedural VFX mesh, placed beside furniture or in clear floor
space when the realm has no suitable furnishing.

## Checks

Campaign coverage:

```sh
godot --headless --path . --log-file /tmp/realm-generation.log --script tools/audit_realm_generation.gd -- --seed=21 --states=7
godot --headless --path . --log-file /tmp/realm-campaign.log --script tools/audit_realm_campaign.gd -- --mode=descent --nologo --seed=21
godot --headless --path . --log-file /tmp/realm-destinations.log --script tools/audit_realm_destinations.gd -- --seed=21
godot --headless --path . --log-file /tmp/realm-persistence.log --script tools/audit_realm_visit_progress.gd
godot --headless --path . --log-file /tmp/discovery-hold.log --script tools/audit_discovery_spawn_hold.gd
godot --path . --audio-driver Dummy --log-file /tmp/discovery-capture.log --script tools/capture_realm_discovery.gd -- --mode=descent --nologo --seed=21 --descent-floor=2
godot --path . --audio-driver Dummy --log-file /tmp/realm-profile.log --script tools/profile_realm_preview.gd -- --mode=descent --nologo --seed=21 --descent-floor=2 --chunktime
```

Add `--descent-floor=N` to the campaign audit for another source floor.
Generation checks count all entrances, prove early route placement and clear
approaches through every generated blackout state. The campaign audit checks
normal creation, real streaming, entry, reward, return, checkpoint persistence,
next-floor creation, visible discovery pulses and title cleanup. The discovery
hold audit checks continued pursuit by an existing figure, blocked fresh spawns,
timer resumption and return cleanup. The rendered capture checks the clue from
the actual incoming doorway and writes images to `/tmp/liminal-realm-discovery`.
Destination checks include supported
landings, reachable rewards and their visibility ahead of the arrival view.

Existing presentation and combat regression checks:

```sh
godot --path . --audio-driver Dummy --log-file /tmp/flash-engine.log --script tools/audit_emergency_flash.gd -- --realm-visit --seed=21
godot --headless --path . --log-file /tmp/flash-loss-engine.log --script tools/audit_realm_bounty_loss.gd -- --realm-visit --seed=21
godot --headless --path . --log-file /tmp/flash-progress-engine.log --script tools/audit_emergency_flash_progress.gd
godot --headless --path . --log-file /tmp/realm-audit-engine.log --script tools/audit_realm_excursion.gd -- --realm-visit --seed=21
godot --headless --path . --log-file /tmp/realm-caught-engine.log --script tools/audit_realm_excursion.gd -- --realm-visit --seed=21 --realm-test-caught
godot --headless --path . --log-file /tmp/realm-entry-engine.log --script tools/audit_realm_entry.gd -- --realm-visit --seed=21
godot --headless --path . --log-file /tmp/realm-collapse-engine.log --script tools/audit_realm_collapse.gd -- --realm-visit --seed=21
godot --path . --audio-driver Dummy --log-file /tmp/realm-wireframe-engine.log --script tools/audit_realm_wireframe.gd -- --realm-visit --seed=21
godot --headless --path . --log-file /tmp/realm-reassembly-engine.log --script tools/audit_realm_reassembly.gd -- --realm-visit --seed=21
godot --headless --path . --log-file /tmp/realm-charging-engine.log --script tools/audit_realm_charging.gd -- --realm-visit --seed=21
godot --path . --audio-driver Dummy --log-file /tmp/realm-collapse-capture-engine.log --script tools/capture_realm_collapse.gd -- --realm-visit --seed=21
godot --path . --audio-driver Dummy --log-file /tmp/realm-wireframe-capture-engine.log --script tools/capture_realm_wireframe.gd -- --realm-visit --seed=21
godot --path . --audio-driver Dummy --log-file /tmp/realm-capture-engine.log --script tools/capture_realm_excursion.gd -- --realm-visit --seed=21
```

The lifecycle audit checks the physical threshold trigger, destination support,
timer, escalating spawns, pause/quit holds, unchanged source objectives/evidence,
safe return, cleanup, and the nonfatal one-shot caught branch. Automated survival checks
isolate attacker movement; they verify lifecycle correctness, not combat balance.
The rendered capture uses the real shutter, checks destination album metadata,
and writes eight images to `/tmp/liminal-realm-visit`.
The emergency-flash audit photographs the generated bounty, checks occlusion
and duplicate capture, banks it on return, then tests the exact catching figure
with a second figure nearby. It verifies icon states, message visibility over
multiple frames, album state, checkpoint consumption, and lack of invulnerability
or torch refund. Its screenshots are in `/tmp/liminal-emergency-flash`.
Add `--realm-close-entry` to the capture arguments to photograph from 0.8m
and walk through using the actual player movement controller. The entry audit
also checks 0.6m, 1m, 2m and 5.8m framing and rejection through walls.
The original collapse audit explicitly selects the preserved fracture version.
It checks fragment bounds, camera-independent motion, complete
fragment disappearance, shader state, reduced flashing, the real quit-dialog
hold, bounded particle allocation, terminal protection, and cleanup. The charging
audit uses a generated mall pod and the player's real focus/E path to check
charging, disconnection, retained charge, and unchanged source progression.
The rendered collapse capture writes the effect's
stages, reduced-flashing variant, VHS composite, and return to
`/tmp/liminal-realm-collapse`.
The separate wireframe audit checks style selection, bounded unique surface
voxels, the wireframe-before-cubes sequence, reduced flashing, pause, protection,
and source restoration. Its capture writes wireframe stages and VHS comparisons
to `/tmp/liminal-realm-wireframe`.
The reassembly audit checks the opaque handoff, decreasing reverse progress,
source collision, held controls/rules/events, tree pause, and final cleanup.
The wireframe capture also follows the real return tween through cubes,
wireframe, solidifying surfaces, and the fully restored source room.

Judge the encounter by whether the foreign room is recognisable before crossing,
the pressure is exciting rather than unfair, and returning to the ordinary room
is unsettling. The 30-second duration and enemy spacing are initial tuning.
