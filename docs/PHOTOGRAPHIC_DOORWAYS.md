# Photographic doorways

In Descent, a solid wall can show a real passage through the raised camera.
Photograph it with **C → Space**. The wall remains solid during print review;
when the print lowers, the passage opens with the existing cyan/violet blackout
reveal. The complete glow lasts **2.5 seconds**. Scheduled blackouts wait until
that reveal finishes, and the evidence caption follows the glow.

The opening connects actual generated rooms. It is visible through the
viewfinder from either side, counts as evidence, stays usable after the photo
quota, and retains the ordinary post-photograph risk roll.

## Photograph away an obstruction — all eleven levels

Each Descent theme can reserve a generated passage filled with appropriate
props. These are solid in ordinary view and absent through the raised camera,
so the actual connected room is visible before the photograph. After print
review, collision clears immediately and a cyan/violet imprint fades over
2.5 seconds. The opening survives streaming, blackouts and Continue. The album
keeps the photograph and a theme-specific description. New discoveries keep
working above the progression minimum; repeat photos give no duplicate credit.

| Floor | Setting | Obstruction |
| --- | --- | --- |
| 1 | Casino | Slot machines |
| 2 | Mall | Stockroom cartons |
| 3 | Office | Metal shelving |
| 4 | Airport | Luggage trolleys |
| 5 | School | Existing single-column lockers |
| 6 | Prison | Bunk beds |
| 7 | Asylum | Hospital beds |
| 8 | Poolrooms | Lounge chairs |
| 9 | Annex | Metal shelving |
| 10 | Data Center | Server racks |
| 11 | Upside Down | Incubator cabinets |

All visible obstruction geometry comes from existing imported game models,
with original materials and uniform scaling. Collision hulls come from those
meshes, and the reveal copies those same meshes. Each endpoint owns a bank
on its side of the doorway; its measured depth also sets the camera framing
points. The mall selects a closed box from the existing cardboard asset pack.

Placement searches generated room connections, with at most sixteen objective
candidates in each of sixteen districts. Existing central arrivals are kept
when suitable; the casino and mall use seeded districts from the start.
The useful entrance lies on the ordinary route and saves at least four room
transitions. Both rooms reserve 6.7m of furnishing-free space. Structural
corridors are excluded except the mall's open galleries; pool sites must be
dry and both endpoints must have matching floor heights. Live clearance checks
suppress unusable previews. A later floor may omit the obstruction if the
bounded placement search finds no suitable connection.

The casino retains its early hidden doorway and can also place an obstruction.
New-run admission continues to validate the introductory doorway; it does not
force every seed to contain both interactions. The obstruction
must still save four transitions after the hidden doorway opens; the hidden
doorway must still improve the route if the obstruction is photographed first.
The short first floor does not require two independent four-room detours.
When both are present, they reserve their rooms before other content is placed. Evidence
coverage follows the route with the reserved passages open, including correct
Annex room ownership, and supplements it from the existing extra-photo pool.

Fast playtest, isolated from normal saves:

```sh
godot --path . -- --first-obstruction=4 --seed=21
```

Replace `4` with any floor number **1–11**. Plain `--first-obstruction` keeps
the original mall test. You start facing the props: **C**, then **Space**, wait
for the print to lower, and walk through. **P** opens the album. For ordinary
route discovery, use `--mode=descent --descent-floor=4 --nologo --seed=21`.

Checks and real shutter captures:

```sh
godot --headless --path . --script tools/audit_all_floor_obstructions.gd -- --seed=21 --states=7
godot --headless --path . --script tools/audit_photo_obstruction.gd -- --mode=descent --descent-floor=2 --nologo --seed=21
godot --path . --audio-driver Dummy --script tools/capture_photo_doorway.gd -- --first-obstruction=4 --seed=21
```

Obstruction captures write six states under
`/tmp/liminal-photo-obstruction/floor-04` (matching the selected floor).
Generation version is **7** because route and reservation selection changed.

## First-floor discovery

New Descent runs admit a first floor only when it contains one introductory
photographic doorway:

- Its useful entrance is in a room on the base route, within the first four
  room transitions and eight cell steps. Merged-room seams are not transitions.
- The connection saves at least four room transitions toward the objective.
- Its entrance is encountered before any optional recording room on that route.
- Neither connected room receives a landmark or an ordinary planned anomaly.
- The shortened route still offers enough evidence to meet the tape quota.
  A portion of the existing extra-photo pool is assigned there when needed;
  the player need not return to skipped rooms just to fill the counter.
- Both rooms reserve 6.7m of space to stand back and frame the doorway.
  Admission and live readiness inspect the full rooms' nested colliders for
  a clear view and passage, rather than accepting an empty navigation edge.

