# Airport baggage carousel

Original low-poly Blender model based on the supplied oval conveyor reference.
The 3.01 × 7.00m capsule has a 0.665m belt deck and leaves 2.5m end aisles in
the smallest 12m baggage rooms. Doorway approach areas reserve 2.2m in these
rooms to support circulation around the full-size conveyor. It has a
continuous stainless skirt and island, sloped feed hood and rubber curtains,
yellow/black number pylon, warning beacon, and two-post arrivals screen.
The screen and posts face +X along the long side, following the user's correction.

3,524 triangles, three meshes/surfaces, embedded 1K PBR atlas and printed graphics.
The belt is one UV-unwrapped strip with an inexpensive animated rubber shader.
Luggage follows a closed racetrack through `airport_carousel_motion.gd`; the
oval shell stays still. Belt and luggage share the same metres-per-second speed.
Three to five normally sized suitcases populate the larger circuit. The monitor,
number pylon and feed hood retain their dimensions and move with their mounts.
Stopped variants remain stopped. Six simple grouped colliders cover the deck
and tall fixtures; the physical pylon and dynamic number cull with the carousel.

Source: `art/airport_carousel/airport_carousel.blend`, packed textures and two
studio renders. Rebuild labels with `python3 tools/blender/draw_hero_labels.py`,
then run Blender in background with `tools/blender/build_airport_carousel.py`.
Validate with `tools/audit_authored_hero_meshes.py`, `audit_authored_hero_props.gd`
and `audit_airport_luggage.gd`. No third-party mesh or photograph pixels embedded.
