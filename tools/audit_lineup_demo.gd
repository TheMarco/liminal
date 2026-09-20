extends SceneTree
## The monster lineup demo stages every roster model as a passive figure in a
## spread ring over a real floor, so the flashlight can burn them one by one.
## Guards two regressions: probes dipping below the floor reject every slot
## and pile the ring onto the fallback (all ten died to one beam), and ring
## geometry that keeps singles unburnable even walked up close. A beam from
## the spawn point legitimately shares side pairs and near/far sightlines
## under the game's wide burn cone; only the closeup singles are asserted.
## Run: godot --headless --path . --script tools/audit_lineup_demo.gd

const MonsterLineupScene := preload("res://scripts/monster_lineup.gd")

const MIN_PAIRWISE := 1.5
const CLOSEUP_RANGE := 2.5

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40.0, 1.0, 40.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var player := Player.new()
	player.world_seed = 7
	player.level_theme = 1
	player.cam = Camera3D.new()
	player.cam.position = Vector3(0.0, 1.5, 0.0)
	player.add_child(player.cam)
	player.flashlight = SpotLight3D.new()
	player.flashlight.spot_range = 21.0
	player.add_child(player.flashlight)
	root.add_child(player)
	var ring := MonsterLineupScene.new()
	root.add_child(ring)
	ring.configure(Vector3(0.0, 0.0, 8.5), Vector3(0.0, 1.5, 0.0), player)
	for frame in 8:
		await physics_frame
	var figs := ring._figs
	_expect(figs.size() == ShadowWalkerVisual.model_count(),
		"lineup staged %d of %d monsters" % [
			figs.size(), ShadowWalkerVisual.model_count()])
	_check_spacing(figs)
	_check_beam_isolation(player, figs)
	floor_body.free()
	player.free()
	ring.free()
	if failures.is_empty():
		print("PASS lineup_demo")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL lineup_demo")
		quit(1)


func _check_spacing(figs: Array) -> void:
	var worst := INF
	for i in figs.size():
		for j in range(i + 1, figs.size()):
			var a: Vector3 = figs[i].global_position
			var b: Vector3 = figs[j].global_position
			var flat := Vector2(a.x - b.x, a.z - b.z).length()
			worst = minf(worst, flat)
	_expect(worst >= MIN_PAIRWISE,
		"lineup monsters piled up: closest pair %.2fm" % worst)


func _check_beam_isolation(player: Player, figs: Array) -> void:
	var cam := player.cam
	var centre := Vector3.ZERO
	for fig in figs:
		centre += fig.global_position
	centre /= float(figs.size())
	for target in figs:
		var inward: Vector3 = centre - target.global_position
		inward.y = 0.0
		cam.position = target.global_position \
			+ inward.normalized() * CLOSEUP_RANGE + Vector3(0.0, 1.5, 0.0)
		cam.look_at(target.global_position + Vector3(0.0, 1.2, 0.0))
		var caught := 0
		for fig in figs:
			var eye: Vector3 = fig.global_position + Vector3(0.0, fig._eye_h, 0.0)
			var sighted: bool = fig._clear_line(cam.global_position, eye)
			if fig._in_beam(cam, fig._beam_aim(cam), sighted):
				caught += 1
		_expect(caught == 1,
			"closeup beam on one lineup monster catches %d" % caught)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
