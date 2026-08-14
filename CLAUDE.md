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
- The suite has 49 registered audits; there are no known tolerated
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
  Monolith: sparse figures, long grace). Playing a tape
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
- **HUD**: distance-only "LIFT NNNm" counter. There is no directional
  needle — finding the lift IS the level. Route bands 26-34 edges (floor 1)
  to 40-52 (floor 11).
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
- One unexplained world-hash drift was accepted 2026-08-03: 8 wander Annex
  cells (seed 1) gained 1-2 nodes with no identified cause. If Annex wander
  dressing looks wrong, start bisecting there.

## Open decisions (owner has not decided)

- Death scope: run restart vs floor restart (summary screen offers retry).
- The passing-shadow source videos need re-supplying (they vanished from
  Downloads before conversion).
