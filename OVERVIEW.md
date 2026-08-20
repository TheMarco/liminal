# It wants you to stay: story and gameplay overview

Prepared for comparative marketing research, 2026-08-20. Describes the game as
currently built. Working title used in code: Liminal.

## One-paragraph pitch

A first-person analog-horror walker through endless procedural liminal
spaces: a casino, a mall, an office, an airport, and seven stranger places
stacked beneath them. The player descends eleven floors by finding each
floor's elevator inside a maze that offers a distance counter and nothing
else. The whole game is seen through a failing consumer camcorder: the
recording is the interface, the danger gauge, and the only instrument that
can see what is wrong with the building. One rule keeps you alive: when the
lights fail, stand still.

## Story

### Premise

Dr. Evelyn Cross, investigating disappearances tied to an aging Las Vegas
casino, found an unmarked service elevator in a forgotten corner of the
building and went down. She missed her check-in. The player enters the casino
after her, takes the same elevator, and is trapped in the same descent.

### How the story is told

Cross is the only visible character. She appears exclusively in VHS
recordings played on CRT televisions found in each floor's elevator room:
one intro tape and ten elevator tapes, every one a restrained monologue to a
fixed camera in the same fluorescent-lit room. There are no cutaways,
flashbacks, or reenactments; tape degradation and Cross's own visible
deterioration carry the story. Across ten tapes she moves from methodical
confidence (mapping rooms, timing elevators) through failing chronology,
contaminated memories, guilt over a mistake someone else paid for, and the
collapse of every theory she has tried, to a calm surrender just before the
final realm. The last realm has no tape: after ten floors of guidance, her
absence is the event.

