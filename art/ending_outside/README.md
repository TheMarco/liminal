# “OUTSIDE” reference pack

Reference and continuity frames for `docs/ENDING_CUTSCENE_SCRIPT.md`.

## Production set

- `00_game_elevator_closed_reference.png` — authoritative game screenshot for the actual closed doors. The HUD and CRT distortion are reference artifacts, not part of the generated source.
- `00_game_elevator_interior_reference.png` — authoritative game screenshot for the car interior and limited half-open door travel.
- `00_intro_casino_reference.png` — authoritative Desert Oasis image from the intro.
- `09_elevator_closed_clean.png` — clean rectilinear start frame with the exact warm door language and no HUD.
- `10_elevator_half_open_wasteland.png` — same car with the doors stopped half-open, facing away from the hotel.
- `11_casino_lookback_open.png` — first look back at the ruined Desert Oasis with the elevator open in its entrance.
- `12_casino_lookback_closing.png` — same view as the last elevator light closes.
- `13_final_wasteland.png` — final view facing away from the hotel.

Files `01_` through `08_` are superseded visual explorations. They are retained as alternates but must not be supplied to SeeDance for the production sequence.

## Non-negotiable image rules

- Clean rectilinear 16:9 source; no CRT curvature, barrel distortion, television mask, scanlines, vignette, chromatic fringing, VHS noise, or generated HUD. The game applies its post-process after compositing.
- No visible player, hands, body, shadow, reflection, or footprints.
- Elevator doors use the game's warm orange-brown flat panels and only open halfway. Both leaves remain visible.
- The first exterior view faces away from the hotel. The Desert Oasis appears only when the camera later turns around.
- Wrecked cars and old human remains are sparse, static, non-graphic evidence. No living figures, zombies, fresh blood, or disaster spectacle.

## Final ImageGen prompt set

### `09_elevator_closed_clean.png`

```text
Reconstruct the exact closed in-game elevator from the supplied open and closed screenshots as a clean rectilinear 16:9 source frame. Preserve the warm orange-brown flat door panels, narrow center seam, dark vertical details, inward-sloping jambs, chrome side rails, lower threshold, centered first-person camera, and modest warm game-rendered materials. Remove all HUD and text. No CRT curvature, barrel distortion, television mask, vignette, scanlines, phosphor texture, chromatic fringing, VHS noise, bloom overlay, player, figure, opening, exterior, or watermark.
```

### `10_elevator_half_open_wasteland.png`

```text
Using the clean closed frame as the exact base, slide each existing warm brown door leaf outward by only roughly half its own width and stop. The central opening is about half the total doorway width and substantial portions of both panels remain visible. Through the opening show a broken yellow-striped road disappearing into shallow black floodwater and wet ash, with three or four sparse abandoned car wrecks and a few distant old non-graphic human remains. The Desert Oasis is behind the camera and absent. Preserve the elevator camera, walls, rails, threshold, and lighting. Clean rectilinear source only; no CRT/VHS treatment, HUD, living figures, gore, or watermark.
```

### `11_casino_lookback_open.png`

```text
Create the first look back after the player has left the elevator. Preserve the exact Desert Oasis casino identity from the intro: full massing, central canopy, tall roadside sign, parking relationship, road, and mountains. The hotel is ruined, flooded and lightless. The half-open warm elevator is physically inset beneath the central entrance canopy and is the only habitable-looking light. Add three or four sparse wrecked cars and a few distant old non-graphic human remains in the drowned parking lot. Clean rectilinear 16:9 first-person source; no CRT/VHS treatment, player, living people, active vehicles, gore, supernatural effects, HUD, or watermark.
```

### `12_casino_lookback_closing.png`

```text
Edit only the inset elevator in the casino look-back frame. Move its two warm brown leaves inward until almost closed, leaving one narrow vertical slit of dirty warm-white light, and reduce only the corresponding parking-lot reflection. Preserve the camera, casino, signage, wrecks, remains, flooded lot, road, mountains, sky, exposure, and every other object. Clean rectilinear source with no CRT/VHS treatment, new objects, gore, HUD, or watermark.
```

### `13_final_wasteland.png`

```text
Final clean rectilinear 16:9 first-person frame facing away from the Desert Oasis. The casino and elevator are behind the camera and absent. A last yellow-striped road remnant disappears completely under shallow black floodwater and wet charcoal ash. Three or four abandoned car wrecks sit at varied distances. A few old non-graphic human remains are small, weathered and partially obscured. Beyond them is only a flat empty horizon beneath a near-black low sky, with no destination, road, structure, light, or future. No CRT/VHS treatment, player, living figures, zombies, active cars, city, rescue signal, fresh blood, gore, text, HUD, or watermark.
```
