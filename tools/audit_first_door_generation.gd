extends SceneTree
## Independent graph checks for first-floor seed admission and replay.

const REQUESTS := [10001, 10003, 10005, 10007, 10009, 10011, 10013, 10015, 10017, 10019, 10021, 10023, 10025, 10027, 10029, 10031, 10033, 10035, 10037, 10039]

var failures: Array[String] = []
var reports: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func room(seed: int, at: Vector2i) -> Vector2i:
	return WorldGen.room_id(seed, at)

func room_path_metrics(route: DescentRoute, record: Dictionary) -> Dictionary:
	var path := route.path_from_origin()
	var at: Vector2i = record["cell"]
	var other: Vector2i = at + WorldGen.DIRV[DescentTopology.edge_dir(record)]
	var approach: Vector2i = record["approach_cell"]
	var tape_rooms := {}
	for tape in route.optional_vhs_cells():
		tape_rooms[room(route.world_seed, tape)] = true
	var changes := 0
	var before_tapes := true
	var previous := room(route.world_seed, route.origin)
	for idx in path.size():
		var current := room(route.world_seed, path[idx])
		if current != previous:
			changes += 1
			previous = current
		if tape_rooms.has(current):
			before_tapes = false
		if current == room(route.world_seed, approach) and maxi(absi(path[idx].x - approach.x), absi(path[idx].y - approach.y)) <= 1:
			return {"idx": idx, "changes": changes, "before_tapes": before_tapes, "at": at, "other": other}
	return {"idx": -1, "changes": 999, "before_tapes": false, "at": at, "other": other}

func room_distances(route: DescentRoute, topology: DescentTopology) -> Dictionary:
	var graph := {}
	for at in route.scanned_cells():
		var owner := room(route.world_seed, at)
		if not graph.has(owner):
			graph[owner] = {}
		for dir in 4:
			var other: Vector2i = at + WorldGen.DIRV[dir]
			if route.scanned_contains(other) and not topology.is_wall(at, dir):
				var next := room(route.world_seed, other)
				if next != owner:
					graph[owner][next] = true
	var target := room(route.world_seed, route.target)
	var distances := {target: 0}
	var queue: Array[Vector2i] = [target]
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		for next in graph.get(current, {}):
			if not distances.has(next):
				distances[next] = int(distances[current]) + 1
				queue.append(next)
	return distances

func build_topology(seed: int) -> Dictionary:
	var route := DescentRoute.build(seed, 0, 0)
	var topology := DescentTopology.new(seed, 0)
	route.set_topology(topology)
	topology.plan_floor(route)
	return {"route": route, "topology": topology}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var all_attempts := 0
	var fallback_count := 0
	var count := REQUESTS.size()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		count = clampi(int(args[0]), 1, REQUESTS.size())
	for requested in REQUESTS.slice(0, count):
		var started := Time.get_ticks_msec()
		var selected := FirstDoorStart.select_seed(requested)
		all_attempts += FirstDoorStart.last_attempts
		if FirstDoorStart.last_used_fallback:
			fallback_count += 1
		expect(selected > 0, "requested %d selected invalid seed %d" % [requested, selected])
		var data := build_topology(selected)
		var route: DescentRoute = data["route"]
		var topology: DescentTopology = data["topology"]
		var record := topology.intro_photo_door()
		expect(not route.intro_door_hint.is_empty(), "selected %d has no route intro hint" % selected)
		expect(not record.is_empty(), "selected %d has no planned intro door" % selected)
		if not record.is_empty():
			var at: Vector2i = record["cell"]
			var other: Vector2i = at + WorldGen.DIRV[DescentTopology.edge_dir(record)]
			var before := room_distances(route, topology)
			var approach: Vector2i = record["approach_cell"]
			expect(topology.open_photo_door(str(record["id"])), "intro doorway refused opening")
			var after := room_distances(route, topology)
			var savings := int(before[room(selected, approach)]) - int(after[room(selected, approach)])
			expect(savings >= DescentTopology.PHOTO_DOOR_MIN_SAVING, "selected %d intro saving %d < %d" % [selected, savings, DescentTopology.PHOTO_DOOR_MIN_SAVING])
			var metrics := room_path_metrics(route, record)
			expect(int(metrics["idx"]) >= 0 and int(metrics["idx"]) <= DescentTopology.INTRO_DOOR_MAX_PATH_STEPS, "selected %d encounter index %s" % [selected, str(metrics["idx"])])
			expect(int(metrics["changes"]) > 0 and int(metrics["changes"]) <= DescentTopology.INTRO_DOOR_MAX_ROOM_STEPS, "selected %d room changes %s" % [selected, str(metrics["changes"])])
			expect(bool(metrics["before_tapes"]), "selected %d intro occurs after tape room" % selected)
			for landmark in route.casino_landmarks:
				expect(room(selected, landmark) != room(selected, at) and room(selected, landmark) != room(selected, other), "selected %d landmark in intro room" % selected)
			var plan := PhotoDirector.build_plan(route)
			# Use the live graph after opening, not the production hypothetical
			# path helper, to prove the shortcut does not strand the photo quota.
			route.refresh_topology()
			var opened_rooms := {}
			for cell in route.path_from_origin():
				opened_rooms[room(selected, cell)] = true
			var available := 1
			for cell in plan:
				if opened_rooms.has(room(selected, cell)):
					available += 1
			expect(available >= PhotoDirector.required_for(0, 0), "shortcut bypasses evidence quota")
			for cell in plan:
				expect(room(selected, cell) != room(selected, at) and room(selected, cell) != room(selected, other), "selected %d evidence in intro room" % selected)
			reports.append("requested=%d selected=%d attempts=%d idx=%d rooms=%d saving=%d elapsed_ms=%d" % [requested, selected, FirstDoorStart.last_attempts, int(metrics["idx"]), int(metrics["changes"]), savings, Time.get_ticks_msec() - started])
		var repeat := FirstDoorStart.select_seed(requested)
		expect(repeat == selected, "requested %d repeat %d != %d" % [requested, repeat, selected])
		if REQUESTS.find(requested) < 3:
			var excluded := FirstDoorStart.select_seed(requested, selected)
			expect(excluded > 0 and excluded != selected, "requested %d exclusion returned %d" % [requested, excluded])
	# At least two separately validated emergency seeds keep exclusion safe.
	var valid_fallbacks := 0
	for seed in FirstDoorStart.FALLBACK_SEEDS:
		if FirstDoorStart.accepts(seed):
			valid_fallbacks += 1
	expect(valid_fallbacks >= 2, "bounded-search fallback cannot survive a same-seed exclusion")
	for report in reports:
		print(report)
	print("PROBE requests=%d total_first_pass_attempts=%d fallback=%d failures=%d" % [count, all_attempts, fallback_count, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)
