# Poolrooms water pass

The previous surface mixed the opaque screen image into lit albedo and then alpha-blended it again. High opacity and strong normals made pools cloudy and mottled. Poolrooms also had no local reflection probes, despite the water shader's old comment.

The revised surface transmits the already-lit scene once, with distance-based RGB absorption, teal depth scattering, gentler world-space normals and view-aligned refraction. Foreground-depth rejection and screen-edge/contact fades protect coping and pillars from refraction smearing. The mean water level, footprints, collision and caustics are unchanged. The Mall's original shader is retained separately as `fountain_water.gdshader`.

Wet room anchors and jacuzzi-containing dry anchors receive one static box-projected probe. It affects only the dedicated water layer, excludes water and photo-only/print-only content from captures, waits for the surrounding chunks, and disables processing after setup. Blackout suppresses cached bright reflections; initially blacked-out rooms wait until the lights return. Capture origins are offset above a quarter of the basin to avoid the usual central pillar.

## Review and validation

- `build/water-review/index.html`: interactive before/after comparison.
- Real seed 240721 geometry and production lighting: basin, channel, stair-basin and cistern; poolside and low cameras; lights on and blackout (16 pairs).
- Baseline uses a fresh material and the original shader body retained in `fountain_water.gdshader`, with new water probes removed. A source snapshot also lives in the ignored `build/water-review/source-before` directory.
- All 10 existing Poolrooms audits passed. The new water audit covers surface ownership, single-probe allocation, masks, blackouts, deferred capture and idle processing.
- An actual game launch with normal streaming and VHS post-processing also completed its screenshot smoke check.
- GPU captures compiled both shaders without shader/script errors. After settling, corresponding scenes had identical draw-call and object counts. This is not an FPS benchmark.
- Static reflections allocate Godot's reflection atlas: isolated capture-process VRAM rose from about 678–681 MiB to 1052–1054 MiB. The atlas is shared with the game's other reflective levels. Captures incur work when rooms first become ready, not six extra scene renders every frame.
- The GPU diagnostic reports seven Texture RID warnings on shutdown with reflection probes enabled; headless lifecycle audit exits without ObjectDB leaks. Runtime memory across repeated level switches has not been benchmarked in this pass.

Static cubemaps approximate parallax and do not reflect moving ghosts or every lamp flicker live. No dynamic planar reflection viewport was added.

## Darker teal revision

The first clear-water pass was too transparent for the intended atmosphere. Following the supplied pool reference, absorption distance is now 1.45 m (previously 5 m), haze spans 0.12–0.56 (previously 0.015–0.23), and scattering colours are darker teal. Red attenuates fastest while green/blue remain balanced. This subdues submerged tile and deepens the water without changing the ripple, reflection or refraction implementation. It adds no geometry, textures or rendering passes. The earlier clear captures are preserved in `build/water-review/clear-pass/`; the gallery now shows this darker revision as After.

## Residual ripple revision

The darker teal treatment is retained. Two crossing wave trains now produce a bounded 12 mm swell with matching analytical surface normals, overlaid with stronger, slightly faster fine ripples. Wave phase comes from world coordinates so adjoining surfaces share the same motion; 3 cm of culling margin includes the crests. No new mesh subdivisions, normal textures, lights, or rendering passes are added.

`capture_pool_water.gd --motion --filter=91` adds an eight-second, 30 fps fixed-camera sequence. Only the diagnostic shader receives an explicit clock so recording speed cannot accelerate the water. The comparison page includes the encoded motion preview.

Residual-motion validation: all four pool layouts were rendered from both camera heights in lights-on and blackout states; the focused water audit passed. The preview was encoded as a 1280 × 720 H.264 MP4, verified at 8 seconds, and a frame was decoded to check orientation and image integrity.

## Player interaction

`Player` now owns a Poolrooms-only water interaction controller. A surface group registers both basin and spa meshes; transformed plane bounds provide the actual water height, and a short physics ray rejects solid coping, rounded corners and piers at that height. The same contact drives water audio, including the raised spa surface. The existing chest-depth speed/drag thresholds remain in place. There is no new jump binding: dropping off a deck triggers the entry splash.

Entry produces an impact-scaled wave packet, a short broken translucent water film and fine ballistic spray carrying some forward momentum. Wading emits alternating disturbances by distance travelled, plus a bow ripple that responds to speed and immersion. Overlapping packets bend the existing reflections and refraction; a little locally lit froth disappears quickly. The underlying dark teal absorption and residual ripple settings are unchanged.

Effects are bounded to 12 wave packets lasting 2.8 seconds, 96 reusable droplets and three reusable splash films. Only nearby disturbed surfaces receive private materials; idle surfaces use the original shared material with zero interaction events. Teleports, floor changes and camera-owned movement resets clear contact history and bursts. Streamed-out surfaces are handled without holding scene geometry alive. Splash materials draw after the screen-composited water while retaining depth tests against the room.

Validation: all 12 Poolrooms audits pass. The interaction audit covers transformed/raised footprints, solid islands, entry and wading, stationary/teleport suppression, bounded storage, natural decay, private-material restoration, stream-out, and the actual Player's teleport/floor-change hooks. Deterministic eight-second captures drive the real Player on physics ticks through entry, wading, turning and stopping; first-person, poolside and blackout views were inspected. `build/water-review/player-water-effects.mp4` and `player-water-effects-poolside.mp4` are 1280 × 720, 30 fps previews.

The capture's optional `--measure` switches disturbances on/off at an identical camera and frozen water phase. This Metal backend returned zero for every viewport GPU timing sample, so no quantitative FPS or GPU-cost claim is made. The captured walking sequence used one disturbed surface, reached the 12-event cap and returned to zero events/private materials after stopping. The existing seven Texture RID shutdown warnings remain in GPU diagnostics; the focused headless lifecycle audit exits cleanly. Only Poolrooms rows were refreshed in the structural golden file; unrelated ongoing model edits affect other themes.
