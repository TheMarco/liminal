# Ending cutscene — “OUTSIDE”

**Status:** Production script for SeeDance 2.5  
**Format:** Four continuous first-person clips, 16:9, approximately 109 seconds through full black  
**Dialogue:** None  
**Visible player:** Never. No hands, body, shadow, reflection, or footprints.

## Dramatic intent

The outro begins inside the elevator exactly as it behaves during the game. The warm brown doors are closed. The car settles, the arrival chime sounds, and the two leaves open only halfway. Through the narrow opening is whatever remains of the real world.

The player steps out facing away from the Desert Oasis hotel. The casino is not visible yet. Ahead is a drowned desert: a broken road that vanishes into black water, scattered wrecked cars, and the old remains of people who had nowhere to go. There is no active threat. The world has already ended.

Only after searching the exterior does the player turn around. The casino from the intro is behind them, recognizable but ruined and lightless. The elevator is set into its entrance. Its small warm interior is the only dry, finite, habitable-looking place left. The doors close before the player can return.

The player finally turns away from the hotel and walks into the waste. Escape succeeded. Life was better in the rooms.

The horror comes from the loss of shelter, direction, community, and future—not from a monster, jump scare, lore reveal, or disaster spectacle.

## Current reference pack

| File | Use |
| --- | --- |
| `art/ending_outside/00_game_elevator_closed_reference.png` | Authoritative in-game closed-door geometry; HUD/CRT reference only |
| `art/ending_outside/00_game_elevator_interior_reference.png` | Authoritative warm car, rails, jambs, threshold, and half-open travel |
| `art/ending_outside/00_intro_casino_reference.png` | Authoritative Desert Oasis identity and intro geography |
| `art/ending_outside/09_elevator_closed_clean.png` | Clean rectilinear starting frame, no HUD or CRT shader |
| `art/ending_outside/10_elevator_half_open_wasteland.png` | Correct limited door travel and first exterior reveal |
| `art/ending_outside/11_casino_lookback_open.png` | First look back: ruined casino, wrecks, remains, open elevator |
| `art/ending_outside/12_casino_lookback_closing.png` | Same view with the last elevator light reduced to a slit |
| `art/ending_outside/13_final_wasteland.png` | Final forward view, away from the hotel |

Use each previous clip's actual final frame as the next clip's start image whenever SeeDance permits. The stills establish continuity; they are not mandatory hard cuts.

## Global generation rules

Apply these to every generated clip:

- One continuous first-person shot with no edits inside the segment.
- Clean rectilinear 16:9 source plates. No CRT curvature, barrel distortion, fisheye, rounded television mask, vignette, scanlines, phosphor dots, chromatic fringing, VHS noise, or generated HUD. The game applies its CRT/camcorder shader after compositing.
- Eye height approximately 1.65 m; 26–30 mm rectilinear lens; restrained human head movement without action-camera shake.
- Photorealistic, physically grounded 3D survival-horror rendering compatible with the supplied game screenshots.
- The elevator retains the actual warm orange-brown flat panels, inward-sloping jambs, chrome side rails, lower threshold, and limited door travel. It must not become a modern silver or luxury elevator.
- On opening, each elevator leaf slides outward by roughly half its own width and stops. The central opening is only about half the total doorway width. Both leaves remain visibly framing it.
- The Desert Oasis retains its intro massing, roadside sign, frontage, parking relationship, and mountain geography. It is seen only after the player turns back.
- The exterior contains sparse car wrecks and scattered old human remains. They are evidence of extinction, never fresh gore, a foreground close-up, or the primary subject.
- Exterior exposure is extremely dark but readable. A dirty gray-peach horizon may recall the intro sunset but cannot resemble a hopeful dawn.
- No living people, standing figures, zombies, creatures, birds, active vehicles, headlights, traffic, rescue signals, city glow, fire, lightning, or habitable distant structures.
- No text overlays, subtitles, watermarks, or added signs. Preserve only existing Desert Oasis signage when the casino is visible.
- Stillness is the dominant rhythm. Nothing approaches the player.

## Picture and sound script

### Segment 1 — “Last Stop” — 27 seconds

**References:** Start on `09_elevator_closed_clean.png`; end at `10_elevator_half_open_wasteland.png` before stepping through.

