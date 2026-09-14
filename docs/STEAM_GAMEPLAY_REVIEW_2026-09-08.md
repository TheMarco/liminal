# It wants you to stay — gameplay and Steam review

Reviewed September 8, 2026, against the current working tree, including the ongoing asset changes.

**Recommendation:** Make the camera's relationship with reality the central attraction. Build a campaign in which players learn to observe, test a suspicion, change something, and live with the result. The existing casino door photograph is a strong example. Prioritize more experiences of that quality, a playable opening, and deliberate changes of pace before expanding the scenery or floor count.

The project has substantial foundations: eleven recognizable environments, a coherent visual identity, procedural architecture that can change safely, photography with different visibility layers, resource pressure, and a restrained narrative. Its largest design risk is repeating a similar set of decisions across all that content. A player may enjoy the first floor but feel that later floors ask for more of the same.

This is an evidence-based design review, not a completed human playthrough or a sales prediction. I inspected the gameplay and presentation code, narrative scripts, asset records, and representative existing captures of all eleven themes; launched a fresh rendered casino view; exercised the actual casino photograph sequence; measured the shipped video durations; and ran three focused gameplay audits. I have not validated the whole campaign's felt pacing, the complete audiovisual performance, Windows/Deck performance, a live Steam store page, or player retention. Those limits matter when interpreting the recommendations.

**What is already worth protecting**

| Foundation | Why it matters to players | Preserve while improving |
| --- | --- | --- |
| Camera-only and print-only information | Looking becomes an action with a payoff; an image can surprise both player and spectator. | The distinction between what the eye, viewfinder, and developed print show. |
| The casino's numbered door | A familiar object contradicts the photograph, then changes in the world. This produces a specific story someone can retell. | The clear before/after and persistent consequence. |
| “When the lights fail, stand still” | A memorable rule creates anticipation before anything attacks. | Its reliability, readable warning, and protection from incompatible threats. |
| Cross's recordings | A human voice gives the descent an emotional thread. The scripts' declining confidence fits a place that defeats observation. | Her restrained delivery, uncertain theories, and the final floor's absence of Cross's guidance. |
| Eleven environments and the Bleed | New surroundings reward progress; advance sounds and objects can build anticipation. | Each floor's acoustic, spatial, and material identity. |
| Persistent photographs and completed tapes | Failure can teach without erasing everything already earned. | This existing behavior; do not accidentally regress it while changing objectives. |
| Wander | Offers a peaceful way to enjoy the spaces and extends their usefulness. | Its clear promise of safe exploration. |

The distinction between modes is valuable. Lead the commercial pitch with Descent's authored horror journey, and describe Wander clearly as an additional peaceful exploration mode. This helps set expectations for players who want threats and those who specifically want their absence.

**What the campaign currently asks the player to do**

The fixed order is Casino → Mall → Office → Airport → School → Prison → Asylum → Poolrooms → Annex → Data Center → Bloom/Upside Down. For the first ten floors, the normal chain is navigation → enough anomaly photographs → objective tape → call elevator → survive the wait → descend.

Photography really is a gate: the initial objective tape refuses playback until the photo requirement is met. The elevator then checks completion of that tape. The first ten floor quotas are **3, 3, 3, 3, 4, 3, 5, 5, 5, 3**, totaling **37 photographs**. Plans provide surplus candidates, including off-route evidence, so the player need not find every anomaly. Bloom has a photo plan and counter, but its OUT passage does not require photographs. [Photo planning](/Users/marcovhv/projects/GIT/liminal/scripts/photo_director.gd:16), [tape gate](/Users/marcovhv/projects/GIT/liminal/scripts/vhs_ritual.gd:261), [lift gate](/Users/marcovhv/projects/GIT/liminal/scripts/chunk.gd:6076).

