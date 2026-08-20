# Liminal — project brief for AI assistants

Godot 4.6.1 (Homebrew `godot`), macOS. First-person horror walker through
endless procedural liminal spaces. Two modes: **Wander** (peaceful, default
title screen) and **Descent** (the game: 11 floors down, rules, ghosts,
ritual). The visual bar is photorealism; verify by rendering, never by
reading code.

## Run and verify

```bash
# Play (Descent straight in, no title):
godot --path . -- --mode=descent --seed=7 --nologo

# Screenshot verification (renders ~2.5s, saves a frame, prints player pos):
godot --path . -- --mode=descent --seed=7 --nologo --pos=X,Z --yaw=DEG \
    --screenshot=/tmp/shot.png --nocrt

# The full audit suite (ALWAYS via the runner — a failed SceneTree audit
# hangs forever without its timeout):
tools/run_audits.sh                 # import pass + compile + 49 audits
tools/run_audits.sh -f descent      # filtered

# After adding assets or a new class_name script, ALWAYS:
godot --headless --path . --import
# or cold launches fail with "Could not find type X" parse errors.
```

- `--nocrt` for every visual-verification screenshot: the CRT filter hides
  what you are judging. Yaw convention: forward = (−sin yaw, 0, −cos yaw).
- Dev flags: `--play-tape` (auto-plays the ritual tape; needs `--pos` at the
  route target), `--passer` (rapid passing-shadow attempts), `--haunt-at`,
  `--attention=`, `--descent-floor=N`.
- `tools/find_cells.gd -- <seed> <theme>` scouts cell styles; a tiny route
  scout pattern: `DescentRoute.build(WorldGen.level_seed(seed, theme),
  theme, floor_idx)` printed from a throwaway SceneTree script.
- `tools/audit_world_hash.gd` is the refactor gate. Any change to generated
  geometry (including Descent target rooms) requires regenerating
  `tools/golden/world_hash.txt` with `-- --out=...` and eyeballing that the
  diff is only what you intended.
- The suite has 55 registered audits; there are no known tolerated
  failures. Do not edit .gd or .sh files while a sweep is running — audits
  torn-read mid-edit files and fail spuriously.

## Architecture in one paragraph

World gen is stateless: every cell/edge property is a pure hash of
(seed, coords) in `scripts/world_gen.gd`; cells are 12m; walls live on
canonical edges; cells cluster into rooms. `ChunkManager` streams `Chunk`s;
per-theme builders receive an immutable `ChunkBuildContext` plus the typed
`ChunkSceneWriter` construction boundary, never a live Chunk. Runtime objects
have stable semantic IDs and floor-scoped `ChunkRuntimeState`. Blackout changes
commit as typed `WorldMutation` transactions with staged scene swap and exact
rollback. `main.gd` orchestrates modes while transition, post-process, developer
tooling, and mutation state live in focused controllers. See
`docs/ARCHITECTURE.md`. Eleven live
themes: 0 casino, 1 office, 2 Annex, 4 airport, 5 asylum, 6 school, 7 mall,
8 prison, 9 Poolrooms, 10 Monolith, 11 Bloom/"the Upside Down" (theme id 3
was deleted; ids are never renumbered).

## Narrative canon

`docs/STORY.md` is the authoritative current narrative bible. Read it before
writing tape dialogue, changing Dr. Cross, altering the intro/outro, or adding
story explanations. Its ambiguity contract and fixed-camera, same-room Cross
monologue format govern the intro and ten elevator tapes; the outro is instead
a silent, first-person ending about the player's hopeless apparent escape.
These constraints are non-negotiable unless that document is deliberately
amended. Older narrative drafts are inspiration only where they do not conflict
with it.

## Descent — current design (2026-08-04, supersedes most of docs/DESCENT.md)

- **Run**: fixed order Casino, Mall, Office, Airport, School, Prison, Asylum,
  Poolrooms, Annex, Monolith, Bloom/Upside Down (exit passage instead of a
  lift). `DescentRun.FLOOR_COUNT = 11`.
- **Persistence**: Continue resumes the deepest unlocked floor with the same
  saved seed/building. Restart Descent starts floor 1 on that seed without
  lowering the deepest checkpoint. New Descent starts floor 1 with a new seed.
  Death respawns at the arrival elevator with clean state and a full flashlight.
