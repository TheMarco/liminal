extends SceneTree
## Regression audit for Descent's rare optional VHS sets and split no-repeat
## tape pools.
## Run: godot --headless --path . --script tools/audit_optional_vhs.gd

const BASE_SEEDS := [405195947, 7, 1234577]
const OBJECTIVE_CHAPTERS: Array[String] = [
	"res://videos/tapes/tape_02.ogv",
	"res://videos/tapes/tape_03.ogv",
	"res://videos/tapes/tape_04.ogv",
	"res://videos/tapes/tape_05.ogv",
	"res://videos/tapes/tape_43.ogv",
	"res://videos/tapes/tape_44.ogv",
	"res://videos/tapes/tape_45.ogv",
	"res://videos/tapes/tape_46.ogv",
	"res://videos/tapes/tape_47.ogv",
	"res://videos/tapes/tape_48.ogv",
]


class TapeListener extends Node:
	var run := DescentRun.new()
	var objective_finishes := 0
	var optional_finishes := 0
	var watching := false

	func _init() -> void:
		run.world_seed = 918273

	func descent_tape_for(key: String, long_form: bool) -> String:
		return run.tape_for_setup(key, long_form)

	func descent_setup_tape_completed(key: String) -> bool:
		return run.setup_tape_completed(key)

	func descent_setup_tape_finished(key: String, objective: bool) -> void:
		run.mark_setup_tape_completed(key)
		if objective:
			objective_finishes += 1
		else:
			optional_finishes += 1

	func descent_tape_watch(on: bool) -> void:
		watching = on


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var all := VhsTapeLibrary.all_paths()
	var shorts := VhsTapeLibrary.paths(false)
	var longs := VhsTapeLibrary.paths(true)
	var beginnings := VhsTapeLibrary.beginning_paths()
	var randoms := VhsTapeLibrary.random_paths()
	if all.size() != longs.size() + shorts.size():
		failures.append("catalogue split lost recordings: %d != %d + %d" % [
			all.size(), longs.size(), shorts.size()])
	if longs.is_empty() or shorts.is_empty():
		failures.append("both objective and optional tape pools must be non-empty")
	if beginnings.size() != 6:
		failures.append("expected 6 ordered beginning tapes, got %d" % beginnings.size())
	if randoms.size() != 15:
		failures.append("expected 15 random optional tapes, got %d" % randoms.size())
	if shorts != beginnings + randoms:
		failures.append("optional pool is not ordered beginnings followed by randoms")
	for i in beginnings.size():
		if beginnings[i].get_file() != "short_beginning_%02d.ogv" % i:
			failures.append("beginning chapter %d has wrong identity: %s" % [
				i, beginnings[i]])
	var expected_chapters := DescentRun.FLOOR_COUNT - 1
	if longs.size() != expected_chapters:
		failures.append("expected %d objective chapters, got %d" % [
			expected_chapters, longs.size()])
	if longs != OBJECTIVE_CHAPTERS:
		failures.append("objective chapter order does not match Cross video1-video10")
	for path in VhsTapeLibrary.RESERVED_GAME_ASSETS:
		if all.has(path) or shorts.has(path) or longs.has(path):
			failures.append("reserved game asset leaked into Cross tape pool: " + path)
		if load(path) as VideoStream == null:
			failures.append("reserved game asset is not loadable: " + path)
	for path in all:
		if load(path) as VideoStream == null:
			failures.append("not a VideoStream: " + path)
	for path in longs:
		if shorts.has(path):
			failures.append("recording appears in both pools: " + path)
	var shader_source := FileAccess.get_file_as_string(
		"res://shaders/vhs_tape.gdshader")
	if shader_source.contains("smoothstep(0.09, 0.0"):
		failures.append("VHS tracking band still uses undefined reversed smoothstep")
	if not shader_source.contains("band_shift") \
			or not shader_source.contains("fuv.x += band"):
		failures.append("VHS footage has no visible tracking displacement")
	_audit_deck(shorts, longs, failures)
	await _audit_playback_modes(shorts, longs, failures)

	var route_setups := 0
	var placed_setups := 0
	for base in BASE_SEEDS:
		var order := DescentRun.order_for(base)
		for floor_idx in DescentRun.FLOOR_COUNT:
			var theme: int = order[floor_idx]
			var ws := WorldGen.level_seed(base, theme)
			var route := DescentRoute.build(ws, theme, floor_idx)
			var cells := route.optional_vhs_cells()
			var expected := clampi(roundi(route.walk_metres() \
				/ DescentRoute.OPTIONAL_VHS_METRES),
				DescentRoute.OPTIONAL_VHS_MIN, DescentRoute.OPTIONAL_VHS_MAX)
			if cells.size() != expected:
				failures.append("seed %d floor %d expected %d route sets, got %d" % [
					base, floor_idx + 1, expected, cells.size()])
			var rebuilt := DescentRoute.build(ws, theme, floor_idx)
			if cells != rebuilt.optional_vhs_cells():
				failures.append("seed %d floor %d route selection changed on rebuild" % [
					base, floor_idx + 1])
			var path := route.path_from_origin()
			var earliest_progress := 1.0
			for slot in cells.size():
				var cell: Vector2i = cells[slot]
				route_setups += 1
				if not path.has(cell) or cell == route.origin or cell == route.target \
						or cell == route.objective_ritual_cell():
					failures.append("invalid route setup cell %s" % cell)
				var progress := float(path.find(cell)) / float(path.size() - 1)
				earliest_progress = minf(earliest_progress, progress)
				var key := "audit:%d:%d:%d:%d" % [
					base, floor_idx, cell.x, cell.y]
				var chunk := Chunk.new(ws, cell, theme, {
					"descent": true,
					"floor_idx": floor_idx,
					"base_seed": base,
					"optional_vhs": true,
					"optional_vhs_key": key,
				})
				root.add_child(chunk)
				await process_frame
				var set := chunk.get_node_or_null("OptionalVhs") as VhsRitual
				if set == null:
					failures.append("optional set did not place seed=%d floor=%d theme=%d cell=%s" % [
						base, floor_idx + 1, theme, cell])
				elif set.objective or not set.has_meta("optional_vhs") \
						or set.get_node_or_null("DescentTapePlay") == null:
					failures.append("optional set contract invalid at %s" % cell)
				elif set._discovery_light == null \
						or set._discovery_light.shadow_enabled \
						or set._discovery_light.omni_range < 8.0 \
						or set._hiss.volume_db > VhsRitual.OPTIONAL_HISS_DB + 0.01:
					failures.append("optional set has no strong low-cost discovery cue at %s" % cell)
				elif chunk._optional_vhs_hits_doorway(set.position, set.rotation.y):
					failures.append("optional set overlaps a doorway approach at %s" % cell)
				else:
					placed_setups += 1
				root.remove_child(chunk)
				chunk.free()
			if not cells.is_empty() and earliest_progress > 0.5:
				failures.append("seed %d floor %d has no optional tape in the first half" % [
					base, floor_idx + 1])

	for failure in failures:
		print("  FAIL " + failure)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	if failures.is_empty():
		print("optional VHS audit: PASS — %d tapes (%d long/%d short), %d/%d route sets placed" % [
			all.size(), longs.size(), shorts.size(), placed_setups, route_setups])
		quit()
	else:
		quit(1)


