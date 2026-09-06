extends SceneTree
## Deterministic contract audit for player-owned pool water interaction.

const Controller := preload("res://scripts/pool_water_interaction.gd")
const DRY := -1.0e8
var failures: Array[String] = []
var world: Node3D
var water: MeshInstance3D
var spa: MeshInstance3D
var fx: Controller

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func stop_processing() -> void:
	fx.set_process(false)

func _init() -> void:
	call_deferred("run")

func plane(size: Vector2, at: Vector3, angle := 0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := PlaneMesh.new(); mesh.size = size
	n.mesh = mesh; n.position = at; n.rotation.y = angle
	n.material_override = Mats.pool_water(); n.add_to_group("pool_water_surfaces")
	world.add_child(n)
	return n

func run() -> void:
	world = Node3D.new(); world.name = "audit_world"; root.add_child(world)
	water = plane(Vector2(4, 4), Vector3(0, 1, 0))
	spa = plane(Vector2(2, 3), Vector3(5, 2, 0), PI * 0.31)
	fx = Controller.new(); world.add_child(fx)
	await physics_frame
	check(is_equal_approx(fx.surface_height(Vector3(0, 1, 0)), 1.0), "footprint height mismatch")
	check(fx.surface_height(Vector3(3, 1, 0)) < DRY, "outside footprint is wet")
	var spa_point := spa.to_global(Vector3(0.4, 0, 0.5))
	check(is_equal_approx(fx.surface_height(spa_point), 2.0), "rotated elevated spa height mismatch")
	var island := StaticBody3D.new(); var shape := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.2, 0.6); shape.shape = box; island.position = Vector3(0, 1, 0); island.add_child(shape); world.add_child(island)
	await physics_frame
	check(fx.surface_height(Vector3(0, 1, 0)) < DRY, "solid island was not rejected")
	island.free(); await physics_frame
	check(fx.surface_height(Vector3(0, 1, 0)) > DRY, "surface did not recover after island removal")
	var base := water.material_override
	fx.sample_motion(0.1, Vector3(0, 0.8, 0), Vector2.ZERO, 0, 1); stop_processing(); fx.advance(0.1)
	check(fx.events.is_empty(), "spawned wet at rest produced entry")
	fx.reset(); fx.sample_motion(0.1, Vector3(0, 1.2, 0), Vector2.ZERO, 0, 1)
	fx.sample_motion(0.1, Vector3(0, 0.8, 0), Vector2.ZERO, -3, 1); stop_processing()
	check(fx.events.size() == 1, "falling entry was not recorded")
	if not fx.events.is_empty(): check(fx.events[0]["kind"] == 0.0, "entry event kind mismatch")
	check(fx._spray != null and fx._spray.multimesh.instance_count == Controller.MAX_DROPS, "drop capacity mismatch")
	check(fx._sheets.size() == Controller.MAX_SHEETS, "sheet capacity mismatch")
	fx.surface_height(Vector3(0, 0.8, 0))
	var before: int = fx.events.size()
	for i in 8:
		fx.sample_motion(0.1, Vector3(float(i) * 0.2, 0.8, 0), Vector2(1, 0), 0, 1); stop_processing()
	check(fx.events.size() > before, "wading did not produce steps")
	var stationary: int = fx.events.size()
	for i in 10: fx.sample_motion(0.1, Vector3(1.4, 0.8, 0), Vector2.ZERO, 0, 1); stop_processing()
	check(fx.events.size() == stationary, "stationary motion produced event")
	fx.advance(0.1)
	check(water.material_override != base, "disturbed material was not privatized")
	check(float((water.material_override as ShaderMaterial).get_shader_parameter("fx_count")) > 0, "disturbed fx_count missing")
	var base_count = (base as ShaderMaterial).get_shader_parameter("fx_count")
	check(base_count == null or is_zero_approx(float(base_count)), "shared base fx_count changed")
	fx.reset(); check(water.material_override == base, "reset did not restore shared material")
	fx.sample_motion(0.1, Vector3(0, 0, 0), Vector2.ZERO, 0, DRY); fx.sample_motion(0.1, Vector3(50, 0, 0), Vector2.ZERO, 0, DRY)
	stop_processing()
	check(fx.events.is_empty(), "teleport correction created wake")
	fx.surface_height(Vector3(0, 0.8, 0)); fx.sample_motion(0.1, Vector3(0, 0.8, 0), Vector2.ZERO, 0, 1); stop_processing()
	for i in 40:
		fx.sample_motion(0.3, Vector3(float(i) * 0.5, 0.8, 0), Vector2(1, 0), 0, 1); stop_processing()
		fx.advance(0.01); stop_processing()
	check(fx.events.size() == Controller.MAX_EVENTS, "event ring did not reach maximum")
	check(is_equal_approx(float(fx.events.back()["at"].x), 19.5), "last event was not retained")
	# Decay must restore a real disturbed surface and disable itself without
	# the test calling reset/set_process(false) to manufacture that outcome.
	fx.reset()
	fx.surface_height(Vector3.ZERO)
	fx.sample_motion(0.1, Vector3(0, 1.2, 0), Vector2.ZERO, 0, 1)
	fx.sample_motion(0.1, Vector3(0, 0.8, 0), Vector2.ZERO, -3, 1)
	fx.advance(0.1)
	check(water.material_override != base, "decay fixture was not disturbed")
	fx.advance(Controller.EVENT_LIFE + 0.1)
	check(water.material_override == base and fx.events.is_empty(), "natural decay did not restore water")
	check(not fx.is_processing(), "natural idle did not disable processing")
	fx.reset()
	fx.surface_height(Vector3.ZERO)
	fx.sample_motion(0.1, Vector3(0, 1.2, 0), Vector2.ZERO, 0, 1)
	fx.sample_motion(0.1, Vector3(0, 0.8, 0), Vector2.ZERO, -3, 1)
	fx.advance(0.1)
	stop_processing()
	check(water.material_override != base, "stream-out fixture was not disturbed")
	water.free(); await process_frame; fx.advance(0.1)
	check(fx.events.size() == 1, "freed disturbed surface altered events")
	fx.reset(); fx.advance(Controller.EVENT_LIFE + 0.1)
	check(water == null or not is_instance_valid(water), "freed surface remains valid")
	check(not fx.is_processing(), "idle effects did not stop")
	# Exercise the real Player's typed query, teleport and floor-change hooks.
	var player := Player.new()
	player.position = Vector3(5, 2.2, 0)
	player.water_y = 1.05
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	check(is_equal_approx(player._water_surface_here(), 2.0), "Player did not use the raised spa water line")
	var player_fx := player._water_fx
	player_fx.sample_motion(0.1, Vector3(5, 2.2, 0), Vector2.ZERO, 0, 2)
	player_fx.sample_motion(0.1, Vector3(5, 1.8, 0), Vector2.ZERO, -3, 2)
	player_fx.advance(0.1)
	player_fx.set_process(false)
	check(not player_fx.events.is_empty(), "Player teleport fixture lacks a splash")
	player.teleport(Vector3(5, 1.8, 0))
	check(player_fx.events.is_empty() and not player_fx._initialized, "Player teleport retained disturbances/contact history")
	check(not player._water_audio_primed, "Player teleport retained water audio history")
	player.water_y = -1.0e9
	check(player._water_surface_here() < DRY and player._water_fx == null, "Player retained pool effects on a dry floor")
	await process_frame
	world.free(); await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures: print("FAIL " + failure)
	if failures.is_empty(): print("PASS pool water interaction audit")
	else: quit(1); return
	quit()
