# Rendering performance audit — September 5, 2026

The strongest opportunities are cheaper room construction, selective wall occlusion, and eliminating repeated calculations. Preserve the approved lighting, reflections, fog, surface wear, VHS treatment, geometry and layered ghosts. The original measurements below were collected before implementation. The implemented changes and their validation are recorded first; graphics quality settings and approved artwork remain unchanged.


## Implemented performance pass

- **Wear:** reuse exact transformed bounds, mesh size keys, fixture priorities and deterministic hashes within a build. Keep both allocation sorts and their tie ordering, every selected overlay, placement and strength.
- **Shared resources:** bounded exact-input caches for Pool corner/opening meshes and Mall fountain discs; shared Pool buoy materials/jacuzzi planes, Mall sign materials, Annex wear quads, Data Center tendril cylinders and Bloom hoops/spore quads. No tessellation or material settings were reduced.
- **Streaming:** prepare complete chunks off-tree in the original eight-stage order, using a **soft** 3 ms work allowance between stages. A single indivisible prop/wear stage can exceed that allowance; this is not a hard 3 ms cap. Keep the safe synchronous 3×3 arrival and urgent collision/interactive lift builds. Cancel obsolete work on travel, blackout, topology and discrete run-state changes. Preserve atomic mutation swaps and durable interaction state.
- **Preparation and visibility:** one background resource request at a time, a floor-specific manifest, and at most 64 strong prefetch references. Consume requests only after they finish. Velocity predicts up to one cell ahead; required room anchors remain visible/resident while their member cells are in view. Desired sets update on cell/focus changes. The base 5×5 horizon is preserved; this reduces late construction and furniture pop-in but does not eliminate the outer visibility boundary in long corridors.
- **Occlusion:** enable only in the Data Center. Register known opaque box wall segments and tunnel shell sides/headers, inset the boxes, and parent them to surviving wall meshes after gameplay cutouts. Openings, glass, bars, props and ghosts do not become occluders. Retiring a chunk or replacing it atomically retires its occluders too.
- **VHS:** move the identical nine fixed exposure samples from every fragment to the screen quad's vertices and pass their scalar result with flat interpolation. This uses the current screen copy, adds no render pass and no frame of latency. Also remove the clean CRT sample that the chromatic-aberration branch immediately replaced.
- **Per-frame uploads:** skip only exactly unchanged ghost shader parameters and Bloom fixture light/emission/audio values. RNG, timers, ghost layer history and all animation still advance.

### Measurements after implementation

A fresh paired generation measurement used sequential processes, the same Godot 4.6.1 build, seed 240721, and the same warmed 25-cell sample per floor. All-game threaded loading was removed from this diagnostic to avoid dummy-renderer loading races. Values are synchronous CPU construction time, **not FPS**. One pair is enough to identify the larger changes, not to establish small differences as significant.

| Floor | Mean before → after, ms | p95 before → after, ms |
|---|---:|---:|
| Casino | 3.17 → 3.01 | 4.83 → 4.54 |
| Office | 5.18 → 5.38 | 10.26 → 10.69 |
| Annex | 1.71 → 1.57 | 2.67 → 2.25 |
| Airport | 3.69 → 3.62 | 7.35 → 6.73 |
| Asylum | 3.55 → 3.64 | 4.70 → 4.36 |
| School | 4.48 → 4.33 | 7.72 → 7.06 |
| Mall | 3.39 → 3.16 | 4.90 → 4.64 |
| Prison | 5.05 → 4.32 | 9.46 → 7.66 |
| Poolrooms | 6.77 → 5.70 | 10.17 → 9.09 |
| Data Center | 8.68 → 7.63 | 34.51 → 26.67 |
| Bloom | 6.26 → 6.59 | 7.42 → 7.75 |

The heavy Data Center sample's maximum synchronous build fell from **34.69 to 27.66 ms (20%)**; staging also separates the approximately 15 ms prop phase from the approximately 12 ms wear phase during nonurgent streaming. Poolrooms' average fell about **16%**, Prison's about **14%**. Office, Asylum and Bloom showed small mean increases in this pair; no speedup is claimed for them. Raw paired data: [generation measurement](performance/2026-09-05-generation.json).

