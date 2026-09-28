extends "res://tools/lib/audit_base.gd"
## Main boot regression for the direct doorway preview.
## Run: godot --headless --audio-driver Dummy --path . --script tools/audit_return_preview_start.gd -- --living-preview=return


func run() -> void:
	Engine.max_fps = 60
	var game := await boot_game(20260807)
	expect(game.opts.living_preview == "return",
		"run without --living-preview=return")
	expect(game._architectural_events == null,
		"shared scheduler replaced the direct return preview")
	var door: SelfReturnDoorDirector = game._self_return_door
	expect(door.preview and not door.managed,
		"preview door is waiting for normal architecture cadence")
	var visible := await await_until(func() -> bool:
		return is_instance_valid(door.site), 12000)
	expect(visible, "preview did not stage a doorway after Main boot")
	if visible:
		await process_frame
		var point: Vector3 = door.site.global_position + Vector3.UP * 1.3
		expect(game.player.cam.is_position_in_frustum(point),
			"preview did not face its staged doorway")
	await teardown_game(game)
	finish("return preview starts through the normal Main command")
