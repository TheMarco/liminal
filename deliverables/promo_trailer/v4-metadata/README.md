# It Wants You To Stay — gameplay promo, version 4

Latest file: `It_Wants_You_To_Stay_Promo_1080p_v4.mp4` — 79.57 seconds, 1920×1080, 30 fps. The earlier 60-second MP4s are preserved.

The edit now opens with a monster kill, introduces four concrete gameplay features, and follows each card with footage demonstrating it. Every card holds for three seconds. The wave, breathing wall, changing door and preview portal have longer shots, and the closing Steam/title card holds for 5.5 seconds. All gameplay footage now plays at its captured speed.

The music ducks under feature cards, with bass punctuation on the cuts. Dr Cross's original dialogue remains aligned to the in-engine tape clock; optional captions are retimed in `dialogue.srt`.

## Feature cards

- **FAMILIAR PLACES. UNFAMILIAR HORRORS.** Explore sprawling, procedurally generated levels.
  Evidence: `scripts/world_gen.gd` — procedural, seed-based room generation.
- **YOUR LIGHT IS A WEAPON.** Burn away the things hunting you.
  Evidence: `scripts/shadow_figure.gd` — production flashlight damage and disintegration; four kills confirmed in capture logs.
- **THE BUILDING IS ALIVE.** Walls breathe. Corridors bend. Doors vanish.
  Evidence: Native hallway-wave, environment-breath and doorway systems, shown directly after the card.
- **LOOK INTO YOUR NEXT NIGHTMARE.** Photograph anomalies. Preview the next floor.
  Evidence: `scripts/photo_camera.gd` and `scripts/realm_excursion.gd` — anomaly photography and the real 3D doorway preview.

## Footage

The corrected enemy roster, stable native-player traversal, Poolrooms grand hall/floaties/girl, full-screen Dr Cross excerpts and intro are retained from version 3. Gameplay uses the production enemy assignments: Office hound, School veiled matron, Poolrooms girl, Annex trenchwalker, and normal dark-roster monsters in the Casino and Server Rooms. The six traversal shots retain normal 3.4 m/s player movement with head bob and handheld motion disabled. Their trajectory and roster checks remain valid in `capture-verification.json`.

All gameplay, actors and effects were rendered in Godot from this working copy, with VHS on and CRT off. Encounters were staged in isolated `--test-mode` sessions. No generated stand-in gameplay is used. Production game files and campaign progress are not edited.

## Timeline

| Time | Footage |
| --- | --- |
| 00.00–02.00 | Opening title |
| 02.00–03.97 | Dr Cross warning, full screen |
| 03.97–06.47 | Casino shadow monster kill |
| 06.47–09.47 | Feature card: FAMILIAR PLACES. UNFAMILIAR HORRORS. |
| 09.47–13.47 | Walk through the casino |
| 13.47–16.97 | Walk through the office and connecting doorway |
| 16.97–20.97 | Walk around the grand Cistern pool |
| 20.97–22.97 | Flamingo and mattress floaties |
| 22.97–26.47 | Poolrooms girl approaches along the deck |
| 26.47–29.47 | Feature card: YOUR LIGHT IS A WEAPON. |
| 29.47–31.97 | Office hound kill |
| 31.97–34.97 | Walk down the school corridor |
| 34.97–37.47 | Veiled matron kill |
| 37.47–40.47 | Traverse the server room |
| 40.47–42.47 | Server-room shadow monster kill |
| 42.47–45.47 | Walk through the Annex corridor |
| 45.47–48.47 | Feature card: THE BUILDING IS ALIVE. |
| 48.47–52.97 | Travelling hallway wave |
| 52.97–56.97 | Breathing Annex wall |
| 56.97–60.57 | Door appears and disappears |
| 60.57–63.57 | Feature card: LOOK INTO YOUR NEXT NIGHTMARE. |
| 63.57–68.07 | Photograph and next-level preview portal |
| 68.07–71.57 | Dr Cross final statement, full screen |
| 71.57–74.07 | Caught by the Annex trenchwalker |
| 74.07–79.57 | Title, tagline, Steam message and creator credit |

## Delivery and rebuild

The export is H.264 with stereo AAC and web playback enabled. `edit.json` records the frame-accurate timeline and card copy. `audio-edit.json` records the sound mix; `verification.json` documents the finished export checks. `feature-cards.jpg` and `shot-contact-sheet.jpg` provide visual overviews.

`tools/edit_promo.py` builds the version 4 edit from the original Godot image sequences. Version 3 gameplay remains in `build/promo-trailer-v3`; Dr Cross footage and synthesized game audio remain in `build/promo-trailer`. Version 4's high-bitrate picture intermediate and lossless audio master are in `build/promo-trailer-v4`. No gameplay recapture was needed for this revision.

The editor uses Pillow, NumPy and `/usr/local/bin/ffmpeg`. The capture tools remain `tools/trailer_capture.gd` and `tools/render_promo.py`; Godot needs access to the macOS graphics session. Earlier metadata is retained in `v1-metadata`, `v2-metadata` and `v3-metadata`.