| Time | Picture | Sound |
| --- | --- | --- |
| 00:00–00:04 | Locked first-person view of the actual warm brown elevator doors, fully closed. The car finishes its final descent and settles by a few centimeters. | Familiar motor decelerates beneath the fluorescent ballast hum. No music. |
| 00:04–00:07 | The car becomes still. Nothing happens for two beats. | Motor stops. One ordinary arrival chime at 00:06. |
| 00:07–00:14 | The doors open at the game's normal speed, then stop at their real half-open position. Through the narrow central opening: broken road, black water, wet ash, wrecked cars, and distant human remains. The casino is behind the camera and completely absent. | Door motor and track rattle. Exterior contributes almost no ambience. |
| 00:14–00:20 | Hold inside the elevator. Let the player search the revealed strip of exterior without moving. The warm panels and rails remain prominent around the opening. | Elevator hum is still the loudest and most familiar sound. A directionless exterior pressure sits below it. |
| 00:20–00:27 | The camera advances through the half-width opening and takes three cautious steps onto the surviving road. The door leaves stay half-open behind the player. End fully outside, still facing away from the hotel. | Dry car floor becomes wet grit and shallow water. The fluorescent hum recedes behind the camera but remains audible. |

**SeeDance prompt**

```text
Create one unbroken 27-second first-person shot using the supplied clean closed-elevator frame as the exact first frame and the supplied half-open wasteland frame as the door-opening target. Preserve the game's actual warm orange-brown flat door panels, dark vertical details, inward-sloping jambs, chrome side rails, lower threshold, camera position, and warm fluorescent light. Begin with the doors fully closed. The car completes a small final downward settle and becomes still. Hold for two quiet beats, then at seven seconds open the two center-splitting leaves at an ordinary mechanical speed. Each leaf slides outward by only roughly half its own width and stops. The central opening is only about half the total doorway width, with substantial warm brown door panels still visible on both sides. Never fully retract or redesign the doors. Through the opening reveal the dead real world facing away from the Desert Oasis hotel: a broken yellow-striped access road disappears beneath shallow black floodwater and wet charcoal ash; three or four old car wrecks sit at varied distances; a few scattered human remains appear as small, non-graphic prone forms or weathered bones. Hold inside the car for six seconds, then the unseen viewer passes through the narrow opening and takes three cautious steps onto the road. The casino and hotel are behind the camera and never visible in this shot. Photorealistic grounded 3D survival-horror game rendering, 1.65-meter eye-level camera, 28 mm rectilinear lens, warm dry elevator against a colder extremely dark exterior. Clean source plate only: no CRT curvature, barrel distortion, fisheye, rounded TV mask, vignette, scanlines, chromatic fringing, VHS noise, HUD, text, or watermark. No visible player, hands, body, shadow, reflection, footprints, living people, standing figures, zombies, creatures, birds, active cars, headlights, traffic, buildings, signs, city glow, rescue lights, fire, lightning, fresh blood, gore, or supernatural effects.
```

### Segment 2 — “What Remains” — 26 seconds

**References:** Begin on Segment 1's final rendered frame; use `13_final_wasteland.png` for terrain, wreck and remains treatment, but retain the slightly lighter initial exposure.

| Time | Picture | Sound |
| --- | --- | --- |
| 00:00–00:06 | Hold on the broken road. Exposure sinks slowly. One wrecked car rests to either side; the nearest remains are visible but not emphasized. | Elevator hum remains faintly behind. No insects, birds, traffic, voices, or recognizable wind. |
| 00:06–00:13 | Walk five slow steps along the remaining yellow stripe. Asphalt passes under the camera, proving movement. The road then vanishes beneath black water. | Wet footsteps and small water displacement. No music. |
| 00:13–00:19 | Slow pan left and right across other car shells and scattered remains. Nothing moves. There is no skyline, road continuation, shelter, or distant light. | A loose piece of metal shifts once far away, then never again. |
| 00:19–00:26 | Return to the empty horizon and hold. The frame becomes darker, not because night falls visibly, but because the camera no longer has the elevator's warm spill. | Exterior pressure gradually overwhelms the last distant fluorescent hum. |

**SeeDance prompt**

