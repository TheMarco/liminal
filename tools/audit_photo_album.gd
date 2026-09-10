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
	game.run.suspended = false
	game.run.watching = false
	game.run.blackout = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	expect(not game._progress_enabled, "audit is not isolated from player saves")
	var mouse_before := Input.mouse_mode
	_open_ui(game)
	expect(paused and game._photo_album._empty.visible, "empty state/pause missing")
	game._photo_album.dismiss()
	await process_frame
	expect(not paused and Input.mouse_mode == mouse_before,
		"closing empty album did not restore gameplay")
	var image := Image.create(160, 90, false, Image.FORMAT_RGB8)
	image.fill(Color(0.4, 0.3, 0.2))
	game._on_album_photograph(image, {"floor": 1, "theme": "CASINO", "caption": "FIRST"})
	game._on_album_photograph(image, {"floor": 2, "theme": "MALL", "caption": "SECOND"})
	expect(game._photo_album_store.entries.size() == 2, "album did not keep ordinary/repeated photos")
	expect(not game._photo_album_store._persistent, "CLI album writes player profile")
	_open_ui(game)
	var album: PhotoAlbum = game._photo_album
	expect(album.index == 1 and album._detail.text.contains("MALL"), "album did not open latest photo")
	album.show_photo(-1)
	expect(album.index == 0 and album._previous.disabled, "previous page bounds failed")
	album.show_photo(999)
	expect(album.index == 1 and album._next.disabled, "next page bounds failed")
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
