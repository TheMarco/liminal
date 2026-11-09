extends CanvasLayer
## Menus, dialogs and subtitles draw at window resolution, after video effects.
## Gameplay HUDs use a local CanvasLayer so they are part of the recording.
## Keep their existing scene ownership so pausing, input and teardown still work.

func _notification(what: int) -> void:
	if what != NOTIFICATION_PARENTED:
		return
	# Select the destination before CanvasLayer registers with a viewport.
	# Moving it during enter_tree leaves stale canvas-order connections in Godot.
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_meta("ntscrt_video_host"):
			var host: Node = ancestor.get_meta("ntscrt_video_host")
			custom_viewport = host.get_viewport()
			return
		# UI deliberately placed in an offscreen viewport belongs to that image.
		if ancestor is Viewport:
			return
		ancestor = ancestor.get_parent()
