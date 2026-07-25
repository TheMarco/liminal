# Liminal Vegas

A Godot 4 proof of concept: first-person wandering through **endless,
procedurally generated liminal spaces** across eight floors:

- **Floor 1 — the casino**: seedy Vegas hotel. Garish carpet, flickering
  fluorescents, humming air, slot machine banks glowing in empty rooms,
  double-height marble halls.
- **Floor 2 — the office**: sterile Severance-style corporate limbo. Endless
  flat-white corridors, teal-green carpet, shadowless fluorescent grids, and
  MDR-style desk clusters where CRT terminals show drifting numbers to no one.
- **Floor 3 — the sewers**: dripping concrete works. Black water sliding
  through channels and basins, caged bulbs, rusting pumps and pipe runs.
- **Floor 4 — the airport**: a vast terminal at 3 a.m. Terrazzo halls, gate
  lounges behind black glass, a docked jetway out on the apron, moving
  walkways that still carry you, baggage carousels turning for no one,
  check-in queues held by belts, departure boards where everything is
  DELAYED, and a PA that chimes and mumbles to an empty building. Through
  the gate glass: an airliner still on stand, cabin lights burning for
  nobody, anti-collision beacon flashing — and further out, parked heavies
  and one aircraft forever taxiing on the horizon.
- **Floor 5 — the asylum**: an abandoned institution nobody decommissioned.
  Peeling institutional-green paint over brick, cracked tile wainscots,
  grimy checkerboard corridors lined with heavy green steel doors, rusty
  bed frames with stained mattresses, parked gurneys and wheelchairs,
  straitjackets on wall hooks, restraint tables under surgical lamps, ECT
  carts, hydrotherapy tubs of black water — and writing on the walls that
  nobody signed. Iron clangs somewhere down the ward. Sometimes it moans.
- **Floor 6 — the school**: a high school after a last bell that never rang.
  Cream block walls under a red line that runs the whole building, a floor
  ground until it throws the strip lights back, and narrow locker-lined
  corridors — the cell is walled down to four metres across, with the doors
  set back in bays off it. Off those: classrooms in rows facing a chalkboard
  with something still written on it, a cafeteria of folding tables and a
  cold serving line, tiled bathrooms with the stall doors ajar, a library of
  half-raided stacks, science labs with gas taps and stools, the front
  office, and a gym with a sprung maple floor, hoops at both ends and the
  bleachers pulled out and left out. The science rooms are now consistent
  chemistry labs built around full sink-and-tap islands, with supported
  glassware left on their black worktops.
- **Floor 7 — the mall**: a dead indoor shopping centre. Broad terrazzo
  galleries pass shuttered storefronts, deserted kiosks and planter islands;
  beyond them are stripped department stores, a food court, service corridors,
  a dry atrium fountain and a sealed six-screen cinema.
- **Floor 8 — the prison**: a salt-eaten island penitentiary. Barred galleries,
  close cells and stacked bunks open into mess halls, communal showers, guard
  cages, workshops and visitation booths. Rare cell blocks rise into false
  upper tiers and a central rotunda watches every direction at once.

It opens on a title card — the logo, what every key does, and one
instruction — over a world that is already built and already running behind
it. Nothing moves until you press **space**.

Press **1**–**8** to ride the elevator between floors — each floor keeps
its own geography and remembers where you were. Or don't press anything:
**swirling portals** hang in the roomier chambers of every floor, tinted the
colour of wherever they lead. Step in and you emerge in the same cell of
another world.

Some of the building now answers back. Aim at an active control and press
**E**: office terminals reveal successive records, a small selection of real
doorway leaves can be opened and closed, and rare physical elevator panels
carry you onward. Local lights occasionally sag, an unused lift may chime down
the hall, and inaccessible rooms sometimes knock from the other side.

The whole feed plays back as **720×480 interlaced footage on a widescreen CRT
tube**: barrel curvature, beam scanlines, a
Trinitron aperture grille, RGB convergence error, halation, interlace
flicker, a rolling scan band, and rounded tube corners. Press **V** to
look at the world with your own eyes instead.

