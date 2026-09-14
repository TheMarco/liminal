extends "res://tools/lib/audit_base.gd"
## Album empty/full browsing, pause restoration, capture integration and CLI isolation.
func run() -> void:
	var subject := PhotoAnomaly.new()
	for kind in PhotoAnomaly.Type.values():
		subject.type = kind
		expect(not subject.album_description().is_empty(), "anomaly lacks album description")
	subject.type = PhotoAnomaly.Type.NUMBERED_DOOR
	expect(subject.album_description(false) != subject.album_description(true),
		"numbered door description ignores its photographed state")
	subject.free()
	var game := await boot_game(21)
	game.player.set_physics_process(false)
	game.run.set_process(false)
	if is_instance_valid(game._realm_visit):
		var realm: RealmExcursion = game._realm_visit
		realm.set_process(false)
		expect(await await_until(func(): return realm._preview_resources_ready, 20000), "realm preloads did not settle")
	game.run.suspended = false
	game.run.watching = false
	game.run.blackout = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	expect(not game._progress_enabled, "audit is not isolated from player saves")
	var mouse_before := Input.mouse_mode
	_open_ui(game)
	expect(paused and game._photo_album._empty.visible, "empty state/pause missing")
	expect(game._photo_album._save.disabled, "empty album offers photograph export")
	game._photo_album.dismiss()
	await process_frame
	expect(not paused and Input.mouse_mode == mouse_before,
		"closing empty album did not restore gameplay")
	var image := Image.create(160, 90, false, Image.FORMAT_RGB8)
	image.fill(Color(0.4, 0.3, 0.2))
	var image_b := Image.create(160, 90, false, Image.FORMAT_RGB8)
	image_b.fill(Color(0.1, 0.5, 0.8))
	game._on_album_photograph(image, {"floor": 1, "theme": "CASINO", "caption": "FIRST"})
	game._on_album_photograph(image_b, {"floor": 2, "theme": "MALL", "caption": "SECOND"})
	expect(game._photo_album_store.entries.size() == 2, "album did not keep ordinary/repeated photos")
	expect(not game._photo_album_store._persistent, "CLI album writes player profile")
	_open_ui(game)
	var album: PhotoAlbum = game._photo_album
	expect(album.index == 1 and album._detail.text.contains("MALL"), "album did not open latest photo")
	album._toggle_pin()
	var pinned_texture: Texture2D = album._pinned_view.image.texture
	var pinned_caption: String = album._pinned_view.caption
	album.show_photo(0)
	expect(album._pinned_view.image.texture == pinned_texture and album._pinned_view.caption == pinned_caption,
		"browsing changed pinned photo texture or caption")
	album._current_view.zoom_by(2.0)
	album._current_view.pan_by(Vector2(20, 10))
	var current_zoom: float = album._current_view.zoom
	var pinned_zoom: float = album._pinned_view.zoom
	expect(current_zoom > 1.0 and pinned_zoom == 1.0, "compare panes do not zoom independently")
	album._pinned_view.grab_focus()
	expect(album._active_view == album._pinned_view, "focus did not select pinned pane")
	album._pinned_view.zoom_by(100.0)
	expect(album._pinned_view.zoom == 8.0, "zoom maximum was not clamped")
	album._pinned_view.zoom_by(0.001)
	expect(album._pinned_view.zoom == 1.0, "zoom minimum was not clamped")
	album._pinned_view.zoom_by(4.0)
	album._pinned_view.reset_view()
	expect(album._pinned_view.zoom == 1.0 and album._pinned_view.pan == Vector2.ZERO, "FIT did not reset zoom and pan")
	expect(album._current_view._surface.clip_contents, "inspection surface is not clipped")
	album.show_photo(-1)
	expect(album.index == 0 and album._previous.disabled, "previous page bounds failed")
	album.show_photo(999)
	expect(album.index == 1 and album._next.disabled, "next page bounds failed")
	for i in 4:
		game._on_album_photograph(image, {"floor": 2, "theme": "MALL", "caption": "REPEATED PHOTO"})
	album.show_photo(5)
	var extent_before := root.size
	for extent in [Vector2i(1280, 720), Vector2i(640, 480), Vector2i(720, 1280),
			Vector2i(3840, 2160), Vector2i(640, 480)]:
		root.size = extent
		for frame in 6:
			await process_frame
		var safe := VhsOsd.safe_inset(Vector2(extent))
		var bounds := Rect2(safe - Vector2.ONE, Vector2(extent) - safe * 2 + Vector2.ONE * 2)
		if album._pinned_view.visible:
			expect(not album._current_view.get_global_rect().intersects(album._pinned_view.get_global_rect()),
				"compare panes overlap at %s" % extent)
		for control: Control in [album._layout, album._frame, album._detail, album._strip,
				album._previous, album._next, album._save, album._close]:
			if control.is_visible_in_tree():
				expect(bounds.encloses(control.get_global_rect()), "album clips %s at %s: %s" % [control.name, extent, control.get_global_rect()])
		expect(album._frame.size.y >= 80, "photo collapsed at %s" % extent)
		expect(album._save.size.y * album._layout.scale.y >= 44, "save target is too small")
		expect(album._save.get_theme_font("font") == VhsOsd.FONT, "album has inconsistent typeface")
	var export_path := "/tmp/liminal-album-ui-export-%d.png" % OS.get_process_id()
	album._export_index = album.index
	album._export_selected(export_path)
	expect(FileAccess.file_exists(export_path) and album._export_status.text.begins_with("SAVED"),
		"export did not create a PNG and show success")
	expect(game._photo_album_store.entries.size() == 6 and album.index == 5,
		"export changed source album or selection")
	DirAccess.remove_absolute(export_path)
	for frame in 6:
		await process_frame
	expect(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(album._export_status.get_global_rect()),
		"export feedback is clipped")
	root.size = extent_before
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	expect(not paused and not is_instance_valid(game._photo_album), "Escape failed to close album")
	expect(not is_instance_valid(game._pause_menu), "Escape opened pause behind album")
	await teardown_game(game)
	finish("photo album: capture integration, browsing, pause, CLI isolation")


## Headless display servers cannot capture the mouse. Exercise the album UI
## directly here; capture_photo_album.gd verifies production opening gates.
func _open_ui(game: Node) -> void:
	game._photo_album_store.configure(game.world_seed, false)
	game._photo_album = PhotoAlbum.new()
	game.add_child(game._photo_album)
	game._photo_album.closed.connect(func(): game._photo_album = null)
	game._photo_album.open(game._photo_album_store)
