extends "res://tools/capture_steam_screenshots.gd"
## Website action stills, using the real production scenes, actors, VHS, and HUD.
## The game's supported full-resolution world rendering keeps details legible.
## Always run with --test-mode so player saves and albums remain isolated.

func setup_room() -> void:
	view.scaling_3d_scale = 1.0
	await super.setup_room()

func take_still(frame: int) -> void:
	super.take_still(frame)
	records[-1]["world_render_scale"] = view.scaling_3d_scale
