extends SceneTree
## Headless exporter for the local sound library. This only writes preview assets.

const OUTPUT_DIR := "res://deliverables/sound-preview"
const AMBIENT_PALETTE := preload("res://scripts/ambient_palette.gd")
const SFX := preload("res://scripts/sfx.gd")
const SOUND_BANK := preload("res://scripts/sound_bank.gd")
const GENERATION := preload("res://tools/sound_generation_prompts.gd")
const SOUND_METHODS := [
	"ding", "buzz", "muzak", "step_carpet", "step_marble", "thud", "key_click",
	"water_rush", "drip", "creak", "clang", "moan", "pa_chime", "pa_voice",
	"jet_far", "portal_hum", "warp", "shiver", "static_hiss", "lift_motor",
	"lift_shaft", "elev"
]
const UNUSED := ["step_marble", "water_rush", "warp"]
var _export_failed := false
const PURPOSES := {
	"ding": "Small confirmation chime: casino/slot wins, terminal beeps, and lift/progression feedback. Different callers change pitch and volume.",
	"buzz": "Continuous electrical hum: charging stations, VHS sets, and some casino/Bloom light fixtures. Not the blackout signal.",
	"muzak": "Muffled casino loudspeaker music, heard around selected lounge/slot areas.",
	"step_carpet": "A Shadow Figure's approaching footsteps. Your own footsteps use the recorded surface loops below.",
	"step_marble": "Unused procedural footstep candidate. The player currently uses recorded marble footsteps instead.",
	"thud": "One short structural impact. Used by blackout, arrival, lift and realm events; also selected under the room-event label 'knocks'. The source contains one hit, not a three-knock sequence. One source, several gameplay roles.",
	"key_click": "Shared small mechanical click: camera shutter/focus, flashlight switch, office typing, and lift call button. Pitch/timing changes by caller.",
	"water_rush": "Unused synthesized water loop. Current player splashes and wading use sound-water-* recordings below.",
	"drip": "Short local drip scattered through the Asylum. This is separate from the new 3-second drips/pipes room events.",
	"creak": "Shared building creak: doors, lift/blackout atmosphere, realm collapse and photo responses. Also the new sparse 'creak' room event. One source, several gameplay roles.",
	"clang": "Metal strike in Asylum ambience, lift descent, and realm collapse/fracture.",
	"moan": "Rare, distant Asylum voice-like ambience. Not the recorded whisper bank.",
	"pa_chime": "Airport public-address preamble. Normally followed by the unintelligible PA voice after about 1.6 seconds.",
	"pa_voice": "Airport's unintelligible announcement after the PA chime. It does not contain gameplay instructions.",
	"jet_far": "Rare distant aircraft rumble in the Airport.",
	"portal_hum": "Continuous realm/portal energy: entrances, flash-bounty objects, and realm-collapse effects.",
	"warp": "Unused synthesized transition candidate; no current gameplay caller.",
	"shiver": "Close, spatial presence sound attached to a Shadow Figure. DORMANT: an emitter is created, but the game currently never triggers it. The replacement does not add a new trigger.",
	"static_hiss": "Raised-camera static and the realm wireframe-erasure effect.",
	"lift_motor": "Motor running during the Descent lift ride.",
	"lift_shaft": "Approaching lift car / shaft whine while waiting for it.",
	"elev": "Two-note elevator arrival chime, played around lift door opening/arrival closing and general elevator responses. This is a chime, not the sound of the door mechanism.",
}
const ROOM_PURPOSES := {
	"trolley": "Unseen trolley rolling nearby. No trolley or enemy is spawned. Now uses your supplied trolley.mp3.",
	"vent": "Local fan or duct movement. Audio only: it does not change power or start a blackout. Now uses your supplied vent.mp3.",
	"printer": "A remote printer or machinery cycling without anyone at it. Now uses your supplied printer.mp3.",
	"ticking": "A short sequence of dry clock ticks. Atmospheric only; not a countdown.",
	"ballast": "Electrical ballast buzz/flutter. Audio only; no light flicker or blackout is triggered.",
	"metal": "Several resonant metal taps: shutters, rails or machinery settling. Not a lift arrival signal.",
	"pipes": "Enclosed plumbing/water movement. Now uses your supplied pipes.mp3 instead of sharing the old synthesized drip tone.",
	"drips": "Separate pool-water droplet event. Now uses your supplied drips.mp3, distinct from the pipe recording.",
	"organic": "Low groaning, pulsing tissue/building noise for the Bloom. Not the player's heartbeat or a damage cue.",
}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var ambient_kinds: Array[String] = []
	for palette in AMBIENT_PALETTE.PALETTES.values():
		for kind in palette:
			if kind not in ambient_kinds:
				ambient_kinds.append(kind)
	if not _validate_prompts(ambient_kinds):
		quit(1)
		return
	# Imported room events are linked directly, not re-encoded as preview WAVs.
	for method_name in SOUND_METHODS:
		_export_stream(_sound_bank_stream(method_name), "soundbank_%s.wav" % method_name)
	if _export_failed:
		quit(1)
		return
	_write_index(ambient_kinds)
	_write_prompts()
	print("Sound preview export complete: %d installed room MP3s, %d SoundBank, %d other source MP3 links" % [AMBIENT_PALETTE.RECORDINGS.size(), SOUND_METHODS.size(), _source_mp3_count()])
	quit()

