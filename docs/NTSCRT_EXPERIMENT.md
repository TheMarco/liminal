# NTSCRT in Liminal

Use **Settings → Visual Effects** and choose a **Tape look**:

- **Off** turns off tape processing and grain.
- **Home video** uses full GPU tape processing for a soft, grainy home movie.
- **Found footage** uses full ntsc-rs for a camcorder recording with moderate wear.
- **Worn tape** adds stronger GPU tape wobble, tracking damage and colour noise.
  It avoids the full receiver's expensive CPU timing simulation.

**Tape damage** adjusts noise, wobble and streaks. The independent **CRT screen**
switch adds scanlines, glow and screen texture to any tape look, including Off.
Tape choices preserve CRT enablement and tuning; switching CRT preserves all tape
settings. The simple CRT switch selects calibrated Aperture on Low/Medium and
Royale on High/Ultra. Existing saved combinations stay unchanged until selected.
Tape presets reset signal/receiver controls and use standard signal resolution
without source processing. Saved graphics choices, input, audio and comfort
are preserved. To avoid spending GPU work on detail the recording discards,
CRT caps the 3D world at 480p; tape without CRT caps it at 720p.
These are ceilings: Low remains 360p, and small windows are not supersampled.
Turning both effects off restores the selected graphics resolution. Lighting, shadows and AA keep
their selected quality, while menus and dialogs retain window resolution.
Custom tape/receiver routes and forced tape playback share the 720p cap;
any TV route uses the 480p cap. CLI stage overrides use their effective state
without rewriting the saved resolution. The Graphics page shows the applied
resolution, including these automatic limits.

Graphics quality also scales the video work automatically, with no new controls:

| Graphics quality | Standard tape buffer | Processed image height ceiling | CRT screen |
| --- | --- | --- | --- |
| Low | 360×240 | 720p | Aperture |
| Medium | 540×360 | 1080p | Aperture |
| High | 720×480 | 1440p | Royale |
| Ultra | 720×480 | Window resolution | Royale |

The processed image is then presented at the window size. Lower tiers preserve
the selected look and normalize tape defect sizes for their smaller buffers.
Custom graphics derives its video tier from the saved world resolution, before
recording caps. Explicit developer signal sizing, source processing and CRT
supersampling remain available. Quality changes never rewrite the saved look.
The simple CRT switch saves an explicit automatic CRT choice. Developer-selected
Aperture/Royale models remain fixed at any graphics quality; the lab's parameter
controls follow the active model when automatic is selected. The exact previous
Aperture Home recipe upgrades while retaining Tape damage; custom tuning is preserved.

The gameplay HUD belongs to the recording: camcorder readouts, battery/stamina,
interaction/event prompts, Descent objectives and the live camera viewfinder
receive tape, CRT, grain and glitch effects. Title screens, settings, dialogs,
the photo album, subtitles and movie playback controls are composited afterward
at window resolution. This also applies to the Classic/compatibility path, whose
recording layer sits above the HUD and below modal screens. Existing styling
baked into title artwork remains.

The old receiver-based Worn tape preset upgrades automatically on load, retaining
tape wear, grain and TV adjustments. Other saved choices, including custom
receiver configurations, are preserved. The exact former Home video preset also
upgrades, keeping Tape damage; custom CRT configurations are left alone.
Custom tape settings are identified in the tape description. Selecting a tape
look resets signal settings while preserving CRT settings.

The normal menu does not construct the technical controls. Launch with
`--video-lab` to reveal **Developer video lab**, including independent grain.
In that lab, choose **Classic**, **NTSCRT approximation**, or **Full ntsc-rs**
for the signal, enable the **NTSCRT receiver** independently, and choose a CRT
model. The VHS and TV switches remain independent.

Examples worth comparing:

- Classic VHS with Aperture: existing tape treatment, original CRT reconstruction.
- Full ntsc-rs with CRT off: recorded footage without a monitor mask.
- Full ntsc-rs + receiver + Crtsim: tape, reception faults and temporal phosphor decay.
- Receiver with VHS off: a clean source seen through a mistuned television.
- Full ntsc-rs with the native tube: original signal filters with the lighter tube model.

All settings persist. Menus and dialogs render above the processed game
and remain readable. Film grain stays independent. Gameplay corruption, nearby
entities, damage and ritual tape playback feed the chosen signal. New hostile
figures remain hidden and stationary for a 0.45-second tracking/sync warning,
then begin their usual manifestation. Full ntsc-rs preserves the five distinct
transient glitch types in its existing GPU preparation pass; no receiver timing
simulation is enabled for the warning. Tape Off suppresses the recording cue.
Reduced flashing suppresses strong signal/receiver faults and temporal field weave.

Two original authored animations are integrated without new player controls:

- **Glitch pop** runs over the 0.45-second enemy warning plus 0.08 seconds of
  overlap with manifestation.
- **Two blips loop** becomes a single 1.1-second ambient tape fault, using the
  existing rare-fault schedule (28–55 seconds between scheduled major faults).

Their original normalized key times, outgoing easing, toggle holds and integer
rounding are retained. Only varying tape tracks are imported: bandwidth,
preemphasis, vertical filter scale, colour loss and edge wobble. Fixed source
looks, receiver settings, shader changes and resolution changes are excluded.
The runtime caps blur, colour loss, wobble and noise detail, fades back to the
active preset, and advances with gameplay time so pause holds the animation.
Reduced flashing suppresses these animations; zero Tape damage suppresses their
overlay. The existing five procedural faults still run in the preparation pass.
No additional GPU passes, receiver warmups or per-event file reads are added.

## Coverage

| Component | Included |
| --- | --- |
| ntsc-rs | All 22 algorithm stages and 62 canonical controls, exact recursive filters, six field modes, original integer random generators |
| NTSCRT receiver | All 17 controls, CPU timing state and original three GPU passes: picture-dependent burst gate, chroma recurrence/color killer, final transport and receiver composition |
| Original CRT models | Aperture, EasyMode, Glow Gaussian, Glow Lanczos, Hyllian, Royale and Crtsim; all 38 passes, original parameters, textures, framebuffer formats, mipmaps and feedback |
| Downscaling | Original nearest, Nearest+, ratio-scaled bilinear, Mitchell bicubic, Lanczos3 and area kernels |
| Sizing | Custom signal width with aspect-derived even height, source-sized signal, original CRT supersampling and integer fit/letterboxing |
| History | Original Crtsim phosphor feedback; optional previous-field weave extends the original ntsc-rs bob reconstruction |
| Authored animations | Selected tracks from Glitch pop (11 keys) and Two blips loop (8 keys), adapted to enemy warnings and rare ambient faults |
| Existing alternatives | Classic VHS/CRT and the lighter native NTSCRT approximation remain available for mixing/comparison |

In **Developer video lab**, expand **Full signal and receiver controls** for original knobs and
**Original CRT controls** for the selected shader's parameters. Nested signal
controls preserve their values when their parent effect is disabled. To try field
weave, select Alternating in the original Field mode control and enable Weave
previous fields. Both-fields modes already contain both fields and do not weave.

**Signal resolution and sampling** separates three costs:

1. Standard signal: follows the graphics-quality table above. Explicit Efficient detail can lower it to 360×240.
2. **Process NTSC at source resolution**: apply ntsc-rs to the completed world and gameplay HUD texture before shrinking, matching NTSCRT's order. Source size is the output viewport, even when the 3D world renders at 480p. Menus and dialogs bypass it.
3. **CRT render size**: automatic output follows the graphics-quality ceiling. Automatic CRT input, except Royale, is also limited to one signal line per three final display rows so smaller windows can resolve the beam and its gap. Royale retains its earlier quality-tier input size and field handling after the progressive-raster experiment produced visible moiré in gameplay. Tape-only input is unchanged. Explicit custom/source sizing, original supersampling and integer fit preserve their requested sizing. CRT targets remain at least signal-sized because original shaders can become undefined below 1×.