The ending belongs to the player alone. Passing the apparent exit produces a
moment of instinctive relief that collapses into an exterior of absolute
desolation, an escape that is only a larger form of imprisonment (the stated
emotional reference is the ending of Fulci's The Beyond). No narrator
interprets it.

### The mystery contract

A deliberate design rule: the game never explains what the realms are, who
built the elevators, what the shadow figures are, whether time is real, or
whether Cross's memories (or the escape) are true. Cross forms theories and
discards them; none is confirmed. There is no villain, no conspiracy reveal,
no lore dump. Optional shorter tapes found in the world deepen the texture
without resolving anything.

## Structure and modes

- **Wander**: a peaceful mode. Eleven endless procedural worlds to explore
  with no enemies and no objectives; elevators and portals move between
  themes, and every floor remembers where you left it.
- **Descent**: the game. Eleven floors in a fixed order: Casino, Mall,
  Office, Airport, School, Prison, Asylum, Poolrooms, Annex, Monolith, and
  Bloom (an organic "Upside Down" realm that ends in an exit passage rather
  than a lift). Persistent checkpoints resume the deepest floor reached;
  death respawns at the floor's arrival elevator with clean state.

The world is generated from a seed: every wall, room, and prop position is a
pure function of seed and coordinates, so a seed is a shareable, replayable
building. Guided routes grow from roughly 200 metres of maze on floor 1 to
over 500 on floor 11.

## Core gameplay loop (per floor)

1. **Arrive by elevator.** A short grace period, a floor card, and the
   floor's objectives: find the lift, and photograph what is wrong.
2. **Navigate.** The HUD shows a distance-only "LIFT 300m" counter. There is
   no compass, no map, no direction needle: reading the building is the
   game. Watching an optional tape found in the world briefly converts the
   counter into an honest room count.
3. **Photograph anomalies.** The phone doubles as a camera. Each floor hides
   planted anomalies; the tape in the objective room refuses to play until
   enough are documented (3 on early floors, scaling to 5 with depth).
4. **The ritual.** The objective room holds a CRT-and-VCR altar, a phone
   charging station, and the lift. Watching the floor's Cross tape is the
   sole key that unlocks the lift. Calling the lift starts a wait (14 to 34
   seconds by depth), usually with something arriving before the doors do.
5. **Descend.** The next theme has already begun bleeding into this one near
   the lift: fog, room tone, and objects from the floor below.

## The camera (signature mechanic)

The phone's camera is raised and lowered at will and is the game's detection
instrument:

- **The camcorder is the detector.** Within range of an undocumented
  anomaly, the viewfinder OSD picks up interference: tracking bars, a
  stuttering REC lamp, tape static, and geiger-style clicks that quicken
  with proximity. A HUD line distinguishes "SOMETHING WRONG NEARBY" (long
  sight line) from "SOMETHING HERE IS WRONG" (in this room).
- **Through the lens you see the truth.** Some anomalies are invisible to
  the eye and appear only in the raised viewfinder; one type is visible to
  the eye and vanishes through the lens; one exists only in the developed
  photograph. The reticle runs hot and cold as aim converges, and prints
  FOCUS when a shot will count.
- **Seven anomaly types**: a prop hovering inverted at head height; two
  identical props where one should be (lens-only); a prop at impossible
  scale; a ring of props facing each other (lens-only); wall writing only
  the camera can see; an object the camera insists is not there; and writing
  that exists only on the developed film. The pool of camera-only phrases is
  50 lines of second-person dread, deliberately unreliable.
- **The photograph answers.** A counted shot returns a print with a
  hand-drawn evidence circle, a caption naming the wrongness ("NOTHING
  HOLDS IT", "THERE ARE TWO"), and a resolution in the world: the hovering
  prop drops with a thud, the duplicates are gone when the camera comes
  down. Photographs can also provoke: most shots pass quietly, some trigger
  an environmental response, a few summon something behind the player.

## Threat systems

- **The one rule**: blackouts strike on a cadence that tightens with depth.
  Moving during a blackout past a short grace fills a locate meter, ending
  in a jump-scare death; standing still is always safe. The torch stays
  usable, at a cost.
- **Shadow figures**: silhouette entities with per-variant behaviour
  (creeper, jailer, reacher, drifter, introduced by depth). Seen, they creep
  slowly; unseen, they close fast but always stop short: only the watched
  approach can kill. The phone's light is a ward and, held on them, burns
  them away, refunding some charge. Pursuit follows through doorways;
  escape is earned by rooms, not timers.
- **The phone economy**: 20 seconds of light, drained only while on,
  refilled only at charging stations. One station per run is dead, and
  discovering that stages an ambush.
- **Attention**: sprinting is legal but feeds an attention meter that
  accelerates encounters. Deeper floors add pressure on top.
- **Post-blackout reality changes**: a blackout may swap the floor to a
  precomputed alternate topology: doorways move, furniture rearranges, and
  a glow marks what changed. The maze does not stay solved.

## Presentation

- Two full-screen recording modes, one shader: the default RECOVERED TAPE
  look (a late-90s camcorder signal model: 360-line raster, chroma smear
  and delay, quantized 29.97 Hz tape noise, handheld jitter, tracking
  tears, head-switching noise, dropouts, bloom, overscan), and a clean CRT
  mode, toggleable live.
- The tape is also a diegetic danger gauge: the nearer a hostile figure,
  seen or not, the more the signal degrades, and a spawn hits a split-second
  of total signal loss. During tape playback the effects belong to the
  televised image only.
- All UI is in-world camcorder OSD: title-safe brackets, REC lamp, battery
  glyph, sprint meter, distance counter. No menus over gameplay, no
  minimap, no objective markers.
- Visual bar is photorealism within a stylized analog frame; ghosts are
  translucent absences with wisps and local gloom, never cartoon sprites,
  and never cast shadows.

## Difficulty shape

Floors 1 to 3 are deliberately gentler: shorter routes, spaced blackouts and
encounters, three photographs. From floor 4 the authored pressure takes
over: longer mazes, flat blackout cadence, new figure variants, per-theme
modifiers (the prison's frequent short blackouts, the Monolith's sparse
figures and long graces), and up to five required photographs.

## Comparative hooks

For positioning work, the nearest reference points and the differences that
matter:

- **Fatal Frame / DreadOut**: camera as revealer, but here the camera is a
  detector and documentation tool, never a weapon; combat does not exist.
- **Outlast**: camcorder presentation and analog grammar, but the recording
  is systemic (a live danger gauge and truth-lens) rather than a viewmodel.
- **P.T. / Layers of Fear**: mutating architecture, delivered here through
  seeded procedural generation and blackout topology swaps rather than
  scripted corridors.
- **Backrooms games (Escape the Backrooms, Complex: Found Footage)**: the
  liminal-space aesthetic, with a fixed authored narrative spine, a
  photography objective, and formal survival rules layered on top.
- **Her Story / analog-narrative games**: the story arrives entirely through
  an actress's degrading recordings, in fixed-camera monologue.

## Factual snapshot

| Aspect | Value |
| --- | --- |
| Engine | Godot 4.6 |
| Perspective | First person |
| Modes | Wander (safe exploration), Descent (11-floor campaign) |
| World | Seed-based procedural, deterministic and shareable |
| Combat | None; light as ward, stillness as defence |
| Narrative delivery | 1 intro tape, 10 fixed-camera monologue tapes, 21 optional shorts, silent final realm and outro |
| Session shape | Floor-based with persistent checkpoints |
| Signature mechanics | Camera-as-detector photography, blackout stillness rule, reality mutation, tape-gated elevators |
| Presentation | Full-screen analog recording pipeline, diegetic OSD interface |