func _sound_bank_stream(method_name: String) -> AudioStreamWAV:
	match method_name:
		"ding": return SOUND_BANK.ding()
		"buzz": return SOUND_BANK.buzz()
		"muzak": return SOUND_BANK.muzak()
		"step_carpet": return SOUND_BANK.step_carpet()
		"step_marble": return SOUND_BANK.step_marble()
		"thud": return SOUND_BANK.thud()
		"key_click": return SOUND_BANK.key_click()
		"water_rush": return SOUND_BANK.water_rush()
		"drip": return SOUND_BANK.drip()
		"creak": return SOUND_BANK.creak()
		"clang": return SOUND_BANK.clang()
		"moan": return SOUND_BANK.moan()
		"pa_chime": return SOUND_BANK.pa_chime()
		"pa_voice": return SOUND_BANK.pa_voice()
		"jet_far": return SOUND_BANK.jet_far()
		"portal_hum": return SOUND_BANK.portal_hum()
		"warp": return SOUND_BANK.warp()
		"shiver": return SOUND_BANK.shiver()
		"static_hiss": return SOUND_BANK.static_hiss()
		"lift_motor": return SOUND_BANK.lift_motor()
		"lift_shaft": return SOUND_BANK.lift_shaft()
		"elev": return SOUND_BANK.elev()
	return null

func _export_stream(stream: AudioStreamWAV, filename: String) -> void:
	if stream == null:
		_export_failed = true
		push_error("No stream returned for %s" % filename)
		return
	var path := "%s/%s" % [OUTPUT_DIR, filename]
	var err := stream.save_to_wav(ProjectSettings.globalize_path(path))
	if err != OK:
		_export_failed = true
		push_error("Could not save %s: %s" % [path, err])

func _source_mp3_count() -> int:
	var files := DirAccess.get_files_at("res://sounds")
	var count := 0
	for file in files:
		if file.to_lower().ends_with(".mp3"):
			count += 1
	return count

func _write_index(ambient_kinds: Array[String]) -> void:
	var html := FileAccess.open("%s/index.html" % OUTPUT_DIR, FileAccess.WRITE)
	html.store_string(_html(ambient_kinds))

func _validate_prompts(ambient_kinds: Array[String]) -> bool:
	var expected: Array[String] = []
	for kind in ambient_kinds:
		if kind not in ["knocks", "creak"]: expected.append("room-" + kind)
	for method in SOUND_METHODS: expected.append("sound-" + method)
	if GENERATION.DATA.size() != expected.size():
		push_error("Synthetic prompt count mismatch")
		return false
	for id in expected:
		if not GENERATION.DATA.has(id):
			push_error("Missing synthetic prompt: " + id)
			return false
		var entry: Dictionary = GENERATION.DATA[id]
		var prompt := str(entry["prompt"])
		var seconds := float(entry["seconds"])
		var stream := _source_for_prompt(id)
		if prompt.is_empty() or prompt.length() > 450 or seconds < 0.5 or seconds > 30 \
				or bool(entry["loop"]) != _is_looping(stream):
			push_error("Invalid duration/loop/prompt length: %s (%d characters)" % [id, prompt.length()])
			return false
	print("Validated %d sound briefs: %d installed replacements, %d remaining procedural sources and %d unused candidates" % [expected.size(), _installed_count(), _remaining_count(), UNUSED.size()])
	return true