The worlds differ meaningfully in space and atmosphere. Poolrooms adds slow wading, ladders and slides; the airport has moving walkways; casino has guaranteed authored landmarks; prison changes blackout cadence; school has a nearly immediate elevator; asylum has a long one. Nevertheless, most floors retain the same objective structure and shared threat responses. Variation exists, but much of it changes the setting or pressure more than the player's reasoning.

**Priority 1 — turn photographs into discoveries with consequences**

The current generic loop can settle into “follow interference, find focus, take a photo, increment counter.” Keep that legibility for ordinary evidence, but make major photographs alter the player's understanding or available route.

Use three reusable encounter patterns:

1. **Reveal:** The photograph shows information the player can act on: the real passage, a numbered gate, or a familiar mark that identifies a room after a blackout.
2. **Change:** Taking a photograph produces a persistent, observable change. The existing 104 → 106 door is the starting point; a later version could open a short connection or change which ordinary room is accessible.
3. **Compare:** An earlier photograph becomes useful later. A matching object or spatial relationship reveals that a remembered place has changed.

This gives progression through understanding. Players first discover a contradiction, then use one deliberately, and finally recognize that their own documentation can become unreliable. It does not require equipment levels or a combat system.

For a first prototype, extend **one** encounter: the red telephone door. Make its change relevant to a short route or a second observation, preserve the original route as a fallback, and let the player inspect the resulting photo afterward. Test whether they understand what happened without explanatory text doing all the work.

Do not add these encounters on top of the existing quota as extra chores. Let a signature discovery replace generic evidence or satisfy a meaningful portion of that floor's objective. Keep extra photographs for curious players. There should be a reason to explore beyond a number, such as a striking optional scene, a useful route, or an unsettling connection to Cross's account.

Add a small evidence album that stores the actual images and their floor context. Current progress remembers documented IDs; I found no player-facing persistent photograph album or export flow in the inspected camera implementation. An album would give players something tangible they created, support comparison puzzles, and produce shareable artifacts. Keep its presentation observational; it should not certify a single correct explanation of the mystery.

The camera currently rolls a response after ordinary documentation: 70% nothing, 22% an environmental response, 8% an encounter request. Those are raw probabilities, not measured encounter rates. For important discoveries, author the response so the player can connect action and consequence. Retain some uncertainty around optional shots, while ensuring that using the core mechanic feels rewarding. [Photo response](/Users/marcovhv/projects/GIT/liminal/scripts/photo_camera.gd:573).

**Priority 2 — get the player into the experience sooner**

Measured from the shipped OGV files using ffprobe, following the runtime tape catalogue:

| Recorded material | Duration |
| --- | ---: |
| Opening prologue | 1:47.65 |
| Arrival camera tutorial | 0:30.14 |
| Ten mandatory objective recordings combined | 10:10.45 |
| Prologue plus objective recordings | 11:58.10 |
| Including the arrival tutorial | 12:28.24 |

The prologue cannot be skipped on its first viewing. The arrival tutorial starts automatically at close range and also disallows a first-view skip, although its location can technically be bypassed. An unfinished objective tape rewinds when interrupted; completed tapes are remembered and optional to replay. The result is a substantial fixed video load, especially for a game whose older design notes target a short run. It does not prove the videos are boring, and it does not establish actual campaign length. It does establish what needs testing. [Prologue](/Users/marcovhv/projects/GIT/liminal/scripts/descent_intro.gd:3), [tutorial and interruption](/Users/marcovhv/projects/GIT/liminal/scripts/vhs_ritual.gd:408).

Prototype this opening:

| Proposed elapsed time | Player experience |
| --- | --- |
| 0:00–0:30 | A brief premise and control of the elevator arrival. Full prologue remains accessible. |
| 0:30–2:00 | A clearly staged discrepancy introduces the camera; the player takes the photograph themselves. |
| 2:00–4:00 | A protected first blackout teaches stillness; when power returns, one unmistakable environmental change rewards observation. |
| 4:00–7:00 | A route choice and a well-telegraphed figure teach looking, light, and retreat. |
| 7:00–12:00 | The first floor culminates in its tape and a purposeful elevator encounter. |
| 12:00–15:00 | The mall introduces a different kind of discovery, then the demo ends after a payoff and a reason to continue. |

