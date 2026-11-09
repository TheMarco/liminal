# Intro cutscene: "DESERT OASIS"

**Status:** In the game 2026-10-20: the owner's own edit of the assembled cut
described below, exported as `deliverables/intro-desert-oasis/intro.mp4.mp4`
(1920x1080, 25 fps, 99.5s) and encoded to `videos/intro/liminal_intro.ogv` at
1280x720 (25.7 MB), played by `scripts/descent_intro.gd` as the Descent
prologue (same path and import uid as before). Since 2026-10-20 the movie
plays inside the game frame, so the player's VHS and CRT presentation (by
default the VHS signal plus the automatic CRT) processes it like gameplay, while
Skip, Pause and subtitles stay crisp above it (`DescentIntro`'s `recorded`
argument; the ending passes `false` and plays clean). `deliverables/` is gitignored:
that export exists only on the owner's machine, and
`tools/intro_assemble.py` writes `intro.mp4`, never the edit. To re-encode it:

```
ffmpeg2theora deliverables/intro-desert-oasis/intro.mp4.mp4 --max_size 1280x720 \
  --videoquality 7 --audioquality 6 -o videos/intro/liminal_intro.ogv
godot --headless --path . --import
```

**Canon:** `docs/STORY.md`. The ending (`docs/ENDING_CUTSCENE_SCRIPT.md`)
returns to these places in ruin.

## The owner's cut

The previous intro (2026-08-07, commit `e0950c5`) is kept, picture and sound,
up to 1:01.1: the drive with the radio, the sign, the canopy, Cross's license
(the original card) and the camera tilting up from the curb. From there the
tilt carries on to new glass doors with the game's casino behind them, and
everything inside is new: the game's slot room, its stools and pink neon, and
the game's brushed-steel elevator car, whose doors close at the game's speed.

An all-new version (Seedance drive and pull-in, the new license tracked into
the old pickup take) was built first and rejected by the owner on 2026-10-20
in favour of the original's exterior. Its clips and tools are kept (see
"Not in the film").

## The film (as assembled, before the owner's edit)

| Time | Shot | Picture | Sound |
| --- | --- | --- | --- |
| 0:00 | O, previous intro | Frames 0-1527 as they were: the drive at sunset, the sign, across the lot, under the canopy, the license on the asphalt picked up, read and put back, the camera tilting up from the curb. | The previous intro's own track (radio, then the night outside). |
| 1:01.1 | T, tilt-up (Seedance) | The tilt continues from the curb up to the new glass doors and settles. | The old track hands over (0.5s) to still night air and the canopy's neon hum. |
| 1:04.7 | I4, doors (Seedance; blends in over 8 frames) | Through the open door into the game's casino, cut while still walking. | Concrete steps, then carpet; the casino's room tone and slots open up at the threshold (1:09.9). |
| 1:14.1 | I5, lift (engine; starts on I4's framing and walking, blends in over 4 frames) | The slot aisle, the open steel car at its end, walk in, turn round, hold on the casino, the doors close, the car starts to move. Fade to black. | Carpet steps, the car's floor, the cabin hum; the door chime (1:35.3), the casino cut off when the doors meet, the brake, the hoist. |
| 1:39.7 | Tail | Black, 1s. | Silence. |

Then the game opens on the arrival car on floor 1.

## How it was made

1. **The cut point.** Frame 1527 is the last frame of the original's tilt-up
   that shows only sidewalk and curb; its own (different) doors enter the top
   of the frame two frames later.
2. **T** (Hedra MCP, Seedance 2.5, 480p, 21:9, 4s): start frame = original
   frame 1527 (letterbox cropped off), end frame = K6 cropped to 21:9
   (`stills/k6_glass_doors_21x9.png`, rows 105-695 of the 1376x768 still).
3. **I4** (Seedance, 480p, 16:9, 12s): K6 to the engine plate's first frame,
   through the doors. Its first second (standing still) is left out, since T
   already settles on the doors, and so is everything after frame 262: the
   clip stops dead at frame 265 and stands for a second, which with the
   engine shot starting from rest read as a stop and a lurch at 1:15 (owner:
   "1:15-1:16 is not smooth").
4. **I5** (engine, `tools/intro_capture.gd --shot=intro_lift`): seed 21, floor
   1, the second slot room out from the origin (cell (-1, 0)) with the game's
   own car (`Chunk._descent_car_shell`) built against its +X wall at the end of
   the central aisle; the path leaves frame 0 already walking
   (`WALK_START_SPEED`, 0.9 m/s, a cubic Hermite over the first stretch, so
   frame 0 itself is unchanged), glances across the banks, walks the aisle
   into the car, turns, holds, closes the doors at frame 530 at the arrival
   speed and moves off at frame 572.
5. **Edit and sound** (`tools/intro_assemble.py`). The new shots are cropped
   to the original's letterbox (I4 with K6's crop, I5 centred) and their 24 fps
   frames are played one for one at the original's 25 fps (4% faster; cue
   times are scaled to match). Static joints are blended (`BLEND_IN`). I4's
   last frame sits 2.7% closer than I5's first (SIFT and a similarity fit:
   scale 0.9734, shift 19, 18 px at 1280x548), so I5 starts on that framing
   and eases back to its own over 36 frames (`ALIGN`); a plain crossfade
   doubled the slot machines. The correction rides on I5 because the engine
   plate has picture above and below the letterbox to zoom into.