func _source_for_prompt(id: String) -> AudioStream:
	return AMBIENT_PALETTE.stream(id.trim_prefix("room-")) if id.begins_with("room-") \
		else _sound_bank_stream(id.trim_prefix("sound-"))

func _is_looping(stream: AudioStream) -> bool:
	if stream is AudioStreamMP3: return stream.loop
	if stream is AudioStreamWAV: return stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
	push_error("Unsupported preview audio type")
	return true

func _installed(id: String) -> bool:
	return id.begins_with("room-") or SOUND_BANK.RECORDINGS.has(id.trim_prefix("sound-"))

func _installed_path(id: String) -> String:
	return "sounds/room_events/%s.mp3" % id.trim_prefix("room-") if id.begins_with("room-") else "sounds/shared/%s.wav" % id.trim_prefix("sound-")

func _installed_count() -> int:
	return AMBIENT_PALETTE.RECORDINGS.size() + SOUND_BANK.RECORDINGS.size()

func _remaining_count() -> int:
	return SOUND_METHODS.size() - SOUND_BANK.RECORDINGS.size() - UNUSED.size()

func _write_prompts() -> void:
	var document := "# Liminal sound replacements and ElevenLabs prompts\n\n"
	document += "%d sound briefs: %d replacements installed, %d remaining procedural sources to replace, and %d unused procedural candidates. Installed prompts are retained only as references; no need to generate them again. The installed shiver is dormant: its emitter exists but has no playback trigger. The room labels knocks and creak still reuse SoundBank thud and creak; do not generate them twice. The other recorded MP3s are outside this prompt set.\n\n" % [GENERATION.DATA.size(), _installed_count(), _remaining_count(), UNUSED.size()]
	document += "Use ElevenLabs Sound Effects. Set the generation duration and Looping switch as listed; the prompt alone does not replace these controls. Durations are authoring recommendations, not a promise of frame-exact output. Audition several takes. Keep sounds isolated: the game already applies distance and reverb. Loops should have no fade or obvious start/end; trim leading silence from one-shots without cutting their natural decay.\n\n"
	document += "For remaining clips shorter than 0.5 seconds, generate 0.5 seconds and trim the single event to the listed in-game length. For loops, longer generation adds natural variation, not a longer gameplay event. Name downloads with their source IDs, keeping the actual file extension. Nine room MP3s are installed in sounds/room_events/. The supplied buzz, drip, moan, PA voice and shiver are prepared as level-balanced WAVs in sounds/shared/; originals remain unchanged in art/shared_sound_sources/. Buzz has a short overlap crossfade for its loop seam. Drip retains its full supplied 0.8-second decay rather than being cut to the old 0.28-second target.\n\n"
	document += "Controls reference: [ElevenLabs Sound Effects guide](%s). All prompts are below 450 characters.\n\n" % GENERATION.GUIDE_URL
	for id in GENERATION.DATA:
		var entry: Dictionary = GENERATION.DATA[id]
		var installed := _installed(id)
		document += "## %s%s\n\n" % [id, " — INSTALLED" if installed else (" — UNUSED" if id.trim_prefix("sound-") in UNUSED else "")]
		if installed:
			document += "- Installed file: %s\n- Status: replaced; original prompt below is reference only\n" % _installed_path(id)
			if id == "sound-shiver": document += "- Playback: DORMANT — emitter has no trigger\n"
		document += "- %s: %s seconds\n- Looping: %s\n- Current source length: %.3f seconds\n" % ["Original generation target" if installed else "Generate", String.num(entry["seconds"], 2), "ON — seamless" if entry["loop"] else "OFF — one-shot", _source_for_prompt(id).get_length()]
		if entry.has("trim") and not installed: document += "- In-game trim target: %s\n" % entry["trim"]
		document += "\n```text\n%s\n```\n\n%s\n\n" % [entry["prompt"], entry["note"]]
	var file := FileAccess.open(OUTPUT_DIR.path_join("elevenlabs-prompts.md"), FileAccess.WRITE)
	file.store_string(document)

