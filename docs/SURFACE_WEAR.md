# Subtle surface wear

The wear pass keeps each level lightly aged and intact. Most of a room's finish
remains visible. Marks follow physical contact, plumbing, fixtures, or existing
damage, with occasional maintenance traces and small lifted edges.

`scripts/surface_wear.gd` runs once after geometry and furniture placement, before
anomalies activate. It creates no colliders, lights, navigation, labels, or
interactions. Surface patches attach to their supporting mesh, and prop wear
uses the original model triangles. Moving or rotating a furnishing carries its
wear with it.

## Level treatments

| Level | Treatment |
| --- | --- |
| Casino / hotel | Soft carpet traffic, sparse drinks and cigarette marks, rubbed furniture and brass, fixture smoke, rare old leaks and lifted wallpaper. |
| Mall | Former kiosk footprints and bolts, faded lettering adhesive, shutter dust, food-area spills, planter/fountain minerals, repaired ceiling leaks. |
| Office | Chair caster wear, occasional coffee marks, wall repaint and notice ghosts, replacement carpet squares, localized air-conditioner runoff. |
| Airport | Low luggage rubs, carousel and seat wear, travelator entrance-plate polish, glass wipe marks, floor-sign adhesive, occasional glazing seep. |
| School | Threshold shoe marks, desk and locker contact wear, poster/tape ghosts, plumbing deposits, gym varnish and court-marking wear. |
| Prison | Light salt deposits, small paint chips, bars and door contact wear, threshold marks, localized shower/toilet minerals and runoff. |
| Asylum | A reduced-strength addition to the existing decay: scrubbed patches, sparse mortar exposure, trolley/bed wear, plumbing grout and runoff. |
| Poolrooms | Subtle waterlines and splash residue, rare missing mosaic, mismatched replacement tiles, ladder-anchor rust. Existing mineral atlases remain the base. |
| Annex | Connected ceiling/wall/carpet damp, mold at seams, occasional small paper edges, rare sections of skirting bowed by a few millimetres. |
| Data Center | Grille and base dust, cleaned handles and label residue, cooling-pad deposits, hairline joint/mount cracks, small cable-entry repairs. |
| Upside Down / Bloom | Fine cracks and damp halos at actual root contacts, sparse lifted paint/plaster, fallen-plaster residue, old flood lines and dried deposits. |

## Restraint and placement

- District age is seeded at 0.16, 0.22, or 0.28. The asylum receives a further
  reduction because its base materials already carry decay.
- Surface tint strength never exceeds 0.36; prop tint never exceeds 0.28.
  Shader masks reduce the effective opacity further. Missing tiles are opaque
  mortar replacements, confined to a small, rare patch aligned to the tile grid.
- At most 20 patches and 24 prop-mesh overlays are generated per chunk. Ordinary
  rooms use fewer. Only three fixture-floor groups may be placed.
- At most one small lifted finish occurs per chunk, and its mesh projects less
  than 8 mm from its patch. Most chunks have none.
- Doorway marks use the current resolved openings. Luggage rubs exclude high
  lintels. Cooling deposits can attach to the actual equipment pad. Emissive
  model surfaces and gameplay objects are excluded from prop overlays.
- Seeds depend on physical positions and the district, not instance IDs or time.
  Wear is stable across streaming and revisits.

## Verification

Run the deterministic contract and produce a coverage report:

```sh
godot --headless --path . --log-file /tmp/liminal-wear-audit.log \
  --script tools/audit_surface_wear.gd -- --out=/tmp/liminal-wear-coverage.json
```

The audit checks three seeds, every discovered room style, additional wet-fixture
rooms, and extra Annex examples. It compares decorated rooms with clean rooms
for identical collider graphs and gameplay object counts; checks repeated builds,
surface bounds, strengths, budgets, and required per-level causes/prop kinds.
The headless renderer discards instance-uniform values, so this audit uses the
applied configuration; graphical captures separately check actual GPU readback.

Inspect a real generated mark with the level's lighting:

```sh
godot --path . --script tools/capture_surface_wear.gd -- \
  --theme=2 --cause=annex_connected_moisture_wall --out=/tmp/annex-wear.png
```

Use `--clean` for the same camera with the pass disabled. `--support-only` is a
diagnostic view for checking tile alignment; it is not a gameplay screenshot.
Full game captures should also be reviewed through the VHS filter to judge the
room's overall atmosphere. `tools/run_audits.sh` includes the wear contract and
the existing gameplay, room, rendering-contract, and world-snapshot gates.