```text
Create one unbroken 26-second first-person search facing away from the Desert Oasis hotel. Continue exactly from the prior clip's road position. Preserve the broken yellow-striped casino access road, shallow black floodwater, wet charcoal ash, wreck and remains locations, low horizon, camera height, and lighting continuity. Begin motionless while exposure falls slightly. The unseen viewer takes five slow steps along the last road stripe; foreground asphalt and water show real parallax, then the road visibly ends beneath the flood. Make one restrained searching pan left and right across three or four long-abandoned passenger-car wrecks, partly submerged or crooked in ash, and a few scattered old human remains. The remains are small, weathered, non-graphic, partially obscured, and never examined closely. Nothing moves. Reveal no functioning road, skyline, shelter, settlement, smoke, or light. Return to the empty horizon and hold. The casino stays behind the camera and never appears. Photorealistic grounded 3D survival-horror rendering, eye-level 1.65-meter camera, 28 mm rectilinear lens, extremely dark but readable. Clean source plate only: no CRT curvature, barrel distortion, fisheye, rounded TV mask, vignette, scanlines, chromatic fringing, VHS noise, HUD, subtitles, or watermark. No visible player, hands, body, shadow, reflection, footprints, living people, standing figures, zombies, creatures, birds, active cars, headlights, traffic, buildings, signs, city glow, rescue signal, fire, lightning, fresh blood, gore, or supernatural effects.
```

### Segment 3 — “Looking Back” — 26 seconds

**References:** Use Segment 2's final frame as the start; reach `11_casino_lookback_open.png`, then `12_casino_lookback_closing.png`.

| Time | Picture | Sound |
| --- | --- | --- |
| 00:00–00:07 | The camera turns around in one slow 180-degree movement. Only during the final third of the turn does the Desert Oasis appear. | The familiar elevator hum gradually returns during the turn. |
| 00:07–00:13 | Hold on the revealed casino from the intro. It is ruined, flooded, and lightless. Wrecks and remains occupy the parking lot. At the center entrance, the elevator is still half-open and warm. | One weak sign-transformer buzz fails. The elevator ballast continues. |
| 00:13–00:21 | The elevator doors begin closing from their half-open position. The camera moves back toward the hotel, increasingly urgent but never sprints. The ordinary doors do not react. | Wet steps quicken; quiet door motor and track rattle. No scare sting. |
| 00:21–00:24 | The player stops well short as the last thin vertical slit closes. | Padded metal contact, latch, then immediate loss of the fluorescent hum. |
| 00:24–00:26 | Hold on the casino. Its windows and entrance are completely black. | One relay click. Absolute silence. |

**SeeDance prompt**

```text
Create one unbroken 26-second first-person shot beginning in the dead exterior facing away from the hotel. Turn around in one slow continuous 180-degree movement. Do not reveal the casino until the final third of the turn. Then match the supplied look-back reference: the exact Desert Oasis from the intro is behind the player, recognizable by its casino massing and tall roadside sign, but ruined, flooded, weather-beaten, and lightless; old wrecked cars and scattered non-graphic human remains sit across the drowned parking lot. The final elevator is physically inset beneath the central hotel entrance canopy. It is not freestanding. Its actual warm brown doors remain only half-open, and its small warm fluorescent interior is the only habitable-looking room. Hold for recognition. At thirteen seconds, close those same door leaves from the half-open position at an ordinary, indifferent speed. The unseen viewer walks back toward the hotel with restrained urgency but remains far short when the last thin vertical slit of warm light disappears. The doors do not pause or respond. Hold on the completely dark hotel entrance. Preserve the supplied Desert Oasis architecture, sign identity, wrecks, remains, flooded lot, road, mountains, low sky, elevator placement, and camera continuity. Photorealistic grounded 3D survival-horror rendering, 1.65-meter eye-level camera, 28 mm rectilinear lens, extremely dark but readable. Clean source plate only: no CRT curvature, barrel distortion, fisheye, rounded TV mask, vignette, scanlines, chromatic fringing, VHS noise, generated HUD, subtitles, or watermark. No player, hands, body, shadow, reflection, footprints, living people, standing figures, zombies, creatures, active cars, headlights, city lights, fire, lightning, fresh blood, gore, or supernatural effects.
```

