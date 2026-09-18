# Vegas wall finish

Casino rooms and hotel corridors share `shaders/wallpaper.gdshader`, with
three related dye lots per family configured in `scripts/mats.gd`.

- Above the chair rail: faded burgundy/brown paper with matte antique-gold
  botanical damask. The ink, stripes, seams, and stains never drive normals.
  Paper-fibre relief is limited to 0.12 mm.
- Below the rail: 18 cm vertical stained hardwood boards, separate grain
  samples and stain variation per board, satin roughness, and shallow joints
  (0.8 mm). Grain relief is 0.18 mm.
- The grain reuses the user-supplied `textures/annex/half_wall_cap_wood.png`;
  no new art, external licensing, or attribution entry was introduced.
  Its mipmaps are enabled, also improving distance filtering wherever that
  existing texture is reused. The Annex and airport materials are unchanged.
- World-space mapping keeps the finish continuous across streamed chunks.
  Existing physical baseboards, chair rails, crowns, and collision stay intact.

## Verification

The material checks require a real GPU renderer, so they are intentionally
separate from the headless audit runner:

```sh
godot --path . --minimized --audio-driver Dummy --disable-render-loop \
  --log-file /tmp/vegas-wall-finish-audit.log \
  --script tools/audit_vegas_wall_finish.gd

godot --path . --minimized --audio-driver Dummy --disable-render-loop \
  --log-file /tmp/vegas-wall-finish-capture.log \
  --script tools/capture_vegas_wall_finish.gd -- --out-dir=/tmp/vegas-wall-finish

tools/run_audits.sh --no-import -j 2 -f casino
```

The GPU audit compares all six variants against flat-paper normal references,
checks that timber still has measurable shallow relief, and verifies the
supplied wood texture and mipmaps. Captures include all six dye lots and a
close view of the wood/paper transition.