The actual production Data Center occluders, with 28 resident chunks and identical geometry/settings, reduced a 240-frame camera sweep from **1,589 to 474 mean draw calls (70%)**, **1.94M to 0.59M submitted primitives**, and **1.73 to 1.15 ms mean viewport renderer CPU time (34%)**. GPU timestamps remained unavailable. These are renderer workload measurements, not a claimed 70% FPS increase. [Raw occlusion measurement](performance/2026-09-05-occlusion.json).

A separate, isolated warm streaming comparison used the same synthetic 60 m out-and-back sprint in the Data Center: the largest `ChunkManager._process` call fell from **37.98 to 16.43 ms (57%)**, and p99 from **9.19 to 6.36 ms**. Work is spread over more updates and upcoming/owning chunks are prepared too: p95 rose from 1.54 to 3.46 ms, mean from 0.414 to 0.470 ms, and final residency from 30 to 37 chunks. This measures streaming CPU work, excludes GPU/player/main-game listener costs, and supports a reduction in large construction spikes rather than a universal frame-rate claim. [Raw streaming measurement](performance/2026-09-05-streaming.json).

Additional exploratory sweeps of structural-wall occlusion covered Casino, Office, Airport, Asylum, School, Mall, Prison and Poolrooms. Most submitted fewer draws, but CPU results ranged from marginal improvements to regressions (for example Office 0.74 → 1.00 ms, Mall 0.74 → 1.14 ms, Poolrooms 0.72 → 1.14 ms). Keep those floors off the default allowlist until an isolated full-frame benchmark establishes a net benefit. Bloom's earlier culling experiment also regressed renderer CPU time.

### Fidelity and regression gates

- **522 generated chunks / three seeds / all eleven themes:** exact generation fingerprint against the fresh pre-change baseline, which also matches the checked-in golden file. Includes geometry, lights, materials, wear, collision and descent variants.
- **VHS GPU readback:** all eight source/exposure/resolution cases are byte-identical on **Metal and Vulkan**. Changing the source between draws also checks that exposure does not lag a frame. Vulkan was tested on this Mac; this is not a Windows hardware benchmark.
- **Occlusion GPU readback:** sixteen paired bright/blackout camera-direction comparisons using both the player view and the photo layer mask. Photos are byte-identical; live views differ by at most one 8-bit channel step. The diagnostic disables TAA only for comparison and settles volumetric-fog history before capture. The workload sweeps retain production TAA/4× MSAA and VHS. The synthetic viewport audit reports the same seven texture RID warnings on renderer shutdown in both the saved pre-change game and the optimized game; functional assertions pass. This is a pre-existing diagnostic shutdown warning, not a clean native-app shutdown test.
- **All 62 headless audits passed**, plus the standalone generation-performance gate. This includes the new resource-cache, floor-preloader and incremental-streaming contracts. Its macOS Bash 3.2 batch accounting was fixed so the suite continues running in parallel after its first batch.

GPU checks are deliberately separate from the headless suite:

```sh
godot --path . --minimized --audio-driver Dummy --disable-render-loop --script tools/audit_vhs_exposure_render.gd
godot --path . --minimized --audio-driver Dummy --disable-render-loop --script tools/audit_occlusion_render.gd -- --nologo --mode=wander
```

### Deliberately not enabled

The detailed hero rack remains 459 source meshes. It has 459 distinct meshes and eight materials, so there is no identical-mesh instancing shortcut. Merging would change the individual wear targets and imported per-mesh LOD/culling behavior; naïvely flattening it after wear adds first-use work without proving a submission win. The current pass instead makes its wear cheaper, separates construction phases and culls it behind actual walls. A future baked batching asset needs a separate geometry/material/LOD/overlay equivalence gate.

A globally wider visible radius and blanket pausing of hidden scripts were also not enabled: the former adds rendering work, while the latter changes audio, RNG and re-entry continuity. No lights, shadows, reflections, fog, particles, texture resolution, MSAA/TAA quality, wear strength or ghost layers were reduced. Windows-native frame-time and full cold-start benchmarks remain external validation work; no new release binaries were produced by this pass.

## Original audit and feasibility measurements

