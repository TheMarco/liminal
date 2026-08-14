extends SceneTree
## Regression for the reported hallway that stayed dark after global power
## returned. Post-blackout secondary beats may no longer request dead lights,
## and a waiting figure unsuitable for a corridor must decline rather than
## silently falling back to killing every fixture.

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	failures += 1


func _light_state(chunk: Chunk) -> Dictionary:
	var state := {}
	for node in chunk.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		state[light] = [light.visible, light.light_energy]
	return state


func _same_light_state(before: Dictionary) -> bool:
	for value in before:
		var light := value as Light3D
		if not is_instance_valid(light):
			return false
		var state: Array = before[value]
		if light.visible != bool(state[0]) \
				or not is_equal_approx(light.light_energy, float(state[1])):
			return false
	return true


func _run() -> void:
	var player := Player.new()
	root.add_child(player)
	await process_frame

	# A working chunk must restore every fixture to its exact pre-blackout state.
	var working := Chunk.new(405195947, Vector2i(3, 3), 0, {
		"descent": true,
		"player": player,
	})
	var working_before := _light_state(working)
	if working_before.is_empty():
		_fail("blackout lighting fixture generated no lights")
	working.set_blackout(true)
	working.set_blackout(false)
	if not _same_light_state(working_before):
		_fail("global blackout did not restore exact working-light state")

	# Find an actual narrow corridor and prove the optional waiting-figure beat
	# declines there without using the old dead-light fallback.
	var corridor := Vector2i(1 << 20, 1 << 20)
	for x in range(-12, 13):
		for y in range(-12, 13):
			var candidate := Vector2i(x, y)
			if WorldGen.corridor(405195947, candidate) != 0:
				corridor = candidate
				break
		if corridor.x < (1 << 19):
			break
	if corridor.x >= (1 << 19):
		_fail("could not find a narrow hallway fixture")
	else:
		var hallway := Chunk.new(405195947, corridor, 0, {
			"descent": true,
			"player": player,
		})
		var hallway_before := _light_state(hallway)
		hallway.activate_anomaly(1)
		if hallway.anomaly_kind != -1:
			_fail("unsuitable hallway did not decline waiting-figure anomaly")
		if not _same_light_state(hallway_before):
			_fail("declined hallway figure killed the corridor lights")
		hallway.free()

	# Repeated post-blackout selection may emit nothing or a waiting figure,
	# but never the removed kind-0 dead-light mutation.
	var run := DescentRun.new()
	run.player = player
	run.target_cell = Vector2i(100, 100)
	run._cell = Vector2i(5, 5)
	for cell in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4)]:
		run.visited[cell] = true
	var requested: Array[int] = []
	run.anomaly_requested.connect(func(_cell: Vector2i, kind: int):
		requested.append(kind))
	run._rng.seed = 8831
	for i in 80:
		run.anomalies.clear()
		run._post_blackout_changes()
	if requested.is_empty():
		_fail("post-blackout anomaly fixture never exercised its optional branch")
	for kind in requested:
		if kind != 1:
			_fail("post-blackout restoration still requested a dead-light anomaly")
			break

	run.free()
	working.free()
	player.queue_free()
	if failures == 0:
		print("blackout lighting audit pass")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(1 if failures > 0 else 0)
