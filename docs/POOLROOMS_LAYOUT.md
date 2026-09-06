# Poolrooms layout and equipment

Pool geometry is sized against its actual water footprint, independently of the
12-metre building grid. Small basins and narrow channels stay open; larger pools
can carry a perimeter support without closing their central crossing lanes.

## Spatial rules

- No water columns below 36 m² or a 6 m short dimension. Channels and walk-in
  stair pools never receive columns. Other compact pools have at most one;
  extended pools above 70 m² have at most two.
- Supports leave at least 0.90 m of water beside the shore, 1.40 m between
  columns, and a 1.60 m crossing along both basin centre axes. Door approaches,
  pool ladders and equipment landing areas are reserved before placement.
- Pier islands are occasional larger-pool features. Their full radius is
  included in the placement budget instead of being added after the column.
- Every wet cell retains its guaranteed exit ladder. Stair pools additionally
  have a 2.20 m wide seven-tread entry, with a matching smooth walking collider.
- Slide basins reserve a 3.85 m staging deck beside a solid wall. Water size
  is preserved and the opposite deck remains at least 1.55 m wide. Connected
  basins shift only perpendicular to their links, keeping the channel opening
  fully submerged. Doorways, exit ladders and rounded tiled corners stay clear.
- Basin/channel joints use one sampled boundary for the deck mesh, convex
  collision, water footprint and coping. Each chunk owns half of the same
  curve. Bend length grows with the width change, maintaining enough radius
  for the coping profile; small offsets are joined as well. Ordinary rounded
  coping corners also have matching tiled fill and solid collision beneath.
- Hot-tub climb strips extend above the deck by the player’s ladder-probe
  height, so forward movement clears the rim and releases onto dry tile.

## Blender equipment

| Prop | Triangles | Meshes / surfaces | Approximate dimensions (W × H × D) |
|---|---:|---:|---|
| White diving board | 784 | 1 / 3 | 0.56 × 0.53 × 2.40 m |
| Blue straight slide | 1,732 | 1 / 3 | 1.10 × 2.32 × 3.00 m |
| Blue spiral slide | 3,068 | 1 / 3 | 3.57 × 3.45 × 3.06 m |

Editable sources live in `art/pool_equipment/`; the game uses
`models/authored/pool_equipment/*.glb`. Slides use closed, explicitly sampled
fiberglass shells and low-sided structural tubes. All three source meshes were
checked for nonmanifold edges. Geometry and material resources are shared
between instances; the three GLBs total about 227 KiB.

Equipment intent is selected before room dimensions: 24% straight slide, 16%
spiral, 20% board and 40% empty among owning basin/cistern rooms. Straight-slide
rooms reserve at least 5.35 m ceiling height; spiral rooms become double-height.
Placement still rejects unsafe sites, with a smaller prop as a fallback.

One equipment prop may spawn per owning basin/cistern room. Its footprint,
ladder operating space, ceiling clearance and 1.8 × 2.7 m water landing must
fit. The spiral requires a tall room, including standing headroom at its
2.75 m platform. Room targets, arrivals, portals, channels and stair pools do
not receive equipment. Ordinary pool ladders remain clear.

The runtime uses primitive support collision and shared simplified chute
shapes: 200 triangles for the straight slide and 370 for the spiral, rather
than full render meshes. Forward movement uses the existing climb assist at
slide ladders and the board heel. Stepping into a slide mouth at platform
height starts an automatic ride along its authored chute. The player
accelerates downhill, keeps free mouse look, then coasts off the outlet into
the water. Movement input is ignored during the ride and footstep/bob effects
stop. The guide temporarily excludes its own walking collider, while the
rest of the world remains solid; an obstruction cancels rather than
teleporting the player through it. Pause freezes the ride; teleport, resource
reset, and removal of the slide release it safely. No jump action is needed.
Collision data is explicitly included in both export presets.

## Verification and review

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run_audits.sh -j 3 -f pool_
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/blender/build_pool_equipment.py
/Applications/Godot.app/Contents/MacOS/Godot --path . --minimized \
  --audio-driver Dummy --disable-render-loop --script tools/capture_pool_equipment.gd
```

The layout regression samples 384 rooms across 16 world seeds and explicitly
checks the former two-column 5.16 × 5.08 m basin at world seed 1029384756,
cell (8,-2). The entry audit drives the real player up and down stairs in all
four directions. Equipment audits check imported triangle counts, material
surfaces, supported feet, water landing space and real-player mounting,
climbing, hands-off chute traversal in all four orientations, and water
splashdown. A separate lifecycle audit covers invalid entries, pause/resume,
teleport/reset and unloading. The corner-boundary regression samples both
sides of real connecting curves across eight seeds, independently checking
visible deck triangles, solid collision, water coverage and bend radius.

The 480-candidate placement sample across 12 world seeds contains 182 boards,
205 straight slides and 42 spirals. A separate audit walks the initial Descent
connectivity graph from arrival: all 12 tested base seeds have a slide within
five open-edge hops (regression limit: eight). This measures connected rooms,
not physical walking distance; player movement audits separately check exits,
ladders and chutes. Hot-tub movement covers eight directions in each of three
real room fixtures, including settling back onto the deck.

Native room captures use these fixtures:

| Equipment | World seed | Cell |
|---|---:|---|
| Board | 1029384756 | (-9,4) |
| Straight slide | 1029384756 | (-10,-6) |
| Spiral slide | 1029384756 | (-10,9) |

Captures go to ignored `build/pool-equipment-review/`. The prop review catalog
also includes all three assets, with front/reverse Godot renders alongside
in-room captures in the existing local procedural review gallery.

Close-up corner renders: `tools/capture_pool_corners.gd`, writing to
`build/pool-corner-review/after/`. The east basin/channel fixture at world seed
473692151, cell (-7,1), reproduces both tile spikes highlighted in the review.