You are, occasionally, not alone. A dark figure sometimes stands where
nothing stood — down a corridor, at the edge of the frame, behind you (one
soft footstep, so you know to turn). **It closes the distance whenever you
are not looking straight at it**, and freezes the instant you are: glance
away, glance back, and it is nearer than it was. Holding it in the centre of
your vision pins it and slowly wears it down; the flashlight burns it away in
a fraction of the time, and burns it away spectacularly — a ragged front runs
up the body, the walls light up, and it goes out screaming. Seven recordings
for that, its own sound rather than a stinger pitched up: a stinger is
something arriving, and this is something ending. Let one reach you instead
and it is a scare in the endless floors and the end of a Descent run.

There are seven of them, and every one is animated — hooded wraiths of drifting
smoke with lit eyes, all but one of them red. Two hang rather than walk and
trail into nothing where legs should be; those keep to the sewers and the
asylum, the floors where something could have got in from below. They are
sprite-sheet flipbooks rather than video: Godot's only codec is Theora, which
carries no alpha, so an animated silhouette would be a black rectangle.

Each floor also carries its own mood track (`music/lim*.mp3`), crossfading as
you ride between worlds. Descent preserves those floor identities, then shifts
to `lim9.mp3` for its final two floors as the pressure peaks; Wander is
unchanged. Whip around fast enough and one may already be
standing there — and that arrival, rarely and never twice inside a minute,
brings a stinger with it. There are twelve of those, each trimmed to a common
mean so none of them is the loud one, and the picker never plays the same
stinger twice in a row: a scare you recognise is a sound effect.

After a fright your own pulse comes up under everything, and it takes its time
going away again — a heartbeat that snaps off the moment the figure fades is a
sound effect, but one still going twenty-five seconds later, slowly settling
while you stand in an empty corridor deciding whether to turn around, is what
the frights are for. It quickens as well as swells, compounds if something
startles you before you have recovered, and holds itself up on its own whenever
one of them is standing close by. Past a certain fright your breathing joins it
— but only past it, so mild dread is a pulse and panting over the top is panic.
Arriving together would leave the game nowhere to escalate to.

Under all of that, someone is muttering. Eleven recordings of whispering in a
dead language surface every forty seconds to two minutes, placed out in the
world rather than in your head — so a voice arrives from a direction, falls off
across the room, and is gone before you have finished turning toward it. They
sit sixteen decibels under the stingers and never come from directly behind
you: that would read as someone at your shoulder, and being startled is the
figures' job. This is only ever a suggestion that the floor is occupied.

Doorways only ever appear between spaces that feel like rooms — an edge
that would put a lone cased door in the middle of a merged open hall opens
fully instead, so every door you do see plausibly leads somewhere.
Closed hotel-room, private-office, asylum patient-room and school-classroom
doors reserve real, inaccessible floor-plan volume behind the corridor wall.
Each corridor shell runs continuously across cell boundaries, while genuine
room connections cut a return-walled vestibule, tiled cross-passage or cased
classroom recess through that shell. You can walk past a locked room forever,
but you can never walk around the wall and discover the back of its door.

The grid also carves **corridor bands**: whole rows and columns collapse
into narrow passages that run cell after cell — numbered-door hotel
corridors in the casino, sealed private offices and return-walled vestibules
in the office, locked patient wards and tiled cross-passages in the asylum, pipe
galleries with the channel running down the middle in the sewers, and
continuous low-ceilinged transit tubes in the airport. Airport walkway banks
sit inside finished panel walls with steel-framed, return-walled access portals
where the graph genuinely connects to a concourse. School halls reserve sealed
classroom strips, with locker banks ending cleanly at wired-glass doors and real
room recesses. Where two corridor cells meet, the passage punches straight
through.