func _html(ambient_kinds: Array[String]) -> String:
	var rows := ""
	rows += '<aside class="generation-intro"><h2>%d sound replacements installed</h2><p>Nine room-event MP3s plus buzz, drip, moan, PA voice and shiver now use your supplied sounds. The <b>buzz loops</b>; the other replacements are <b>one-shots</b>. Room previews play the original MP3s; shared replacements preview level-balanced WAVs. The game then adds its existing emitter volume, distance and reverb.</p><p><b>%d procedural sources remain to replace</b>, plus %d unused candidates. Installed prompts are reference only. Shiver is installed but dormant: its emitter has no playback trigger. Knocks and creak remain unchanged.</p><p>For remaining replacements, use <b>Sound Effects</b>, not text-to-speech. Set duration and Looping as listed. Audition and trim one-shots where indicated. Longer loops add variation, not a longer gameplay event. Preserve the actual downloaded file extension.</p><p><a href="elevenlabs-prompts.md" download>Download all prompts, settings and replacement status</a> · <a href="%s" target="_blank" rel="noreferrer">ElevenLabs controls guide</a></p></aside>' % [_installed_count(), _remaining_count(), UNUSED.size(), GENERATION.GUIDE_URL]
	var floor_names := {0: "Casino", 1: "Office", 2: "Annex", 4: "Airport", 5: "Asylum", 6: "School", 7: "Mall", 8: "Prison", 9: "Poolrooms", 10: "Data Center", 11: "Bloom"}
	rows += '<h2>Where you hear the room sounds</h2><p>The new short room events occur roughly every 38–72 seconds when the horror pacing system allows it, and can answer a successful photograph. Each floor shuffles three choices without immediate repeats. They are atmosphere, not warnings about a nearby enemy. The continuous bed is the underlying recorded room tone; Airport and Mall now have distinct supplied continuous loops. This does not affect the short room events.</p><table><tr><th>Floor</th><th>Short room events</th><th>Continuous bed (source file)</th></tr>\n'
	for theme in [0, 7, 1, 4, 6, 8, 5, 9, 2, 10, 11]:
		var bed: Array = SFX.BEDS.get(theme, [])
		rows += '<tr><td>%s</td><td>%s</td><td>%s.mp3</td></tr>\n' % [floor_names[theme], ", ".join(AMBIENT_PALETTE.PALETTES.get(theme, [])), bed[0] if not bed.is_empty() else "—"]
	rows += '</table>\n'
	rows += '<h2>New short room events — replaced</h2><p>All nine below use your supplied recordings. <b>Unchanged aliases:</b> <code>knocks</code> is <a href="#sound-thud">SoundBank.thud()</a>; <code>creak</code> is <a href="#sound-creak">SoundBank.creak()</a>. They are listed once below under shared sounds.</p>'
	for kind in ambient_kinds:
		if kind in ["knocks", "creak"]: continue
		rows += _item("room-" + kind, kind.capitalize() + " — INSTALLED", "sounds/room_events/%s.mp3" % kind, ROOM_PURPOSES.get(kind, ""), "../../sounds/room_events/%s.mp3" % kind)
	rows += '<h2>Shared sounds — recorded replacements and remaining procedural sources</h2><p>These names are reusable sound sources, not one-to-one event names. Replacing one shared source affects every role listed in its description. Installed shared recordings are previewed as the level-balanced WAVs used by the game; shiver remains dormant.</p>'
	for method_name in SOUND_METHODS:
		if method_name in UNUSED: continue
		var id: String = "sound-" + method_name
		var installed := _installed(id)
		var label: String = method_name.replace("_", " ").capitalize() + (" — INSTALLED" if installed else "")
		var path := _installed_path(id) if installed else "scripts/sound_bank.gd · SoundBank.%s()" % method_name
		rows += _item(id, label, path, PURPOSES[method_name], "soundbank_%s.wav" % method_name)
	var source_groups := {"ambient": [], "footsteps": [], "water": [], "scares": [], "whispers": [], "figure deaths": [], "player deaths": [], "other": [], "unused": []}
	for file in DirAccess.get_files_at("res://sounds"):
		if not file.to_lower().ends_with(".mp3"): continue
		var group := "other"
		if file == "sound-sewer-ambient.mp3": group = "unused"
		elif file.begins_with("ambient-") or file in ["data-center-ambient.mp3", "poolrooms-calm-tranquil.mp3", "sound-office.mp3", "sound-airport.mp3", "sound-mall.mp3", "sound-asylum.mp3"]: group = "ambient"
		elif file.begins_with("sound-walking-"): group = "footsteps"
		elif file.begins_with("sound-water-"): group = "water"
		elif file.begins_with("sound-jumpscare"): group = "scares"
		elif file.begins_with("sound-whisper"): group = "whispers"
		elif file.begins_with("sound-playerdeath"): group = "player deaths"
		elif file.begins_with("sound-demondeath"): group = "figure deaths"
		source_groups[group].append(file)
	for group in source_groups:
		if source_groups[group].is_empty(): continue
		rows += '<h2>%s (existing sounds)</h2>\n' % group.capitalize()
		for file in source_groups[group]:
			rows += _item(file.get_basename(), file, "sounds/" + file, _recorded_purpose(file, group), "../../sounds/%s" % file)
	rows += '<h2>Unused procedural candidates</h2><p>These are not currently played by the game. No replacement is necessary.</p>'
	for method_name in UNUSED:
		rows += _item("sound-" + method_name, method_name + " — UNUSED", "scripts/sound_bank.gd · SoundBank.%s()" % method_name, PURPOSES[method_name], "soundbank_%s.wav" % method_name)
	return '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Liminal sound library</title><style>body{font:16px system-ui;line-height:1.5;max-width:1080px;margin:40px auto;padding:0 20px;background:#111;color:#eee}h1{margin-bottom:8px}p{color:#bbb}.item{display:flex;gap:28px;align-items:flex-start;border-top:1px solid #333;padding:18px 0}.description{flex:1;min-width:0}.description p{margin:6px 0}.path{font:12px ui-monospace,monospace;color:#aaa;overflow-wrap:anywhere}audio{width:300px;flex:none}h2{margin-top:40px;color:#8fd3ff}table{width:100%%;border-collapse:collapse;margin-bottom:24px}th,td{text-align:left;border:1px solid #333;padding:8px;vertical-align:top}a{color:#8fd3ff}.generation{margin-top:16px;border:1px solid #454238;padding:14px;background:#1b1915}.settings{color:#e3d5ac;font-weight:650}.generation label{display:block;margin:10px 0 4px}.generation textarea{box-sizing:border-box;width:100%%;resize:vertical;background:#111;color:#eee;border:1px solid #666;padding:12px;font:14px/1.55 system-ui}.generation button{min-height:44px;padding:8px 16px;background:#eadfbf;border:0;color:#17140e;cursor:pointer;margin-top:8px;font:inherit}.generation button:focus-visible,.generation textarea:focus-visible{outline:3px solid #8fd3ff;outline-offset:3px}.copy-status{margin-left:12px;color:#e3d5ac}.generation-intro{border-left:3px solid #8fd3ff;padding-left:18px}.generation-intro h2{margin-top:24px}@media(max-width:700px){.item{flex-wrap:wrap;gap:8px}.description{flex-basis:100%%}audio{width:100%%}table{font-size:13px;display:block;overflow-x:auto}}</style><h1>Liminal sound library</h1><p>Listen, identify the gameplay role, then choose what to replace. Exact aliases are grouped; unused candidates are marked separately. These dry source previews omit the game’s distance, reverb, pitch variation and volume trims. Start at a low volume: scare and death recordings are much louder than ambience. Preview files do not change the game.</p>%s<script>document.querySelectorAll(".copy-prompt").forEach(button => { button.addEventListener("click", async () => { const box = button.closest(".generation"); const field = box.querySelector("textarea"); const status = box.querySelector(".copy-status"); try { await navigator.clipboard.writeText(field.value); status.textContent = "Copied"; } catch { field.focus(); field.select(); status.textContent = "Selected — press Ctrl+C / Cmd+C"; } }); });</script>' % rows