func _audit_deck(shorts: Array[String], longs: Array[String],
		failures: Array[String]) -> void:
	var run := DescentRun.new()
	run.world_seed = 12345
	var beginnings := VhsTapeLibrary.beginning_paths()
	var randoms := VhsTapeLibrary.random_paths()
	for i in beginnings.size():
		var key := "beginning:%d" % i
		var interrupted_key := "beginning:interrupted:%d" % i
		var tape := run.tape_for_setup(key, false)
		if tape != beginnings[i]:
			failures.append("beginning %d dealt %s instead of %s" % [
				i, tape, beginnings[i]])
		if run.tape_for_setup(interrupted_key, false) != beginnings[i]:
			failures.append("walking past/interrupted VCR consumed beginning %d" % i)
		run.mark_setup_tape_completed(key)
		if run.completed_beginning_count() != i + 1:
			failures.append("completing beginning %d did not advance exactly once" % i)
		run.mark_setup_tape_completed(key)
		if run.completed_beginning_count() != i + 1:
			failures.append("duplicate completion advanced beginning %d twice" % i)
		if i + 1 < beginnings.size() \
				and run.tape_for_setup(interrupted_key, false) != beginnings[i + 1]:
			failures.append("stale interrupted assignment did not move to beginning %d" % (i + 1))

	var seen := {}
	for i in randoms.size():
		var key := "random:%d" % i
		var tape := run.tape_for_setup(key, false)
		if not randoms.has(tape):
			failures.append("%s draw escaped its pool" % key)
		if seen.has(tape):
			failures.append("%s repeated before pool exhaustion" % key)
		seen[tape] = true
		if run.tape_for_setup(key, false) != tape:
			failures.append("%s assignment changed on revisit" % key)
	if seen.size() != randoms.size():
		failures.append("short pool dealt %d/%d unique recordings" % [
			seen.size(), randoms.size()])
	var cycled := run.tape_for_setup("short:cycle", false)
	if not randoms.has(cycled):
		failures.append("post-exhaustion draw escaped the short pool")

	# Long recordings are story chapters, fixed by floor rather than dealt.
	for floor_idx in DescentRun.FLOOR_COUNT - 1:
		run.floor_idx = floor_idx
		var key := "floor:%d:objective" % floor_idx
		var tape := run.tape_for_setup(key, true)
		var expected := VhsTapeLibrary.objective_chapter(floor_idx)
		if tape != expected or not longs.has(tape):
			failures.append("floor %d objective chapter was %s, expected %s" % [
				floor_idx + 1, tape, expected])
		if run.tape_for_setup(key, true) != tape:
			failures.append("floor %d objective chapter changed on revisit" % [
				floor_idx + 1])

	# Claiming the first optional after an objective must initialize the short
	# deck without erasing the already-watched objective state.
	var mixed := DescentRun.new()
	mixed.world_seed = 54321
	var objective_key := "floor:0:objective"
	mixed.tape_for_setup(objective_key, true)
	mixed.mark_setup_tape_completed(objective_key)
	mixed.tape_for_setup("mixed:optional", false)
	if not mixed.setup_tape_completed(objective_key):
		failures.append("first optional claim erased objective completion")
	mixed.free()

	var done_key := "persist-across-floor"
	run.mark_setup_tape_completed(done_key)
	run.prepare_floor()
	if not run.setup_tape_completed(done_key):
		failures.append("optional completion was lost across prepare_floor")
	if not shorts.has(VhsTapeLibrary.deterministic_fallback(12345,
			"optional", false)):
		failures.append("optional fallback did not use the short pool")
	if not longs.has(VhsTapeLibrary.deterministic_fallback(12345,
			"objective", true)):
		failures.append("objective fallback did not use the long pool")
	run.free()


