# It Wants You To Stay — gameplay promo, version 6

Latest: `It_Wants_You_To_Stay_Promo_1080p_v6.mp4` — 77.07 seconds, 1920×1080, 30 fps. VHS enabled; CRT disabled.

## This revision

After the hallway wave, a new walk through the Annex's tall 36×36-metre flooded hall replaces the static breathing-wall shot. The generated room has nine water surfaces and 81 pillars. The player walks and turns through its interior using the native movement, collision, head bob and handheld camera systems.

The portal sequence now lasts seven seconds. It shows the player photographing the hidden doorway, lowering the camera, walking across the threshold, then continuing through a doorway in the actual Office destination toward its glowing flash pickup. The native realm transition is used. Five raw frames (115–119) showing the source world at the handoff are removed; the real destination fade-in remains. No invented destination or stand-in gameplay is used.

The other version 5 footage is retained: natural traversal across the six requested levels, four monster kills with correct level assignments, Poolrooms floaties and girl, hallway wave, appearing/disappearing door, both full-screen Dr Cross excerpts, intro, and the corrected death-camera fall. Feature cards remain 1.5 seconds; the closing title/Steam card remains 4.5 seconds.

The new flooded shot has water footsteps, and the portal approach and arrival have footsteps timed to player movement. Music, Dr Cross's dialogue and optional captions are retimed for the longer portal sequence.

## Timeline

| Time | Shot |
| --- | --- |
| 00.00–02.00 | intro |
| 02.00–03.97 | cross warning |
| 03.97–06.47 | casino kill |
| 06.47–07.97 | card explore |
| 07.97–11.97 | casino traverse |
| 11.97–15.97 | office traverse |
| 15.97–19.97 | pool grand |
| 19.97–21.97 | pool floaties |
| 21.97–25.47 | pool girl |
| 25.47–26.97 | card fight |
| 26.97–29.47 | office kill |
| 29.47–32.97 | school traverse |
| 32.97–35.47 | school kill |
| 35.47–38.97 | server traverse |
| 38.97–40.97 | server kill |
| 40.97–44.47 | annex traverse |
| 44.47–45.97 | card alive |
| 45.97–50.47 | wave |
| 50.47–54.47 | annex flood |
| 54.47–58.07 | doors |
| 58.07–59.57 | card preview |
| 59.57–66.57 | portal |
| 66.57–70.07 | cross stay |
| 70.07–72.57 | death |
| 72.57–77.07 | title |

## Sources and verification

All gameplay was rendered in Godot from the working game in isolated test sessions. The new scenes are in `build/promo-trailer-v6/raw`. Version 5 traversal and death footage remain in `build/promo-trailer-v5/raw`; unchanged action and effects remain in `build/promo-trailer-v3/raw`; Dr Cross and the closing background remain in `build/promo-trailer/raw`.

`capture-verification.json` records movement, room contents, opening the portal and entering the Office. `verification.json` records final media checks and the scan for pause-menu flashes. `edit.json` includes the timeline and portal source-frame omission; `audio-edit.json` records sound cues; `dialogue.srt` contains optional captions. `shot-contact-sheet.jpg` shows the complete sequence.

`python3 tools/render_promo.py annex_flood portal` renders the two new scenes. `python3 tools/edit_promo.py` rebuilds version 6 using Pillow, NumPy and `/usr/local/bin/ffmpeg`. Godot rendering requires the macOS graphics session. Production game code and campaign progress are not edited for the trailer.

Earlier MP4 versions are preserved. Their metadata is retained in `v1-metadata` through `v5-metadata`.