Fast bilinear is an additional inexpensive fixed-footprint resize. The six
original kernels use their original support widths and quantized intermediate
textures. Source-resolution mode uses original filtered bilinear when Fast
bilinear is selected. Custom width follows the window aspect; the standard tape
sizes retain the game's anamorphic 3:2 convention.

The four presets inside **Developer video lab → Approximation controls** affect the native
approximation controls only. The full signal and original CRT controls retain
their own settings. `--classic-video`, `--ntscrt` and `--full-ntscrt` select the
corresponding signal for one launch, without saving that override. Explicitly
choosing a look clears launch video overrides; selecting a stage in the menu
clears that stage's override. The menu displays active launch choices accurately.

## Runtime and limits

A stable SubViewport contains the game world and gameplay HUD from startup. Its completed
texture is processed on Godot's render thread and displayed the following frame.
The full signal, receiver and original CRT route therefore adds **one frame of
presentation latency**. Model changes never reparent the running game. The
Classic and native approximation routes retain their immediate display path.
Menus and dialogs use a shared CanvasLayer base that selects the final viewport before
entering the scene tree, retaining its normal scene ownership, input and pause
behavior. Those interfaces have no recording-frame latency. Intentional offscreen canvases
inside snapshot viewports remain local to those images.

Pixel processing is GPU work. CPU work consists of settings/uniform submission
and the receiver's sequential timing simulation at 59.94 fields per second.
There is no runtime image readback, CPU pixel filtering or GPU wait. Diagnostic
captures and benchmarks do read back images; those are separate tools.

The economical order is scene → shrink/SDR conversion → ntsc-rs → receiver → CRT.
The source-resolution option moves ntsc-rs before shrinking. Receiver faults and
CRT selection can operate independently of the chosen signal. Disabled stages
stop dispatching; previously allocated objects may remain ready for reuse.

This is the live video-processing port with two selected preset animations.
The other bundled looks and animation tracks are not integrated. Media import/transcoding, timeline and
keyframe editing, historical seek replay, export codecs, comparison UI and
editor zoom/pan are application features outside the game pipeline. Receiver
clock rewinds or jumps use bounded two-second warmup instead of replaying an
arbitrary historical settings timeline. Live control changes preserve receiver
timing history, including when multiple display frames share one NTSC field.
Search speed changes tape damage, not gameplay time. Line-21 captions are the
original decorative waveform data.

The signal remains gamma-domain SDR, including when presented in an HDR window.
Presentation samples the raw output texture and converts to linear exactly once
for HDR canvas composition. The native colour audit checks shadow, midtone and
highlight patches through UNORM, sRGB and floating-point outputs in SDR and HDR.
GPU f32 transcendental calculations can differ from upstream Rust f64 at rare
random-event thresholds; exact arithmetic for every possible input is not
claimed. The measured reference cases bound the tested differences below.
Original shader sources retain upstream licenses and attribution, including
Apache-2.0 for ntsc-rs and the various Slang licenses/GPL notices.

The GPU path requires Godot RenderingDevice (Forward+ or Mobile). Native checks
have run on Godot 4.7.2, Metal, Apple M3 Max. Other GPUs/platforms and low-end
frame-rate targets remain unmeasured. Compatibility/headless rendering does not
exercise these compute stages.

## Reference and integration checks