These timings are prototype targets, not measured current performance or a reason to rush every player. Quiet exploration still belongs in the game.

Replace the separate camera lecture with a safe, interactive example. Allow first-view skipping with a deliberate hold, provide subtitles, and retain the full recording in a replay archive. For the objective tapes, first test shorter edits that retain one emotional turn per floor. Preserve the longer version for interested players. If full-length mandatory tapes are essential to the intended experience, validate that choice with new players before building the demo around it.

**Priority 3 — author a campaign rhythm**

The scheduled waits on the first ten floors are **14, 16, 18, 20, 1, 24, 52, 28, 30, 32 seconds**: **3:55** total before cancellations, retries, and elevator travel. Waiting can include defending the room, so this is not all passive time. School and asylum already break the pattern; extend that authoring beyond duration changes. [Wait schedule](/Users/marcovhv/projects/GIT/liminal/scripts/descent_run.gd:300).

Give each floor a role in the emotional arc:

- Early: curiosity, a clear proof that the impossible is real, and understandable survival.
- Middle: apply learned rules in unfamiliar combinations; alternate tense sections with time to notice the environment.
- Late: recognition, uncertainty about recorded evidence, and selective peaks of danger.
- Final: use what the player has learned; let Cross's absence register; implement the narrative document's intended bleak escape through the player's perspective.

Make Poolrooms a genuine recovery chapter for part of its duration. Wading already slows traversal, and water carries its own sensory tension. A uniform increase in threat can squander this contrast. Reserve a few elevator vigils for major encounters; shorten others, or move the floor's climax into its approach. Always preserve the elevator car's established safety.

The game already has a HorrorDirector that separates competing beats and grants recovery time. Extend that system using encounter history, recent failures, resource condition, and actual player progress. Measure before retuning. Frequent attempts to frighten can make players optimize an interruption routine; a quiet interval after a strong event lets its meaning linger. [Existing director](/Users/marcovhv/projects/GIT/liminal/scripts/horror_director.gd:1).

**A concept bank for all eleven floors**

These are proposed encounter directions, not descriptions of implemented features. They reuse the camera, architecture, and existing props. Prototype a few before committing to the whole table.

| Floor | Existing identity | Proposed signature experience | Decision or learning |
| --- | --- | --- | --- |
| Casino | Last Chance, lounge, red telephone; 104/106 proof already works. | Give the changed door a small navigational consequence and a photo the player can retain. | Learn that documenting something can change the place. |
| Mall | Shuttered shops, cinema, newly authored photo booth. | The booth produces an image of a storefront that is absent from the live view; comparing the two reveals a short passage. | Choose where to investigate using photographic evidence. |
| Office | Repeated desks, terminals, rigid organization. | Prototype one photograph that preserves a doorway through a blackout while another local connection changes. | Choose a useful route to preserve; substantial implementation and mutation QA required. |
| Airport | Moving walkways, gate desks, boards, carousels. | A gate clue is only readable through the camera from a moving walkway; a longer stationary vantage remains available. | Trade a difficult moving observation for a slower, clearer route. |
| School | Classrooms, projector, trophies; Cross recalls specific classroom details. | A scratch on a desk or bent coat hook links to her account; the player's photograph identifies that room after its surroundings change. | Use memory and comparison, with an emotional reason to care. |
| Prison | Bars, visitation booths, short frequent blackouts. | Photograph through a visitation window to see a connection obscured in the ordinary view; it offers a shortcut past a threatening gallery. | Use the lens to choose a route; keep a safe longer route. |
| Asylum | Treatment rooms, heavy institutional objects, the longest lift wait. | An optional photographic contradiction places an object in a room the player just verified as empty; investigating it provides a useful bypass before the climax. | Decide whether additional knowledge is worth approaching an unsettling space. |
| Poolrooms | Water, ladders, slow movement, strong light and acoustic identity. | Submerged markings appear in the lens and identify a short water route; the dry path remains legible and longer. | Choose between route length and movement constraints during a quieter chapter. |
| Annex | Compressed passages and visually similar corridors. | A previously photographed junction reappears with one wrong opening; recognizing the mismatch reveals the useful connection. | Test learned spatial memory without a new control scheme. |
| Data Center | Server aisles, machinery, cold light. | A terminal briefly quiets a local machine bank so the player can distinguish an evidence signal and identify its aisle. | Use an environmental control to improve observation. This needs distinct visual feedback as well as sound. |
| Bloom | Organic intrusion and no final tape. | Echo several earlier discoveries in transformed surroundings; let the player recognize the final route using familiar photographic relationships. | Resolve the player's learned actions while leaving the world's explanation uncertain. |

