extends SceneTree
## Prints imported AnimationPlayer libraries, clips, lengths and track paths.
## Run: godot --headless --path . --script tools/dump_animations.gd -- <res://path>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass a res:// scene path.")
		quit(1)
		return
	var scene := load(args[0]) as PackedScene
	if scene == null:
		push_error("Could not load %s" % args[0])
		quit(1)
		return
	var root := scene.instantiate()
	for found in root.find_children("*", "AnimationPlayer", true, false):
		var player := found as AnimationPlayer
		print("AnimationPlayer %s" % player.name)
		for clip_name in player.get_animation_list():
			var clip := player.get_animation(clip_name)
			print("  %s length=%.3f loop=%s tracks=%d" % [
				clip_name, clip.length, clip.loop_mode, clip.get_track_count()])
			for track in clip.get_track_count():
				print("    %s  %s" % [
					clip.track_get_path(track), clip.track_get_type(track)])
	root.free()
	quit()