- **One rule**: when the lights fail, stand still. Blackout movement past a
  2.6s→1.6s grace fills a locate meter → jump-scare death. Moving with the
  torch lit fills it 1.5× — standing still stays free with the torch on or
  off, so the caption's "the torch still works" promise holds. Standing still
  under working lights is free (the stop rule and the stare rule are both
  retired — do not reintroduce them). Sprint is enabled and legal: holding it
  feeds attention (`SPRINT_ATTENTION_RATE`), never the violation channel.
  Sprint spends a stamina reserve (`Player.STAMINA_MAX` 5s, refills over 10s,
  0.75s re-arm floor after full depletion so a held shift key cannot
  stutter); partial recharge is spendable.
- **Ghosts** (`shadow_figure.gd` / `shadow_figures.gd`): per-variant
  `TUNING` rows over a shared contract. Baseline: creep 1.25 m/s seen, close
  4.5 m/s unseen, 1.5s burn, unseen approach parks at 3.6m, three doorways of
  pursuit. Archetypes with debut floors (`ShadowFigures.DEBUT_FLOOR`): the
  Gaoler (floor 4+) creeps 0.9 but follows five doors; the Reacher (6+)
  parks at 2.4m and burns in 1.0s; the Drifter (7+) moves 1.6 seen or
  unseen. Every row must satisfy (park − 1.05) / creep ≥ burn — the
  burn-window invariant, enforced by the ghost room audit. A natural give-up
  only starts while ghost and player are in different rooms and is cancelled
  if they reunite; there are no timers, one-door escapes or stare-banishes.
  The unseen approach never completes a kill: it parks, and only the watched
  creep takes the last metres. A lit torch is a ward: figures loom at arm's
  length and cannot kill until it goes out. Spawns need only line of sight
  (corridors included). There are no unburnable or persistent special-case
  enemies; every hostile figure obeys these rules. `HorrorDirector` spaces
  encounters (recovery window after burns/escapes) and holds them during
  tapes and blackouts.
- **The ritual** (every non-final objective room): CRT+VCR altar
  (`vhs_ritual.gd`), charging station and lift are always co-located at the
  guided route target. The lift refuses entry until the floor's tape has been
  watched — the tape is the sole gate; charging is optional.
  Lift waits ramp 14s→34s with two authored breaks
  (`LIFT_WAIT_INSTANT_FLOOR` school ≈ instant, `LIFT_WAIT_LONG_FLOOR` asylum
  ≈ double). One lattice charging station per run is dead
  (`ChargingStation.broken`, floor seeded via
  `ChunkManager.BROKEN_STATION_FLOORS`): the press fakes a connect for 1.2s,
  collapses to a permanent OUT OF ORDER, captions "THE STATION IS DEAD" and
  forces an encounter behind the player. It never drains charge. Per-theme
  pacing lives in `DescentRun.THEME_MODS` (prison: frequent short blackouts;
  Monolith: sparse figures, long grace). Floors 1-3 ease both cadences
  (2026-08-19, because the photo hunt lengthened floors 2-3x): blackout
  intervals x1.9/1.5/1.2 and figure intervals x1.7/1.35/1.15
  (`DescentRun._schedule_blackout`/`figure_interval_scale`), flat authored
  cadence from floor 4; the runtime audit checks both ends. Post-photo
  danger is 70/22/8 (nothing/environment/encounter). Playing a tape
  dollies the camera onto the tube (footage fills the screen through
  `shaders/vhs_tape.gdshader`), freezes the player, holds all threats and
  pauses music/ambience; E/Esc cancels = rewind. Leaving the room cancels a
  called lift. Rare optional sets use the same full-screen playback without
  gating the lift: each route gets 2–3 over roughly 500m, and the endless
  off-route world continues at about one per 200m explored. `VhsTapeLibrary`
  discovers `videos/tapes/*.ogv`; recordings >=30s are ten fixed, lexically
  sorted chapters for objective floors 1–10. The optional pool is 21 authored
  shorts: six `short_beginning_*` clips completed in order, plus fifteen
  `short_random_*` clips in a persistent no-repeat cycle. `tape_06`–`tape_09`
  are reserved converted game assets and excluded from the Cross pool. Add one with `ffmpeg2theora INPUT.mp4 --videoquality 7
  --audioquality 3 --max_size 512x512 -o videos/tapes/tape_NN.ogv` (Homebrew
  ffmpeg cannot encode Theora or Vorbis), then document its source.
- **Phone**: 20s of light, drains only while on, refills only at stations
  (10s); interrupting a charge reverts to the session-start level.