- ntsc-rs: 81 cases compared with pinned Rust; 71 byte-exact, maximum RGB difference 1/255, largest mean difference 0.006265 byte. RGB/YIQ roundtrip and history lifecycle passed.
- Receiver: healthy identity, mistimed picture-dependent burst gate, color loss, fault transport and resize/reset/repeated-frame behavior passed; timing compared with original Swift fixtures.
- Downscaler: 162 fixtures byte-exact against untouched original Swift/Metal kernels. A CPU oracle differs at a truncated Gaussian boundary; original Metal produces the same result as the port.
- Original settings: 62 descriptors match executable upstream metadata; all 79 signal/receiver controls passed their headless audit.
- Sizing: 444 checks, including original Swift tests and Swift-generated exact outputs.
- Packaged assets: all five compute shaders, schemas, authored animation data, embedded Slang source and ten exact-pixel LUTs passed 82 checks using production export filters.
- Authored cues: original key timing/easing, integer/toggle handling, readable limits, exact preset restoration, comfort gates and saved Home video migration passed. A native encounter check confirmed the warning precedes manifestation and survives pause correctly.
- World resolution: the graphics-quality audit checks Ultra switching between all four looks, Clean restoration, receiver-only and CLI overrides, forced playback, Retina resizing, Low preservation and the resolution shown in settings.
- Video quality: all four tiers, switching back and forth, saved-look preservation, smaller-buffer damage normalization, Custom graphics and explicit developer overrides pass the focused headless audit.
- Independent controls: all four tape choices roundtrip with CRT on and off without changing the other stage. Native menu clicks verify Worn tape plus Royale, CRT alone and both effects off; the menu remains crisp.
- Screen UI: native pixel comparisons confirm the entire title is identical across Clean/Home/Worn, while gameplay prompts change under tape/glitch effects, Classic, native approximation and Royale. HUD/viewfinder/objective canvases stay in the recording; title/settings canvases stay on the final viewport. Mouse navigation, keyboard activation, Escape and offscreen canvas ownership are checked too.
- Native game captures: all seven CRT chains passed with the full signal and receiver; settings remain above the processed image.

Pinned dependencies and original-file hashes are in `third_party/ntscrt/`.
Reference harness instructions are in `tools/ntscrt/reference/README.md`.
Generated captures, raw fixtures and native benchmark output live under ignored
`build/ntscrt-review/` and `build/ntscrt-reference/`.

```sh
# Saved controls, menu and gameplay gates; no player progress is written.
godot --headless --path . --script tools/audit_ntscrt_integration.gd -- --nologo
godot --headless --path . --script tools/audit_post_process.gd
godot --headless --path . --script tools/audit_video_quality.gd -- --nologo
godot --headless --path . --script tools/audit_ntscrt_full_controls.gd
python3 tools/ntscrt/verify_ntsc_schema.py

# Native full-stage integration and original CRT captures.
godot --path . --audio-driver Dummy --script tools/audit_screen_ui.gd -- --nologo --level=1
godot --path . --script tools/audit_ntscrt_color.gd
godot --path . --script tools/capture_enemy_glitch.gd -- --nologo --level=1
godot --path . --script tools/capture_ntscrt_authored_looks.gd -- --nologo --level=0
godot --path . --audio-driver Dummy --script tools/audit_ntscrt_full_pipeline.gd -- --nologo --level=1
godot --path . --audio-driver Dummy --script tools/capture_ntscrt_slang_game.gd -- --nologo --level=1 --full

# Import first so packaged compute shaders have compiled resources.
godot --path . --editor --import
GODOT_BIN=godot tools/ntscrt/check_export_assets.sh

# Complete LDR 2D matrix, then core routes with production linear/HDR 2D canvases.
# Same scene/source/output, no display pacing; run with other GPU jobs idle.
godot --path . --audio-driver Dummy --script tools/benchmark_ntscrt_game.gd -- --nologo --level=1 --full-matrix
godot --path . --audio-driver Dummy --script tools/benchmark_ntscrt_game.gd -- --nologo --level=1 --quality-ladder
godot --path . --audio-driver Dummy --script tools/benchmark_ntscrt_game.gd -- --nologo --level=1 --crt-comparison
godot --path . --audio-driver Dummy --script tools/benchmark_ntscrt_game.gd -- --nologo --level=1 --production
# Focused comparison of original animations and the tuned Home video preset.
godot --path . --audio-driver Dummy --script tools/benchmark_ntscrt_game.gd -- --nologo --level=1 --authored-looks
```

