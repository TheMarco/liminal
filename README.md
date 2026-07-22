# Liminal Vegas

A Godot 4 proof of concept: first-person wandering through **endless,
procedurally generated liminal spaces** across six floors:

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
  bleachers pulled out and left out.

It opens on a title card — the logo, what every key does, and one
instruction — over a world that is already built and already running behind
it. Nothing moves until you press **space**.

Press **1**–**6** to ride the elevator between floors — each floor keeps
its own geography and remembers where you were. Or don't press anything:
**swirling portals** hang in the roomier chambers of every floor, tinted the
colour of wherever they lead. Step in and you emerge in the same cell of
another world.

The whole feed plays back as **240p footage on a consumer CRT tube** (the
composite pass ported from the scramble Godot port, dropped to 240 lines;
the 3D view itself renders at 240p): barrel curvature, beam scanlines, a
Trinitron aperture grille, RGB convergence error, halation, interlace
flicker, a rolling scan band, and rounded tube corners. Press **V** to
look at the world with your own eyes instead.

You are, occasionally, not alone. A dark figure sometimes stands where
nothing stood — down a corridor, at the edge of the frame, behind you (one
soft footstep, so you know to turn). Hold your gaze on it or walk toward it
and it is gone before your eyes finish focusing. It never approaches. There
are thirteen of them: a coat with hair over its face, a gown that hangs
rather than stands, something tattered that used to be a man, a walker
carrying a knife, a hooded one with an axe in each hand — and, only down in
the sewers and the asylum, two that are not pretending to be people at all.
Each floor also carries its own mood track (`music/lim*.mp3`), crossfading as
you ride between worlds. Whip around fast enough and one may already be
standing there — and that arrival, rarely and never twice inside a minute,
brings a stinger with it.

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
crutches in the asylum. Anything animated or bespoke (slot machines,
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

1. Install [Godot 4.3+](https://godotengine.org/download) (Forward+ / desktop).
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
| 1–6 | Switch floor (casino / office / sewers / airport / asylum / school) |
| V | Toggle the CRT tube effect |
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
asylum. Set dressing runs deep: neon amenity signs, blackjack tables and
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
zones. Office directories, airport wayfinding, asylum ward plates and school
room labels agree with the surrounding district.

True 24x24m halls can very rarely become a memorable **landmark**: the Silver
Room ballroom, an impossible corporate boardroom, a four-pool cistern under a
pipe manifold, a shuttered airport food court, the asylum chapel, or the school
auditorium. Landmarks are deterministic, never claim a corridor or small room,
and leave a clear route through the space.

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
- `godot --headless --path . --script tools/profile_generation.gd` — constructs
  real chunks for every floor, reporting first-pass and steady-state build
  latency plus mesh, collision, light and reflection-probe counts.

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
scripts/travelator.gd     moving-walkway drive volume
scripts/spinner.gd        baggage-carousel rotation
scripts/*_sounds.gd       per-theme spatial sound emitters
shaders/*.gdshader        carpet / wallpaper / marble / terrazzo / night apron / ...
textures/asylum/          CC0 PBR textures for the asylum (ambientCG), 1K JPG
textures/cc0/             shared CC0 textures for the other floors
models/asylum/            CC0 glTF props for the asylum (Poly Haven)
models/cc0/               shared CC0 prop pool (Poly Haven)
```
