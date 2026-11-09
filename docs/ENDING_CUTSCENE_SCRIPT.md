# Ending cutscene: "OUTSIDE"

**Status:** Shipped in-game 2026-10-17 (`videos/outro/outside.ogv`, 94.7s).
Supersedes the 2026-09-10 plan (warm-brown car, half-open doors, doors
closing in the player's face).
**Canon:** `docs/STORY.md`, "Outro sequence". Read it before changing the
story of this sequence.
**Format:** First person, 16:9, 1920x1080, 24 fps, no dialogue, no text.
**Visible player:** Never. No hands, body, shadow, reflection or footprints.

This document is the production record: what the film is, how every piece
was made, and how to change any part of it without redoing the rest. Every
prompt is in `art/ending_outside/v2/PROMPTS.md` (verbatim, with inputs and
costs); every file is listed in `art/ending_outside/v2/README.md`.

## What the ending says without saying it

You got out. Nothing got better. The rooms were keeping you from this.

The last beats carry the implication: the arrival chime calls from behind,
the lift stands open and lit in the ruined entrance, and it waits. The player
turns away anyway and walks to where the road goes under the water. Behind
them, unseen, it closes. Nothing in picture, sound or text states the motive.

## The film

| Time | Shot | Picture | Sound |
| --- | --- | --- | --- |
| 0:00 | E1 Last stop (engine) | Inside the real brushed-steel arrival car, doors closed. Settle, stillness, doors open fully at the game's speed onto the underside of the ruined porte-cochère and a dead pale sedan where the intro's car parked. | Lift motor tail, cabin hum, the game's arrival ding (2.48s) and door chime (2.56s). |
| 0:09.5 | E2 Outside | Walk out of the car and under the canopy, around the wreck. | Steps on the car floor (marble) then wet concrete; cabin hum recedes. |
| 0:18 | E3 Road | Down the drowned access road. | Wet steps every 0.9s; a low exterior pressure bed fades in. |
| 0:30.5 | E3b Drowned road | Light failing, the road runs into still floodwater that mirrors the sky; stop short of it, look left and right, face the water. | Steps stop when the camera stops. |
| 0:46.2 | E4 The chime | Hold. Far behind, the arrival chime. Turn right: the Desert Oasis in the intro's hero framing, dead, except the open lit lift at the right-end entrance. Hold. | Distant ding + chime (low-passed, slapback), then the lift's faint hum. |
| 1:00.9 | E5 Away | Hold on the lit lift. Turn left, back to the water. | The faint hum continues. |
| 1:13.6 | E6 Waterline | Walk the last metres to where the yellow line goes under. Stop. | Steps; at 7.5s the door chime far behind, at 8.4s the leaves meet and the hum stops. |
| 1:25.7 | Tail | Hold the last frame 4s, fade to black over 3s, 2s of silent black. | Silence under the fade. |

Then the game's `OUT` summary rises from black.

## How it was made

Anything that exists in the game comes from the game; everything outside is
generated and chained frame to frame.

1. **Engine plate, E1** (`tools/outro_capture.gd`, on the trailer v7
   director). The real arrival car at the real door speed and easing.
   Everything outside the car is hidden, so the steel reflects nothing of the
   casino; a cold spotlight stands in for the dead exterior. Through the doors
   sits a screen-aligned backdrop carrying a painted exterior plate, sized to
   the camera frustum so the plate lands pixel for pixel.
2. **Stills** (Hedra, Nano Banana Pro). Made by editing real frames (the
   engine render, intro movie frames, cut frames from earlier clips) so
   camera, perspective and geography carry over. The exterior plate is a
   three-step edit chain from the engine's grey-backdrop frame.
3. **Clips** (Hedra, Seedance 2.5, "Use Frames"). Each clip starts on the
   exact frame where the previous one is cut. Stills pin destinations as end
   frames (`f_end.png`, `l1_lookback_matched.png`, `f_edge_matched.png`).
4. **Edit and sound** (`tools/ending_outside_assemble.py`). Trims, joins, the
   tail, and a mix built only from the game's own sounds. Seedance's audio is
   discarded.
5. **Encode and hook** (ffmpeg2theora to `videos/outro/outside.ogv`; played by
   `main._play_descent_outro()`).

Total generation cost: 20,089 Hedra credits (97,865 to 77,776), including
rejected takes.

### Continuity chain

```
E1 engine ── last frame ──► E2 ── frame 204 ──► E3 ── frame 300 ──► E3b ──► f_end.png
                                                                     ▲            │
f_end.png ──► E4 ──► l1_lookback_matched.png ──► E5 ──► f_end.png ──► E6 ──► f_edge_matched.png
```

`f_end.png` (the road running into still water) is the hinge: E3b ends on it,
E4 starts on it, E5 ends on it, E6 starts on it. Changing it means
regenerating E3b, E4, E5 and E6.

## Rebuilding

All commands from the repo root.

**1. E1, the engine shot** (only if the car, its timing, or the exterior plate
changes). Renders 228 PNG frames at 24 fps; then encode them to the clip the
edit reads:

```
godot --path . --minimized --audio-driver Dummy --fixed-fps 24 \
  --disable-render-loop --script tools/outro_capture.gd -- --nologo \
  --test-mode --seed=21 --descent-floor=1 --shot=outro_open --frames=228 \
  --out=/tmp/outro --look=clean --no-handheld --fov=77 --plate-gain=0.8 \
  --fps=24 --plate=$PWD/art/ending_outside/v2/e1_plate.png
ffmpeg -framerate 24 -i /tmp/outro/outro_open/frame-%04d.png -c:v libx264 \
  -crf 13 -preset slow -pix_fmt yuv420p art/ending_outside/v2/clips/e1_engine.mp4
cp /tmp/outro/outro_open/frame-0227.png art/ending_outside/v2/e1_last_frame.png
```

Without `--plate`, the doorway shows flat grey: that is the base frame for
painting a new exterior (`e1_base_open.png`). `--open-at=S` moves the door
opening (default 2.6s); `--back=M` moves the eye back from the arrival stand
point (default 0.75m). It must run with `--look=clean` (no tape pass, no NTSC
signal) or the plate comes out at 540x360 signal resolution. If E1's last
frame changes, E2 must be regenerated from it.

**2. The film.**

```
python3 tools/ending_outside_assemble.py
```

Writes `deliverables/ending-outside/outside.mp4` (intermediates in
`build/ending-outside/`, both gitignored); about 4 minutes. `--upto E3`
builds a partial cut for checking; `--out PATH` writes elsewhere.

**3. Encode and import.**

```
ffmpeg2theora deliverables/ending-outside/outside.mp4 --videoquality 8 \
  --audioquality 6 -o videos/outro/outside.ogv
godot --headless --path . --import
tools/run_audits.sh -f descent_outro
```

Homebrew ffmpeg cannot encode Theora. If ffmpeg2theora fails with a missing
`libx265.NNN.dylib`, Homebrew has moved x265 under the `ffmpeg@4` it links:
`HOMEBREW_NO_INSTALL_CLEANUP=1 brew upgrade ffmpeg@4` (this happened on
2026-10-17; 4.4.8_2 fixed it).

## Changing things later

**Re-time or swap footsteps.** `WALKS` in the assembly script holds the
spans where the camera moves, in seconds into each shot, with the surface
(`marble`, `wet`). They were read off each clip's frame-difference motion
profile:

```
python3 -c "import subprocess,numpy as np; f=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i','CLIP.mp4','-vf','scale=96:54,format=gray','-f','rawvideo','-']),np.uint8).reshape(-1,54,96).astype(float); d=np.abs(np.diff(f,axis=0)).mean(axis=(1,2)); print(' '.join(f'{d[i:i+12].mean():.1f}' for i in range(0,len(d),12)))"
```

Each number is half a second; motion shows as values well above the ~0.2
noise floor. `STEP_INTERVAL` (0.9s) sets the pace and `STEP_GAIN` the level.
Steps are single footfalls cut from the game's walking loops by
`single_steps()` (the loops themselves walk every 0.44s, which read as too
fast against Seedance's slow glide).

**Move the chime or the close.** `CALL = ("E4", 1.5)` and `CLOSE = ("E6", 7.5)`
are seconds into a shot. The close is the game's own sequence when you walk
away from an arrival car (door chime, doors shut in 0.9s, the leaves meet);
the distant hum runs between the call and the moment the leaves meet.

**Change levels or the sound bed.** All in `sound()`: cabin hum envelope,
arrival cues at E1, the far call/close filter chain
(`lowpass=f=2600,aecho=...`), the exterior bed (shaped noise at 0.0045,
around -63 dBFS). The final mix peaked at -9 dBFS.

**Replace one generated shot.** Generate it with the same start frame (and
end frame, if it has one) listed in `PROMPTS.md`, download it into
`art/ending_outside/v2/clips/`, point its `SHOTS` entry at it, rebuild,
encode. As long as the new take starts and ends on the same keyframes,
nothing around it changes. If it does not land on its end frame, the next
shot needs regenerating from its real last frame instead.

**Trim a take.** `SHOTS` entries are `(name, file, first frame, frame
count)`. If a trim moves, the next clip no longer starts on the right frame:
export the new cut frame (`ffmpeg -i CLIP -vf "select='eq(n\,N)'"
-fps_mode passthrough -frames:v 1 cut.png`) and regenerate the next shot from
it.

**Static joints.** At E3b-E4, E4-E5 and E5-E6 both sides are holds, and a
take never lands exactly on its end frame, so a hard cut shows a small pop.
`BLEND_IN` gives those shots an 8-frame cross-blend; joints in motion stay
hard cuts. All joints were checked by frame difference: none exceeds the
motion around it by more than ~0.5 on a 0-255 scale.

**Change the look-back.** `l1_lookback.png` is the last of a three-step edit
chain (S4 to S6 in `PROMPTS.md`). Its geography is fixed by the owner: the
lift stands in the porte-cochère at the hotel's right end (the intro car's
entrance, `ref_intro_canopy_from_lot.png`), never under the sign or in the
lot. After editing, re-run the colour match against `f_end.png` (see the v2
README) and regenerate E4 and E5.

**Make the in-game version longer, shorter or later.** `HOLD`, `FADE`,
`BLACK` set the tail. The summary appears after the movie, rising from black
(`main._show_descent_summary(won, from_black)`).

## In the game

- `scripts/main.gd`: `OUTRO_PATH`, `_play_descent_outro()`, and
  `_on_descent_ended()` awaits the ending before the summary when `won`.
  The movie is loaded on demand, not preloaded.
- `scripts/descent_intro.gd`: the prologue player takes an optional stream
  and Skip label, so the ending inherits every gate built for the prologue
  (pause, keyboard capture, presence). It is stored in `main._descent_intro`
  while it plays.
- Skip ("SKIP ENDING") appears only after one full viewing on that machine,
  stored as a completed video in `IntroPlaybackState` (`user://intro_playback.cfg`).
- `tools/audit_descent_outro.gd` (registered as `descent_outro`): a won run
  starts the ending with the right stream, the summary waits for it, then
  rises from black, and a full viewing unlocks Skip. Runs in test mode, so it
  never touches the player's playback file.
- Export: `videos/outro/outside.ogv` ships (about 41 MB). `art/ending_outside/*`
  and `deliverables/*` are excluded from export.

**Known seam.** The run ends at the Bloom exit door, and the film opens inside
the elevator car with its doors closed. There is no shot connecting the two.
Options if it jars: end Bloom in an elevator instead of a door, or add an
engine-rendered beat of the door closing to black before E1.

## Prompting rules learned

- One paragraph per prompt: Enter in Hedra's box submits immediately.
- Describe motion as the camera's ("the camera moves slowly forward at a tired
  walking pace"). "The unseen viewer takes steps" produced a third-person
  figure wading into the water.
- Never ask for "black floodwater": it rendered as a matte black void. Ask
  for "perfectly still shallow water that mirrors the sky and the mountains".
- No wading: ripples were faked as rings ahead of the camera. End on dry
  ground at the waterline instead.
- Give every clip that must arrive somewhere an end frame, and say "arriving
  exactly on the end frame". Without one, takes drift (E2 walked into the
  wreck; E3 let the road run clear to the horizon).
- Grade keyframes to the same exposure and colour as the neighbouring clip
  before uploading, or the clip spends its seconds fading between them.
- Edit real frames rather than generating from text: the engine render, intro
  frames and cut frames keep perspective and geography consistent.
- Seedance renders the steel car from a single frame well, but the engine is
  the only source that gets the doors, their travel and their timing right.

## Acceptance test

Viewers should understand, without words:

1. The lift brought the player back to what is left of the real world.
2. The Desert Oasis is where it all started, and it is dead.
3. The lift waited for them; they walked away; it closed.
4. Outside has evidence of people but no one, no route, no rescue, no future.