## Measured cost

**Home video CRT choice:** calibrated Royale adds approximately 0.2–0.5 ms to
the paired Aperture render workload on M3 Max (High and Ultra, 1080p and 4K).
Two opposite-order rounds use three synchronized 30-frame batches per case.
High's 4K output still uses the 1440p processing ceiling. GPU timestamps are
unavailable; these timings include CPU submission, GPU completion and amortized
readback, and are not gameplay FPS. Low-powered hardware remains untested.
The small measured cost and more distinct phosphor-screen texture justify Royale
for High/Ultra; Low/Medium retain Aperture.

Royale's stock gamma darkened a casino wall region to 35% of the tape-only
reference's mean brightness. Calibrating `lcd_gamma=2.8` and
`beam_min_sigma=0.12` brought it to 95%, versus Aperture's 102%. A bright-office
capture also retained wall and desk detail. These are fixed-view checks, not
whole-game visibility guarantees. Menus and dialogs are composited after both renderers.
Measurements and exact settings are in [the CRT comparison](performance/2026-10-02-crt-comparison.json).

**Graphics-tier sizing check (before automatic Royale):** on the same M3 Max, with the real Low world,
lighting and AA settings and unfiltered screen UI, automatic video scaling
reduced the measured Low render cost as follows. Values are the mean of two
opposite-order round medians, each from three 30-frame batches.

| Low preset | Previous video sizing → automatic, 1080p | Previous video sizing → automatic, 4K |
| --- | ---: | ---: |
| Home video | 6.46 → 3.92 ms (39% lower) | 9.65 → 6.25 ms (35% lower) |
| Worn tape | 6.36 → 3.75 ms (41% lower) | 8.54 → 6.21 ms (27% lower) |

The comparison holds the Low scene workload constant and changes only the video
budget. All four tiers passed at both output sizes, preserving their actual
world resolutions and AA. These are synchronized rendering batches, including
CPU submission and amortized image readback, not gameplay FPS or pure GPU time.
No low-powered hardware was available. Settings, effective sizes and measurements
are in [the quality-tier results](performance/2026-10-02-video-quality.json).

**Earlier full-port baseline (before graphics-tier scaling and UI separation):**
Apple M3 Max, Godot 4.7.2, Forward+/Metal, fixed office scene and camera,
480-line 3D source. The table uses the game's production linear/HDR 2D canvases
with SDR display output. Film grain remains at 0.4 in every case, including the
video-stages-off baseline. Each value is the range of the two round means.

| Configuration | 1080p | 4K |
| --- | ---: | ---: |
|Video stages off (grain retained) |2.9–3.3 ms |7.3–7.5 ms |
|Existing VHS + CRT |5.6–5.7 ms |17.1–17.6 ms |
|Full ntsc-rs, no receiver/CRT |10.5–11.3 ms |15.4–16.4 ms |
|Receiver only |10.2–12.4 ms |11.2–12.9 ms |
|Full signal + receiver + Aperture |11.0–13.1 ms |20.0–21.5 ms |
|Full signal + receiver + Crtsim |13.0–14.0 ms |14.8–17.4 ms |
|Efficient full signal + receiver, no CRT |7.7–7.9 ms |10.2–12.8 ms |
|Source-resolution signal + receiver, no CRT |22.3–25.6 ms |73.8–80.6 ms |

The old effects have a measurable cost, particularly at 4K. The full signal
adds substantial work at 1080p; at 4K the complete Crtsim combination is in the
same general range as the existing VHS/CRT combination in this fixture.
The source-resolution mode is the clear expensive option: its 4K rendering
alone takes roughly 74–81 ms. Start with the standard 720×480 signal; Efficient
uses 360×240. Keep source-resolution processing as an explicit fidelity experiment.

