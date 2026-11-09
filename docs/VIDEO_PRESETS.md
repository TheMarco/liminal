# Video preset workshop

Choose a complete look in **Settings → Visual Effects → Recording look**, available
on the title screen and during play. Direct VHS on/off, VHS strength, film grain,
CRT on/off and CRT model controls sit below it, with no preset editor required.
Changes mark the look as custom; switching VHS or CRT off and on preserves its tuning.
Choosing another preset replaces these adjustments. For live comparison and detailed adjustments,
open **Pause → Visual Effects → Preview & fine-tune looks**. The room stays
visible and gameplay stays paused. The panel is drawn after the video effects.

Start with the [**20 built-in looks**](CURATED_VIDEO_LOOKS.md) at the top. The dropdown and arrow buttons
apply a look immediately. Each description says whether it is a direct camera
capture, a VHS recording, or a picture played through a CRT. **Fine-tune this
look** is off by default; turn it on only to open the detailed tabs.

Try **09 Found footage · original tape**, **02 MiniDV · daylight**,
**12 Security camera · monochrome**, or **15 VHS on the living-room TV** first.
Browsing preserves your video budget, reduced-flashing preference and automatic
3D-resolution policy. Loading a captured JSON still restores its full settings.

- **Look** adjusts recording effects, CRT model, damage, grain and video-processing
  budget. Arrow buttons cycle the seven original CRT models. The recording-effects
  toggle bypasses the signal without replacing its settings. There is no second
  tape-preset picker to overwrite the chosen complete look.
- **CRT tuning** exposes each model's original parameters, with search and reset.
- **Signal** exposes all NTSC and receiver controls.
- **Output** controls signal size, filtering, supersampling, field history and
  the automatic reduction of 3D resolution.
- **Keep as A / Show A / Back to B** compare a stored look without overwriting
  the one being edited. **Done** returns to the paused settings menu.

**Capture preset** saves a new folder under `user://presets/`. **Open captures**
opens that location. Each folder contains `preset.json`, `preset.tres`, and a
full-scene `preview.png`, with the filtered game HUD and no workshop UI.

The JSON records every video-profile setting, all 62 NTSC controls, recurring-defect type/rate/strength, all 17 receiver
controls, camera saturation/white balance/shadow lift, and complete parameters for all seven CRTs, including inactive stages.
It also records game-specific rendering/HDR/camera settings and source dimensions.
Loading a game capture restores those rendering settings; input bindings, audio,
progress and world state are not part of a visual preset. PNG previews are SDR.

Use **Load preset…** for JSON files from this game or the standalone
`godot-ntscrt` workshop. JSON is the interchange format; the `.tres` references
the capturing project's profile script. Game-specific context survives editing
and re-exporting in the standalone workshop. Animated noise and gameplay-triggered
glitches are not frozen into a preset; capture clears an active workshop cue.

The workshop uses the full GPU signal pipeline and seven original CRT models.
It gives video processing its own quality budget. Selecting a normal graphics
quality preset restores automatic video budgeting. Detailed settings remain
outside the ordinary player menu.

Automatic CRT sizing leaves at least three display rows per signal line: a
720-row window uses up to 240 lines, 1080 uses up to 360, and larger windows use
the selected tier's signal budget (up to 480). This is separate from the 3D
world resolution. Tape-only processing and explicit custom/source sizing or
original supersampling keep their chosen sizes.

## Maintenance and checks

`video_preset_profile.gd`, `video_preset_io.gd`, `video_preset_workshop_panel.gd`
`video_preset_library.gd`, and `video_preset_controls.gd` share the standalone addon's profile format, preset IO,
workshop and canonical controls. `crt_calibration.gd` holds the game's shared
beam/mask defaults and upgrades only recognized, untouched older model settings.
Custom tuning remains unchanged. The game-specific
bridge and host adapt settings, scene capture, crisp UI and pausing.

Focused checks: `tools/audit_video_preset.gd` (headless) and
`tools/audit_video_workshop.gd` (native, with `-- --nologo --level=1`). The native
check uses temporary settings and cannot change campaign progress. Both native
workshop tests accept `--import-preset=/absolute/path/preset.json` for cross-project
checks; the standalone case expects a game capture with rendering context.

## Authored realism

These are visual interpretations, not camera-specific emulators. MiniDV entries
represent an AV-cable capture: they do not simulate a DV codec, macroblocks, or
change the game's frame rate. The IR-style preset is a noisy monochrome color
response; it does not illuminate unlit geometry. Camera views have no CRT unless
the name explicitly describes a screen. Stable tapes avoid large tracking bands; worn copies now include visible noise, wobble and bottom-edge wear.

The seven CRT playback looks cover Aperture, Royale, EasyMode, Glow Gaussian,
Glow Lanczos, Hyllian, and Crtsim. Their glow, masks, curvature and brightness are
tuned per screen, with no receiver simulation or source-size supersampling.
Royale retains its earlier automatic interlace detection, beam profile and
quality-tier signal size. Its game and living-room defaults use mask type 2
(shadow mask). The fixed progressive raster tuning was withdrawn
after visible moiré was reported in gameplay; exact saved copies of that tuning
are restored on load while deliberate custom settings are preserved. EasyMode and Hyllian
retain scanlines at 480-line input; the security monitor uses Crtsim's staggered
phosphor mask. EasyMode's generated shader includes a positive floor before its
fractional beam power to prevent black NaN rows on Metal. Vendored source files
are unchanged, and the importer reproduces this portability fix.
Camera grading shares the existing grain pass, with neutral defaults for old
presets. Choosing the ordinary Clean tape option also resets that grading.

`tools/audit_video_preset_library.gd` checks recipe validity, 20 distinct effective
profiles, complete save/load, default-hidden controls, budget/comfort preservation
and A/B. `tools/capture_video_preset_library.gd` renders real game previews with
temporary settings (`-- --nologo --level=1`, or `--level=0` for Vegas). Optional
`--looks=14,19`, `--hdr-review`, and `--capture-dir=/absolute/path` narrow visual
review without changing campaign progress. Low-end physical hardware remains
unverified; quality-budget testing on a powerful GPU is not a substitute for it.

The recipe library owns recurring defects, including in the paused workshop.
A **Preview this look’s tape damage** button appears for damaged looks. The
portable profile replaces the game’s legacy random fault schedule, so a clean
camera does not acquire unrelated VHS glitches. Enemy cues remain independent
and take priority over the small preset defects. Ordinary tape buttons restore
their existing behavior. The defect overlay uses the existing GPU preparation
pass; it adds no receiver simulation or extra render pass.

For moving-picture checks, `capture_video_preset_library.gd -- --nologo
--level=1 --seed=240721 --looks=2,3,9,10 --motion` saves short frame samples and a
visible defect frame, using explicit redraws even if the capture window becomes
occluded. The scene's player input is disabled in this isolated check.
