# It Wants You To Stay — gameplay promo, version 5

Latest: `It_Wants_You_To_Stay_Promo_1080p_v5.mp4` — 74.57 seconds, 1920×1080, 30 fps, VHS enabled, CRT disabled.

## This revision

Six traversal shots and the death ending were rendered again from the game. The Casino, Office, School, Server Rooms and Annex use actual player acceleration, collision, native head bob and the handheld camera spring, with 90-degree mouse turns. Left and right turns have different timing. The Poolrooms shot walks along the clear deck, stops naturally, and turns across the grand hall. No repeated artificial camera oscillation is added.

The final death shot now uses the native camera fall, so the creature looms over the player instead of moving through the lens. All eight reviewed phases show the outside of the actor. The five continuous routes and the pool approach were checked against their planned positions, with under 0.02 metres of error and no body-height jumps.

Feature cards are halved from 3 seconds to 1.5 seconds, with shorter copy that can be read at that pace. The closing title and Steam message hold for 4.5 seconds. Four monster kills, the floaties and pool girl, wave, breathing walls, changing doors, photograph and next-floor preview, intro, and both full-screen Dr Cross excerpts remain.

## Feature cards

- EXPLORE THE IMPOSSIBLE.
- FIGHT WITH LIGHT.
- THE BUILDING IS ALIVE.
- PREVIEW YOUR NEXT NIGHTMARE.

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
| 50.47–54.47 | breath |
| 54.47–58.07 | doors |
| 58.07–59.57 | card preview |
| 59.57–64.07 | portal |
| 64.07–67.57 | cross stay |
| 67.57–70.07 | death |
| 70.07–74.57 | title |

## Sources and checks

All environments, monsters and gameplay effects are rendered in Godot from the working game. Enemy assignments remain those of `ShadowFigures.THEME_WALKER` and `DARK_ROSTER`. Isolated test sessions preserve campaign progress; production game code was not edited for this trailer.

`capture-verification.json` records movement, enemy and capture evidence. `verification.json` records final video and audio checks, including the complete decode and scan for the old pause-menu overlay. `edit.json`, `audio-edit.json` and `dialogue.srt` record the timeline, audio cues and optional captions. `feature-cards.jpg` and `shot-contact-sheet.jpg` provide overviews.

`tools/render_promo.py` and `tools/trailer_capture.gd` render the revised shots into `build/promo-trailer-v5/raw`. The unchanged action/effect shots remain in `build/promo-trailer-v3/raw`; Dr Cross and the closing background remain in `build/promo-trailer/raw`. `python3 tools/edit_promo.py` rebuilds the finished cut using Pillow, NumPy and `/usr/local/bin/ffmpeg`. Godot capture requires the macOS graphics session.

Earlier MP4 versions are preserved, with their metadata in `v1-metadata` through `v4-metadata`.