The recent photo booth, projector, vending-style machines, and other fixtures are explicitly environmental props today. Giving a few of them a meaningful interaction could make the world feel more responsive without another asset expansion. [Current fixture status](/Users/marcovhv/projects/GIT/liminal/docs/AUTHORED_HERO_PROPS.md:143).

**Navigation: being lost should produce a discovery**

The current distance instruments and camera cues provide assistance, and the system already includes stall mercy and route mutations. Preserve those foundations. The next step is to help players build a mental map using recognizable places.

Extend the casino's guaranteed-landmark approach to the important route of other floors: one strong arrival landmark, one recognizable midpoint, and a distinct approach to the objective. Allow some loops to reconnect somewhere familiar. Use signs, sound sources, and photographic comparisons to make those reconnections understandable.

A blackout's alteration is more effective when the player remembers what was there. Stage an early change next to a memorable object. Later changes can be subtler. Keep a dependable return or onward route; reserve disorientation for authored moments rather than allowing procedural wandering to become the main source of length.

Test the length of runs of rooms without a new observation, decision, or payoff. This is different from imposing a scare every fixed number of seconds. A beautiful, quiet water hall may be a payoff; six interchangeable turns toward a decreasing meter may not be.

**Threats and resource pressure**

Seven figure variants exist, including differences in pursuit distance, speed, and burn window. Four share the baseline tuning. The flashlight carries 20 seconds of nominal beam time and a full refill takes ten seconds; charging can be interrupted. The code preserves a burn opportunity, and the focused survivability audit passed. [Figure tuning](/Users/marcovhv/projects/GIT/liminal/scripts/shadow_figure.gd:54), [light budget](/Users/marcovhv/projects/GIT/liminal/scripts/player.gd:38).

Make encounter variety come from sightlines, approach directions, escape routes, timing, and recognizable behavior. Introduce a variant where its distinguishing behavior can be understood before a demanding combination. It is more useful for a player to recognize “this one follows farther” than to memorize seven silhouettes with nearly identical solutions.

Keep stillness reliable during blackouts. The player can still listen and observe the space, so make the event carry a clue or a perceptible change. Do not undermine the learned rule with an untelegraphed exception.

Treat the late-floor encounter density as a question for playtests, not a confirmed defect. Log how often a figure produces an interesting retreat or light decision versus a routine burn. Also inspect whether players who get lost accumulate more pressure and backtracking encounters, creating a frustration spiral. Existing mercy and recovery systems can be tuned if that pattern appears.

**Story, attachment, and the ending**

Cross's strongest material concerns observations that stop agreeing with her own memory. Let the player experience some of those details before or after hearing about them. The school desk is an unusually efficient opportunity because the scripts already describe it. A concrete mismatch gives a recording meaning beyond opening an elevator.

Build recurring motifs with small changes: a room number, a familiar arrangement, a sound, a mark in a saved photograph. Use a few carefully. This creates recognition across the eleven themes while leaving Cross as the only recurring visible speaker.

Preserve the narrative bible's uncertainty. An evidence album should not become a lore database that explains the realms. Preserve the safe elevators, fixed-camera monologues, absence of a final tape, and player's first-person ending unless those are deliberately reconsidered as creative decisions. [Narrative contract](/Users/marcovhv/projects/GIT/liminal/docs/STORY.md:13).

