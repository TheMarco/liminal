# Native gameplay performance review — October 9, 2026

The lighting update is GPU-heavy at fullscreen Retina sizes. Rebalancing the most expensive shadow and environment settings improves Ultra materially without reducing world resolution, removing light sources, or changing the CRT filters. Low and Medium retain their existing budgets.

## Shipped change

`scripts/graphics_quality.gd` now uses a 4096 rather than 8192 positional shadow atlas for Ultra, low/medium soft filtering for High/Ultra, half-size high-quality SSAO, 16 rather than 32 full-GI rays, and a 96 rather than 128 voxel fog volume. Ultra retains its finer GI grid and update cadence. The atlas has 75% fewer pixels; the fog volume has about 58% fewer cells.

These are measured quality-budget tradeoffs, not pixel-identical rendering optimizations. Visual captures were checked in Office, Airport, Bloom, School, Mall, Prison and Pool. Fixture positions, energy, visibility, through-wall blockers, adjacent-room lighting, exposure, floor materials, reflection settings and world/video resolutions are unchanged. CRT shader parameters and Royale's mask type 2 are unchanged. Saved player settings are untouched.

## Strongest before/after evidence

Paired native fullscreen tests on the Apple M3 Max, Godot 4.7.2/Metal, at the same resolution and with both test orders where shown:

| Scene and look | Before FPS | After FPS |
| --- | ---: | ---: |
| Office, Ultra Clean | 39.1–39.2 | 47.3–49.0 |
| Airport, Ultra Clean | 27.0–27.2 | 34.4–34.5 |
| Bloom, Ultra Clean | 29.1–29.3 | 36.1–36.2 |
| Casino, Ultra Home video | 73.7–73.9 | 82.0–82.2 |
| Office, Ultra Native CRT + tape, HDR and normal audio | 60.1–60.2 | 68.1–68.4 |

Office Clean Ultra's paired p95 frame time improves from about 28ms to 22–24ms; Airport from 44ms to 34–35ms; Bloom from 42–43ms to 34ms. This reduces sustained frame time, not just the mean of a few unusually fast frames.

The broad sweep covers all eleven levels and all four original presets with Clean and Home video, followed by High/Ultra integration checks on every level. Low/Medium implementation is unchanged. The broad Clean comparison is below; differing preset sequences and live fixture timing make these less tightly controlled than the paired runs above.

| Level | High before → after | Ultra before → after |
| --- | ---: | ---: |
| Casino | 95 → 104 | 49 → 62 |
| Office | 74 → 82 | 39 → 50 |
| Annex | 75 → 84 | 38 → 47 |
| Airport | 51 → 57 | 26 → 34 |
| Asylum | 59 → 62 | 33 → 36 |
| School | 84 → 94 | 45 → 55 |
| Mall | 68 → 74 | 36 → 44 |
| Prison | 53 → 60 | 31 → 36 |
| Pool | 120 → 120 | 79 → 114 |
| Data Center | 71 → 72 | 38 → 44 |
| Bloom | 51 → 55 | 28 → 35 |

High with Home video shows much smaller gains and some run-to-run variance. Casino's unpaired Home result had substantially more draw work; a paired rerun measured High 90.4–90.8 → 92.3–92.7 FPS and Ultra 73.7–73.9 → 82.0–82.2. A further run using the baseline preset order measured Home High 92.6 and Ultra 74.2 FPS, with extra draw work returning partway through Ultra. Its exact source is not isolated. Do not interpret the unpaired matrix as a deterministic regression or guarantee.

## Other findings

- All eight selectable CRT models were measured separately on Office High/Ultra without tape. High reached about 113–120 FPS; Ultra about 99–116 FPS. Tape processing adds substantial cost independently of the CRT model. No filter calibration was changed.
- NTSC row workgroup experiments were byte-identical across six field modes, temporal history, noise and three input sizes, but remained about 4.9ms per submission. Larger groups gave no meaningful improvement; production code is unchanged.
- Office wall occlusion removed roughly 70% of submitted draws but only gained about 1–2 FPS in a paired Ultra sweep. The existing Data Center allowlist remains unchanged.
- Runtime light/shadow preparation is generally below 1ms per room. Data Center's most elaborate sampled cells reached about 2ms. Rewriting these traversals is not justified by the measured cost.
- The existing staged-generation/streaming audit passes. Casino's sampled manager work is 3.47ms p95 / 4.58ms maximum; Airport is 3.15 / 4.13ms. These are CPU-only timings. The urgent missing-floor path remains synchronous to preserve collision beneath the player.
- A normal-audio/HDR Office walk with Native CRT and tape traversed 34m across three cells: 71.8 FPS average, 17.88ms p95, 19.74ms p99 and 47.40ms maximum. Occasional hitches remain; their exact GPU/asset contribution is not isolated by this test.

## Validation and limits

Graphics-quality and video-quality audits pass. The native fixture occlusion audit now exercises the real Low, High and Ultra implementations: zero reflected-light leakage across the test wall, with a positive shadowless control; the Office ceiling still responds to the flashlight. The generation performance audit passes. Native comparisons completed without script failures or presenter errors. Existing Royale LUT-loading and occasional shutdown resource warnings remain.

The benchmark uses the production video host, normally scheduled rendered frames, seed 240721, fullscreen 3456×2168 output, 120 settling frames and 180 measured frames per case. It does not force draws or read back pixels during timing. Screenshots happen after timing. The stationary matrix suppresses spontaneous architecture changes; fixture animation and room streaming continue. This is Wander coverage, not a whole Descent campaign or maximum-enemy stress test. The moving run permits live architecture events.

Most comparisons use SDR and Dummy audio; the separate Office HDR/audio checks confirm HDR was active. No Windows/minimum-spec measurements or release builds were made. The display tops out near 120 FPS despite disabling VSync. Engine process-time monitors update periodically and can retain preceding-case stalls, so the report uses wall-clock frame intervals for performance claims. Heavy Clean Ultra scenes still fall below 60 FPS; Medium remains the default, with High a useful sharper gameplay option.

Raw summary and per-case references: [gameplay-review.json](2026-10-09-gameplay-review.json). Full frame arrays and screenshots live under `build/performance-review/`.

Reproduce a native sample with `tools/profile_gameplay_performance.gd`, `-- --nologo --level=1 --tiers=3:previous,3,3,3:previous --looks=clean`. The `previous` variant reproduces this review's starting graphics implementation. Use `--hdr --with-tape --looks=native` for the HDR/tape check, or `--walk --events --frames=1800` for movement. The tool uses isolated settings and leaves campaign saves untouched.
