extends SceneTree
## Real actor/manager physics: warn once while moving, with optional explicit holds.
const UnitAudit = preload("res://tools/audit_reality_aftershock.gd")
const Effect = preload("res://scripts/reality_aftershock.gd")
const DT := 1.0 / 60.0
var failures: Array[String] = []
var world: Node3D
var player: Player
var manager: ShadowFigures
var effect: CanvasLayer

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _init() -> void:
	call_deferred("run")

func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func actor(at: Vector3) -> ShadowFigure:
	var f := ShadowFigure.new()
	f.variant = ShadowFigure.DROWNED
	f.player = player
	f.position = at
	f.set_physics_process(false)
	world.add_child(f)
	f.set_physics_process(false)
	f.grace = 0.0
	f._fade = -1.0
	f._seen = true
	f._observed = false
	f._approach_announced = false
	f._approach_hold = 0.0
	f._was_sighted = true
	manager.adopt(f)
	return f

func tick(f: ShadowFigure, frames: int) -> void:
	for i in frames:
		effect._process(DT)
		f._physics_process(DT)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	ground.position.y = -0.5
	ground.add_child(shape)
	world.add_child(ground)
	player = Player.new()
	player.position = Vector3(6, 0, 6)
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.flashlight.visible = false
	manager = ShadowFigures.new()
	manager.player = player
	world.add_child(manager)
	manager.set_physics_process(false)
	var host := UnitAudit.HostStub.new()
	world.add_child(host)
	effect = Effect.new()
	effect.host = host
	world.add_child(effect)
	effect.set_process(false)
	manager.approach_starting.connect(effect.before_approach)
	await physics_frame
	var f := actor(Vector3(6, 0, 0.8))
	player.cam.look_at(f.global_position + Vector3.UP * 1.4)
	await physics_frame
	var start := f.global_position
	f.suppressed = true
	tick(f, 15)
	expect(effect.pulse_count == 0, "suppressed figure warned early")
	f.suppressed = false
	f.grace = 0.5
	tick(f, 10)
	expect(effect.pulse_count == 1, "spawn grace prevented the approach warning")
	expect(flat_distance(start, f.global_position) > 0.01,
		"actor did not move through its arrival warning")
	expect(f._approach_hold == 0.0, "ordinary warning imposed an unwanted movement hold")
	f.grace = 0.0
	# Explicit holds remain supported for callers that need a reaction window.
	f.hold_approach(1.5)
	start = f.global_position
	f._physics_process(DT)
	expect(f._approach_hold > 1.3, "explicit reaction hold was lost")
	expect(flat_distance(start, f.global_position) < 0.0001, "actor moved during explicit hold")
	tick(f, 75)
	expect(not effect.visible, "warning still obscures view at 1.25 seconds")
	expect(flat_distance(start, f.global_position) < 0.0001, "actor moved before clear-view margin")
	tick(f, 60)
	expect(flat_distance(start, f.global_position) > 0.1, "actor did not approach after warning")
	expect(effect.pulse_count == 1, "ordinary chase repeated warning")
	f._was_sighted = false
	tick(f, 45)
	expect(effect.pulse_count == 1, "cover/reveal replayed first-approach warning")
	f.queue_free()
	await physics_frame
	effect.cancel()
	var world_placed := actor(Vector3(18, 0, 6))
	player.cam.look_at(world_placed.global_position + Vector3.UP * 1.4)
	var world_start := world_placed.global_position
	world_placed._physics_process(DT)
	expect(effect.pulse_count == 2, "world-placed figure did not warn immediately")
	expect(world_placed._approach_hold == 0.0, "world-placed warning froze the figure")
	tick(world_placed, 100)
	expect(flat_distance(world_start, world_placed.global_position) > 0.1, "world-placed figure stayed dormant after its warning")
	# Holding approach is not immunity from the torch.
	player.flashlight.visible = true
	var before_burn := world_placed._burn
	tick(world_placed, 12)
	expect(world_placed._burn > before_burn, "warning disabled torch burn")
	player.flashlight.visible = false
	# Also exercise the normal spawn path, rather than relying only on adoption.
	var pulses: int = effect.pulse_count
	manager._force_variant = ShadowFigure.DROWNED
	manager._spawn_at(Vector3(15, 0, 1), false, 0.0)
	var spawned: ShadowFigure = manager._figs[-1]
	spawned.set_physics_process(false)
	spawned._was_sighted = true
	spawned._fade = -1.0
	spawned._seen = true
	spawned._observed = false
	spawned._approach_announced = false
	spawned._approach_hold = 0.0
	var spawned_start := spawned.global_position
	spawned._physics_process(DT)
	expect(effect.pulse_count == pulses + 1, "normal spawned actor missed its warning")
	expect(spawned._approach_hold == 0.0, "normal spawn warning froze the figure")
	tick(spawned, 10)
	expect(flat_distance(spawned_start, spawned.global_position) > 0.01,
		"normal spawned actor did not advance during its warning")
	for tween in get_processed_tweens():
		tween.kill()
	for audio in world.find_children("*", "AudioStreamPlayer3D", true, false):
		audio.stop()
	for audio in world.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
	world.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("REALITY APPROACH: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
