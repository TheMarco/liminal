# It Wants You To Stay — 60-second promo

The trailer is rendered from this working copy of the Godot game. All gameplay, monsters, architectural effects, the portal and Dr Cross's television presentation were captured in-engine. No generated stand-in gameplay was used. Capture uses the game's VHS presentation with CRT disabled, delivered in a 1920×1080, 30 fps MP4.

The encounters and first-person camera paths are staged with the production actors, environments and effect systems in isolated `--test-mode` sessions. Monster kills are driven by the actual flashlight damage routine; the capture logs confirm each burn. Playback speed and hard cuts supply the montage pacing. Production game files and the player's campaign progress are not edited.

## Files

- `It_Wants_You_To_Stay_60s_1080p.mp4`: finished trailer, H.264 / stereo AAC, with web playback enabled.
- `dialogue.srt`: optional captions for the two Dr Cross excerpts.
- `edit.json`: frame-accurate shot order and source ranges.
- `audio-edit.json`: source audio, placements and level targets.
- `shot-contact-sheet.jpg`: visual overview of the edit.
- `title-review.jpg`: closing card.

## Featured moments

| Time | Footage |
| --- | --- |
| 00:00–00:04 | Death flash, casino, Dr Cross's warning |
| 00:04–00:11 | Casino flashlight kill, office, office monster kill |
| 00:11–00:16 | Annex sprint and the travelling hallway wave |
| 00:16–00:23 | Poolrooms, school, hound kill |
| 00:23–00:28 | Server rooms and a flashlight kill in the machine aisle |
| 00:28–00:34 | A doorway appears and disappears; an Annex wall breathes |
| 00:34–00:39 | Camera viewfinder, photograph and live next-level preview portal; reality aftershock |
| 00:39–00:48 | Annex monster kill, sprinting, rapid environment and burn montage |
| 00:48–00:52 | Dr Cross: “I think it wants us to stay.” |
| 00:52–00:54 | Player caught, falling to the floor, and death |
| 00:54–01:00 | Title, requested tagline, Steam message and creator credit |

## Rebuilding

`tools/trailer_capture.gd` is the separate capture director. `tools/render_promo.py` runs the selected shots sequentially; original 1080p image sequences and capture logs are retained under `build/promo-trailer`. `tools/trailer_audio_assets.gd` exports the game's synthesized shutter and portal sounds. `tools/edit_promo.py` assembles the picture, mixes the game's music and sounds with original editorial percussion, and masters the audio. Dr Cross audio is synchronized to the actual tape playback times logged by the capture runner.

The render runner requires Godot with access to the macOS graphics session. The editor uses Pillow, NumPy and the working FFmpeg binary at `/usr/local/bin/ffmpeg`. The higher bitrate picture intermediate and lossless sound master remain in `build/promo-trailer` for revisions.