6. **Encode and hook** (ffmpeg2theora to `videos/intro/liminal_intro.ogv`).

Generation cost over the whole redo: 1,375 Hedra credits (13,523 to 12,148),
of which the film uses T (84), I4 (250) and the keyframe stills; the rest went
to the rejected all-new version.

## Rebuilding

All commands from the repo root.

**1. I5, the engine shot** (only if the set, the path or the car changes;
about 25 minutes):

```
godot --path . --minimized --audio-driver Dummy --fixed-fps 24 \
  --disable-render-loop --script tools/intro_capture.gd -- --nologo \
  --test-mode --seed=21 --descent-floor=1 --shot=intro_lift --frames=640 \
  --set=1 --wall=0 --out=/tmp/intro --look=clean --no-handheld --fov=77 --fps=24
ffmpeg -framerate 24 -i /tmp/intro/intro_lift/frame-%04d.png -c:v libx264 \
  -crf 18 -preset slow -pix_fmt yuv420p art/intro_v2/clips/i5_engine.mp4
cp /tmp/intro/intro_lift/frame-0000.png art/intro_v2/k7_engine_first.png
```

`--jpg --scale=0.5` makes a fast draft; `--shot=intro_scout` renders stills of
any set (`--set`, `--wall`). If frame 0 changes, I4 must be regenerated to land
on it.

**2. The film.** `python3 tools/intro_assemble.py` writes
`deliverables/intro-desert-oasis/intro.mp4` (intermediates in
`build/intro-desert-oasis/`; it pulls the previous intro out of git history
on first run). About a minute.

**3. Encode and import.**

```
ffmpeg2theora deliverables/intro-desert-oasis/intro.mp4 --videoquality 7 \
  --audioquality 6 -o videos/intro/liminal_intro.ogv
godot --headless --path . --import
tools/run_audits.sh -f intro_playback
tools/run_audits.sh -f story_subtitles
```

The original, for comparison: `deliverables/intro-desert-oasis/original_intro.mp4`
(or `git show e0950c5:videos/intro/liminal_intro.ogv`).

## Working with Hedra from here

The Hedra MCP generates, but cannot read or write files on this machine, and
this repo's session permissions refuse inline commands that carry the API key
or Hedra's presigned links. Two allowed scripts do the transfers:

- `tools/hedra_upload.sh FILE...` posts files to Hedra (`/v3/files`) with the
  key from the gitignored `.env` and logs the handles to
  `art/intro_v2/upload/uploads.jsonl`. Handles last an hour.
- `tools/hedra_download.sh LIST DEST` downloads `FILENAME<TAB>URL` lines (the
  presigned links the MCP returns) from a gitignored list file.

Jobs made through the MCP are invisible to the API key (`GET /v3/jobs/{id}`
is a 404); `tools/hedra_fetch.sh` (by job id) only works for jobs made with
the key. Hedra's moderation refuses to render driver's licenses or ID cards.

## Changing things later

**Move the cut.** `SHOTS[0]` keeps that many frames of the original. A new cut
frame needs a new T generated from it (start frame) to K6 (end frame).

**Replace a generated shot.** Same start and end frames (`PROMPTS.md`),
download over the clip, rebuild, encode. Check joints by frame difference: a
joint in motion can be a hard cut, one on a still frame needs `BLEND_IN`.

**Steps and cues.** `WALKS`, `THRESHOLD`, `ENTER`, `DOORS`, `DEPART` are in
each new shot's own seconds at 24 fps (I4's are already shifted for its
trimmed first second); `at()` puts them on the film's clock.

**Levels.** The new part: night air -46 dBFS, neon -50, casino room tone -46
and slots -42 (near the original's own interior, -40 to -47), steps by
`STEP_GAIN`; the mix peaks at about -5 dBFS.

## Not in the film

From the rejected all-new version, kept for the record: `clips/i1_drive.mp4`,
`clips/i2_pullin_v2.mp4`, `clips/rejected/i2_pullin_v1_pitch.mp4`,
`clips/i3_license.mp4` and `tools/intro_license_track.py` (the new card
tracked into the original's pickup take with OpenCV, run with
`liminal_env_lab/.venv/bin/python`). The owner's notes on it: the turn into
the lot looked like the car lifting (fixed in v2 with a level-camera prompt),
the license as stills "sucks compared to the original", and the slowed start
of the pull-in read as a freeze.
