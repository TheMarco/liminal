extends SceneTree
## Regression for the reported hallway that stayed dark after global power
## returned. Post-blackout secondary beats may no longer request dead lights,
## and hostile encounter requests must never be baked into streamed chunks or
## silently fall back to killing every fixture.

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

	# Prove encounter requests are declined by streamed geometry without using
	# the old dead-light fallback. Main hands these to the hostile manager.
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
			_fail("streamed hallway accepted a live encounter as room geometry")
		if not _same_light_state(hallway_before):
			_fail("declined hallway figure killed the corridor lights")
		hallway.free()

	# Repeated post-blackout selection may emit nothing or a hostile encounter,
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
	# Walking away used a separate legacy path; the post-blackout check above
	# did not cover it. Repeat at different cells without changing its rolls.
	requested.clear()
	run.anomalies.clear()
	run.world_seed = 1021555651
	run.floor_idx = 2
	for x in range(14, 26):
		for y in range(45, 62):
			run._maybe_anomaly(Vector2i(x, y))
	if requested.is_empty(): _fail("walk-away fixture did not exercise encounter selection")
	for kind in requested:
		if kind != 1:
			_fail("walking away still requested a permanent dark chunk")
			break
	# Legacy state must not darken Office tiles or lights, even across a
	# genuine blackout. Compare exact material identities, not just energy.
	var office := Chunk.new(677189935, Vector2i(18, 46), 1, {"anomaly": 0})
	var office_before := _light_state(office)
	var surfaces := {}
	for mesh: MeshInstance3D in office.find_children("*", "MeshInstance3D", true, false):
		surfaces[mesh] = mesh.material_override
	office.activate_anomaly(0)
	office.set_blackout(true)
	office.set_blackout(false)
	if office.anomaly_kind != -1 or not _same_light_state(office_before):
		_fail("legacy Office dead-light state survived blackout restoration")
	for mesh in surfaces:
		if mesh.material_override != surfaces[mesh]:
			_fail("Office ceiling or fixture material failed to restore")
			break
	office.free()
	run.free()
	working.free()
	player.queue_free()
	if failures == 0:
		print("blackout lighting audit pass")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(1 if failures > 0 else 0)
