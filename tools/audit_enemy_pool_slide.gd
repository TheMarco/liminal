extends SceneTree
## Automatic enemy boarding and riding on authored pool slides.

const DT := 1.0 / 60.0
var failures: Array[String] = []

class TestWalker extends ShadowWalkerVisual:
	func _ready() -> void: pass

class Pursuer extends ShadowFigure:
	func _create_walker_visual() -> void:
		_walker = TestWalker.new()
		add_child(_walker)
	func _build_presence() -> void: pass
	func _seize() -> void: pass
	func _edge_info(_cell: Vector2i, _dir: int) -> Dictionary:
		return {"wall": false, "t": 6.0, "full_open": true}

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("FAIL — ", message)

func make_chunk() -> Chunk:
	var chunk := Chunk.new(1029384756, Vector2i.ZERO, 9)
	root.add_child(chunk)
	for child in chunk.get_children():
		if child != chunk.body: child.free()
	for child in chunk.body.get_children(): child.free()
	chunk._scene_writer.box(Vector3(0, 1.32, -5), Vector3(20, .2, 10), Mats.pool_tile())
	chunk._scene_writer.box(Vector3(0, -.1, 5), Vector3(20, .2, 10), Mats.pool_tile())
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 10)
	water.mesh = plane
	water.position = Vector3(0, 1.05, 5)
	water.material_override = Mats.pool_water()
	water.add_to_group("pool_water_surfaces")
	chunk.add_child(water)
	return chunk

func actor(parent: Node, player: Player, at: Vector3) -> Pursuer:
	var f := Pursuer.new()
	f.player = player
	f.position = at
	f.grace = 0.0
	parent.add_child(f)
	f.set_physics_process(false)
	return f

func _case(kind: int, yaw: float) -> void:
	var chunk := make_chunk()
	chunk.rotation.y = yaw
	var prop := PoolEquipment.build(chunk._scene_writer, kind, Vector3(0, 1.42, 0), 0)
	var slide := prop.get_node("SlideRide") as PoolSlide
	check(slide != null, "pool equipment kind %d missing SlideRide" % kind)
	if slide == null:
		chunk.free()
		return
	var tangent := slide.tangent_at(slide.length)
	var player := Player.new()
	player.level_theme = 9
	player.water_y = 1.05
	player.flashlight.visible = true
	player.position = slide.point_at(slide.length) + tangent * 0.4
	player.position.y = 0.0
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	var f := actor(root, player, slide.point_at(0.0) + Vector3.UP * PoolSlide.FOOT_CLEARANCE)
	await physics_frame
	var boarded := 0
	var ride_ticks := 0
	var max_step := 0.0
	for i in 1200:
		var before := f.global_position
		f._advance(DT, false)
		max_step = maxf(max_step, before.distance_to(f.global_position))
		if f._pool_slide != null:
			boarded += 1
		if f.global_position.y < 0.15 and f._pool_slide == null:
			break
		ride_ticks = i + 1
	check(boarded >= 10, "kind %d yaw %.2f never boarded slide" % [kind, yaw])
	check(max_step <= PoolSlide.MAX_SPEED / 60.0 + 0.001,
		"kind %d yaw %.2f exceeded slide speed: %.4f" % [kind, yaw, max_step])
	check(f.global_position.y < 0.15 and f._pool_slide == null,
		"kind %d yaw %.2f failed to clear slide into basin: %s" % [kind, yaw, f.global_position])
	f.free()
	player.free()
	chunk.free()
	await physics_frame

func _run() -> void:
	for kind in [1, 2]:
		for yaw in [0.0, PI / 2.0]:
			await _case(kind, yaw)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("enemy pool slide audit: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