- **HUD**: VHS camcorder viewfinder OSD (`VhsOsd`, bare shadowed VT323, no
  panels): corner brackets + blinking REC, battery glyph top-right, sprint
  meter bottom-left, distance-only "LIFT NNNm" counter top-centre with
  "PHOTOS n/3" under it. TV-safe since 2026-08-18: every element sits inside
  `VhsOsd.SAFE_FRACTION` (6% of each viewport dimension, marked by the
  brackets), the HUD scale is `VhsOsd.hud_scale` (viewport_h/720,
  unclamped), all text carries a same-ink `STROKE` outline plus hard shadow
  (`style_label` / `draw_osd_string`) so VT323 hairlines survive the tube,
  and no in-game text drops under ~32px at 720p. Verify OSD changes with a
  CRT-on screenshot, not `--nocrt`. There is no directional needle — finding the lift IS
  the level. Route bands: authored 26-34 edges (floor
  1) to 40-52 (floor 11), with floors 1-3 shortened by
  `DescentRoute.EARLY_SHORTEN` (x0.62/0.78/0.9 → floor 1 ≈ 16-21 edges;
  2026-08-19 teaching-floor pass; floor 4+ untouched — the airport audit
  depends on floor 4 crossing baggage claim).
- **Photography** (`photo_camera.gd` / `photo_director.gd` /
  `photo_anomaly.gd`): the phone is also the camera — C toggles it up and
  down, Space is the shutter (hold-RMB / LMB still work for mouse users);
  the torch state is untouched, so a lit
  torch keeps warding while shooting, and photos cost no charge. The
  camcorder is the detector: within 14m of an undocumented anomaly the OSD
  picks up interference (tracking bars, stuttering REC lamp, tape static
  from `SoundBank.static_hiss`, detector clicks that rattle faster as you
  close in) and the HUD blinks an amber "SOMETHING HERE IS WRONG" under
  the PHOTOS counter (`DescentHUD.set_photo_proximity`; the interference
  alone was invisible inside the tape look), camera raised or not, at 0.45
  weight through walls (`PhotoCamera.PROXIMITY_*`). Raising
  the camera and framing it snaps the brackets with a tick — the last metre
  stays a search, and it is what makes invisible writing findable. Each
  floor plans 3 required anomalies on the route spine plus 9 extras off it
  (dense on purpose: the spine is one path through an open maze and nothing
  forces the player across it), pure from (seed, theme, floor). Every bleed
  prop is also photographable evidence (`PhotoDirector._register_bleed_props`,
  id `bleed:x:y` per cell) worth ONE credit per floor
  (`bleed_credit_used`), except that ANY bleed item may serve as the LAST
  photograph regardless of spent credit — the lift area is thick with
  them, so the floor is always completable there — guaranteed ops near the lift. The HUD's persistent "EVIDENCE NNNm"
  distance counter to the nearest undocumented planned anomaly
  (`DescentHUD.evidence_target`) appears automatically at 2/3 and on any
  photo tape refusal (`descent_commit_refused`), so the last photograph
  always has a heading and 0/3 at the altar is never a dead end. Props are ALWAYS the floor's own
  signature `Chunk.BLEED_PROPS` object (owner rule 2026-08-19: foreign
  objects appear only as the bleed near the elevator, never as scattered
  anomalies — the 2026-08-18 foreign-prop experiment is reverted; prop-less
  themes plan WRITING only via `PhotoAnomaly.PROP_THEMES`): five types, and the required
  trio on a floor is always three DIFFERENT ones where the theme allows,
  claiming one WRITING greedily the first time a route cell offers a wall
  (the writings are the feature's voice and were otherwise rare); extras
  weight WRITING double (`PhotoDirector._eligible_types`/`_spec_for`,
  enforced by the plan audit): PLACEMENT (own prop inverted, hovering at head height under a
  faint cold underlight, slowly turning), DUPLICATE (two identical,
  shoulder to shoulder — LENS-ONLY like the writing: eye-visible
  duplicates of a theme's own prop read as furniture, a playtest proved
  it), GIANT (the prop scaled to nearly touch the ceiling, eye-visible,
  real collider), RING (five copies in a circle facing the centre,
  LENS-ONLY), WRITING
  (a phrase on a wall that exists only on render layer 20 — the RAISED
  viewfinder and the snapshot camera see it, the bare eye never does
  (`PhotoCamera._raise` adds the layer to the player cam cull mask; without
  this the sweep was aiming at literally nothing visible — do not revert);
  it registers only from the side it faces (`PhotoAnomaly.facing_normal`,
  the occlusion tolerance alone cannot tell front from behind-the-wall);
  room cells only, corridors line their walls). While raised the reticle
  runs hot/cold: brackets close and a tick accelerates as aim nears any
  findable anomaly (`PhotoCamera._aim_warmth`), full two-tone bite on true
  framing. The arrival card is followed 3.3s later by the brief ("THE TAPE WANTS PROOF —
  PHOTOGRAPH 3 THINGS THAT ARE WRONG" on floor 1, "PHOTOGRAPH WHAT IS WRONG
  — n/3" after), and "PHOTOS n/3" sits under the LIFT distance in
  `DescentHUD` so the two objectives read as one instrument. The objective
  tape refuses to play until 3 are documented (the tape stays the lift's
  sole gate; the photo count gates the tape, never the lift). After a counted photograph: 60% nothing, 25% environmental
  response, 15% `ShadowFigures.force_encounter` — the same rear-arc,
  LOS-checked spawn the tape ending uses. Documented ids persist per floor
  through death (`DescentProgress.photo_states`). Blackouts, tape playback,
  suspension and charging all lower the camera. Dev flag `--photo-debug`
  prints the plan and renders hidden writing on the main camera.
- **Bleed**: one-way ratchet toward the next theme as the player nears the
  lift (fog/room-tone lerp in main, next-theme props via `Chunk.BLEED_PROPS`
  in rebuilt cells).
- **Post-blackout changes**: blackouts may transition between complete,
  precomputed topology realities, including safe doorway and furniture
  mutations. Live frustum plus occlusion gating requires a visible architectural
  change or a designated set-piece witness before a blackout may start. The
  active reality persists and may later mutate back; the legacy kind-2
  furniture rearrange is retired.
- **Passing shadows** (`passing_shadows.gd`): rare non-threat silhouettes
  crossing a distant opening with a shock sting. DORMANT until
  `textures/ghosts/passer1-3.webp` exist — build them with
  `tools/build_flipbook.py` from the three walk videos (white-background
  silhouettes; the tool prints the BODY numbers to paste into
  `ShadowFigure.BODY`, replacing the placeholder 0.754 entries).

## Asset pipelines

- **Tapes**: ffmpeg2theora, above. Sources are owner-supplied; record them
  in `videos/tapes/SOURCES.md`.
- **Corner apparitions**: rare Descent-only sightings are armed behind a real
  topology turn, reveal only after line of sight opens, hold still for two
  seconds, then dissolve. Their successful cooldown is 150–290 seconds and
  blackout, tape viewing, arrival safety, and pause states suppress them.
- **Ghost/passer flipbooks**: `tools/build_flipbook.py SRC.mp4 OUT.webp` —
  white-backdrop videos → alpha sprite sheets (6x4, 24 frames, 12fps),
  consumed via `ShadowFigure.FLIPBOOKS/BODY/SOFT` + `shaders/ghost.gdshader`.
  Since 2026-08-15 hostile figures run the sheet with temporal frame
  blending (`flip_blend`/`flip_loop`), a two-pose analog echo (`trail_amt`),
  and a heat-haze rim shimmer (`aura_amt`); each figure also carries true-3D
  presence — shed wisp particles (`shaders/ghost_wisp.gdshader`, absorption
  like the body) and a local dark `FogVolume` (`GLOOM_DENSITY`), both
  following `fade`. Both recording modes run one shader
  (`shaders/post.gdshader`, c64cosmin's CC0 CRT, see THIRD_PARTY_ASSETS.md):
  the CRT material uses its clean defaults (subtle roll bar), the RECOVERED
  TAPE material a gritty preset the glitch machinery rides
  (`PostProcessController.setup`/`_apply_found_footage_state`);
  `found_footage.gdshader` is retired. The tape grit dials (all default off
  so CRT is untouched: `jitter_amount`, `wobble_amount`, `tear_amount`,
  `ghost_amount`, `flicker_amount`, `saturation`/`contrast`/`black_crush`,
  `head_switch_amount`, `dropout_amount`) were grafted 2026-08-18 from an
  owner-supplied found-footage shader; corruption and glitches push them
  toward 1.0. Tape grid is 640x360 (854x480 read as too fine; the 3D world still
  renders at 480 lines via `main._apply_scaling`, the shader resamples).
  During ritual tape playback the full-screen pass is held
  (`PostProcessController.hold_for_tape`) — playback CRT-ness belongs to
  the TV's own `vhs_tape.gdshader`, not the display. Signal
  model (2026-08-19): `signal_fps` 29.97 quantizes every tape-side random
  process to video frames (CRT-side TIME stays continuous); `chroma_delay`,
  `overscan` 3%, `black_lift`, `field_amount` (half-line parity shimmer,
  never dark lines), row-correlated `line_noise`/`chroma_noise`,
  horizontal `bloom_amount` above `bloom_threshold`, `color_balance`; the
  warp is aspect-aware in both modes. Deliberately NOT done: a SubViewport
  with a 29.97 fps frame hold (input-lag feel in mouse-look; broad
  refactor) — the noise cadence gets the perceptual payoff. The tape is also the danger instrument
  (2026-08-19): `PostProcessController.set_presence` takes the nearness of
  the closest hostile figure, seen or not (fed from
  `main._update_entity_halo`, 20m range, fast attack / 0.35 per s release)
  and climbs a ladder — near: chroma split, line wobble, iris pulsing;
  very near (>0.6): tears, frame displacement, noise, band-wise
  `signal_loss` — and `ShadowFigures.spawned` fires `glitch_burst()`, ~0.11s
  of catastrophic loss. Tape material only; CRT stays clean by owner
  decision. The figure-interference halo
  (`entity_pos/radius/amt`, fed by `main._update_entity_halo`) is fed to the
  tape material only — the owner cut it from CRT mode. On the tape pass
  hostile figures run the ghost shader's `density` at
  `ShadowFigure.TAPE_DENSITY` (0.25, darker; tape grain is luminance-weighted so blacks stay black — a wider noise-veiled body floor was tried and is grey, do not reintroduce) via `ShadowFigure.set_tape_look`,
  because the tape's grey lift and grain cost them their contrast; the
  clean tube runs 1.0. Still no ground
  shadow, ever.
- **Third-party models/textures**: every asset needs a SOURCE.md next to it
  and an entry in `THIRD_PARTY_ASSETS.md`. Policy: CC0 / CC BY / marked
  CC BY-NC only — no ShareAlike, no ND. Sketchfab GLBs embed author/license
  metadata in their JSON chunk (`strings file.glb | grep author`).
- **`liminal_env_lab/`**: Python damage-extraction studio (venv on Homebrew
  python@3.14 — a brew cleanup once deleted that formula and silently broke
  the venv; `brew install python@3.14` fixes it). Produced the Annex
  mold/carpet masks. `tools/build_pool_mineral_atlases.py` builds the
  Poolrooms mineral atlases from `damage-lab/poolrooms/` scans.

## Gotchas that cost real time

- Chunks are built by `Chunk.new()` in `_init`; anything a child builds in
  `_ready` (interactables, stations) does not exist for tree-less audits —
  add the chunk to the tree first.
- The Descent car is authored AFTER theme dressing;
  `Chunk._descent_clear_car_footprint` sweeps props out of its footprint.
  The moving car is wrapped in a tight inward-facing shell — keep it tight
  or the world shows through door-leaf cracks.
- The retro TV model's glass dome is a translucent surface of the BODY mesh
  reaching raw z 2.59; the screen quad must stay proud of that apex.
- Figure movement uses a 0.52-radius capsule sweep with sticky wall-slide
  avoidance; widening it re-breaks doorway traversal, and re-scanning the
  detour every frame re-introduces the doorway "shiver".
- `audit_descent_routes` costs ~6s/seed at current bands; the suite runs 40
  seeds to fit the 300s timeout.
- `audit_photo_coverage` proves every REQUIRED anomaly on the boot floor is
  capturable from a real stance — the guard against "EVIDENCE points at it,
  nothing can frame it" (a GIANT's own collider once occluded its sample
  points; camera rays exclude `PhotoAnomaly.occlusion_excludes()`).
- One unexplained world-hash drift was accepted 2026-08-03: 8 wander Annex
  cells (seed 1) gained 1-2 nodes with no identified cause. If Annex wander
  dressing looks wrong, start bisecting there.

## Open decisions (owner has not decided)

- Death scope: run restart vs floor restart (summary screen offers retry).
- The passing-shadow source videos need re-supplying (they vanished from
  Downloads before conversion).
