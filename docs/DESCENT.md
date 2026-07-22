# Descent — implementation plan

A second play mode for Liminal. The existing endless-wander experience stays
exactly as it is and remains the default; **Descent** is a separate mode,
selected at the title screen, that gives the world a goal, a rule set, and an
ending.

This document is written to be implementable by someone who has not read the
codebase. Every hook into existing files is named with its file and function.
Read [Codebase rules](#codebase-rules-read-before-touching-anything) before
writing any code — several of them have cost real debugging time already.

---

## 1. The design

**Core loop.** You start on floor 1 and descend. The only way down is a real
elevator, placed rarely in the world hash and found by following painted
arrows on the floor. Six floors down there is a way out.

**The rules.** At the title you are given a card. Four rules:

> - do not look at them
> - do not stop walking
> - do not go back
> - if the lights fail, stand still

Breaking a rule never kills you directly. It raises the building's
**attention**. Attention is never shown as a number or a meter — it shows only
as the world getting worse: more figures, more CRT snow, more blackouts, and
finally a figure that does not vanish and does not stop following.

**Why these rules.** Rule 1 converts the project's best existing asset into a
mechanic. Today, staring a shadow figure away is pure relief — it costs
nothing. Under Descent it is still the only way to make one go away, but it
costs you. Rule 2 sets the pace: you can never stand and admire a room. Rules 2
and 4 are deliberate opposites, and the lights tell you which one is live.

**Anomalies are the enforcement of rule 3, not a separate system.** When you
re-enter a cell you have already left, that chunk rebuilds *wrong* — the lights
in it are dead, or something is standing in it. Backtracking is punished by the
building lying to you. This is the whole of the "anomaly" feature; do not build
a separate spot-the-difference mode.

**Floor order.** Descent does **not** use the sandbox's `1`–`6` order. It uses:

| Floor | Theme id | Name |
|---|---|---|
| 1 | 0 | the casino |
| 2 | 1 | the office |
| 3 | 4 | the airport |
| 4 | 6 | the school |
| 5 | 5 | the asylum |
| 6 | 2 | the sewers |

Rationale: it reads as an actual descent — garish → sterile → vast and cold →
institutional → wrong → underneath. It also puts the two floors that can spawn
the non-human figures (`ShadowFigures.UNDERNEATH_THEMES == [2, 5]`) at the
bottom two, so the worst things are deepest. The way out is at the bottom of
the sewers.

---

## 2. Hard constraint: the sandbox does not change

The wander mode must be byte-for-byte the experience it is today. Every
behaviour below is gated on the mode being Descent. Concretely:

- `Chunk` must build **no** elevator, **no** floor arrows and **no** anomalies
  unless the mode is Descent.
- `WorldGen.portal()` must return exactly what it returns today in wander mode.
- `ShadowFigures` cadence, `Environment` values, CRT `noise_amount` and music
  must be untouched in wander mode.
- The title screen's `SPACE` must still start the wander mode, unchanged.

The mechanism is a single static flag, set once at startup, checked in the two
static/stateless places that need it:

```gdscript
# world_gen.gd, near the top
static var descent := false
```

`Chunk` and `WorldGen` are static/stateless by design and are constructed by
`ChunkManager` without a reference to `main`, so a static flag is the correct
tool here. It matches the existing precedent (`ChunkManager._dev_timing`).

Set it in `main._ready()` before the first `_build_level()` call, and never
again.

---

## 3. File map

### New files

| File | Class | Responsibility |
|---|---|---|
| `scripts/run.gd` | `Run extends Node` | The whole mode: floor progression, the four rules, attention, blackouts, run summary state. Added under `main` **only** in Descent. |
| `scripts/elevator.gd` | `Elevator extends Node3D` | The set piece's behaviour: door animation, approach/commit areas, chime. Geometry is built by `chunk.gd` and handed to it. |

### Modified files

| File | Change | Size |
|---|---|---|
| `scripts/main.gd` | mode var, `--mode=descent`, construct `Run`, gate keys `1`–`6`, `_on_elevator` group callback, blackout apply, CRT noise, summary UI | ~120 lines |
| `scripts/title.gd` | two start options + the rule card | ~60 lines |
| `scripts/world_gen.gd` | `descent` flag, `elevator_cell()`, `elevator_wall()`, `nearest_elevator()`, portal suppression | ~70 lines |
| `scripts/chunk.gd` | `_build_elevator()`, `_floor_arrow()`, anomaly mutations | ~350 lines |
| `scripts/chunk_manager.gd` | anomalous-cell set, force-rebuild of a cell | ~25 lines |
| `scripts/shadow_figures.gd` | `attention` input, `stared_away` signal, pursuer spawn | ~50 lines |
| `scripts/shadow_figure.gd` | emit on gaze-kill, `pursuer` mode | ~40 lines |

---

## 4. Codebase rules (read before touching anything)

These are established facts about this project. Violating them produces bugs
that are slow to diagnose.

1. **There is no git in this repo.** Copy `scripts/`, `shaders/` and `scenes/`
   somewhere safe before any large edit.
2. **Theme ids are sparse.** `WorldGen.THEMES == [0, 1, 2, 4, 5, 6]`. Id 3 was a
   theme park that was cut, and the ids were deliberately not renumbered so old
   seeds still reproduce. Anything indexed *by theme id* must keep a dead slot
   at 3 (see `Mats.PORTAL_COLS`). Anything that *iterates* themes must iterate
   `WorldGen.THEMES`.
3. **New `class_name` scripts are invisible to headless runs until imported.**
   Run `godot --headless --path . --import` after adding `run.gd` and
   `elevator.gd`.
4. **`var x := cell + DIRV[d]` fails to infer** — `DIRV` is untyped. Annotate
   `var x: Vector2i = cell + WorldGen.DIRV[d]`.
5. **Thin meshes near an omni light must set `cast_shadow = OFF`.** The
   per-cell shadowed omni smears thin geometry into long streaks across walls
   and floors. This bit the escalator handrails and every light fixture. Door
   panels, jambs, handrails and sign plates all qualify.
6. **`CharacterBody3D` cannot step up.** The player has no step-up height. An
   elevator threshold must be flush with the floor or ramped — a 5cm lip will
   trap the player outside the car.
7. **Never position anything from the `H`/`H2` constants** — use the chunk's
   `ceil_h`, which is per-room. Two black-screen renders were lost to lights
   ending up above low ceilings.
8. **Props laid out by a room's anchor cell get shifted to the room centre.**
   `Chunk._shift_props(off, n0, b0)` walks every child added to the chunk and to
   `body` since the marks `n0`/`b0` and moves it. Wall-anchored set pieces must
   avoid this — see §6.2.
9. **Verify visuals by rendering, not by reading code.**
   ```sh
   godot --path . -- --seed=N --pos=x,z --yaw=deg --level=<THEME_ID> \
         --nocrt --screenshot=/tmp/shot.png
   ```
   renders ~2.5s and saves a frame. `--level` takes a **theme id**, not a floor
   number. Always pass `--nocrt` for visual checks — the 240p blur and snow
   hide exactly what you are judging.
10. **Camera yaw convention**: forward is `(-sin yaw, 0, -cos yaw)`. Yaw `-90°`
    faces `+x`; yaw `0°` faces `-z`.
11. **Judge walls and ceilings from ~4m.** `--pos=0,0` puts the camera under
    half a metre from a wall.
12. **`--quit-after N` counts frames, not seconds**, and headless runs
    uncapped. Print `Time.get_ticks_msec()` to measure real cadence.
13. **Screenshot instances share the user's mouse.** If the mouse moves during
    a dev screenshot the camera is dragged. Retake before diagnosing framing.
14. **Re-run `--audit`** (`godot --path . -- --audit`) after touching anything
    to do with partitions or door widths. It must report `NOW: 0` for every
    theme.

### Useful existing API

- `WorldGen.r01(ws, a, b, salt) -> float` — deterministic 0..1. All world
  randomness goes through this. `Chunk._r(salt)` is the per-cell shorthand.
- `WorldGen.anchor_wall(ws, cell, salt) -> int` — first solid edge from a hashed
  start, or `-1`. Directions: `0 = +x, 1 = -x, 2 = +z, 3 = -z`.
- `WorldGen.corridor(ws, cell) -> int` — `0` none, `1` along x, `2` along z.
- `WorldGen.room_id / room_size / room_centre / room_height / room_split`.
- `Chunk._air_yaw_for(dir) -> float` — yaw that points a node's local `+z` at
  the given edge (`0 → PI/2`, `1 → -PI/2`, `2 → 0`, `3 → PI`).
- `Chunk._wp(o, local, yaw) -> Vector3` — rotate a local offset into chunk space.
- `Chunk._collider_yaw_box(pos, size, yaw)` — collider for yawed geometry.
- `Chunk._mbox / _mrbox / _mcyl / _msphere(parent, ...)` — build under a given
  parent node (use these inside a yawed node).
- `Chunk._box / _rbox / _cyl(...)` — build directly on the chunk, with collider.
- `Mats.steel() / chrome() / charcoal() / metal_gray() / brass() / panel_on() /
  panel_dead() / screen_glow() / caution_yellow() / rubber_black() / bulb()`.
- `SoundBank.elev() / ding() / thud() / clang() / creak() / warp()`;
  `SoundBank.randomized(wav, pitch, vol_db)`.
- `shaders/post.gdshader` exposes `noise_amount : hint_range(0.0, 3.0) = 1.0`
  and `bright_boost` (set to `1.4` in `main._build_ui`).

---

## 5. Phase 1 — mode plumbing

**Goal:** the mode exists and is selectable; no gameplay yet. Wander mode is
provably unchanged.

### 5.1 `scripts/run.gd` (skeleton)

```gdscript
class_name Run
extends Node
## Descent mode. Six floors down and a way out at the bottom. Four rules.
## Breaking one raises the building's attention; attention is never drawn on
## screen, only felt — more figures, more snow, more blackouts, and eventually
## something that does not vanish when you look at it.

signal floor_reached(floor_idx: int)
signal run_ended(won: bool)

## Theme ids in descent order — NOT WorldGen.THEMES order.
const ORDER: Array[int] = [0, 1, 4, 6, 5, 2]
const NAMES := ["the casino", "the office", "the airport",
	"the school", "the asylum", "the sewers"]

var floor_idx := 0
var attention := 0.0        # 0..1, never shown
var broken := 0             # rule violations this run, for the summary
var elapsed := 0.0
var ended := false

func theme() -> int:
	return ORDER[floor_idx]

func is_last_floor() -> bool:
	return floor_idx >= ORDER.size() - 1
```

Fill in the rest across phases 3–5.

### 5.2 `main.gd`

- Add `var run: Run` and `var descent := false`.
- Parse `--mode=descent` in the `OS.get_cmdline_user_args()` loop in `_ready()`,
  alongside the existing `--seed=` / `--pos=` / `--level=` handling.
- After parsing, before the first `_build_level()`:
  ```gdscript
  WorldGen.descent = descent
  if descent:
      active_level = Run.ORDER[0]
  ```
- Construct `Run` next to the other managers (near where `_figures` is added)
  **only** when `descent` is true. Add `main` to a new group:
  ```gdscript
  add_to_group("elevator_listener")
  ```
- Gate the floor keys in `_unhandled_input()`:
  ```gdscript
  var idx: int = event.physical_keycode - KEY_1
  if idx >= 0 and idx < WorldGen.THEMES.size():
      if not descent:                     # no free rides on the way down
          _switch_level(WorldGen.THEMES[idx])
  elif event.physical_keycode == KEY_V:
      ...
  ```
  Keep `V` working in both modes.
- Suppress the wander-mode hint strip (`_hint`) in Descent — the mode has no HUD.

### 5.3 `title.gd`

`TitleScreen` currently swallows all input until `KEY_SPACE`, then emits
`started`. Change to:

- `signal started(descent: bool)` — update the `main._on_start` connection to
  take the argument.
- Under the existing key list, two lines:
  ```
  SPACE    wander
  ENTER    descend
  ```
- On `ENTER`, replace the key list with the rule card before starting — a beat
  where the four rules are the only thing on screen, then `SPACE` to begin. The
  rules must be read once; there is no in-game way to recall them.
- Reuse `_style()` for every new label so `_relayout()` scales it. Labels not
  registered through `_style()` will be the wrong size at anything other than
  720p.

### 5.4 Acceptance

- `godot --path . --headless --quit-after 120` — clean, no errors.
- Wander mode: title `SPACE`, keys `1`–`6` still switch floors, hint strip
  still fades after 9s.
- `godot --path . -- --mode=descent --nologo` starts on the casino; `1`–`6` do
  nothing; `V` still toggles the tube.
- `godot --path . -- --audit` still reports `NOW: 0` for all six themes.

---

## 6. Phase 2 — the elevator

The largest phase. Build and verify it before touching rules.

### 6.1 Placement — `world_gen.gd`

```gdscript
## Cells that may hold an elevator, per theme. Chosen because their furnishing
## only places props in the middle of the cell — the wall-anchored set pieces
## (airport gates, check-in, escalators, transit) and the self-walling rooms
## (asylum hydro/treatment, every corridor style) would collide with the alcove.
const ELEV_STYLES := {
	0: [STYLE_EMPTY, STYLE_LOUNGE, STYLE_PILLARS, STYLE_GRAND],
	1: [OFFICE_EMPTY, OFFICE_STORAGE, OFFICE_BREAK, OFFICE_CUBICLES],
	2: [SEWER_DRY],
	4: [AIR_HALL, AIR_CONCOURSE, AIR_BAGGAGE],
	5: [ASY_OFFICE, ASY_WARD, ASY_DAYROOM],
	6: [SCH_GYM, SCH_CAFETERIA, SCH_LIBRARY, SCH_ADMIN],
}
const ELEV_P := 0.06        # of eligible cells; tune by playtest

static func elevator_cell(ws: int, cell: Vector2i, theme: int) -> bool:
	if not descent or cell == Vector2i.ZERO:
		return false
	if corridor(ws, cell) != 0:
		return false
	var root := room_id(ws, cell)
	if not room_split(ws, root, theme).is_empty():
		return false          # a partition could cut the alcove
	if not ELEV_STYLES.get(theme, []).has(cell_style(ws, cell, theme)):
		return false
	if anchor_wall(ws, cell, 770) < 0:
		return false          # needs a solid edge to back onto
	return r01(ws, cell.x, cell.y, 771) < ELEV_P

static func elevator_wall(ws: int, cell: Vector2i) -> int:
	return anchor_wall(ws, cell, 770)
```

`SEWER_DRY` is the only sewer style: the others carry water channels and
basins, and an alcove over a channel is unwalkable.

**Portal suppression.** In `WorldGen.portal()`, first line:

```gdscript
if descent:
	return -1
```

One way down. A portal that teleports you to a random floor destroys the run's
shape, and it frees the roomy styles for other uses.

**Wayfinding.** Elevators at ~6% of eligible cells are roughly one per 30–80
cells depending on theme — findable only if the building points at them.

```gdscript
const ELEV_SIGN_R := 4   # cells

## Nearest elevator within ELEV_SIGN_R, or NO_HALL if there is none.
## Chebyshev-nearest, ties broken by the lower (x, y) so it is deterministic.
static func nearest_elevator(ws: int, cell: Vector2i, theme: int) -> Vector2i
```

Cost: 81 `cell_style()` calls per chunk build. `cell_style` chains through
`room_id` → `merge_dir`, so measure with `--chunktime` before and after; if any
chunk crosses ~4ms, cache per (ws, theme) in a static `Dictionary` keyed by
cell.

### 6.2 Geometry — `chunk.gd`

Call it from `_build_props()` **immediately after the portal block and before
the `if not is_room_anchor: return` line**:

```gdscript
portal_dest = WorldGen.portal(wseed, cell, theme)
if portal_dest >= 0:
	_build_portal(portal_dest)
if WorldGen.elevator_cell(wseed, cell, theme):
	_build_elevator()
_floor_arrow()                    # no-ops unless descent and in range
if not is_room_anchor:
	return
```

Building here is deliberate and load-bearing: `_shift_props()` only moves
children added *after* the `n0`/`b0` marks, which are taken further down. An
elevator built before those marks can never be dragged off its wall — the same
protection the portal already relies on. **Do not** move this call into the
`match style` block, and do not add the elevator to the `off = Vector3.ZERO`
list; it does not need to be there if it is built early.

**Frame.** Everything is authored inside one yawed `Node3D` so it can be
written in a single sane coordinate system:

```gdscript
var d := WorldGen.elevator_wall(wseed, cell)
var yaw := _air_yaw_for(d)
var v := Node3D.new()
v.position = Vector3(S / 2.0, 0.0, S / 2.0)   # cell centre
v.rotation.y = yaw
add_child(v)
```

Inside `v`: local `+z` points **at the anchor wall**, local `-z` points into the
room. Local `z` runs `-6` (far wall) to `+6` (anchor wall). Local `x` is `±6` at
the perpendicular walls.

Colliders cannot be parented to `v` — they must go on `body`. Use
`_collider_yaw_box(_wp(v.position, local_pos, yaw), size, yaw)` for each.

**Layout** (all local to `v`, metres):

| Part | Position | Size | Material |
|---|---|---|---|
| Alcove facade, left | `x -3.65, z 3.9` | `2.1 × ceil_h × 0.2` | theme wall mat |
| Alcove facade, right | `x +3.65, z 3.9` | `2.1 × ceil_h × 0.2` | theme wall mat |
| Facade header | `x 0, y 2.45, z 3.9` | `3.2 × (ceil_h - 2.45) × 0.2` | theme wall mat |
| Alcove side, left | `x -2.6, z 4.95` | `0.2 × ceil_h × 2.1` | theme wall mat |
| Alcove side, right | `x +2.6, z 4.95` | `0.2 × ceil_h × 2.1` | theme wall mat |
| Door surround | around the `1.8 × 2.25` opening at `z 3.9` | `0.12` proud | `Mats.steel()` |
| Car back | `z 5.85` | `2.4 × 2.35 × 0.1` | `Mats.metal_gray()` |
| Car sides | `x ±1.2, z 4.9` | `0.1 × 2.35 × 1.9` | `Mats.metal_gray()` |
| Car ceiling | `y 2.35, z 4.9` | `2.4 × 0.1 × 1.9` | `Mats.charcoal()` |
| Car floor | `y 0.01, z 4.9` | `2.4 × 0.02 × 1.9` | `Mats.rubber_black()` — **flush, see rule 6** |
| Handrail | `y 0.9`, three sides | `0.04` radius cyl | `Mats.chrome()` |
| Doors ×2 | `x ∓0.45, z 3.9` | `0.9 × 2.25 × 0.08` | `Mats.steel()` |
| Call plate | `x 1.35, y 1.15, z 3.78` | `0.16 × 0.26 × 0.03` | `Mats.charcoal()` |
| Call button | on the plate | `0.045` radius | `Mats.panel_on()` when live |
| Floor indicator | `x 0, y 2.62, z 3.82` | `0.5 × 0.24 × 0.04` | `Mats.screen_dark()` |

The alcove is a closed island against the anchor wall: it never reaches the
perpendicular walls (`±2.6` against walls at `±6`), so it cannot cross a
doorway. Facade and sides are thick enough to be opaque from any angle.

**Floor indicator** is a `Label3D` showing the current floor number in amber
(`Color(0.95, 0.68, 0.2)`), the same treatment as `_exit_sign`. On the last
floor it reads `OUT` instead.

**Car light.** One `OmniLight3D` inside the car, warm, `omni_range` ~4,
`shadow_enabled = false`. When the doors open this throws a rectangle of light
into a dark room — that is the long-range "found it" cue, and it is the reason
the car light must be brighter than the room. Every thin part of the fixture
gets `cast_shadow = OFF` (rule 5).

**Chime.** `AudioStreamPlayer3D` on the elevator: `SoundBank.elev()`,
`bus = "Hall"`, `max_distance` ~45, quiet, retriggered every 12–20s. This is the
audible version of the same cue — a chime somewhere down the corridor.

### 6.3 Behaviour — `scripts/elevator.gd`

```gdscript
class_name Elevator
extends Node3D
## The way down. Doors open when you come near and close behind you; there is
## no button to press and no way back up.

signal committed

var floor_label: Label3D
var doors: Array[StaticBody3D] = []   # [left, right]
var open := false
var _busy := false
```

- **Two `Area3D`s**, both handed in by `chunk.gd`:
  - *approach* — a `3.0 × 2.4 × 2.6` box in front of the doors. On
    `body_entered` with a `CharacterBody3D`: open the doors (0.9s tween, chime).
    On `body_exited`: close them after a 2s delay, unless committed.
  - *car* — a `2.0 × 2.3 × 1.6` box inside the car. On `body_entered`: commit.
- **Commit** closes the doors, waits for them to seal, then
  `get_tree().call_group("elevator_listener", "_on_elevator", cellv)`.
  This mirrors exactly how `portal.gd` hands off today.
- **Doors are `StaticBody3D`**, each with its mesh and its `CollisionShape3D` as
  children, so tweening the body's `position.x` moves collision with the mesh.
  Only close them once the player is inside the car area — a `StaticBody3D`
  teleporting into a `CharacterBody3D` standing in the threshold will trap or
  eject them.
- Guard everything with `_busy` so a player jittering in the doorway cannot
  start two tweens.

### 6.4 Descent — `main.gd`

```gdscript
func _on_elevator(_cellv: Vector2i) -> void:
	if _switching or run == null or run.ended:
		return
	if run.is_last_floor():
		run.finish(true)
		return
	run.floor_idx += 1
	run.floor_reached.emit(run.floor_idx)
	_jump_to(run.theme(), _safe_arrival(run.theme(), Vector2i.ZERO, DEFAULT_SPAWN), false)
```

Reuse `_jump_to()` untouched: it already fades, plays `_ding` (the elevator
chime — correct here), crossfades music, rebuilds the level and calls
`player.teleport()`. Arriving at the origin cell of the new floor is right —
each floor is a fresh start and `_safe_arrival` already handles the airport
gate-cell trap.

Do **not** write to `_saved_pos` for Descent floors. There is no going back up,
so remembered positions are meaningless and would leak state between runs.

### 6.5 Floor arrows

`Chunk._floor_arrow()`:

```gdscript
func _floor_arrow() -> void:
	if not WorldGen.descent:
		return
	var target := WorldGen.nearest_elevator(wseed, cell, theme)
	if target == WorldGen.NO_HALL or target == cell:
		return
	...
```

A painted arrow on the floor at `y = 0.02`, pointing along
`(target - cell)` in world space:

- shaft — `BoxMesh`, `2.0 × 0.005 × 0.18`
- head — the shared `CONE` mesh, `rotation.x = PI / 2.0` to lay it flat
  pointing along `+z`, then yawed to the target bearing
- material — a faded safety yellow with a low emissive so it survives the dark
  floors (`Mats.caution_yellow()` is the starting point; it may need a dedicated
  low-emission variant)
- `cast_shadow = OFF`, **no collider**

Floor arrows were chosen over hanging signs deliberately: a hanging sign at cell
centre collides with chandeliers, transit bulkheads and gate glass across six
themes, whereas nothing in this project occupies the floor plane at 2cm. It also
reads as a marking left by whoever ran the building, not as the building's own
signage — which is the right voice for the mode.

### 6.6 Acceptance

- Write a small Python replica of `elevator_cell()` (there is an existing
  pattern for replicating `WorldGen` in Python for cell scouting — 64-bit
  signed wrap, arithmetic shift) to find elevator cells for a given seed,
  rather than wandering blind looking for one.
- Screenshot one elevator per theme, doors closed and doors open, from ~5m back,
  with `--nocrt`. Check: no geometry poking through the anchor wall, no props
  clipping the alcove, the car light reads at distance, the threshold is flush.
- Walk in and confirm the descent fires and lands you on the next floor.
- `--chunktime` — no chunk over ~4ms.
- Confirm zero elevators and zero arrows in wander mode.

---

## 7. Phase 3 — rules and attention

### 7.1 Detection, in `Run._physics_process`

| Rule | Detection | Cost |
|---|---|---|
| do not look at them | `ShadowFigure` emits when it is stared away | `+0.10` per figure |
| do not stop walking | horizontal speed `< 0.3` for `> 6.0s`, outside a blackout | `+0.03/s` while stopped |
| do not go back | entering a cell already in `_visited`, first time only | `+0.06`, and marks the cell anomalous |
| lights failed, stand still | horizontal speed `> 0.3` **during** a blackout | `+0.08/s` while moving |

Rules 2 and 4 are mutually exclusive by construction: rule 2 is suspended while
`blackout` is true and rule 4 only applies then.

Track cells as `Vector2i(floori(pos.x / 12.0), floori(pos.z / 12.0))` — the same
expression `Player._surface()` uses. Only count a *transition* into a cell, not
every physics tick inside it. Clear `_visited` on every floor change.

Attention decays slowly while you are obeying — target roughly `-0.01/s`, so
about a hundred seconds of clean walking undoes one stare. It should be
recoverable but not quickly.

### 7.2 Consequences

All continuous in `attention`, none of them drawn:

- **CRT snow** — `main` sets the post material's `noise_amount` from
  `1.0 + attention * 1.6` (shader range is `0..3`). Only when `_crt` is on;
  with the tube off there is no substitute, which is an accepted cost.
- **Figures** — `ShadowFigures` gains `var attention := 0.0` and scales its
  spawn interval by `lerpf(1.0, 0.35, attention)`. Baseline today is one figure
  per ~11s; at full attention that is one per ~4s. Leave `MAX_FIGS` at 3 until
  playtested — more than three at once reads as comedy.
- **Blackouts** — see below.
- **The pursuer** — phase 5.

### 7.3 Blackouts

The lights failing is an **event driven by attention**, not a property of a
room. This was chosen over sampling the ambient light at the player: it is
unmistakable to the player, fully controllable, and needs no light-probing.

In `main`:

```gdscript
func set_blackout(on: bool) -> void:
	# kill every light under the current level, and the ambient with it
	for n in _all_lights(level_root):
		n.visible = not on
	we.environment.ambient_light_energy = 0.0 if on else _ambient_for(active_level)
```

- Interval scales with attention: idle around 90–150s at zero, 25–40s at one.
- Duration 5–8s.
- Announce it with `SoundBank.thud()` — a breaker going somewhere.
- Chunks streaming in *during* a blackout must arrive dark. Either gate on a
  static `Chunk.blackout` checked in `_build_lighting()`, or re-apply
  `set_blackout(true)` whenever `ChunkManager` builds a chunk. The static flag
  is cleaner and matches the `WorldGen.descent` precedent.
- Cache the per-theme ambient energy when `_build_env()` runs so restoring it
  does not have to rebuild the `Environment`.

### 7.4 `shadow_figure.gd` / `shadow_figures.gd`

- `ShadowFigure` gains `signal stared_away`, emitted where the gaze timer
  currently triggers the fade (`_gaze > GAZE_TIME`, guarded by `grace`). Emit
  **only** for the gaze path — walking a figure down (`NEAR_D`) and the natural
  7–14s expiry are not rule breaks. Looking is the rule.
- `ShadowFigures` connects the signal on every figure it spawns in `_spawn_at()`
  and re-emits upward, or takes a `Callable` from `Run`.
- Neither file may change behaviour when `attention == 0.0`. Verify by playing
  wander mode.

### 7.5 Acceptance

- A dev flag (`--attention=0.7`) that pins attention, for screenshotting each
  consequence without playing up to it.
- Blackout: everything goes dark, chunks built during it arrive dark, the
  restore returns the exact ambient the floor had before.
- Wander mode: no blackouts, `noise_amount` stays at 1.0, figure cadence
  unchanged (measure with `--haunt` and real `Time.get_ticks_msec()` deltas —
  remember `--quit-after` counts frames).

---

## 8. Phase 4 — anomalies

Anomalies exist **only** as the punishment for rule 3. A cell you re-enter
rebuilds wrong.

- `Run` marks the cell: `cm.mark_anomalous(cellv)`.
- `ChunkManager` gains `var anomalous := {}` and a `force_rebuild(c)` that frees
  and rebuilds a loaded chunk. The player is standing in the cell when it
  rebuilds, so rebuild the *neighbours* they are walking toward rather than the
  cell under their feet — a chunk freed underneath the player drops them
  through the floor.
- `Chunk` takes an `anomaly: bool` in `_init` and applies **one** mutation,
  picked by `_r(780)`:
  1. every light in the cell is dead (`Mats.panel_dead()`, no omni)
  2. a figure standing in the corner — a `ShadowFigure` that does not drift, does
     not vanish under gaze, and is simply not there when you leave and return
  3. all doorways in the cell reduced to one

Mutation 3 is the most interesting and the most dangerous: it can seal the
player in. It must respect the `WorldGen._parent_dir` spanning tree — every cell
force-opens one edge toward the origin, and that edge is what guarantees the
world is connected. **Never close a parent edge.** If that cannot be
guaranteed cheaply, ship mutations 1 and 2 only; they carry the idea on their
own.

Verify connectivity with a flood fill after any change here. The existing
guarantee is 361/361 cells reachable across seeds.

---

## 9. Phase 5 — the pursuer and the end of a run

**Pursuer.** At `attention >= 0.85`, one figure spawns that:

- does not vanish under gaze, proximity or time
- moves toward the player at just under walk speed (~3.0 m/s against the
  player's 3.4) so walking holds it off and stopping does not
- despawns on a floor change — descending is the escape, which is the whole
  point of the mode

Reuse `ShadowFigure` with a `pursuer := true` flag rather than writing a new
node: the mesh build, the billboard and the materials are all there. It needs
simple navigation — a floor raycast plus a wall raycast, or straight-line drift
with a wall slide. It does not need pathfinding; something that catches on
corners occasionally is scarier than something that solves the maze.

Contact ends the run.

**Summary.** On end, fade to black and show, centred, in the title's type:

```
FLOOR 4 — THE SCHOOL
17:42   ·   3 rules broken
seed 1839472051

SPACE to walk again
```

Won runs say `OUT` in place of the floor line. Build it as a `CanvasLayer` at
layer 3 (above the tube, like `TitleScreen` — the CRT eats 15px text at 240
lines) and reuse `TitleScreen._style()`/`_relayout()` sizing so it scales with
the viewport.

Restart should rebuild from `main`, not reload the scene, so the seed can be
kept or rerolled deliberately.

---

## 10. Tuning values, all in one place

Everything below is a first guess. None of it is derived from playtesting.

| Constant | Start | Notes |
|---|---|---|
| `ELEV_P` | `0.06` | of eligible cells. Lower if elevators feel common. |
| `ELEV_SIGN_R` | `4` cells | ~48m of guidance. |
| stare cost | `+0.10` | ten stares to max attention. |
| stopped cost | `+0.03/s` after 6s | |
| backtrack cost | `+0.06` | once per cell. |
| blackout-move cost | `+0.08/s` | |
| attention decay | `-0.01/s` | ~100s of clean walking per stare. |
| blackout interval | 90–150s → 25–40s | by attention. |
| blackout duration | 5–8s | |
| `noise_amount` | `1.0 → 2.6` | shader hard max 3.0. |
| figure interval scale | `1.0 → 0.35` | ~11s → ~4s. |
| pursuer threshold | `attention 0.85` | |
| pursuer speed | `3.0 m/s` | player walks 3.4, sprints 6.2. |

---

## 11. Suggested order of work

1. **Phase 1** — plumbing. Small, and it proves the sandbox is safe.
2. **Phase 2** — the elevator. The biggest single piece; nothing downstream
   works without it. Verify by screenshot per theme before moving on.
3. **Phase 3** — rules and attention. The mode becomes playable here; stop and
   play it before adding more.
4. **Phase 5** — pursuer and summary. A run needs an ending before anomalies
   are worth tuning.
5. **Phase 4** — anomalies. Genuinely optional for a first playable; it is
   texture, not structure.

Phases 4 and 5 are deliberately swapped relative to their numbering. A run that
can end is worth more than a run with better texture.

---

## 12. Open questions

- **Sprinting.** Should Shift still work in Descent? It trivialises "do not stop
  walking" and outruns the pursuer. Consider removing it, or giving it a cost.
- **Rule 3 and dead ends.** A maze with no map will produce corridors that must
  be backtracked. `+0.06` once per cell is intended to be survivable, but if
  dead ends are common the rule may need to only fire on cells you have *fully
  crossed* rather than merely entered.
- **The tube.** `noise_amount` is the main attention tell, and `V` turns the
  tube off entirely. Either Descent locks the tube on, or attention needs a
  second expression that survives with the tube off.
- **Seeds.** Generation is deterministic, so a daily seed and a shareable run
  string are nearly free once the summary screen exists. Out of scope here, but
  do not do anything that makes it harder.
