# It Wants You To Stay — 60-second promo, version 3

Latest file: `It_Wants_You_To_Stay_60s_1080p_v3.mp4`. The earlier MP4 versions are preserved for comparison.

This revision uses the production enemy roster (`ShadowFigures.THEME_WALKER` and `DARK_ROSTER`) rather than manual per-shot monster selections. The Office features the hound, School the veiled matron, Poolrooms the horror girl, Annex the trenchwalker, and Casino/Server Rooms members of their normal dark roster.

The six longer traversal shots use the actual Player controller, normal 3.4 m/s walking speed, acceleration and collision. Head bob and handheld camera motion are disabled in the isolated capture session. All added sine-wave camera bob, roll and aiming oscillation have been removed. Traversal footage plays at its captured speed. Each walk has a camera trajectory log for verification.

The Poolrooms sequence includes its grand Cistern hall, generated striped/ring/mattress floaties, a closer view of the new flamingo and mattress, and the girl approaching along the deck. Four native flashlight kills, the wave, breathing wall, disappearing/appearing door, preview portal and player death remain in the edit. The intro and full-screen Dr Cross presentation from version 2 are retained.

All scenes, actors and effects are rendered from this working copy of the game in Godot, using VHS with CRT off. The encounters and camera paths are staged in isolated `--test-mode` sessions. No generated stand-in gameplay is used. Production game files and campaign progress are not edited. Typography, cutting and audio mastering are performed afterward.

## Timeline

| Time | Footage |
| --- | --- |
| 00.00–02.00 | Opening title |
| 02.00–03.97 | Dr Cross warning, full screen |
| 03.97–07.97 | Walk through the casino |
| 07.97–10.47 | Casino shadow monster kill |
| 10.47–13.97 | Walk through the office and connecting doorway |
| 13.97–16.47 | Office hound kill |
| 16.47–20.47 | Walk around the grand Cistern pool |
| 20.47–22.47 | Flamingo and mattress floaties |
| 22.47–25.97 | Poolrooms girl approaches along the deck |
| 25.97–28.97 | Walk down the school corridor |
| 28.97–31.47 | Veiled matron kill |
| 31.47–34.47 | Traverse the server room |
| 34.47–36.47 | Server-room shadow monster kill |
| 36.47–39.47 | Walk through the Annex corridor |
| 39.47–42.47 | Travelling hallway wave |
| 42.47–44.47 | Breathing Annex wall |
| 44.47–47.47 | Door appears and disappears |
| 47.47–50.50 | Photograph and next-level preview portal |
| 50.50–54.00 | Dr Cross final statement, full screen |
| 54.00–56.50 | Caught by the Annex trenchwalker |
| 56.50–60.00 | Title, tagline, Steam message and creator credit |

## Delivery and rebuild

The export is 1920×1080, 30 fps, exactly 60 seconds, H.264 with stereo AAC. `dialogue.srt` supplies optional captions. `edit.json`, `audio-edit.json`, `capture-verification.json` and `verification.json` document the final edit and checks. `shot-contact-sheet.jpg` shows the shot sequence.

`tools/trailer_capture.gd` and `tools/render_promo.py` generate the gameplay frames in `build/promo-trailer-v3`. Native Dr Cross footage and synthesized game audio retained from version 2 are read from `build/promo-trailer`. `tools/edit_promo.py` assembles the edit and mixes game music, dialogue and effects with original editorial percussion. The higher-bitrate picture intermediate and lossless audio master remain under `build/promo-trailer-v3`.

Godot requires the macOS graphics session. The editor uses Pillow, NumPy and the working FFmpeg binary at `/usr/local/bin/ffmpeg`. Earlier metadata is retained in `v1-metadata` and `v2-metadata`.
