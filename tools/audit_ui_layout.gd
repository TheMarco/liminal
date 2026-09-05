extends SceneTree
## Regression for clipped saved-run actions and unscaled replay controls.
## godot --headless --path . --log-file /tmp/liminal-ui-layout.log \
##   --script tools/audit_ui_layout.gd
var failures := 0

func _init() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)

func settle() -> void:
	for i in 6:
		await process_frame

func contained(control: Control, bounds: Rect2, label: String) -> void:
	expect(bounds.grow(1.0).encloses(control.get_global_rect()),
		"%s: %s outside %s" % [label, control.get_global_rect(), bounds])

func run() -> void:
	var view := SubViewport.new()
	root.add_child(view)
	var title := TitleScreen.new()
	title.configure_descent_progress(true, 6, "the asylum")
	view.add_child(title)
	var summary := DescentSummary.new()
	summary.floor_display = "THE DATA CENTER"
	view.add_child(summary)
	var intro := DescentIntro.new(true)
	view.add_child(intro)
	intro._video.stop()
	var buttons: Array[Node] = title._pages[TitleScreen.Page.MAIN].find_children("*", "Button", true, false)
	expect(buttons.size() == 7, "Saved title lost an action")
	for size in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(1024,768),
			Vector2i(720,1280), Vector2i(3840,2160), Vector2i(1280,720)]:
		view.size = size
		await settle()
		var safe := VhsOsd.safe_inset(Vector2(size))
		var bounds := Rect2(safe, Vector2(size) - safe * 2.0)
		for button in buttons:
			contained(button, bounds, "%s %s" % [size, button.text])
		for entry in summary._labels:
			contained(entry[0], bounds, "%s summary" % size)
		contained(intro._skip_button, bounds, "%s skip" % size)
		expect(intro._skip_button.get_theme_font_size("font_size") ==
			roundi(22.0 * VhsOsd.hud_scale(Vector2(size))), "Skip font lost its scale")
		for i in buttons.size():
			for j in range(i + 1, buttons.size()):
				expect(not buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()),
					"Saved title buttons overlap")
	view.free()
	await process_frame
	print("UI layout: %s (six live resize states, seven saved-run actions)" %
		("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