Receiver timing/submission is also significant. It runs on the CPU while image
filtering stays on the GPU; costs overlap, so stage differences cannot simply
be added together. CRT costs depend on the model and output resolution.
Supersampling enlarges the CRT target and can move the bottleneck toward the GPU.

**Worn tape correction:** the table above used a healthy receiver. Enabling its
jitter, crinkle and tracking exposed a much greater CPU cost: a focused 720×480
probe measured about 14.5 ms for one field of timing evolution plus 52.9 ms to
prepare the frame's timing data. The original Worn preset therefore performed
much worse than those healthy-receiver results implied.

Worn now uses the existing GPU tape passes for its damage, leaving the original
receiver as an explicit developer option. A fresh fixed-scene comparison, with
the TV off and each look's own grain, measured:

| Worn tape preset | 1080p | 4K |
| --- | ---: | ---: |
| Original, with damaged receiver |68.7–69.2 ms |69.0–69.1 ms |
| Updated, GPU tape damage |6.76–6.77 ms |9.97–10.02 ms |

These ranges cover two opposite test orders, three 30-frame batches each.
[Preset settings and measurements](performance/2026-10-02-worn-tape.json) retain
the before/after configuration and validation. Reproduce this focused comparison
with `--tape-looks` on `tools/benchmark_ntscrt_game.gd`.

**Repeated-field stall correction:** changing gameplay stress while rendering
the same NTSC field incorrectly restarted the receiver's two-second settling
simulation. A native 720×480 probe measured 827.7–844.3 ms of CPU submission for
those calls before the fix and 4.35–4.38 ms afterwards. The receiver now keeps
its clock and scanline history when live controls change. This affects the
developer Receiver option; Worn tape does not require it. The receiver GPU audit
checks this continuity, updated picture output, subsequent field progression,
and reset behavior for actual seeks. These timings isolate receiver calls,
exclude GPU completion, and do not measure whole-game frame rate.

The final authored-look comparison uses the same office, 480-line world and
production canvases. These are ranges of the two round medians (three 30-frame
batches per case, with reversed order in the second round):

| Look | 1080p | 4K |
| --- | --- | --- |
| Previous Home video | 2.99–3.02 ms | 9.12–10.89 ms |
| Home video: full tape + tuned Aperture | 8.32–8.51 ms | 11.70–13.41 ms |
| Worn tape, steady | 8.30–8.49 ms | 11.00–12.75 ms |
| Worn tape + Glitch pop | 8.27–8.40 ms | 10.99–12.68 ms |
| Worn tape + Two blips | 8.26–8.33 ms | 10.99–12.69 ms |

The authored tracks add no measurable cost beyond variation in this test;
Home video's full tape route is more expensive than its former approximation.
An earlier run on the same machine was faster across all cases, so these are
workload samples, not performance guarantees. The Casino capture also checks
dark-scene readability: tuned Home video retained approximately 93% of Clean's
mean encoded luminance in the sampled dark-wall region, compared with about 71%
using Aperture's untouched defaults. This is a fixed-view visual check, not a
universal luminance bound. [Authored-look measurements](performance/2026-10-02-authored-looks.json)
retain exact settings and per-batch evidence.

The preset comparisons report synchronized rendered-workload measurements, including CPU submission,
GPU completion and one amortized image readback per 30-frame batch. They exclude
normal gameplay simulation and are not isolated shader timings or a promised
FPS. The Metal driver returned no useful GPU timestamps. All cases include the common
scene viewport and small benchmark preview; they compare the stages within
the integrated game. The stable scene viewport also adds a presentation copy
when Classic is selected. Some texture-memory
counters underflowed and are recorded as unavailable. The broad LDR matrix had
substantial variation between its two 4K rounds; both are retained.

[Full measurements and methodology](performance/2026-10-02-ntscrt.json) include
all 34 configurations in the LDR matrix and eight core configurations with
production canvases, at both resolutions and in opposite test orders. That
replaces the earlier display-paced comparison; the earlier ~8 ms results were
limited by desktop pacing and did not isolate rendering cost.