**What was measured.** Godot 4.6.1, Apple M3 Max, Metal Forward+, seed 240721. The existing generation profiler built 25 cells per theme twice, plus one landmark per theme. Separately, the actual game rendered all eleven themes in an always-updated 1280×720 SubViewport, with the current 480-line world scaling, TAA, 4× MSAA and recovered-tape passes. Each theme had 100 settling frames and a 240-frame camera rotation at its arrival position. This is representative sampling of a procedural game, not exhaustive coverage of every seed or room.

The table uses warmed construction timings; first-use timings from the existing profiler are not a production cold-start benchmark because that tool requests all prop preloads and production deliberately does not. Draw counts are the engine's frame totals, including additional render passes, not a count of visible objects. The renderer returned zero GPU timestamps both offscreen and in a separate native-window `--gpu-profile` check. Those readings are unavailable, not zero GPU cost. No FPS improvement or Windows performance is claimed. Audio used the dummy driver in render captures; gameplay mode was Wander, so hostile encounters were inspected in source rather than included in these baseline sweeps.

| Level | Warm build average / p95, ms per cell | Mean / p95 draw calls | Best level-specific targets |
|---|---:|---:|---|
| Casino | 2.91 / 4.34 | 525 / 978 | Prepare first-use slot/table assets before visibility; test opaque-wall occlusion in enclosed gaming rooms; preserve neon, brass, bank lighting and probes. |
| Office | 5.14 / 10.25 | 397 / 516 | Cache workstation wear analysis; reuse fixture assemblies; test occlusion through solid walls. Keep the individual dead/flickering lights. |
| Annex | 1.60 / 2.37 | 180 / 219 | Already the lightest construction sample. Share identical damage-overlay quad resources; improve streaming scheduling. Preserve the special wall-face ownership that fixed seams. |
| Airport | 3.60 / 7.21 | 320 / 430 | Prepare seating/luggage/board resources ahead of first use; cache repeated assembly metadata. Keep travelators, glass, sound and moving parts live. |
| Asylum | 3.50 / 4.58 | 529 / 717 | Prepare first-use medical props; cache their bounds/wear analysis; test room-wall occlusion. |
| School | 4.07 / 6.52 | 640 / 833 | Prepare uncommon classroom/lab/auditorium assets; reuse desk/fixture metadata; test corridor occlusion. |
| Mall | 3.58 / 5.78 | 305 / 346 | Cache painted-sign materials and the identical fountain-disc mesh; prepare first-use shop props. Keep water/reflections and open atrium views. |
| Prison | 5.39 / 9.57 | 573 / 767 | Reuse cell-block fixtures and wear calculations; evaluate small spatial batches for opaque repeated parts. Bars and openings must remain see-through to culling. |
| Poolrooms | 6.72 / 10.05 | 221 / 265 | Cache curved coping, corner and doorway mesh variants; reuse buoy tint materials and jacuzzi water meshes. Address long-sightline streaming. Keep all curves, tessellation, refraction and light shafts. |
| Data Center | 8.88 / 34.36 | 1,180 / 2,156 | Highest construction priority: wear analysis and detailed rack hierarchy. Strongest measured wall-occlusion opportunity. |
| Bloom | 6.08 / 7.06 | 2,536 / 3,158 | Highest sampled draw workload. Investigate shadow-pass geometry submission and repeated growth/fixture resources. Keep pulsation, spores, shadows and material detail; generic occlusion was not a clear win here. |

**1. Make the current wear cheaper to place.** A warmed Data Center sanctum at cell `(2, 0)`, theme 10/style 107, took 37.87 ms: 21.87 ms in surface wear and 15.01 ms in props. This room has 3,341 nodes and 1,343 meshes. The wear pass walks the complete hierarchy, collects transformed bounds, and sorts mesh candidates with bounds calculations inside the comparator. `_prop_overlay()` can revisit the same furnishing on its two allocation passes. The visual limits of 20 patches and 24 treated meshes do not limit the initial discovery work.

Start by computing each candidate's exact sort key once, reusing bounds and ordering within the same build, and caching immutable imported-scene metadata where valid. Keep original traversal/tie order, transform arithmetic, chosen surfaces, seeds, strengths and overlay placement. Do not simply stop scanning at the patch limit: floor stains and other effects use the complete furnishing bounds. Evidence: [surface_wear.gd](/Users/marcovhv/projects/GIT/liminal/scripts/surface_wear.gd:60), [candidate selection](/Users/marcovhv/projects/GIT/liminal/scripts/surface_wear.gd:704).

