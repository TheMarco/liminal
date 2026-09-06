# Gameplay quality pass — 2026-09-05

## Changes

- **Remembered objective recordings.** Completed chapters persist per floor in
  the current building. Death, Continue and streamed room rebuilding restore
  the completed state and lift access. The television offers optional replay;
  interrupting a replay does not erase completion or repeat the first-viewing
  encounter. Restart/New clear progress with the new building. Save format 4
  still reads formats 1–3; format 3 retains its runtime and photograph state.
- **Casino landmarks.** The original Descent route reserves LAST CHANCE, the
  Amber Lounge and a red telephone passage. LAST CHANCE has two banks of four
  cabinets, with one powered wheel. The lounge has a 32 cm recess and four
  gentle ramps. The phone rings intermittently from its physical position.
  Landmark rooms retain their identity through streaming and are excluded from
  blackout geometry/furniture mutations. A corridor-heavy route can open one
  passage cell into the lounge instead of omitting it.
- **A concrete photographic contradiction.** The telephone door and viewfinder
  read 104; the developed print reads 106. Lowering the print changes the real
  plate to 106, which stays changed on revisits. This replaces one generic
  photograph opportunity and does not increase the evidence quota. The moment
  remains available after reaching that quota, and its reveal does not trigger
  the usual random post-photo encounter.
- **Pause and comfort controls.** Escape pauses movement and Descent timers;
  Resume restores the previous mouse and playback state. Title Settings is
  available by button or S. Sensitivity, FOV, bob, music, effects, VHS distortion
  and reduced flashing persist in `user://settings.cfg`. Music and world effects
  have independent volume buses; changing volume preserves temporary TV mutes.
  Reduced flashing steadies fixtures, the low-battery torch and slot lighting,
  removes the shutter flash, and suppresses rapid shader signal-loss effects.

## Verification

Checks use Godot 4.6.1, generated worlds, native rendering and automated input.

| Check | Coverage |
|---|---|
| Landmark planning survey | 1,024 deterministic seeds; three distinct landmarks in every plan, first within three room transitions |
| Permanent landmark regression | 65 seeds, including corridor-heavy seed 1333692015; repeatability, route membership and whole-room mutation protection |
| Physical landmark builds | 39 rooms across 13 seeds; doorway clearance, eight cabinets/one powered wheel, actual lounge floor/ramp physics, telephone and plate |
| Numbered-door persistence | Live photo director resolves 104 to 106; rebuilt rooms retain 106 |
| Rendered shutter sequence | Real PhotoCamera shutter/review/lower flow asserts 104 → print 106 → physical 106 |
| Photograph coverage | Seed 7: all 17 planned anomalies capturable from actual geometry |
| Recording retry | Save/reload, actual floor rebuild, restored lift state, replay access without new evidence, interrupted replay |
| Settings | Disk round-trip, bounds, invalid numbers, reset, live player/audio/shader application |
| Pause input | Keyboard slider and mouse Resume at 640×480, 1280×720, 1920×1080, 2560×1440, 3456×2186 and 3840×2160; readable proportional menu size, paused motion/timer and playback gates |
| Title layout | Eight saved-run actions, six live resize states, no overlap/clipping |
| Casino mutation graph | Six alternative states; connected, reversible and reconstructable |
| World fingerprint | 522 chunks over three seeds and eleven themes; six expected slot material/metadata/placement hashes updated, unchanged node counts |

The independent planning survey uses
`posmod(WorldGen.h(61057, i, 9127, 9919), 2147483646) + 1`, for `i = 0…1023`.
It found the corridor-heavy missing-lounge case; that seed now has a permanent
geometry and planning regression in `tools/audit_casino_landmarks.gd`.

The pause menu scales as a complete layout from a 720p reference, including
text and interactive controls. At 3456×2186 the panel is 1822×1943 pixels;
small windows keep readable text and scroll the settings. Native captures
verified the scaled layout at Retina and 4K resolutions.

The SLOTS wall sign is now built after slot banks are centered in merged rooms,
so it retains the selected wall's coordinates. The cabinet audit verifies wall
collision immediately behind the lettering and neon rail: 85 signs across 138
casino rooms, including 22 merged-room signs. The pre-fix check reproduced the
floating sign; the repaired layouts pass all support checks.

The new focused audits are registered in `tools/run_audits.sh`. Its `-f` option
matches a name substring, for example:

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run_audits.sh -f casino_landmarks
GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run_audits.sh -f comfort_runtime
```

Some immediate chunk teardown paths log Godot's existing null-material cleanup
diagnostic, which the repository audit runner already allows. Native capture
shutdown also reports seven texture RIDs. Functional assertions pass; these
shutdown diagnostics are not claimed fixed by this pass.

## Visual review

Regenerate production-lighting captures and exercise the actual photo flow:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --minimized \
  --audio-driver Dummy --disable-render-loop \
  --script tools/capture_casino_landmarks.gd -- --mode=descent --nologo --seed=7
```

Images go to ignored `build/gameplay-review/`: `last_chance.png`,
`sunken_lounge.png`, `red_telephone.png`, `door-print-106.png`,
`door-real-106.png`, and `pause-settings.png`. These use in-game geometry and
lighting with HUD/VHS overlays hidden for inspection.
