# Liminal sound replacements and ElevenLabs prompts

31 sound briefs: 14 replacements installed, 14 remaining procedural sources to replace, and 3 unused procedural candidates. Installed prompts are retained only as references; no need to generate them again. The installed shiver is dormant: its emitter exists but has no playback trigger. The room labels knocks and creak still reuse SoundBank thud and creak; do not generate them twice. The other recorded MP3s are outside this prompt set.

Use ElevenLabs Sound Effects. Set the generation duration and Looping switch as listed; the prompt alone does not replace these controls. Durations are authoring recommendations, not a promise of frame-exact output. Audition several takes. Keep sounds isolated: the game already applies distance and reverb. Loops should have no fade or obvious start/end; trim leading silence from one-shots without cutting their natural decay.

For remaining clips shorter than 0.5 seconds, generate 0.5 seconds and trim the single event to the listed in-game length. For loops, longer generation adds natural variation, not a longer gameplay event. Name downloads with their source IDs, keeping the actual file extension. Nine room MP3s are installed in sounds/room_events/. The supplied buzz, drip, moan, PA voice and shiver are prepared as level-balanced WAVs in sounds/shared/; originals remain unchanged in art/shared_sound_sources/. Buzz has a short overlap crossfade for its loop seam. Drip retains its full supplied 0.8-second decay rather than being cut to the old 0.28-second target.

