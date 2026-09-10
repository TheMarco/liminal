# VT100-style terminal and keyboard

Original low-poly Blender meshes modeled after the supplied vintage terminal reference.
The cream enclosure is hollow at the front. Its deep offset black bezel leaves a wide
right fascia with an original fictional facility badge. Rear ports, ventilation,
plastic grain, inspection markings and key legends use one shared 1024px atlas.
Plain plastic faces use consistent physical UV density and padded atlas regions
to prevent texture bleeding on thin bevels in Godot's mipmapped renderer.

`vt100_monitor.glb` contains `VT100_MoldedHousing` and the separate `CRTScreen`.
The screen is a smooth convex 16×12 grid with ordinary 0–1 UVs. Exported glTF UVs
run U left-to-right and V top-to-bottom (Blender flips V during glTF export).
Replace its material
with the game's live CRT shader; do not place an opaque housing box in the opening.
Front is Godot +Z. Origin is the bottom of the monitor on its tabletop, y=0.
Screen center: (-0.055, 0.18, 0.211); visible size: 0.30 × 0.225 m.
Glass front z=0.218, bezel lip z=0.230. Place in-game readout at z≈0.220.

`vt100_keyboard.glb` is a separate matching wedge keyboard. Origin is its tabletop
floor, +Z toward the operator, width 0.52m, depth 0.21m. No letters are mesh geometry.
The preview places this keyboard forward of the monitor; GLB transforms stay at origin.

Rebuild: `/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/build_vt100.py`
Source atlas and editable scene: `art/vt100/`. Exact counts: `mesh_stats.json`.
