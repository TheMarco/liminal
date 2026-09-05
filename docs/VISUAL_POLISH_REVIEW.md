# Visual polish review — September 5, 2026

This pass improves texture stability, four existing fixtures, and UI readability. The established lighting, subtle surface wear, room density, VHS treatment, and approved ghosts remain the visual reference.

## Changes

- Enabled mipmap generation for 219 existing textures used by 3D surfaces and props. Their materials already requested mipmapped filtering, but the imported textures lacked the smaller image levels. Original pixels, source resolution, compression, and color-space settings are unchanged. Ghost and UI textures were excluded.
- Airport gate desks: monitor stands, charcoal bezels and separate dark screens; ceiling-aware sign height fixes inverted suspension rods in low rooms. Four additional meshes per desk.
- Asylum equipment cart: cylindrical wheels, controls contained on the fascia, and an original printed analog dial. One additional mesh per cart.
- School servery: thin stainless supports connect the glass guard to its counter. Four additional meshes per servery.
- Prison showers: round pipes and shower heads at human height in tall rooms. Mesh count is unchanged.
- Saved-run title actions now occupy two rows. Results use the game's VHS font, wrap within safe margins, and resize with the viewport. Replay skip controls and camera reticles scale with the HUD. Nearby interaction prompts temporarily replace the startup controls strip. Instructions now describe running in Descent and the camera controls correctly.

## Coverage

Reviewed source construction and representative GPU captures of 86 room styles across all eleven worlds, using seed 240721. The capture tool writes both the production VHS view and clean views facing two directions. This samples every style found by the tool; it is not an exhaustive review of every procedural room or seed.

| World | Review result |
| --- | --- |
| Casino | Preserve warm lighting, carpet detail and decorative density; shared prop texture filtering improved. |
| Office | Preserve empty corridors and institutional furniture; shared prop texture filtering improved. |
| Annex | Preserve sparse concrete spaces and long sightlines; concrete texture filtering improved. |
| Airport | Improve gate fixtures and sign suspension; retain existing wayfinding and lighting. |
| Asylum | Improve cart construction and meter detail; preserve dark rooms and restrained wear. |
| School | Ground the glass guard with visible supports; retain existing room furnishings. |
| Mall | Preserve storefront emptiness and polished floors; masonry and prop texture filtering improved. |
| Prison | Correct plumbing shape and head height; preserve tile, iron and existing stains. |
| Poolrooms | Preserve the bright tiled atmosphere; mineral textures gain mipmaps. |
| Data Center | Preserve equipment silhouettes, cold lighting and cable detail; no model redesign. |
| Bloom | Preserve organic silhouettes and dark industrial contrast; organic texture filtering improved. |

## Validation and limits

- Godot 4.6.1, Apple M3 Max, Metal Forward+ for GPU captures.
- Verified actual mip chains on all 220 affected imported textures, including the new dial. Aggregate decoded mip data adds approximately 236.5 MiB across the complete texture set; this is not a measurement of additional resident memory on an individual floor. No FPS improvement is claimed from this visual pass.
- Compared 282 paired before/after room builds across three seeds and four affected worlds: collision shapes, transforms, layers, masks, interactions and semantic metadata matched.
- Reviewed a 522-chunk structural snapshot across three seeds and eleven worlds. Exactly eight entries changed, confined to the four intended fixture families. The original builders reproduce the previous snapshot. Node-level comparison confirms only the intended visual geometry, materials and sign transforms changed.
- The new UI layout audit checks six live resize states, including 4K, portrait and 4:3, and all seven saved-run actions. GPU captures also cover title reference pages, results, interaction prompts and camera reticles.
- The equipment-cart preview rendered and exited successfully on final retest. One earlier diagnostic preview crashed during shutdown after saving its image; the cause was not established. The complete room-capture helper reports seven texture RID allocations at shutdown; no script error was observed during that sweep.
- Windows GPU appearance and performance were not tested in this pass. Existing release archives predate these source changes.

All 62 existing audits completed with passing status, including the refreshed world snapshot; compilation and the generation-performance gate also passed. The new UI audit passed separately and through the final runner, for 63 passing audits in total. Adding the UI entry while the original shell process was running disrupted its final summary after the tests completed; the per-audit statuses were verified, shell syntax checked, and the updated runner completed successfully with the UI filter.

## Options for a future discussion

These are proposals, not implemented changes:

1. Model a shallow ceiling plenum behind selected missing panels, so openings have actual depth. This needs careful lighting and visibility checks.
2. Author a small family of period-specific filing cabinets, medical carts and security terminals where players can approach closely. Establish one approved example before replacing assets throughout the game.
3. Add shallow exterior jetway geometry to selected airport windows, preserving the ambiguous darkness beyond them.
4. Evaluate carpet micro-highlights in motion before adjusting roughness. A still image is insufficient to judge shimmer against the VHS treatment.

## Reproducing the review

Run the normal regression suite with `tools/run_audits.sh`. The added UI check also runs in CI.

For GPU screenshots, run:

```sh
godot --path . --minimized --audio-driver Dummy --disable-render-loop \
  --log-file /tmp/liminal-visual-review.log \
  --script tools/capture_visual_review.gd -- --nologo --mode=wander \
  --review-out=/tmp/liminal-visual-review
```

Local review evidence is retained under ignored `build/visual-review/`: world contact sheets, fixture comparisons, UI captures, manifests and validation logs. The captures are diagnostic evidence, not release assets.
