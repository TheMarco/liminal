# Room-event recordings

These nine MP3s were supplied by the user from Downloads on 2026-09-13,
replacing the corresponding procedural `AmbientPalette` sources. Filenames
and MP3 bytes are preserved. The originals in Downloads are untouched.

All are one-shots with looping disabled. Godot reports 3.080 seconds of decoded
audio; the MP3 container includes padding and reports approximately 3.12 seconds.
Their original ElevenLabs generation briefs remain in the sound-preview library
as references, labelled INSTALLED rather than still needing replacement.

| File | Playback trim (dB) |
| --- | ---: |
| trolley.mp3 | +6.4 |
| vent.mp3 | -4.2 |
| printer.mp3 | -0.6 |
| ticking.mp3 | +9.5 |
| ballast.mp3 | -4.8 |
| metal.mp3 | -7.5 |
| pipes.mp3 | +6.8 |
| drips.mp3 | -1.9 |
| organic.mp3 | +5.3 |

Trims are the measured full-clip RMS differences from each previous procedural
source, decoded through Godot's `AudioStreamPlayback.mix_audio` at the audio-server
mix rate. `AmbientPalette.gain_db()` applies them before the existing -11 dB event
gain, 3D attenuation, pitch variation and Hall reverb. No normalization or lossy
re-encoding was applied to the files. Raw browser previews are not gain-trimmed.

Floor palettes, event timing and the shared `knocks`/`creak` aliases are unchanged.
The game loads these resources through explicit preloads so they are included in
exported builds.