func _audit_playback_modes(shorts: Array[String], longs: Array[String],
		failures: Array[String]) -> void:
	var listener := TapeListener.new()
	root.add_child(listener)
	listener.add_to_group("descent_listener")
	var optional := VhsRitual.new()
	optional.objective = false
	optional.setup_key = "optional-mode"
	root.add_child(optional)
	var objective := VhsRitual.new()
	objective.objective = true
	objective.setup_key = "objective-mode"
	root.add_child(objective)
	await process_frame
	optional._claim_tape()
	objective._claim_tape()
	if not shorts.has(optional._tape_path):
		failures.append("optional VCR did not claim a short recording")
	if not longs.has(objective._tape_path):
		failures.append("objective VCR did not claim a long recording")
	optional._on_activated(null)
	if optional._video == null or optional._video_vp == null:
		failures.append("optional VCR did not construct its video viewport")
	else:
		if optional._video_vp.render_target_update_mode \
				!= SubViewport.UPDATE_ALWAYS:
			failures.append("video viewport did not update during playback")
		if not optional._video.is_playing():
			failures.append("claimed recording did not start playing")
	if optional._screen_mat == null \
			or optional._screen_mat.shader.resource_path \
				!= "res://shaders/vhs_tape.gdshader":
		failures.append("CRT screen lost its VHS distortion shader")
	else:
		if float(optional._screen_mat.get_shader_parameter("use_footage")) != 1.0:
			failures.append("CRT shader did not enter distorted-footage mode")
		if optional._screen_mat.get_shader_parameter("tape_tex") == null:
			failures.append("decoded recording was not bound to the CRT shader")
	var interrupted_tape := optional._tape_path
	optional.reset_tape()
	if not optional._tape_path.is_empty():
		failures.append("interrupted optional VCR kept a stale local assignment")
	optional._claim_tape()
	if optional._tape_path != interrupted_tape:
		failures.append("interrupted beginning did not remain the next recording")
	optional._finish_tape()
	if listener.optional_finishes != 1 or listener.objective_finishes != 0:
		failures.append("optional completion mutated the objective channel")
	if listener.run.completed_beginning_count() != 1:
		failures.append("completed optional beginning did not advance the sequence")
	# Threat/passive protection must cover the whole camera-return tween. The
	# previous ordering released it while player physics and input were frozen.
	var viewer := Player.new()
	root.add_child(viewer)
	await process_frame
	optional._begin_watch(viewer)
	optional._end_watch()
	if not listener.watching or viewer.is_physics_processing():
		failures.append("VCR released protection before restoring player control")
	await create_timer(0.75).timeout
	# A long construction audit can advance timer and tween clocks across the
	# same oversized frame. Let the tween callback queue drain before sampling.
	await process_frame
	if listener.watching or not viewer.is_physics_processing():
		failures.append("VCR did not release protection after restoring control")
	root.remove_child(viewer)
	viewer.free()
	objective._finish_tape()
	if listener.objective_finishes != 1:
		failures.append("objective completion did not reach its gate channel")
	root.remove_child(optional)
	optional.free()
	root.remove_child(objective)
	objective.free()
	root.remove_child(listener)
	listener.run.free()
	listener.free()
