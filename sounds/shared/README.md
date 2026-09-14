# Supplied shared-sound replacements

Five named MP3s from the user's Downloads were installed on 2026-09-13.
Original bytes are preserved in `art/shared_sound_sources/` (excluded from Godot
import/export with `.gdignore`). Downloads originals remain untouched.

The game uses prepared stereo 16-bit PCM WAVs, retaining the existing
`SoundBank` WAV API and caller behavior. WAV import normalization, trimming,
resampling and lossy compression are disabled. Playback gain is baked into the
prepared WAV once; do not apply these trims again at the emitter.

| Input | Game WAV | Length | Loop | Gain |
| --- | --- | ---: | --- | ---: |
| buzz.mp3 | buzz.wav | 7.960 s | Yes | -11.6 dB |
| drip.mp3 | drip.wav | 0.800 s | No | +8.0 dB |
| moan.mp3 | moan.wav | 3.080 s | No | -4.9 dB |
| pa-voice.mp3 | pa_voice.wav | 4.480 s | No | -13.0 dB |
| shiver.mp3 | shiver.wav | 0.880 s | No | -3.9 dB |

Buzz overlaps/crossfades its head and tail by 40 ms, shortening the supplied
8-second clip to a continuous 7.96-second loop. SoundBank explicitly enables
its loop bounds. Other recordings preserve their supplied duration and decay.
The drip is not the separate `room_events/drips.mp3` sequence.

Gains match the previous sources' full-clip RMS, except drip: it matches the
previous single event's total energy across its longer supplied decay. This
avoids an excessive +12.6 dB boost from blindly matching average RMS over unequal
durations. All prepared source peaks are below -4.5 dBFS before the existing
negative emitter gains. Existing pitch/volume randomization, distance falloff,
bus routing and PA chime sequencing are unchanged.

Shiver remains dormant: a figure emitter is created but has no playback trigger.
Replacing this source does not add a new behavior.

Rebuild with:

```sh
godot --headless --audio-driver Dummy --path . --log-file /tmp/liminal-shared-build.log --script tools/build_shared_sounds.gd
godot --headless --editor --path . --log-file /tmp/liminal-shared-import.log --import
```

`tools/audit_shared_sounds.gd` checks all 14 replacement source levels, headroom,
PCM/loop contracts, buzz seam continuity, Asylum randomizers, PA timing and
finite playback. These are source/meter checks, not an ear-verified final game mix.