Controls reference: [ElevenLabs Sound Effects guide](https://elevenlabs.io/docs/eleven-creative/playground/sound-effects). All prompts are below 450 characters.

## room-trolley — INSTALLED

- Installed file: sounds/room_events/trolley.mp3
- Status: replaced; original prompt below is reference only
- Original generation target: 3.2 seconds
- Looping: OFF — one-shot
- Current source length: 3.080 seconds

```text
An old hotel service trolley rolling briefly over uneven hard flooring: small rubber caster wheels rumble, one loose wheel rattles and gives a restrained squeak. A believable, worn mechanical object, not a horror sting. One short roll, then a natural stop. Isolated dry Foley, fixed perspective, no footsteps, voices, music or room echo.
```

One brief event, not a moving stereo pass. The game supplies direction, distance and reverb.

## room-vent — INSTALLED

- Installed file: sounds/room_events/vent.mp3
- Status: replaced; original prompt below is reference only
- Original generation target: 3.2 seconds
- Looping: OFF — one-shot
- Current source length: 3.080 seconds

```text
A small commercial ventilation fan briefly slows as its damper adjusts: soft airflow, a low motor pitch falling gently, and a faint loose grille rattle settling. Subtle local machinery, not a building-wide power failure. Dry isolated recording, no impact, alarm, electrical bang, voices, music or long reverberation.
```

Keep it local and understated; this must not resemble the game's blackout cue.

## room-printer — INSTALLED

- Installed file: sounds/room_events/printer.mp3
- Status: replaced; original prompt below is reference only
- Original generation target: 3.2 seconds
- Looping: OFF — one-shot
- Current source length: 3.080 seconds

```text
A late-1980s office printer makes one brief print-and-paper-feed cycle. A textured carriage buzz passes once, rubber rollers grip a sheet, and dry paper lightly scrapes before the motor stops. Authentic close mechanical Foley, restrained and slightly worn. No keyboard typing, beeps, voices, footsteps, music or room echo.
```

The carriage and paper should distinguish this from a generic electrical buzz.

## room-ticking — INSTALLED

- Installed file: sounds/room_events/ticking.mp3
- Status: replaced; original prompt below is reference only
- Original generation target: 3.2 seconds
- Looping: OFF — one-shot
- Current source length: 3.080 seconds

```text
Four evenly spaced ticks from a cheap mechanical wall clock. Small dry plastic-and-metal clicks with a subtle alternating tick-tock character and natural silence between them. Quiet, ordinary and slightly worn, not a dramatic countdown. Isolated close Foley, no alarm, chime, footsteps, voices, music or reverb.
```

This is a short sequence of ticks; do not generate a perpetual clock loop.

## room-ballast — INSTALLED

- Installed file: sounds/room_events/ballast.mp3
- Status: replaced; original prompt below is reference only
- Original generation target: 3.2 seconds
- Looping: OFF — one-shot
- Current source length: 3.080 seconds

```text
A tired fluorescent ballast briefly flutters: low electrical buzz with a fine irregular sizzling edge, wavering twice before settling away. Intimate, believable fixture noise, not sparks or a power outage. A short contained event with a soft ending. Dry isolated sound, no switch click, alarm, impact, voices or music.
```

Finite unstable flutter; different from the steady looping SoundBank buzz.

## room-metal — INSTALLED

- Installed file: sounds/room_events/metal.mp3
- Status: replaced; original prompt below is reference only
- Original generation target: 3.2 seconds
- Looping: OFF — one-shot
- Current source length: 3.080 seconds

```text
An old metal shutter settling under tension: three small uneven metal taps, a brief muted rattle, then silence. Dull low-mid resonance with restrained high detail, as if a loose rail shifted by itself. Natural mechanical Foley, not hammering or a cinematic crash. Dry fixed perspective, no lift chime, voices, music or room echo.
```

A small settling sequence, not the single sharper clang used elsewhere.

## room-pipes — INSTALLED

- Installed file: sounds/room_events/pipes.mp3
- Status: replaced; original prompt below is reference only
- Original generation target: 3.2 seconds
- Looping: OFF — one-shot
- Current source length: 3.080 seconds

```text
Water briefly moving inside an old narrow metal pipe: a low liquid gurgle, hollow tube resonance and two soft internal water knocks, then settling. Close, enclosed plumbing texture with no open-water droplets. Restrained realistic Foley, no running tap, shower, large splash, motor, voices, music or long reverb.
```

Emphasize enclosed pipe resonance so this no longer sounds like the separate pool-drip sequence.

## room-drips — INSTALLED

- Installed file: sounds/room_events/drips.mp3
- Status: replaced; original prompt below is reference only
- Original generation target: 3.2 seconds
- Looping: OFF — one-shot
- Current source length: 3.080 seconds

```text
Three separated water droplets falling into a still indoor pool. Each makes a delicate natural plip with a tiny liquid ripple and slightly different pitch, with quiet gaps. Clear water detail, gentle rather than musical. Dry isolated Foley, no pipe rumble, running water, shower, large splash, footsteps, voices, music or room echo.
```

Several drops into open water; the Asylum's drip below is only one droplet.

## room-organic — INSTALLED

- Installed file: sounds/room_events/organic.mp3
- Status: replaced; original prompt below is reference only
- Original generation target: 3.2 seconds
- Looping: OFF — one-shot
- Current source length: 3.080 seconds

```text
Thick fibrous organic material slowly stretching and settling: damp leathery tension, a low woody groan and a faint release of trapped air. Ambiguous living architecture, tactile and physically believable. One restrained short movement. Dry isolated texture, no heartbeat, human breathing, voice, creature scream, gore splatter, music or cinematic boom.
```

Bloom ambience only. Avoid the heartbeat and breath sounds already reserved for player fear.

## sound-ding

- Generate: 0.55 seconds
- Looping: OFF — one-shot
- Current source length: 0.550 seconds

```text
One short, rounded electronic confirmation bell from a late-1980s commercial device. A clear bright note with a gentle attack, a small glassy overtone and a clean quick decay. Pleasant but restrained, not cheerful or magical. Dry isolated one-shot beginning immediately. No melody, second note, jackpot flourish, voice, background hum or reverb.
```

Shared by terminals, slots and success feedback. Keep one neutral note, not a distinctive jackpot sound.

## sound-buzz — INSTALLED

- Installed file: sounds/shared/buzz.wav
- Status: replaced; original prompt below is reference only
- Original generation target: 8.0 seconds
- Looping: ON — seamless
- Current source length: 7.960 seconds

```text
Steady low hum of an old commercial fluorescent ballast and small electrical transformer. Soft mains-frequency body with a delicate raspy upper buzz and barely perceptible natural variation. Seamless continuous loop at stable level and tone. Dry isolated recording, no startup, shutdown, clicks, sparks, periodic pulses, voices or music.
```

Shared continuous electrical bed. No fade-in or fade-out at the loop seam; eight seconds adds variation to the current short loop.

## sound-muzak

- Generate: 12.0 seconds
- Looping: ON — seamless
- Current source length: 12.000 seconds

```text
An original twelve-second instrumental hotel-lounge organ phrase, four slowly changing soft minor-seventh jazz chords. Warm electric organ, gentle tape wobble, narrow-band old ceiling-speaker character, quietly wistful rather than sinister. Seamless musical loop returning naturally to its opening harmony. No vocals, drums, recognizable tune, dramatic swell, announcement or room reverb.
```

A short musical texture for Sound Effects, not a full score. Keep it original and unobtrusive.

## sound-step_carpet

- Generate: 0.5 seconds
- Looping: OFF — one-shot
- Current source length: 0.160 seconds
- In-game trim target: 0.16 s approximately

```text
Exactly one soft shoe footfall on thick office carpet: a muted heel thump and a tiny compressed-fabric scuff in one compact motion. Ordinary body weight, not a heavy monster stomp. Very short dry close Foley, starting immediately, then silence. No second step, walking sequence, breathing, clothing rustle, voice, music or reverb.
```

Used for the figure, not the player. Trim the single footfall to roughly 0.16 seconds; the game supplies the walking rhythm.

## sound-step_marble — UNUSED

- Generate: 0.5 seconds
- Looping: OFF — one-shot
- Current source length: 0.120 seconds
- In-game trim target: 0.12 s approximately

```text
Exactly one hard shoe heel contacting polished marble: a crisp small tack with a brief solid sole impact and minimal scrape. Natural adult footfall, not a tap-dance step or heavy stomp. Dry close Foley, beginning immediately, then silence. No second step, walking sequence, hall echo, voice, music or background ambience.
```

UNUSED. Only generate if reviving this source; isolate a roughly 0.12-second footfall.

## sound-thud

- Generate: 0.6 seconds
- Looping: OFF — one-shot
- Current source length: 0.600 seconds

```text
One compact heavy structural thud: a blunt impact through a dense wall panel, with a low woody-steel body and a tiny loose-material rattle, dying away quickly. Grounded physical Foley, not an explosion or cinematic bass hit. Starts immediately. Dry isolated one-shot, no repeated knocks, footsteps, voices, music or long echo.
```

Also serves the palette label 'knocks'. Generate one hit, not three; repeated hits belong in playback logic.

## sound-key_click

- Generate: 0.5 seconds
- Looping: OFF — one-shot
- Current source length: 0.045 seconds
- In-game trim target: 0.045–0.08 s

```text
Exactly one tiny neutral mechanical button click: a crisp plastic contact with a very short fine metal spring snap. Compact and understated, suitable for an old electronic device. One immediate click followed by silence. Dry isolated close Foley. No double click, keyboard sequence, camera shutter mechanism, beep, resonance, voice, music or reverb.
```

Trim to a single 45–80 ms click and remove leading silence. Shared by camera, flashlight, typing and lift buttons.

## sound-water_rush — UNUSED

- Generate: 10.0 seconds
- Looping: ON — seamless
- Current source length: 1.800 seconds

```text
Continuous water flowing through a shallow concrete channel. Soft broad rushing water with gentle irregular gurgles and fine surface splashing, even in energy and natural rather than stormy. Seamless steady loop. Close dry field-recording texture, no waterfall roar, isolated drips, footsteps, voices, music, sudden changes or long room echo.
```

UNUSED. Only generate if reviving channel-water ambience; the player's existing water sounds are recorded separately.

## sound-drip — INSTALLED

- Installed file: sounds/shared/drip.wav
- Status: replaced; original prompt below is reference only
- Original generation target: 0.5 seconds
- Looping: OFF — one-shot
- Current source length: 0.800 seconds

```text
Exactly one water droplet landing in a thin layer of water inside a metal basin. A small wet plink with a quick falling pitch and tiny soft basin resonance. Natural close Foley, not a musical note. One immediate droplet, then silence. Dry isolated sound, no repeated drips, running water, voices, music or hall echo.
```

Trim to one roughly 0.28-second droplet. Asylum ambience handles spacing, pitch, volume and position.

## sound-creak

- Generate: 1.6 seconds
- Looping: OFF — one-shot
- Current source length: 1.600 seconds

```text
Old structural steel flexing slowly under weight: a low uneven metallic groan, fine friction chatter and one restrained higher strain overtone, rising gently then releasing. A single short physical movement, dry and textured. No wooden-door squeak, door slam, monster voice, scream, music, cinematic boom or long reverb.
```

Shared by door, lift, realm and room events. Keep it material-neutral stressed metal, not a recognizable wooden hinge.

## sound-clang

- Generate: 1.1 seconds
- Looping: OFF — one-shot
- Current source length: 1.100 seconds

```text
One solid iron bar struck once: a short hard attack, uneven metallic overtones and a restrained hollow ring decaying naturally. Worn industrial metal, not a tuned bell, gong or cymbal. Dry isolated Foley, immediate onset. No second strike, rattling sequence, room echo, voices, music or cinematic bass enhancement.
```

One strike shared by Asylum, lift and realm effects; keep the natural tail within the clip.

## sound-moan — INSTALLED

- Installed file: sounds/shared/moan.wav
- Status: replaced; original prompt below is reference only
- Original generation target: 2.4 seconds
- Looping: OFF — one-shot
- Current source length: 3.080 seconds

```text
A single subdued low human moan, tired and indistinct, gently falling in pitch with a little breath at the end. Muffled tonal detail as if filtered by a wall, but no baked room echo. A quiet uneasy environmental sound, not a performance or jump scare. No words, crying, scream, growl, other people, music or dramatic effects.
```

An anonymous nonverbal Asylum sound. The game adds distance and pitch variation; do not use a named voice.

## sound-pa_chime

- Generate: 1.7 seconds
- Looping: OFF — one-shot
- Current source length: 1.700 seconds

```text
An old airport public-address attention chime: exactly three soft electronic bell tones descending in pitch, evenly spaced about four-tenths of a second apart. Rounded late-twentieth-century commercial PA timbre, slight speaker bandwidth restriction, quick natural decay. Isolated cue, no announcement, voice, background airport noise, music or long reverb.
```

Keep 1.7 seconds. The PA voice starts after 1.6 seconds, so only the final soft decay should overlap it.

## sound-pa_voice — INSTALLED

- Installed file: sounds/shared/pa_voice.wav
- Status: replaced; original prompt below is reference only
- Original generation target: 4.6 seconds
- Looping: OFF — one-shot
- Current source length: 4.480 seconds

```text
One short unintelligible airport PA announcement through a worn narrow-band ceiling speaker. Calm impersonal adult speech-like mumbling with believable syllables, pauses and faint consonant hiss, but absolutely no understandable words or language. Band-limited and softly distorted, isolated without room echo. No opening chime, names, gate numbers, crowd, music or intelligible instructions.
```

Generate as a sound effect, not narration. Reject takes with intelligible words; do not include the separate opening chime.

## sound-jet_far

- Generate: 9.0 seconds
- Looping: OFF — one-shot
- Current source length: 9.000 seconds

```text
A large passenger jet spooling up far beyond closed airport-terminal glass. A low broad engine rumble swells slowly, holds briefly and fades, with only a faint distant turbine whine. Restrained and believable, filtered rather than loud. Fixed listening position, no close flyby, Doppler swoosh, explosive takeoff, wind, crowd, announcement, music or indoor reverb.
```

Preserve the slow nine-second swell and distant perspective; not a nearby aircraft flyby.

## sound-portal_hum

- Generate: 8.0 seconds
- Looping: ON — seamless
- Current source length: 2.400 seconds

```text
A restrained unsettling resonance of held-open space: low detuned tones gently beating, a faint glassy upper shimmer and soft air vibration. Stable, continuous and subtly physical, neither musical nor a machine motor. Seamless loop with no attack or ending. Dry centered source, no pulses, whoosh, impact, voice, heartbeat, melody or cavern reverb.
```

Looping realm presence, not a portal-opening or travel effect. No marked beginning or ending.

## sound-warp — UNUSED

- Generate: 1.1 seconds
- Looping: OFF — one-shot
- Current source length: 1.100 seconds

```text
One short spatial-collapse sound: a low airy pressure sweep rising in pitch and narrowing into a soft inward suction, then abruptly vanishing without a bang. Restrained uncanny texture, physically close rather than cinematic. Dry isolated one-shot, no laser, explosion, voice, melody, repeated pulses or long reverberant tail.
```

UNUSED transition candidate. Do not generate unless this effect will be brought back.

## sound-shiver — INSTALLED

- Installed file: sounds/shared/shiver.wav
- Status: replaced; original prompt below is reference only
- Playback: DORMANT — emitter has no trigger
- Original generation target: 0.8 seconds
- Looping: OFF — one-shot
- Current source length: 0.880 seconds

```text
One extremely soft cold exhale, a short close breath of air that darkens and disappears, with a faint low pressure vibration beneath it. Ambiguous nearby presence, not a voiced human phrase or monster sound. Dry intimate centered source. No inhalation, panting, whisper words, heartbeat, growl, jump-scare hit, music or reverb.
```

A brief figure-presence cue, not a breathing loop. Keep it quiet in character, but export without clipping or heavy limiting.

## sound-static_hiss

- Generate: 8.0 seconds
- Looping: ON — seamless
- Current source length: 1.200 seconds

```text
Soft steady analogue tape-head hiss with very faint irregular fine-grain crackle. Warm band-limited noise, not bright radio static or digital glitching. Seamless continuous loop with stable level and no obvious repeating event. Dry isolated source, no loud pops, tuning sweeps, signal beeps, voices, music, motor or start-stop clicks.
```

Used under the viewfinder and during realm erasure. Avoid conspicuous pops that become repetitive when looped.

## sound-lift_motor

- Generate: 8.0 seconds
- Looping: ON — seamless
- Current source length: 2.400 seconds

```text
An old traction elevator motor heard from inside the moving car: a substantial low hoist drone, subdued cable vibration and a soft uneven sheave rhythm. Steady continuous travel, weighty but not loud. Seamless loop, isolated fixed perspective. No startup, braking, arrival chime, door movement, speech, music, dramatic swells or added hall reverb.
```

Inside-car body and vibration. Keep continuous speed; the game starts and stops the ride sound.

## sound-lift_shaft

- Generate: 8.0 seconds
- Looping: ON — seamless
- Current source length: 3.100 seconds

```text
Elevator machinery heard from a landing through closed doors: a distant thin cable whine, muffled pulley friction and a light filtered motor rumble. Less bass and body than being inside the lift car. Stable running machinery, seamless continuous loop. No approaching crescendo, stopping, chime, doors, footsteps, voices, music or long reverb.
```

Outside/landing perspective. Do not bake an arrival into a loop that may repeat while the player waits.

## sound-elev

- Generate: 1.3 seconds
- Looping: OFF — one-shot
- Current source length: 1.300 seconds

```text
A familiar old elevator arrival chime: exactly two rounded electronic bell tones, the second lower than the first, separated by about three-tenths of a second. Warm modest commercial hardware sound, short soft decay. Dry isolated cue beginning immediately. No third note, door mechanism, slam, voice, music, background hum or long lobby reverb.
```

A two-note lift chime, NOT door mechanics. Distinct from the single confirmation ding and the three-note airport PA chime.
