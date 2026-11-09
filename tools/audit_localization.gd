extends "res://tools/lib/audit_base.gd"

func run() -> void:
	var model := GameSettings.new("/tmp/liminal_language_%d.cfg" % OS.get_process_id())
	root.size = Vector2i(1280, 720)
	LocalizedArt.inscription("poster-office-01.webp")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/en.json"))
	var tokens := RegEx.create_from_string("%[-+0-9.]*[sdif]|%%")
	var english_tracks := StorySubtitles.tracks("en")
	var label := Label.new()
	label.text = "SETTINGS"
	root.add_child(label)
	var sign := Label3D.new()
	sign.text = "EXIT"
	root.add_child(sign)
	var menu := PauseMenu.new()
	root.add_child(menu)
	menu.setup(model)
	menu.open()
	for code: String in Localization.LOCALES:
		model.set_value("language", code)
		await process_frame
		await process_frame
		expect(Localization.current_locale() == code, "language did not apply: " + code)
		if code == "en": continue
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % code))
		expect(catalog.size() == source.size(), "catalog entry count: " + code)
		var font := load(Localization.FONT_PATHS[code]) as Font
		for key: String in source:
			expect(catalog.has(key) and not str(catalog.get(key, "")).is_empty(), "missing " + code + ": " + key)
			var translation := str(catalog.get(key, ""))
			expect(_tokens(tokens, key) == _tokens(tokens, translation), "format tokens differ: " + code + ": " + key)
			_check_glyphs(font, translation, code)
		var tracks := StorySubtitles.tracks(code)
		expect(tracks.size() == english_tracks.size(), "subtitle track count: " + code)
		for path: String in english_tracks:
			var original: Array = english_tracks[path]
			var translated: Array = tracks.get(path, [])
			expect(original.size() == translated.size(), "subtitle cue count: " + code + path)
			for i in mini(original.size(), translated.size()):
				expect(original[i].start == translated[i].start and original[i].end == translated[i].end,
					"subtitle timing mismatch: " + code + path)
				expect(not str(translated[i].text).is_empty(), "empty subtitle: " + code + path)
				_check_glyphs(font, str(translated[i].text), code)
		for inscription: String in LocalizedArt._texts.values():
			for line in inscription.split("\n"):
				expect(catalog.has(line), "untranslated artwork: " + code + line)
		expect(Localization.text("SETTINGS") != "SETTINGS", "missing settings: " + code)
		expect(not Localization.text(LocalizedArt.inscription("mall_directory")).contains("Fashion"),
			"multi-line artwork escaped translation: " + code)
		expect(label.tr(label.text) == Localization.text("SETTINGS"), "live label translation: " + code)
		expect(sign.tr(sign.text) != sign.text, "live Label3D translation: " + code)
		expect(menu._language_select.selected == Localization.LOCALES.find(code), "picker out of sync: " + code)
		var menu_rect := menu._panel.get_global_rect()
		expect(menu_rect.position.y >= 20 and menu_rect.end.y <= root.size.y - 20,
			"pause menu exceeds safe vertical bounds: " + code)
		expect(not menu._quality_status.text.contains("Balanced performance"), "assembled graphics note escaped translation: " + code)
		expect(Localization.text("PHOTOS 2 · MIN 3") != "PHOTOS 2 · MIN 3", "formatted message: " + code)
		expect(Localization.text("Z — open door").begins_with("Z —"), "remapped action lost: " + code)
		expect(Localization.text("Z — open door") != "Z — open door", "interaction untranslated: " + code)
		for c in Localization.NAMES[Localization.LOCALES.find(code)]:
			expect(font.has_char(c.unicode_at(0)), "missing font glyph: " + code + " " + c)
		expect(bool(model.get_value("story_subtitles")), "translated dialogue defaults off: " + code)
		if "--capture-localization" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/liminal-settings-%s.png" % code)
		root.size = Vector2i(800, 600)
		await process_frame
		await process_frame
		var small := menu._panel.get_global_rect()
		expect(small.position.x >= 0 and small.position.y >= 0 and small.end.x <= 801 and small.end.y <= 601,
			"small-window settings clipped: " + code)
		root.size = Vector2i(1280, 720)
		await process_frame
		await process_frame
	await _check_art_reader()
	await _check_readable_hud()
	await _check_compact_feedback()
	model.set_value("language", "ja")
	expect(model.save_to_disk() == OK, "language save failed")
	var reloaded := GameSettings.new(model._path)
	expect(reloaded.get_value("language") == "ja", "language not persisted")
	reloaded.reset_defaults()
	expect(reloaded.get_value("language") == "ja", "reset stranded player in English")
	DirAccess.remove_absolute(model._path)
	menu.free()
	label.free()
	sign.free()
	Localization.apply("en")
	finish("localization")