### Segment 4 — “Outside” — 25 seconds

**References:** Begin on Segment 3's final rendered frame; end at `13_final_wasteland.png`.

| Time | Picture | Sound |
| --- | --- | --- |
| 00:00–00:06 | Hold on the dead Desert Oasis. Nothing relights or opens. The building from the intro is now only another ruin containing no accessible shelter. | Silence. After four seconds, the exterior pressure returns. |
| 00:06–00:12 | Turn away from the hotel in one slow 180-degree movement. Reframe the broken road, wrecks, remains, and empty horizon. The casino leaves the frame permanently. | Small wet pivot. No casino or elevator ambience remains. |
| 00:12–00:19 | Take four slow steps forward. The last yellow stripe disappears under black water. There is no route to follow. | Four isolated wet footsteps. Remove rather than add environmental sound. |
| 00:19–00:25 | Stop in the final reference composition. Hold without camera drift or environmental change. This is not a puzzle or another floor. | The last footfall decays into silence. No wind and no music. |
| After clip | Hold the final frame for four additional seconds, fade to black over three seconds, then hold full black for two seconds before the normal `OUT` summary. | Let even the noise floor disappear during the fade. Full black is completely silent. |

**SeeDance prompt**

```text
Create one unbroken 25-second final first-person shot. Begin on the ruined Desert Oasis after its inset elevator has closed and gone completely dark. Hold on the dead hotel for six seconds; nothing relights, opens, moves, or answers. Then turn away in one slow continuous 180-degree movement. The casino leaves the frame and never appears again. Match the supplied final wasteland reference: a last strip of cracked yellow-striped road disappears beneath shallow black floodwater and wet charcoal ash; three or four abandoned car wrecks sit at varied distances; a few scattered old human remains are small, non-graphic, weathered, and partially obscured; beyond them is only a flat empty horizon under a near-black low sky. Take four slow steps until the last road stripe passes beneath the water, then stop. Hold completely still. This is not a route, puzzle, or new level. It is where the player is now. Photorealistic grounded 3D survival-horror rendering, 1.65-meter eye-level camera, 28 mm rectilinear lens, near-black cold palette, extremely dark but readable, no dawn and no warm light. Clean source plate only: no CRT curvature, barrel distortion, fisheye, rounded TV mask, vignette, scanlines, chromatic fringing, VHS noise, HUD, subtitles, text, or watermark. No player, hands, body, shadow, reflection, footprints, living people, standing figures, zombies, creatures, birds, active cars, headlights, buildings after the turn, road continuing through water, city glow, rescue signal, sun, moon, stars, fire, lightning, fresh blood, gore, or supernatural effects.
```

## Edit and transition notes

- Transition from live gameplay to Segment 1 on an exact match frame while the elevator doors are closed. Do not fade or cut to white.
- The door action is canonical: closed first, then normal opening motion, then a hard stop at half-open. Both panels remain visible. Do not let interpolation finish opening them.
- Use clean undistorted generated clips. Apply the game's CRT/camcorder shader once to the final composite so the outro matches gameplay without baking the effect twice.
- Use straight cuts between clips on static or nearly static frames. Avoid dissolves, which make the exterior feel dreamlike instead of real.
- Keep remains old and non-graphic. A few readable silhouettes are more disturbing than a field of bodies.
- Keep wrecks sparse enough that the player cannot read them as cover, supplies, or navigational objectives.
- The `OUT` summary appears only after full black. It should feel administrative and indifferent, never triumphant.
- Roll credits without music for at least ten seconds. Any later score remains sparse, tonal, and unresolved.

## Acceptance test

The ending works if viewers independently understand all four ideas:

1. The elevator genuinely returned the player to what remains of the real world.
2. The Desert Oasis was behind the player and becomes visible only when they look back.
3. The elevator and the rooms were terrible, but they were the last shelter.
4. Outside contains evidence of humanity but no surviving community, route, rescue, enemy to defeat, or future.

If the wrecks suggest loot or transport, damage and submerge them further. If the remains become spectacle, reduce their size and count. If the casino appears during the initial exit, the camera direction is wrong. If the doors fully retract, the animation is wrong. If straight walls bow at the edges, CRT distortion has been baked into the source and must be removed before the game's shader is applied.