The casino starts in a seeded district away from the world's central hub.
The generator tries up to twelve valid objective locations and reserves both
photographic discoveries before assigning landmarks and optional recordings. This creates a
procedural connection; it does not insert a fixed room or scripted encounter.

`FirstDoorStart` accepts the requested seed when valid, otherwise tries a
bounded sequence of derived seeds. After 32 attempts, it checks a small set of
fallback generated seeds through the same validation. It never silently admits
an invalid floor. The accepted seed becomes the actual run seed and is saved;
Continue uses that seed without rerolling. CLI starts print any seed change.
This selection adds work at new-run startup, including construction of the
candidate's two owning rooms. Repeated checks are cached within the process.

Every later floor now reserves a themed obstruction when a suitable generated
connection exists. Their placement remains unpredictable. The existing interference,
proximity sounds and viewfinder focus lead to the first door; no new text
explains that photographs alter the wall. Existing camera control hints remain.

## Play it

Start a **new Descent** to test discovery naturally. For a reproducible run
from its normal arrival:

```sh
godot --path . -- --mode=descent --nologo --seed=21
```

To start directly facing the introductory doorway:

```sh
godot --path . -- --first-door --seed=21
```

Seed 21 encounters it after two room transitions. The entrance is in cell
`(53, 51)`, facing north into `(53, 50)`; it saves seven room transitions.
Press C, lower it without shooting to see the wall return, then C → Space and
walk through after the print lowers. Rerun the command for a fresh test.
CLI sessions do not overwrite the player's normal checkpoint. Earlier seed-7
coordinates predate the first-floor generation change and are no longer the
test location.

Use [the five-player protocol](FIRST_DOOR_PLAYTEST.md) for discovery testing.
Participant results are still blank; automated checks do not establish that
people will notice or understand the mechanic.

## Persistence and construction

`DescentTopology` owns reservations and opened state; `PhotoDoorSeal` owns the
visual/physical seal; `PhotoDirector` reconciles streaming and evidence;
`PhotoCamera` commits after review. The aperture is constructed and furnished
before the player sees it. Opening it removes the independent seal, without
rebuilding rooms or deleting props in view.

Both complete owning rooms must be resident before the closed doorway becomes
visible through the camera. Saved photo IDs restore opened doors before chunk
streaming, including quitting during print review. A floor-bound callback
survives retirement of the photographed anomaly node. Opened doors take
precedence over every blackout state and refresh navigation.

Mutation generation is version **5**. Older mutation signatures fall back to
the base reality on Continue. First-floor arrival, target and discovery
placement have changed; use a new run to evaluate this version. Existing photo,
tape and runtime-object progress formats are retained. Wander remains unchanged.

## Verification

```sh
godot --headless --path . --script tools/audit_first_door.gd -- --mode=descent --nologo
godot --headless --path . --script tools/audit_first_door_generation.gd -- 20
godot --headless --path . --script tools/audit_photo_doorways.gd -- --mode=descent --nologo
godot --headless --path . --script tools/audit_descent_routes.gd -- 5
godot --headless --path . --script tools/audit_casino_landmarks.gd
godot --headless --path . --script tools/audit_optional_vhs.gd
```

For environments that cannot write Godot's normal user log directory, add
`--log-file /tmp/first-door-test.log` before `--script`.

The live discovery audit follows resident-room streaming from the normal route,
checks detector/focus and a legal standing position, and rebuilds both complete
rooms through all blackout furnishing variants. The generator audit measures
shortcut savings through an independent room graph, checks ordering and content
reservations, deterministic admission, seed exclusion and fallback validity.
The existing doorway audit verifies both-side framing, delayed collision,
player traversal, quota independence, disk save, streaming and blackout state.

Current checks passed: 20 requested seeds with independently measured savings
and shortened-route evidence coverage; 55 routes across all eleven floors;
65 casino landmark seeds; 78 optional recording placements; live detector,
framing, opening, save/reload and blackout contracts. Seed admission selected
another layout when a candidate could not support the shortened-route quota.
No fallback seeds were needed in the 20-case sweep. New-run preparation can
add several seconds; the bounded search deliberately favors a valid encounter
over immediately accepting an unsuitable layout.

For real shutter captures:

```sh
godot --path . --audio-driver Dummy --script tools/capture_photo_doorway.gd -- --mode=descent --nologo --seed=21
```

It writes six states to `/tmp/liminal-photo-doorway`. Current logs and captures
are retained locally in ignored `build/first-door-review/`. Earlier generation-4
validation remains in `build/photo-doorway-review/`.

Some headless tools emit macOS certificate or dummy-renderer teardown errors;
the capture tool can report texture RIDs retained at exit. Record these
separately from assertion results rather than describing every log as clean.
