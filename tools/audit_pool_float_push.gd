extends SceneTree

## Verify generated floats are surface-locked rigid bodies and a walking
## player can move the flamingo, mattress, and striped float by colliding.

const PoolBuilder = preload("res://scripts/levels/pool_level_builder.gd")
const WaterInteraction = preload("res://scripts/pool_water_interaction.gd")

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ws := WorldGen.level_seed(240721, 9)
	var chunk := Chunk.new(ws, Vector2i(-2, 2), 9)
	get_root().add_child(chunk)
	var float_body: RigidBody3D
	for node in chunk.find_children("*", "RigidBody3D", true, false):
		if node.has_meta("pool_flamingo_float"):
			float_body = node
			break
	if float_body == null:
		push_error("POOL_FLOAT_PUSH: no flamingo rigid body generated")
		quit(1)
		return
	if not float_body.is_in_group("pool_pushable_floats") \
			or not float_body.axis_lock_linear_y \
			or not float_body.axis_lock_angular_x \
			or not float_body.axis_lock_angular_z:
		push_error("POOL_FLOAT_PUSH: float physics configuration incomplete")
		quit(1)
		return
	if not await _wake_probe(float_body):
		quit(1)
		return
	if not await _push_probe(float_body, 2.65, "flamingo"):
		quit(1)
		return
	chunk.free()
	var mattress_chunk := Chunk.new(ws, Vector2i(-1, 3), 9)
	get_root().add_child(mattress_chunk)
	var mattress: RigidBody3D
	for node in mattress_chunk.find_children("*", "RigidBody3D", true, false):
		if node.has_meta("pool_mattress_float"):
			mattress = node
			break
	if mattress == null:
		push_error("POOL_FLOAT_PUSH: no colored mattress generated")
		quit(1)
		return
	var collider := mattress.find_child("*", true, false) \
		as CollisionShape3D
	if collider == null or not collider.shape is BoxShape3D \
			or PoolBuilder.POOL_MATTRESS_TINTS.size() < 8:
		push_error("POOL_FLOAT_PUSH: mattress shape or color palette missing")
		quit(1)
		return
	var tinted := 0
	for node in mattress.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.get_surface_override_material(0) != null:
			tinted += 1
	if tinted < 2:
		push_error("POOL_FLOAT_PUSH: mattress vinyl materials were not tinted")
		quit(1)
		return
	if not _draft_probe(mattress, "mattress"):
		quit(1)
		return
	if not await _push_probe(mattress, 2.2, "mattress"):
		quit(1)
		return
	mattress_chunk.free()
	var striped_chunk := Chunk.new(ws, Vector2i(-1, 2), 9)
	get_root().add_child(striped_chunk)
	var striped: RigidBody3D
	for node in striped_chunk.find_children("*", "RigidBody3D", true, false):
		if node.has_meta("pool_striped_float"):
			striped = node
			break
	if striped == null or PoolBuilder.POOL_STRIPED_PAIRS.size() < 8:
		push_error("POOL_FLOAT_PUSH: striped float or color pairs missing")
		quit(1)
		return
	var vinyl_found := false
	var welds := 0
	for node in striped.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var material := mesh_instance.get_surface_override_material(0)
		if material is ShaderMaterial:
			vinyl_found = material.get_shader_parameter("light_color") != null \
				and material.get_shader_parameter("dark_color") != null
		elif material is StandardMaterial3D:
			welds += 1
	if not vinyl_found or welds < 2:
		push_error("POOL_FLOAT_PUSH: striped panel or weld recolor missing")
		quit(1)
		return
	if not _draft_probe(striped, "striped"):
		quit(1)
		return
	if not await _push_probe(striped, 1.8, "striped"):
		quit(1)
		return
	striped_chunk.free()
	var ring_chunk := Chunk.new(ws, Vector2i(-2, 3), 9)
	get_root().add_child(ring_chunk)
	var ring: RigidBody3D
	for node in ring_chunk.find_children("*", "RigidBody3D", true, false):
		if node.has_meta("pool_ring_float") \
				and node.is_in_group("pool_pushable_floats"):
			ring = node
			break
	if ring == null:
		push_error("POOL_FLOAT_PUSH: grand pool ring is not pushable")
		quit(1)
		return
	var ring_collider := ring.find_child("*", true, false) as CollisionShape3D
	if ring_collider == null or absf(ring_collider.position.y) > 0.01 \
			or not _draft_probe(ring, "ring"):
		push_error("POOL_FLOAT_PUSH: ring collider or draft is wrong")
		quit(1)
		return
	if not await _push_probe(ring, 1.6, "ring"):
		quit(1)
		return
	ring_chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("POOL_FLOAT_PUSH PASS")
	quit()