func _item(id: String, title: String, path: String, purpose: String, source: String) -> String:
	return '<section class="item" id="%s"><div class="description"><strong>%s</strong><p>%s</p><div class="path">%s</div>%s</div><audio aria-label="Listen to %s" controls preload="none" src="%s"></audio></section>\n' % [id.xml_escape(), title.xml_escape(), purpose.xml_escape(), path.xml_escape(), _prompt_panel(id), title.xml_escape(), source.xml_escape()]

func _prompt_panel(id: String) -> String:
	if not GENERATION.DATA.has(id): return ""
	var entry: Dictionary = GENERATION.DATA[id]
	var installed := _installed(id)
	var loop_label := "ON — seamless" if _is_looping(_source_for_prompt(id)) else "OFF — one-shot"
	var settings := "INSTALLED: %.3f s · Looping: %s" % [_source_for_prompt(id).get_length(), loop_label] if installed else "Generate: %s s · Looping: %s" % [String.num(entry["seconds"], 2), loop_label]
	var trim := "<p><b>Trim for the game: %s.</b> Generate one event, then remove unused silence.</p>" % str(entry["trim"]).xml_escape() if entry.has("trim") else ""
	if installed:
		trim = '<p><b>Already replaced — no generation needed.</b> Original generation prompt retained below for reference (target %s s).</p>' % String.num(entry["seconds"], 2)
	return '<div class="generation"><div class="settings">%s</div><div class="path">Current source: %.3f s · Download name: %s</div>%s<label for="prompt-%s">ElevenLabs prompt</label><textarea id="prompt-%s" rows="6" readonly>%s</textarea><button class="copy-prompt" aria-label="Copy ElevenLabs prompt for %s">Copy prompt</button><span class="copy-status" role="status" aria-live="polite"></span><p>%s</p></div>' % [settings.xml_escape(), _source_for_prompt(id).get_length(), id.xml_escape(), trim, id.xml_escape(), id.xml_escape(), str(entry["prompt"]).xml_escape(), id.xml_escape(), str(entry["note"]).xml_escape()]

