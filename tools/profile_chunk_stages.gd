extends SceneTree
## Focused CPU-stage profiler for a single generated chunk.
## Usage: godot --headless --path . --script tools/profile_chunk_stages.gd --
##            --theme=11 --x=-2 --y=0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var theme := 11
	var x := -2
	var y := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="):
			theme = int(arg.trim_prefix("--theme="))
		elif arg.begins_with("--x="):
			x = int(arg.trim_prefix("--x="))
		elif arg.begins_with("--y="):
			y = int(arg.trim_prefix("--y="))
	Chunk.request_prop_preloads()
	await create_timer(2.0).timeout
	var ws := WorldGen.level_seed(240721, theme)
	var warm := Chunk.new(ws, Vector2i.ZERO, theme)
	warm.free()
	Chunk.profile_build_stages = true
	var chunk := Chunk.new(ws, Vector2i(x, y), theme)
	Chunk.profile_build_stages = false
	chunk.free()
	Chunk.clear_runtime_caches()
	quit()