**The intended ending is not yet implemented in the current runtime.** The narrative document specifies an apparent escape followed by a desolate first-person exterior. The final exit currently calls `run.finish(true)` and immediately opens the “OUT” summary. Completing this is a substantial release priority, not simply polishing an existing cinematic. [Current exit](/Users/marcovhv/projects/GIT/liminal/scripts/main.gd:1355), [summary transition](/Users/marcovhv/projects/GIT/liminal/scripts/main.gd:1725), [intended outro](/Users/marcovhv/projects/GIT/liminal/docs/STORY.md:321).

The proposed bleak ending can work if the player has achieved something mechanically and emotionally before the apparent escape collapses. Make the final route a payoff to their observations, then build the exterior sequence before showing results. Avoid making the conclusion feel interchangeable with an ordinary death. Test whether players describe the ending as haunting or as having made their effort meaningless; those reactions require different revisions. Multiple endings are unnecessary for the first improvement pass.

One concrete clarity fix: Bloom currently receives the photo counter/brief even though its exit is not photo-gated and there is no tape. Present its photographs as optional, or remove the quota instruction on that floor. The objective language should reflect what actually enables progress. [HUD configuration](/Users/marcovhv/projects/GIT/liminal/scripts/main.gd:1317), [final exit construction](/Users/marcovhv/projects/GIT/liminal/scripts/chunk.gd:5566).

**Presentation, audio, and usability**

The sampled images show clear palette changes and recognizable spaces. Casino's controlled pool of light around the powered machine gives it a useful focal point. Poolrooms creates contrast through brightness and water; the Data Center has a strong directional composition. Some ordinary sampled rooms remain visibly modular and sparse. Improve the composition of guaranteed gameplay locations first: one meaningful focal object, a believable approach, and an intentional view toward the next connection.

The fresh casino gameplay capture uses the recovered-tape mode at the saved 100% distortion setting, matching the configured distortion default. It strongly softens edges and spreads color around both scene detail and HUD text. This is a style judgment, not proof of widespread discomfort. Because the core mechanic requires observation, test a gentler baseline, a separate clean-HUD option, and stronger distortion reserved for important signal events. Retain the full-strength treatment for players who prefer it.

![Current casino gameplay with recovered-tape presentation](/Users/marcovhv/projects/GIT/liminal/build/steam-review-2026-09-08/liminal-review-casino.png)

The interface already has saved FOV, sensitivity, head bob, music/effects volume, VHS intensity and reduced flashing. Pause is implemented. Build on that rather than describing those features as missing.

The main remaining usability work is:

- Full controller support and complete keyboard menu navigation, including title, settings, photo review, intro, death, and confirmation screens. Current input is largely hard-coded physical keys and mouse, and several buttons explicitly disable focus.
- Remappable actions and configurable hold/toggle behavior. The camera already supports a keyboard toggle as well as mouse hold; preserve both options.
- Subtitles for Cross and essential speech, scalable readable text, optional transcripts, and captions for gameplay-relevant sound cues. Existing event captions are not a dialogue subtitle system.
- Separate dialogue control and an optional narrower audio dynamic range. Tape audio currently routes separately from the world; expose useful player control over that distinction.
- A clear primary “Begin/Continue Descent” action with the peaceful mode visibly described. Test whether fresh players choose the experience they intended.
- An accessible replay/skip flow. A mouse-only skip after the first completed prologue is too restrictive.

The code describes layered room tone, footsteps, whispers, heartbeat, music, and isolated tape audio. That is a promising sound structure, but this review did not certify the final mix by listening through the campaign. Run dedicated headphone and speaker sessions to assess masking, directional clarity, fatigue, and whether constant music leaves enough room for environmental sound to matter. [Settings](/Users/marcovhv/projects/GIT/liminal/scripts/game_settings.gd:11), [input](/Users/marcovhv/projects/GIT/liminal/scripts/player.gd:374), [intro skip](/Users/marcovhv/projects/GIT/liminal/scripts/descent_intro.gd:99).