func _check_compact_feedback() -> void:
	root.size = Vector2i(640, 480)
	var album_store := PhotoAlbumStore.new()
	album_store.configure(1, false)
	album_store.add_photo(Image.create(160, 90, false, Image.FORMAT_RGB8),
		{"floor": 2, "theme": "MALL", "caption": "REPEATED PHOTO"})
	var album := PhotoAlbum.new()
	root.add_child(album)
	album.open(album_store)
	album._export_status.text = "SAVED — liminal-album-ui-export-99999.png"
	album._export_status.visible = true
	var notice := preload("res://scripts/save_failure_notice.gd").new()
	root.add_child(notice)
	notice.report_failure("Progress", ERR_FILE_CANT_WRITE)
	notice.report_failure("Settings", ERR_FILE_CANT_WRITE)
	for code: String in Localization.LOCALES:
		Localization.apply(code)
		for frame in 6: await process_frame
		expect(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(album._export_status.get_global_rect()),
			"localized photo export feedback clipped: " + code)
		expect(notice._panel.get_global_rect().end.y < 100.0,
			"localized save warning covers settings: " + code)
	album.dismiss()
	notice.free()
	await process_frame
	root.size = Vector2i(1280, 720)

func _tokens(regex: RegEx, text: String) -> Array[String]:
	var found: Array[String] = []
	for token in regex.search_all(text): found.append(token.get_string())
	return found

func _check_glyphs(font: Font, text: String, code: String) -> void:
	for c in text:
		var point := c.unicode_at(0)
		if point >= 0x2e80 and point < 0xd800:
			expect(font.has_char(point), "missing glyph: " + code + c)

func _check_art_reader() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position.z = 3
	LocalizedArt.mark(world, "EMPLOYEE GUIDANCE\nYOUR DESK REMEMBERS YOUR SHAPE")
	var reader := preload("res://scripts/world_text_reader.gd").new()
	reader.camera = camera
	root.add_child(reader)
	await physics_frame
	reader._physics_process(1.0)
	expect(reader.visible, "visible inscription was not translated")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	collider.shape = box
	wall.add_child(collider)
	world.add_child(wall)
	wall.position.z = 1.5
	await physics_frame
	await physics_frame
	reader._physics_process(1.0)
	expect(not reader.visible, "inscription readable through a wall")
	reader.free()
	world.free()

func _check_readable_hud() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var source := VhsOsd.make_label(28)
	source.text = "EXIT"
	viewport.add_child(source)
	var mirror := preload("res://scripts/readable_game_text.gd").new()
	mirror.custom_viewport = root
	mirror.source_viewport = viewport
	viewport.add_child(mirror)
	mirror._process(0)
	expect(mirror._copies.has(source), "CJK HUD did not reach the window canvas")
	expect(source.self_modulate.a == 0, "CJK HUD still doubled inside the tape")
	if mirror._copies.has(source):
		source.hide()
		mirror._process(0)
		expect(not mirror._copies[source].visible, "hidden HUD retained a readable copy")
		source.show()
		source.modulate.a = 0.4
		mirror._process(0)
		expect(is_equal_approx(mirror._copies[source].modulate.a, 0.4), "HUD fade lost")
	mirror.allowed = func() -> bool: return false
	mirror._process(0)
	expect(not mirror.visible, "readable HUD obscures a modal screen")
	mirror.allowed = Callable()
	var previous := Localization.current_locale()
	Localization.apply("en")
	mirror._process(0)
	expect(source.self_modulate.a == 1 and mirror._copies.is_empty(), "English HUD not restored")
	Localization.apply(previous)
	var window_ui := CanvasLayer.new()
	window_ui.custom_viewport = root
	viewport.add_child(window_ui)
	var album_caption := VhsOsd.make_label(28)
	window_ui.add_child(album_caption)
	var reticle := PhotoCamera.PhotoReticle.new()
	viewport.add_child(reticle)
	reticle.size = Vector2(1280, 720)
	reticle.feedback = "FOCUS"
	reticle._process(0)
	mirror._process(0)
	expect(not mirror._copies.has(album_caption) and album_caption.self_modulate.a == 1,
		"window-resolution album text was intercepted")
	expect(mirror._copies.has(reticle._feedback_label), "camera feedback bypassed readable HUD")
	expect(Localization.text(reticle._feedback_label.text) != "FOCUS", "camera feedback untranslated")
	reticle.feedback = ""
	reticle._process(0)
	mirror._process(0)
	if mirror._copies.has(reticle._feedback_label):
		expect(not mirror._copies[reticle._feedback_label].visible, "empty camera feedback remained visible")
	viewport.free()
