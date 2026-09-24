# Prepared supernatural doorways

The gameplay effect now starts from an **originally solid wall**. Procedural
generation reserves an optional passage on both sides, builds the native
doorway and a native full-wall version of the same edge, and leaves the full
wall visible and collidable. The selected visual treatment is wall deformation
with a soft local blur; gameplay does not enable the prototype's particles,
smoke or glow. F6 in `--doorway` mode triggers a nearby prepared solid wall.

The opening takes 0.9 seconds, remains open for at least 5.5 seconds, and
closes in 0.9 seconds once the player and other encounters are clear. Its
moving collider follows the contour. The route resolver sees the original
wall until the aperture is fully usable, then sees the opening; restoration
reverses that change. An existing alternative route is required so closure
cannot strand the player. Interruption preserves an already open passage or
restores the original wall before it opens. Open/closed state survives chunk
streaming and is included in Descent's runtime-state snapshot.

Seed-stable candidates are limited to ordinary solid boundaries with matching
floor and ceiling heights. Poolrooms use only dry-to-dry edges; Airport
terminal corridors and elevator cells are excluded. Existing photographic
doors, mutable reality edges, and authored signed openings are not borrowed.
All structurally safe edges are prepared; spatial availability is separate
from event frequency. The shared architectural event manager waits 12–18
exploration seconds before its first doorway opportunity, then polls visible
prepared walls every half-second after its quiet gap. It waits 30–45 seconds
after each completed reveal, with at most six reveals per Descent floor. The doorway
director never reuses the same site on a floor and still respects the shared
visual pacing where enabled. It additionally checks both resident chunks, the player's
view with a collision ray to the hidden wall, and furnishing clearance. A
quiet area can therefore go longer without an event; no effect is forced onto
an unsafe wall. This does not mean every
possible procedural seed has been visually inspected.

## Manual check

From the repository root:

```sh
godot --path . -- --nologo --level=1 --seed=20260807 --pos=-138,-28.8772 --yaw=-90 --doorway
```

Face the solid wall ahead and press F6. It should develop a blurred, irregular
opening, settle into an ordinary cased doorway, then eventually become the
same wall again. You can walk through it while open; it waits for you to clear
the opening before closing. `--doorway` is a manual trigger and does not alter
saved settings. It owns F6 across level changes, so the breathing-preview
handler cannot consume it. Without it, the encounter is quiet and paced
automatically. F6 only triggers when a prepared solid wall is in view; other
walls report that no prepared wall is nearby.

For a direct School check with the same seed:

```sh
godot --path . -- --nologo --level=6 --seed=20260807 --pos=-210.3284,-174 --yaw=180 --doorway
```

Wait for nearby rooms to finish streaming, then face the wall ahead and press
F6 (Fn+F6 on keyboards that require it).

## Focused checks

```sh
godot --headless --path . --script tools/audit_native_doorway_runtime.gd
godot --headless --path . --script tools/audit_native_doorway_themes.gd
godot --headless --path . --script tools/audit_native_doorway_live.gd -- --nologo --level=1 --doorway
godot --headless --path . --script tools/audit_native_doorway_live.gd -- --nologo --level=1 --switch-to-school --doorway
godot --headless --path . --script tools/audit_native_doorway_live.gd -- --nologo --level=1 --switch-to-school --auto-doorway
```

The Office audit checks the hidden wall, traversal collision, route overlay,
closure and interruption. The theme audit samples one originally solid edge
in each of the 11 playable themes and reports near-arrival site density for
the selected seed. The live audit boots the streamed game and exercises both
the F6 input path and, with `--auto-doorway`, the shared manager and real
doorway safety gate.
A rendered `--capture` on the theme or live audit writes comparison frames
under `/tmp/liminal-native-doorway-*`.

The old isolated comparison remains available through
`tools/preview_native_doorway.gd` (F6 replay, B blur toggle, M old full-magic
comparison). It is not the gameplay scene.
