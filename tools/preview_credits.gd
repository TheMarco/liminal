extends Node2D
## Dev: render any title page straight to a PNG for overflow and hierarchy QA.
##
## Run: godot --path . tools/preview_credits.tscn -- \
##   --screenshot=/tmp/c.png --page=credits


func _ready() -> void:
	var shot := "/tmp/liminal-credits.png"
	var panel := "_show_credits"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			shot = arg.substr(13)
		elif arg == "--rules":
			panel = "_show_descent_rules"
		elif arg.begins_with("--page="):
			match arg.substr(7):
				"main":
					panel = ""
				"instructions":
					panel = "_show_instructions"
				"about":
					panel = "_show_about"
				"credits":
					panel = "_show_credits"
				"rules", "descent":
					panel = "_show_descent_rules"
	# The credits panel is transparent; give it the title screen's own ground so
	# the contrast in the capture matches what a player actually sees.
	var bg := ColorRect.new()
	bg.color = Color8(2, 2, 2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := TitleScreen.new()
	add_child(title)
	if not panel.is_empty():
		title.call(panel)
	print("preview panel: %s" % panel)
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(shot)
	print("title page -> %s" % shot)
	get_tree().quit()
