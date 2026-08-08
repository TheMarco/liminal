extends SceneTree
## Focused contract test for the station economy and deterministic coverage.

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	failures += 1


func _has_station(root: Node) -> bool:
	if root.has_meta("charging_station"):
		return true
	for child in root.get_children():
		if _has_station(child):
			return true
	return false


func _run() -> void:
	var player := Player.new()
	root.add_child(player)
	await process_frame
	player.set_flashlight(true)
	player._update_flashlight(20.0)
	if player.flashlight_charge() > 0.001:
		_fail("flashlight did not drain in 20 seconds")
	var station := Node3D.new()
	root.add_child(station)
	station.global_position = player.global_position
	if not player.start_charging(station):
		_fail("empty flashlight refused a valid station")
	player._update_flashlight(5.0)
	if absf(player.flashlight_charge() - 0.5) > 0.001:
		_fail("five seconds did not produce half charge")
	# Floor teardown invalidates the old station before the next physics tick.
	# The session must still know its starting value and roll the gain back.
	station.free()
	player._update_flashlight(0.01)
	if player.flashlight_charge() > 0.001 or player.is_charging():
		_fail("destroyed station banked an interrupted partial charge")
	station = Node3D.new()
	root.add_child(station)
	station.global_position = player.global_position
	if not player.start_charging(station):
		_fail("empty flashlight refused a replacement station")
	player._update_flashlight(5.0)
	player._update_flashlight(5.0)
	if absf(player.flashlight_charge() - 1.0) > 0.001:
		_fail("ten seconds did not produce full charge")
	if player.is_charging():
		_fail("connection remained active at full charge")
	player.set_flashlight(true)
	player._update_flashlight(7.0)
	player.velocity = Vector3(1.0, 0.0, 1.0)
	player.reset_descent_resources()
	if player.flashlight.visible or player.flashlight_charge() < 0.999:
		_fail("checkpoint did not restore a full, switched-off flashlight")
	if player.velocity != Vector3.ZERO or player.is_charging():
		_fail("checkpoint did not clear player motion/charging state")
	player.queue_free()
	station.queue_free()

	for theme in WorldGen.THEMES:
		var found := 0
		for x in 3:
			for y in 3:
				var cell := Vector2i(x, y)
				var chunk := Chunk.new(918273, cell, theme)
				if _has_station(chunk):
					found += 1
				chunk.free()
		if found != 1:
			_fail("theme %d macro-cell has %d stations, expected 1" % [theme, found])

	if failures == 0:
		print("flashlight charging audit pass")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(1 if failures > 0 else 0)