func _recorded_purpose(file: String, group: String) -> String:
	if file == "sound-airport.mp3": return "Airport only: your new 30-second looping background room tone. The game applies its own measured volume adjustment; this preview plays the unadjusted source."
	if file == "sound-mall.mp3": return "Mall only: your new 30-second looping background room tone, separate from Airport. The game applies its own measured volume adjustment; this preview plays the unadjusted source."
	match group:
		"ambient": return "Continuous background room tone for the floors listed in the table above. Mixed much quieter in-game than this raw file."
		"footsteps": return "Your walking loop on the named surface; faded with movement. These are player footsteps, not enemy approach sounds."
		"water":
			if file.contains("enter"): return "Splash when the player enters water."
			if file.contains("exit"): return "Splash when the player leaves water."
			return "Continuous wading/splash loop while moving through water."
		"scares": return "One variation in the random scare bank: figure, apparition and blackout-ambush stingers. Variants avoid immediate repetition; each is a separate recording."
		"whispers": return "One variation in the quiet positional whisper bank, also used by VHS rituals. An unintelligible atmospheric mutter, not a spoken objective."
		"figure deaths": return "A Shadow Figure dying under the flashlight. Random variation; this is NOT the player's death."
		"player deaths": return "The player being caught by a figure. Random variation, played close and non-positional."
		"unused": return "UNUSED: this sewer ambience file has no current gameplay caller. No replacement is necessary."
	if file == "sound-heartbeat.mp3": return "The player's heartbeat, increasing with fright/tension."
	if file == "sound-breathing.mp3": return "The player's breathing at higher fright/tension, layered with the heartbeat."
	if file == "sound-slots.mp3": return "Positional continuous casino slot-bank noise; fades with distance from the machines."
	return "Existing source recording."