**Steam positioning and launch priorities**

The commercial proposition should be specific enough to show in a short gameplay clip. A proposed description, based on the existing identity:

> Your camera sees what the building hides. Photograph the impossible, stand still when the lights die, and follow a missing researcher through eleven floors that won't stay the same.

Illustrative comparisons checked against current primary sources:

| Reference | Established promise | Implication for this game |
| --- | --- | --- |
| POOLS | Atmospheric exploration with no chasing monsters; its store describes six chapters lasting 10–30 minutes each. | Peaceful environmental horror has an audience. Wander should make its own promise clear. [Steam page](https://store.steampowered.com/app/2663530/POOLS/) |
| The Exit 8 | Observe anomalies and decide whether to turn back; the store lists a 15–60 minute experience. | A compact, comprehensible action can carry the pitch. Explain this game's photographic decision just as clearly. [Steam page](https://store.steampowered.com/app/2653790/The_Exit_8/) |
| The Complex: Expedition | Exploration and a narrative framing within a vast Backrooms setting. | The environmental category is already recognizable; the camera's consequences must be visible in marketing. [Steam page](https://store.steampowered.com/app/2172260/The_Complex_Expedition/) |
| MADiSON | Its official site describes an instant camera used for supernatural puzzles and survival. | A supernatural camera alone is not a unique claim. The combination of recording contradictions, mutable architecture, and the descent is the stronger distinction. [Official site](https://madisongame.com/) |

The retrieved Steam pages showed strong English-language user ratings for the first three examples: POOLS 95% of 3,441 reviews, The Exit 8 93% of 5,163, and The Complex: Expedition 89% of 1,662. These are changing, language-filtered snapshots, not total sales, genre success rates, or a representative market sample. Their value here is positioning evidence. This review does not claim that copying their features predicts commercial success.

Make the first trailer's opening show a real, understandable before/after photograph sequence. Then show the stillness rule in action, a contrasting environment, and another player decision. Use actual gameplay, preserve later surprises, and make on-screen changes readable on a small video. The current title is emotionally appropriate; its capsule artwork needs to remain legible at small sizes and communicate the camera/architecture relationship.

Develop a **15–20 minute public demo** around the improved casino and a taste of the mall, preserving campaign order. It should end after the player has successfully used the core mechanic and seen a reason the next floor will differ. Separately, use an internal airport or Poolrooms slice to validate that later chapters offer different decisions. There is little value in a polished demo whose later campaign cannot sustain its promise.

Track qualified store visits, wishlists, demo completion, and stated reasons for wanting more. Use referral attribution for a small creator outreach experiment once the demo is ready. Prepare short factual creator notes and spoiler boundaries; this review has not contacted anyone or published materials. Avoid treating raw traffic or an arbitrary wishlist target as a guarantee. Valve says store traffic and conversion rate are not direct visibility factors, and wishlists have limited algorithmic roles while remaining valuable for player notifications. [Valve visibility guidance](https://partner.steamgames.com/doc/marketing/visibility).

Next Fest needs deliberate timing. Valve currently permits one Next Fest participation per title and requires a public base-game page and playable demo, among other eligibility conditions. The October 2026 event runs October 19–26, but its published registration deadline was August 31, which has already passed as of this review. If the game is already registered, assess readiness against its deadlines; otherwise verify the next eligible event. Do not assume an October slot or rush the game for it. [Next Fest eligibility](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest), [October schedule](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/2026october).

Set price after measuring representative campaign length, variation, completion, and perceived value. Eleven floors do not by themselves establish a premium price. Avoid lengthening navigation to reach a nominal playtime. A satisfying ending and consistently worthwhile progression are better reasons to recommend the game.

**Release issue that must be resolved**

Update after this review: the nine sign faces have been replaced with original
generated artwork in `textures/authored/mall_signs/`. The old NC files have been
deleted; both export presets retain NC exclusions as a safeguard. The paragraph
below records the issue as it stood on the review date.

The repository identifies the mall storefront textures as **CC BY-NC 4.0**, explicitly marks commercial use as not permitted, and still loads them in the mall builder. The current export presets include all resources and do not exclude that directory. Replace or remove the sign textures and ensure they are absent from the actual commercial package; merely ceasing to display them is insufficient for a clean release inventory. The project already has generated-lettering fallbacks. [Asset record](/Users/marcovhv/projects/GIT/liminal/THIRD_PARTY_ASSETS.md:486), [runtime use](/Users/marcovhv/projects/GIT/liminal/scripts/levels/mall_level_builder.gd:253), [license terms](https://creativecommons.org/licenses/by-nc/4.0/).

Other release work should support the experience:

- Validate the exported Windows build on representative target hardware, including cold launch, streaming, large rooms, effects, video playback, and long sessions. The existing M3 Max headless timings measure only parts of CPU work; they do not establish a Windows or GPU frame-rate claim. [Measurement limits](/Users/marcovhv/projects/GIT/liminal/docs/performance/2026-09-05-streaming.json:5).
- Offer practical resolution/display and graphics-quality controls. Validate readable gameplay under each supported preset.
- Verify saves across updates and Steam accounts, offline behavior, install/uninstall expectations, and Cloud conflicts. No Steam integration was found in the inspected repository; backend settings were not inspected, so Cloud absence cannot be concluded from source alone. Auto-Cloud can be configured without a game API integration. Sync progress deliberately and avoid blindly syncing machine-specific graphics choices. [Steam Cloud](https://partner.steamgames.com/doc/features/cloud).
- Add controller support before claiming it. Validate Deck readability, performance, video, input and suspend/resume if targeting Deck. A native Linux port is optional: Valve supports testing Windows builds through Proton. [Compatibility guidance](https://partner.steamgames.com/doc/steamhardware/compat).
- Add a small set of discovery/completion achievements and easy photograph/seed sharing after the core experience works. Treat these as supporting features.
- Reconcile shipped instructions and public descriptions with current mechanics. For example, older README text says staring can banish figures; current figure code says it cannot. Also standardize Data Center versus older Monolith naming, and Bloom versus Upside Down, across player-facing material.

**Suggested production order**

Effort is relative: S is a bounded change, M involves a feature or authored encounter, L spans systems and substantial QA. These are planning categories, not calendar estimates.

| Order | Work | Expected benefit | Effort | Evidence needed before expanding |
| --- | --- | --- | --- | --- |
| Immediate commercial prerequisite | Replace NC sign textures and inspect the exported package. | Removes a documented commercial-use obstacle. | S–M | Clean package inventory and current attribution record. |
| 1 | Playable opening, skip/replay changes, subtitles for demo material. | Faster understanding and less friction before the first payoff. | M | Fresh players use the camera and explain the blackout rule without coaching. |
| 2 | Expand one camera contradiction into a meaningful consequence; retain its photograph. | Establishes the central reason to play and share the game. | M | Players notice the change and can describe what their action did. |
| 3 | Add one contrasting later-floor encounter and revise the demo's first two floors. | Tests whether the premise supports development beyond the opening. | M–L | Players describe different decisions, not only different scenery. |
| 4 | Tune route landmarks, pacing and elevator climaxes using session evidence. | Reduces repetitive searching and predictable interruptions. | M | Lower aimless backtracking and boredom reports without losing dread. |
| 5 | Finish remapping, controller/UI navigation, dialogue accessibility, display presets. | Makes the game usable by more of its intended audience. | M–L | End-to-end input and comfort tests on supported configurations. |
| 6 | Extend proven encounter patterns across the campaign; implement and validate the intended ending. | Gives eleven floors a coherent progression and completes the currently missing narrative payoff. | L | Complete runs maintain curiosity and deliver a satisfying final payoff before results appear. |
| 7 | Final demo/store/creator assets, release QA, Cloud and achievements. | Converts the validated experience into a credible release. | M | Accurate store promises, stable exports, and evidence of voluntary interest. |

Pause additional themes, large prop expansions without a gameplay purpose, multiplayer, VR, combat trees, and live-service systems during this pass. They would enlarge production before answering whether the campaign's existing identity sustains interest. Small ambient interactions can still be worthwhile when they reinforce the setting or a signature encounter.

**How to test whether the changes are helping**

Begin with twelve unfamiliar players: roughly half already enjoy liminal/analog horror, half enjoy adjacent first-person horror. This is formative testing, not a statistically representative market forecast. Observe mostly without coaching; use retrospective questions so constant narration does not destroy the intended atmosphere. Test the current opening first, then a revised opening with a fresh group. Follow with longer campaign sessions and a broader demo audience.

Record time to control, first camera use, first valid photograph, rule comprehension, first avoidable death, floor completion, tape interruption, lift cancellation, and voluntary stopping point. Break floor time into navigation, active encounter, video, photograph review, and elevator wait. Record route progress and repeat traversal, not just total playtime.

Useful initial acceptance targets, chosen for this project rather than borrowed as industry benchmarks:

- At least 10 of 12 can explain what the camera does and when stillness is safe without help.
- Most encounter the first meaningful photographic contradiction within two minutes of gaining control.
- At least 10 of 12 complete the first intended photographic action without developer intervention.
- Players can name two distinct memorable events from the demo, including one that is not simply a jump scare.
- No repeat case of a necessary anomaly being unreadable, unreachable, or blocked by input/comfort settings.
- Every death has a cause the player can reasonably identify; investigate unfairness reports even when code invariants pass.

Ask afterward: “What did you think you were trying to do?”, “When did you most want to stop?”, “What would you tell a friend happened?”, and “What do you expect the next floor to do differently?” The answer to the last question is especially useful. Wanting to see another environment is a start; wanting to discover how the building will respond next is the stronger campaign engine.

**Validation record and remaining uncertainty**

Fresh checks on Godot 4.6.1:

| Check | Result | What it establishes |
| --- | --- | --- |
| `audit_photo_runtime.gd` | PASS | Production startup, anomaly spawn/framing, quota gate, delayed post-photo resolution. |
| `audit_recording_replay.gd` | PASS | Saved objective completion restores through a floor rebuild; lift access and optional replay persist; interrupting replay retains completion. |
| `audit_survivability.gd` | PASS | Eleven floors, 900 simulated seconds per floor; tested rule and resource invariants allow survival. This is not an autonomous full campaign playthrough. |
| Rendered casino landmark capture | PASS | Actual shutter/review/lower flow verifies real 104 → printed 106 → real 106; captures three landmarks and pause settings. |
| Normal rendered casino startup | Captured | Current recovered-tape presentation and objective HUD at 1280×720. |
| ffprobe measurement | Reproduced | Actual shipped objective/prologue/tutorial durations in the table above. |

The replay audit logged a null-material diagnostic during teardown despite passing its assertions. Rendered exits logged resource/texture cleanup warnings. These are not claimed fixed and should be tracked separately from gameplay judgments. An initial diagnostic launch combined `--audit` with screenshot capture and exited without a capture; the normal isolated screenshot path was then used successfully. No game code was changed for this review.

Fresh images, logs, and exact measurements are in [the local evidence directory](/Users/marcovhv/projects/GIT/liminal/build/steam-review-2026-09-08), which is under the repository's ignored build directory. The capture helper was copied to a temporary file solely to redirect its output. Existing all-floor captures informed the broad visual comparison; they predate some ongoing prop changes and are not a certification of every current room.

The next design investment should be one playable proof: a new player makes a photograph, sees an impossible consequence, uses what they learned, survives an understandable threat, and chooses to keep going. Establish that response, then build the campaign and Steam presentation around it.