**2. Use wall occlusion selectively.** The production game has frustum/depth rejection but no authored occluders. A temporary test added slightly inset occlusion boxes to tall, thin, opaque box geometry, without changing meshes, materials or quality settings. A second 240-frame sweep at the same camera position and orientation sequence produced:

| Diagnostic | Data Center before → after | Bloom before → after |
|---|---:|---:|
| Mean draw calls | 1,363 → 418 (−69%) | 2,528 → 2,349 (−7%) |
| Mean submitted primitives | 1.46M → 0.51M (−65%) | 1.49M → 1.31M (−12%) |
| Mean viewport renderer CPU time | 1.67 → 1.11 ms (−34%) | 2.39 → 2.77 ms (+16%) |

These are sequential feasibility measurements, not an isolated GPU/FPS benchmark. Flicker, particles and presentation time continued between sweeps. The inspected Data Center endpoint captures retained the visible geometry, but this is not complete visual equivalence validation. The prototype used 123 occluders in the Data Center and 216 in Bloom; blindly adding many occluders is not justified by these results.

A production version should derive simple occluders from known structural wall segments, respect doorways/glass/bars and scene changes, and retire them atomically with chunks and blackout mutations. Validate both camera views and secondary views such as photos and reflections. Keep lighting contributors and shadow behavior intact. Start with the Data Center and then measure enclosed levels individually. Godot documents both the benefits and CPU overhead of [occlusion culling](https://docs.godotengine.org/en/4.6/tutorials/3d/occlusion_culling.html).

**3. Prepare assets and room work before they become visible.** Production intentionally removed the all-game threaded preload because it could block Windows launch. Cache misses now reach synchronous `load()` inside a synchronous room build. The only theme-specific construction warmups are Annex and Bloom. The one-chunk-per-frame budget limits count, not milliseconds; a 35 ms room still interrupts a frame whose entire 60 FPS budget is 16.7 ms.

Use a bounded, floor-specific preload queue during the title/transition, consume only completed requests, and prepare upcoming room families before travel reveals them. Spread layout/preparation work across available frames; attach scene/physics objects on the main thread with existing arrival safety and mutation transactions preserved. Track first-use pipeline compilations separately from imported asset decoding. Do not restore unrestricted all-game preload or assume constructing and freeing an off-tree chunk warms every GPU pipeline. Evidence: [launch policy](/Users/marcovhv/projects/GIT/liminal/scripts/main.gd:203), [resource loading](/Users/marcovhv/projects/GIT/liminal/scripts/chunk.gd:7335), [theme warmup](/Users/marcovhv/projects/GIT/liminal/scripts/chunk.gd:945). Godot explains its separate [pipeline compilation stages](https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html).

**4. Separate loading priority from the visible horizon.** The 5×5 visible square changes abruptly at cell boundaries. With 12 m cells, its nearest outer boundary is only 24–36 m along an axis; the per-level volumetric fog lengths of roughly 30–62 m do not prove geometry is invisible there. A volumetric fog length is not an opaque clipping distance. The outer retained ring is collision-ready but hidden. Even already-loaded chunks can therefore visibly appear when visibility changes.

Use player position, velocity and view direction to prioritize upcoming cells, account for merged rooms whose contents extend beyond the anchor cell, and retain relevant full room bounds. Evaluate actual visibility through long corridors in both bright and dark states before choosing the render boundary. Resource look-ahead alone will not fix abrupt visibility switching. Do not conceal it by thickening fog or adding alpha fades to opaque architecture. A wider horizon has a render/memory cost, so combine it with measured culling and preparation rather than increasing the radius indiscriminately. Evidence: [streaming and visibility](/Users/marcovhv/projects/GIT/liminal/scripts/chunk_manager.gd:96).

**5. Reuse or consolidate identical geometry without simplifying it.** The single hero server rack contributes 459 meshes and 699 descendants; repeated ordinary racks contribute 15 meshes and 51 descendants each. Flatten redundant static hierarchy and, where safe, combine opaque surfaces by material within a furnishing. Preserve every triangle, normal, UV, transform, material, shadow/GI flag, and the wear-selection contract. Smaller batches retain useful culling bounds.

Do not assume every mesh node costs an independent draw: Forward+ already [automatically instances identical opaque meshes and materials](https://docs.godotengine.org/en/4.6/tutorials/performance/optimizing_3d_performance.html). Explicit MultiMesh is a candidate for measured node/submission costs, not a universal fix. Avoid combining independently flickering, interactable, transparent or moving objects. Evidence: [rack wrappers](/Users/marcovhv/projects/GIT/liminal/scripts/levels/brutalist_level_builder.gd:359), [sanctum placement](/Users/marcovhv/projects/GIT/liminal/scripts/levels/brutalist_level_builder.gd:910).

There are direct resource-sharing opportunities too: Mall fountain discs/sign materials; Pool curved geometry, buoy tint overrides and jacuzzi planes; Data Center tendril cylinder meshes; Bloom hoop and particle quad meshes; Annex overlay quads. Cache by exact geometry/material inputs with bounded keys. The shared primitive and material caches already in place should remain. References: [Pool corners](/Users/marcovhv/projects/GIT/liminal/scripts/pool_corner_mesh.gd:10), [Pool openings](/Users/marcovhv/projects/GIT/liminal/scripts/pool_opening_mesh.gd:42), [Mall signs](/Users/marcovhv/projects/GIT/liminal/scripts/levels/mall_level_builder.gd:269).

**6. Remove repeated VHS exposure work, keeping the signal identical.** The live tape path is `vhs_signal.gdshaderinc`, followed by `crt_display.gdshader`. It does not execute the legacy CRT reconstruction branch. The tape path performs approximately 24 source samples per output fragment under the live preset, including the same nine fixed-position exposure samples everywhere. The CRT display adds 21 source samples for beam reconstruction and diffusion. These source counts are not GPU time estimates: caching and compiler behavior matter.

Compute the nine-tap exposure result once per frame in a tiny GPU pass and share it, using exactly the same current-frame input, coordinates, filtering and arithmetic. This preserves the brightness curve; using a different mip average or a previous-frame result would change it. Measure whether the extra pass actually wins. Leave chroma misalignment, noise, blur, ghost trails, scan timing and CRT reconstruction unchanged. A smaller clean-CRT-only candidate is avoiding the initial `Tri(pos)` result when the aberration branch replaces it; the compiler may already eliminate this. Evidence: [tape exposure](/Users/marcovhv/projects/GIT/liminal/shaders/vhs_signal.gdshaderinc:228), [CRT display](/Users/marcovhv/projects/GIT/liminal/shaders/crt_display.gdshader:37).

**7. Reduce redundant per-frame bookkeeping.** Recompute the desired chunk set when its center/focus changes; continue servicing pending work every frame. Avoid assigning unchanged visibility and light/material values. The invisible retained ring still runs scripts, but do not blanket-pause it: audio, mutation timers, flicker RNG and re-entry animation continuity are observable. Separate logical time progression from unnecessary rendering-property uploads. Likewise, the new ghosts share their art/materials and only use four sheets; their body shader does not read the screen. Their small CPU upload opportunities are secondary to whole-level construction and rendering. Preserve all four layers, delayed pose history, blur and burn/dissolve behavior.

**Recommended implementation order.** First cache wear calculations and immutable mesh variants; then bounded first-use preparation and time-budgeted room construction; then production-safe occlusion in the Data Center and measured enclosed floors. Follow with room-aware streaming, detailed rack consolidation, and a VHS exposure prototype. Bloom needs pass-level GPU evidence before further lighting/shadow changes. Its growth material is opaque, and its lighting already limits shadow sources per room; reducing lights or spores would change the approved look.

**Acceptance checks.** Compare fixed-seed clean and tape captures in bright/dark rooms, flashlight/shadow/reflection views, and all ghost states. Exercise doorways, merged-room boundaries, fast travel, reversing direction, floor transitions, blackouts and photo capture. Use the world-hash audit against a fresh pre-change baseline for resource/calculation changes, plus surface-wear, pool, arrival, mutation and ghost audits. Structural batching requires equivalent geometry/material/transform checks rather than blindly updating hashes. Add cold and warm traversal frame-time percentiles and maximum hitch duration for every floor, with exact resolution/driver/settings recorded. Run Mac and Windows release builds; accept a change only when measured performance improves and the relevant visual/gameplay comparisons pass.