func _push_probe(body: RigidBody3D, start_distance: float,
		label: String) -> bool:
	var player := Player.new()
	player.level_theme = 9
	player.water_y = Chunk.POOL_WATER_Y
	get_root().add_child(player)
	player.set_physics_process(false)
	player.global_position = body.global_position \
		- Vector3(start_distance, body.global_position.y, 0)
	var initial := body.global_position
	for i in 150:
		await physics_frame
		player.velocity = Vector3(1.8, 0.0, 0.0)
		player.move_and_slide()
		player._push_pool_floats(Vector3(1.8, 0.0, 0.0))
	var moved := body.global_position.distance_to(initial)
	print("POOL_FLOAT_PUSH %s moved=%.3f m float_y=%.3f" % [
		label, moved, body.global_position.y])
	player.free()
	if moved < 0.35 or absf(body.global_position.y - initial.y) > 0.02:
		push_error("POOL_FLOAT_PUSH: %s did not stay afloat and move" % label)
		return false
	return true


func _draft_probe(body: RigidBody3D, label: String) -> bool:
	var low := INF
	var high := -INF
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var bounds := mesh.mesh.get_aabb()
		for i in 8:
			var y := mesh.to_global(bounds.get_endpoint(i)).y
			low = minf(low, y)
			high = maxf(high, y)
	print("POOL_FLOAT_PUSH %s draft=%.3f m freeboard=%.3f m" % [
		label, Chunk.POOL_WATER_Y - low, high - Chunk.POOL_WATER_Y])
	if low == INF or low < Chunk.POOL_WATER_Y - 0.10 \
			or low > Chunk.POOL_WATER_Y - 0.005 \
			or high < Chunk.POOL_WATER_Y + 0.12:
		push_error("POOL_FLOAT_PUSH: %s is floating at the wrong depth" % label)
		return false
	return true


func _wake_probe(body: RigidBody3D) -> bool:
	var visual := body.get_node_or_null("FloatVisual") as Node3D
	if visual == null:
		push_error("POOL_FLOAT_PUSH: missing bobbing visual")
		return false
	var low := INF
	var high := -INF
	for i in 90:
		await physics_frame
		low = minf(low, visual.position.y)
		high = maxf(high, visual.position.y)
	if high - low < 0.005:
		push_error("POOL_FLOAT_PUSH: ambient float bob is motionless")
		return false
	var fx := WaterInteraction.new()
	get_root().add_child(fx)
	fx._add_event(body.global_position + Vector3(-0.45, 0.17, 0.0),
		1.0, Vector2.RIGHT, 1.0)
	var wake_peak := 0.0
	for i in 45:
		await physics_frame
		wake_peak = maxf(wake_peak, (visual.get("_wake_roll") as Vector2).length())
	fx.free()
	print("POOL_FLOAT_PUSH bob=%.3f m wake=%.3f" % [high - low, wake_peak])
	if wake_peak < 0.015:
		push_error("POOL_FLOAT_PUSH: float does not react to a passing water wake")
		return false
	return true