The world generation, lighting, shaders and audio are procedural — but
every floor is now dressed with **downloaded CC0 assets**: photo PBR
textures from [ambientCG](https://ambientcg.com) applied with world-space
triplanar mapping (glossy marble and red hotel runners in the casino, old
brick in the sewers, real terrazzo in the airport, peeling plaster and broken tile in the asylum),
and glTF props from [Poly Haven](https://polyhaven.com): Victorian sofas,
chandeliers and gilt-framed oils in the casino; CRT televisions, coffee
carts and wet-floor signs in the office; oil drums, crates, tyres and
trash bags in the sewers; abandoned trunks in baggage claim; bed frames, wheelchairs and
crutches in the asylum; adjustable desks and moulded chairs in the school.
Anything animated or bespoke (slot machines,
travelators, water, departure boards) stays procedural. The
music (`music/lim*.mp3`) and the recorded audio in `sounds/` are the binary
indulgences.

Audio is mixed by measurement rather than by ear: the recordings in `sounds/`
arrive anywhere between -12.7 dB and -43.3 dB mean, a thirty-decibel spread,
so `scripts/sfx.gd` carries each file's measured level and trims it to a
common target. The room tone for a floor sits about 9 dB under the music,
which itself plays at -14 dB — the casino and the school borrow the office
recording for now, having none of their own, while `sound-slots.mp3` is not a
room tone at all but the machines, emitted from the slot banks themselves so
it fades up as you walk into one; the walking loops — continuous recordings of
roughly two steps a second, faded in and out with your speed and pitched up
when you run, rather than triggered per stride — sit alongside it and cut
through on their transients.

## Run it

1. Install [Godot 4.6+](https://godotengine.org/download) (Forward+ / desktop).
2. Open this folder in the Godot project manager (Import → select `project.godot`).
3. Press **F5** (Run Project).

Or from the command line:

```sh
godot --path .
```

## Building

`./build.sh` produces both desktop builds (needs Godot 4.6 on `PATH` with
export templates installed):

- `build/macos/LiminalVegas.app` — universal (Apple Silicon + Intel), signed
  with Developer ID under the hardened runtime, **notarized by Apple and
  stapled**, so it opens on any Mac with no Gatekeeper warning. Notarization
  uses the stored `AC_PASSWORD` notarytool profile; `NOTARIZE=0 ./build.sh`
  skips it for a quick local build.
- `build/windows/LiminalVegas.exe` — single self-contained x86_64 binary,
  no installer and no DLLs beside it.

## Controls

| Input | Action |
|---|---|
| WASD / arrow keys | Move |
| Mouse | Look |
| Shift | Sprint |
| E | Use a focused terminal, elevator panel or working door |
| F | Toggle the handheld flashlight |
| 1–8 | Switch floor (casino / office / sewers / airport / asylum / school / mall / prison) |
| V | Toggle the CRT tube effect |
| Q | Ask to end the current mode and return to the title |
| Esc | Release mouse |
| Click | Recapture mouse |

## How it works

The world is an infinite grid of 12×12 m cells. Every property of a cell —
its walls, doorway positions, room style, light color, whether its light is
dead or flickering — is a **pure hash of (world seed, cell coords)**
(`scripts/world_gen.gd`). Chunks stream in around the player
(`scripts/chunk_manager.gd`) and are freed behind them; walking back rebuilds
them identically.

Walls live on cell edges and are decided by a hash of the *edge*, so both
neighbouring cells always agree. A cell that would be sealed on all four
sides deterministically force-opens its lowest-hash edge. Open edges are
either full open (rooms merge into halls) or a cased doorway, sometimes with
a glowing EXIT sign.

Room styles per floor range from empty halls to set pieces: slot rows,
lounges and grand halls in the casino; corridors, cubicle clusters, storage
and break rooms in the office; tunnels, basins and pump rooms in the sewers;
gate lounges, moving-walkway concourses, transit corridors (banks of three
walkways running in opposite directions), check-in rows, baggage claims and
escalator mezzanines in the airport; patient rooms, bed wards, treatment
rooms, hydrotherapy halls, records offices and the rare dayroom in the
asylum; shuttered stores, atriums, food courts and cinema lobbies in the mall;
and cell blocks, mess halls, showers, workshops and guard posts in the prison.
Set dressing runs deep: neon amenity signs, blackjack tables and
velvet ropes in the casino; filing banks, motivational posters, department
signs and idling copiers in the office; stencilled markings, control
cabinets, hanging chains and knee-deep mist in the sewers; scrawled walls
in two different hands, cork noticeboards, ward signs and numbered steel
doors in the asylum.

Rooms are grouped into deterministic **96m semantic districts**, so a run of
spaces now belongs to the same part of the building instead of every doorway
rolling independently. Casino gaming floors give way to hotel and convention
areas; offices resolve into operations, records and staff departments; sewer
conveyance reaches treatment and maintenance works; airport airside becomes
departures and arrivals; patient wings transition through treatment to
administration; school academic wings open into commons and front-office
zones; mall retail galleries decay toward food/cinema and service wings; prison
cell blocks give way to institutional and custody zones. Office directories,
airport wayfinding, asylum ward plates and school room labels agree with the
surrounding district.

True 24x24m halls can very rarely become a memorable **landmark**: the Silver
Room ballroom, an impossible corporate boardroom, a four-pool cistern under a
pipe manifold, a shuttered airport food court, the asylum chapel, or the school
auditorium, along with a dead six-screen cinema and prison guard rotunda. Landmarks are
deterministic, never claim a corridor or small room, and leave a clear route
through the space.

Merged rooms furnish against their full generated footprint rather than
repeating a 12×12 m layout in the middle: grand casino halls extend their
column grid and gaming islands, open offices grow into multiple cubicle
neighbourhoods, sewer pump works place a complete machine train in every
occupied cell while treatment banks dress every pool with rails and inspection
bridges, baggage claims gain perimeter seating and trolley ranks, and large
asylum dayrooms divide into separate abandoned activity groups.

Surface finishes also change in deterministic six-cell maintenance districts:
related wallpaper dye lots, office paint, airport panels and school block paint
stay coherent over long stretches, then shift as though another renovation era
took over. Every cell of a merged room agrees on the finish. Sparse casino and
office rooms receive occasional abandonment vignettes—an uncleared service cart
or archive boxes with forms spilled across the carpet—without blocking routes.
The existing CC0 pool is used more broadly as well: food-court tables and carts,
modelled auditorium seating, office edge furniture, and several generations of
sewer crates, stoves, wheel rims, lanterns and industrial fixtures break up the
most recognizable procedural repeats.

### Fidelity features

- **Real-time global illumination (SDFGI)** — light bounces: neon washes the
  slot floor, green carpet tints the office walls, emissive panels light
  their rooms. Reflection probes give true reflections in marble halls and
  slot rooms.
- World-space procedural shaders with **height-field normal mapping**
  (carpet pile, embossed wallpaper, ceiling tile seams, marble veining) —
  patterns continue seamlessly across chunk borders, with mipmapped noise
  textures for calm-at-distance micro detail.
- **Shadow-casting per-room lights** (soft, high-res atlas) with distance
  fade, plus sconces, chandeliers, slot glow and neon coves.
- **AGX tonemapping, TAA + MSAA, SSAO + SSR**, bloom, depth + volumetric
  fog, and a photographic post pass: film grain, vignette, subtle chromatic
  aberration.
- Architectural trim: crown molding, baseboards, chair rails, door casings.
- Procedural audio, all synthesized at runtime (`scripts/sound_bank.gd`):
  global room-tone hum, spatial slot machine chimes, fluorescent ballast buzz
  on flickering fixtures, muffled PA muzak in lounges, footsteps that switch
  between carpet and marble, and rare distant thuds / elevator chimes — all
  routed through a shared reverb bus.

## Tuning

- `world_seed` — export on the root node in `scenes/main.tscn` (0 = random,
  printed to the console each run).
- `WorldGen.WALL_P` — wall density (default 0.45).
- `ChunkManager.LOAD_R` / `BUDGET` — stream radius and per-frame build budget.
- Level changes synchronously build only a safe 3x3 neighbourhood; the rest of
  the 7x7 view streams closest-first inside a 6ms frame slice. glTF props begin
  loading on worker threads behind the title card, and multi-cell rooms share a
  single reflection probe.
- Performance: the biggest costs are SDFGI, TAA, volumetric fog and omni
  shadows — set in `scripts/main.gd::_build_env`, `project.godot` and
  `chunk.gd::_build_lighting` if you need to trade fidelity for FPS.
- `godot --headless --path . --script tools/audit_corridors.gd` — exercises
  deterministic corridor topology across many seeds and fails if a narrow
  corridor exposes its reserved backing space, interrupts a through-spine, or
  disagrees with the neighbouring cell about a shared edge.
- `godot --headless --path . --script tools/audit_sewers.gd` — verifies the
  sewer channel and flow graph from both sides of every edge, the protected dry
  spawn edge, and the room-size contracts for tunnels, basins, pump rooms, dry
  chambers and service galleries.
- `godot --headless --path . --script tools/audit_zones.gd` — samples more than
  26,000 rooms per theme, verifies room-level district/style consistency and
  checks that landmarks only occupy eligible 2x2 halls at the intended rarity.
- `godot --headless --path . --script tools/audit_arrivals.gd -- 16` — follows
  real generated portals across every floor and many seeds, builds each 3×3
  destination neighbourhood, then verifies both portal and restored saved-position
  landing capsules have a supporting floor and at least two clear escape directions.
- `godot --headless --path . --script tools/audit_level_switches.gd -- --nologo`
  — runs the actual floor-transition path against the school regression seed and
  verifies the outgoing floor leaves physics before the landing probe begins.
- `godot --headless --path . --script tools/audit_interactions.gd` — activates
  a generated terminal, lift panel and working door, then verifies their state
  and animation responses.
- `godot --headless --path . --script tools/audit_doorways.gd` — builds
  furnished rooms across every floor and fails if any generated prop mesh or
  collider remains inside the protected approach lane of a real doorway. It
  also rejects orphan EXIT lettering and invalid school boards, stationery,
  terminals, or projector screens, and takes a census of every authored
  furnishing across all eight floors — beds, gurneys, baths, door leaves,
  blackjack and roulette tables, the hotdog cart, the autopsy table, the copier,
  school desks and desk phones. A downloaded model that quietly stops reaching
  its rooms fails the build instead of just disappearing.
- `godot --headless --path . --script tools/audit_slots.gd` — samples casino
  banks across many seeds and requires every slot cabinet to have explicit,
  opaque front and rear volume.
- `godot --headless --path . --script tools/audit_new_levels.gd` — builds every
  mall and prison room style, checks support and doorway clearance, enforces
  one coherent food-court identity, and keeps bunks and detention fixtures
  inside actual barred cell contexts. It also proves the authored mall models
  still import: a painted fascia keeps the artwork's own aspect inside the sign
  band, and the payphone and directory are counted rather than allowed to fail
  silently into their generated fallbacks.
- `godot --headless --path . --script tools/audit_wall_art.gd` — exercises all
  seventeen active paintings across the seven art-bearing floors and verifies
  that every piece remains wall-mounted, inside the solid wall bounds and at
  its original aspect ratio without being bisected by an interior partition.
  The sewer is explicitly audited to remain bare.
- `godot --headless --path . --script tools/profile_generation.gd` — constructs
  real chunks for every floor, reporting first-pass and steady-state build
  latency plus mesh, collision, light and reflection-probe counts.

GitHub Actions runs every `audit_*.gd` check above on pushes to `main` and on
pull requests via `.github/workflows/audits.yml`.

## Assets and attribution

The game is not restricted to attribution-free assets. Carefully selected
CC BY work is welcome when it is a strong visual and contextual fit, its source
and license are recorded, and any modification is documented. The compact
in-game Credits screen is available from the title with `C`; the canonical
record is [`THIRD_PARTY_ASSETS.md`](THIRD_PARTY_ASSETS.md).

The accepted-license policy and level-by-level high-value replacement list are
in [`docs/ASSET_OPPORTUNITIES.md`](docs/ASSET_OPPORTUNITIES.md). Clearly
documented CC BY-NC work is permitted for this explicitly noncommercial game;
any future commercial build must replace those assets first. No-derivatives,
editorial-only, personal-use-only and unclear licenses remain out of scope.

Attributed models are stored separately by license: `models/cc_by/` contains
redistributable attribution-required work, while `models/cc_by_nc/` and
`textures/cc_by_nc/` contain assets that make the resulting build
noncommercial. Every such asset has a local `SOURCE.md` in addition to the
canonical record above.

Where a download is a whole scene rather than a prop — an abandoned hospital, a
shopping mall — only its separately-modelled objects are extracted, re-origined
and redistributed; the building itself is not. Those extractions are listed
individually in the asset's `SOURCE.md` with their source node names.

The single CC BY-NC dependency in the mall is deliberately confined to one
function, `_mall_painted_sign` in `scripts/chunk.gd`. Deleting that function and
its one call site restores the generated storefront lettering and removes the
noncommercial obligation in a single edit.

Dev tools for adding content:

- `godot --path . tools/preview_model.tscn -- --model=res://… --screenshot=/tmp/x.png`
  stages one model on a lit floor. `--scale=`, `--rot-x/y/z=`, `--camera=` and
  `--scale-reference` (a 1m grid plus a slab at the player's 1.62m eye height)
  make it possible to check a placement transform before writing any placement
  code. It needs a real window — Godot cannot render in `--headless`.
- `godot --headless --path . --script tools/dbg_asylum.gd -- <seed> <x> <z>`
  prints where every authored asylum prop landed in one cell, with world AABBs,
  which answers most placement questions without opening a window at all.
- `godot --headless --path . --script tools/dbg_find_prop.gd -- <seed> <theme>
  <kind> [radius]` finds authored furnishings by kind — `blackjack_table`,
  `hotdog_stand`, `autopsy_table`, `ward_bed` and so on — and prints a
  ready-made `--pos`/`--yaw` to stand in front of one. Aiming a screenshot by
  trial and error wastes far more time than it looks like it will.
- `godot --headless --path . --script tools/dbg_mall_signs.gd -- <seed>
  [radius]` does the same for painted storefront fascias, which are quads
  rather than furnishings and so are not in the census above.
- `python3 tools/build_flipbook.py SRC.mp4 textures/ghosts/NAME.png --frames 24
  --height 288 --cols 6` turns a white-background looping video into an
  animated ghost sheet, printing the shader constants and the `BODY` row it
  needs. Godot's only video codec is Theora and it carries no alpha, so an
  animated silhouette has to be a flipbook.
- `godot --path . -- --whispers` shortens the whisper timer and prints the
  bearing, distance and level of each one, so the layer can be judged in a
  minute rather than in twenty.

## Structure

```
scenes/main.tscn          minimal root scene (everything else is code-built)
scripts/main.gd           environment, player, streamer, UI bootstrap
scripts/world_gen.gd      deterministic hash queries (walls, styles, doors)
scripts/chunk_manager.gd  chunk streaming
scripts/chunk.gd          per-cell geometry, furnishing, lights
scripts/mats.gd           shared material cache
scripts/player.gd         FPS controller
scripts/flicker_light.gd  fluorescent flicker behaviour
scripts/ambience.gd       procedural room tone
scripts/whispers.gd       positional muttering, placed out in the world
scripts/heartbeat.gd      fright tension: pulse, then breathing; decays to calm
scripts/interactable.gd   shared E-key ray targets
scripts/environment_events.gd  sparse local power and sound events
scripts/arrival_safety.gd physics-tested portal / floor arrival resolver
scripts/travelator.gd     moving-walkway drive volume
scripts/spinner.gd        baggage-carousel rotation
scripts/*_sounds.gd       per-theme spatial sound emitters
shaders/*.gdshader        carpet / wallpaper / marble / terrazzo / night apron / ...
textures/asylum/          CC0 PBR textures for the asylum (ambientCG), 1K JPG
textures/cc0/             shared CC0 textures for the other floors
models/asylum/            CC0 glTF props for the asylum (Poly Haven)
models/cc0/               shared CC0 prop pool (Poly Haven)
models/cc_by/             attributed models with per-asset source records
```
