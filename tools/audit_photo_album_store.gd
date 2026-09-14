extends SceneTree

const Store = preload("res://scripts/photo_album_store.gd")
var failures: Array[String] = []
var test_root := "/tmp/liminal_album_%d" % Time.get_ticks_usec()


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var photo := Image.create(2000, 1000, false, Image.FORMAT_RGBA8)
	photo.fill(Color(0.8, 0.2, 0.1))
	var store := Store.new()
	store.configure(102, true, test_root)
	_expect(store.add_photo(photo, {"floor": 2, "theme": "casino", "caption": "WE COUNTED YOU", "documented_ids": ["writing_1"]}) == OK, "first image save failed")
	_expect(store.add_photo(photo, {"floor": 2, "theme": "casino", "caption": "ordinary"}) == OK, "second image save failed")
	_expect(photo.get_width() == 2000, "save mutated caller's image")
	var loaded := Store.new()
	loaded.configure(102, true, test_root)
	_expect(loaded.entries.size() == 2, "manifest replacement lost entries")
	if loaded.entries.size() == 2:
		_expect(loaded.entries[0]["caption"] == "WE COUNTED YOU" and loaded.entries[1]["caption"] == "ordinary", "chronological metadata changed")
		_expect(loaded.entries[0]["documented_ids"] == ["writing_1"], "documented IDs lost")
	var decoded: Image = loaded.image_at(0)
	_expect(decoded != null and decoded.get_size() == Vector2i(1600, 800), "image decode or maximum size incorrect")
	if decoded != null:
		_expect(absf(decoded.get_pixel(10, 10).r - 0.8) < 0.03, "JPEG color roundtrip failed")
	var export_path := test_root.path_join("export.png")
	var before := FileAccess.get_file_as_string(test_root.path_join("102/manifest.json"))
	_expect(loaded.export_photo(0, export_path) == OK, "photo export failed")
	_expect(Image.load_from_file(export_path).get_size() == Vector2i(1600, 800), "exported size changed")
	_expect(loaded.export_photo(0, export_path) == ERR_ALREADY_EXISTS, "export overwrote without confirmation")
	_expect(loaded.export_photo(1, export_path, true) == OK, "confirmed export overwrite failed")
	_expect(loaded.export_photo(-1, test_root.path_join("invalid.png")) != OK, "invalid photo exported")
	_expect(loaded.export_photo(0, test_root.path_join("invalid.jpg")) == ERR_INVALID_PARAMETER, "export accepted wrong format")
	_expect(before == FileAccess.get_file_as_string(test_root.path_join("102/manifest.json"))
		and loaded.entries.size() == 2, "export changed source album")
	loaded.configure(102, true, test_root)
	_expect(loaded.entries.size() == 2, "same-seed configure reset album")
	loaded.configure(103, true, test_root)
	_expect(loaded.entries.is_empty(), "different seed leaked photographs")
	_expect(loaded.image_at(-1) == null and loaded.image_at(0) == null, "invalid index returned image")
	var memory_root := test_root.path_join("must_not_exist")
	var memory := Store.new()
	memory.configure(102, false, memory_root)
	_expect(memory.add_photo(photo, {"caption": "memory"}) == OK, "memory capture failed")
	memory.configure(102, false, memory_root)
	_expect(memory.entries.size() == 1 and memory.image_at(0) != null, "memory configure reset album")
	var thumbnail: Image = memory.image_at(0)
	thumbnail.resize(100, 50)
	_expect(memory.image_at(0).get_size() == Vector2i(1600, 800), "thumbnail resize mutated stored original")
	_expect(not DirAccess.dir_exists_absolute(memory_root), "nonpersistent album wrote to disk")
	memory.configure(104, false, memory_root)
	_expect(memory.entries.is_empty(), "memory seed did not reset")
	var blocker := FileAccess.open(test_root.path_join("blocker"), FileAccess.WRITE)
	blocker.store_string("not a directory")
	blocker.close()
	var broken := Store.new()
	broken.configure(1, true, test_root.path_join("blocker"))
	_expect(broken.add_photo(photo, {}) != OK and broken.entries.is_empty(), "failed write claimed successful capture")
	var committed := Store.new()
	committed.configure(105, true, test_root)
	_expect(committed.add_photo(photo, {"caption": "committed"}) == OK, "manifest failure setup failed")
	DirAccess.make_dir_recursive_absolute(test_root.path_join("105/manifest.json.tmp"))
	_expect(committed.add_photo(photo, {"caption": "must not appear"}) != OK, "manifest failure claimed success")
	_expect(committed.entries.size() == 1, "failed manifest appended an entry")
	var unchanged := Store.new()
	unchanged.configure(105, true, test_root)
	_expect(unchanged.entries.size() == 1 and unchanged.entries[0]["caption"] == "committed", "failed manifest damaged committed album")
	_expect(DirAccess.get_files_at(test_root.path_join("105")).size() == 2, "failed manifest left an orphan image")
	# Malformed rows cannot point outside this run; valid but missing pictures load gracefully.
	var manifest := FileAccess.open(test_root.path_join("102/manifest.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"version": 1, "entries": [null, {"file": "../photo_stolen.jpg", "floor": 1, "theme": "x", "caption": "x"}, {"file": "photo_missing.jpg", "floor": 1, "theme": "x", "caption": "missing"}, {"file": "photo_bad.jpg", "floor": "bad", "theme": "x", "caption": "x"}]}))
	manifest.close()
	var malformed := Store.new()
	malformed.configure(102, true, test_root)
	_expect(malformed.entries.size() == 1 and malformed.image_at(0) == null, "malformed or missing image handling failed")
	# Corrupt image handling is intentionally exercised (Godot logs a decode error).
	var corrupt := FileAccess.open(test_root.path_join("102/photo_missing.jpg"), FileAccess.WRITE)
	corrupt.store_string("invalid JPEG")
	corrupt.close()
	_expect(malformed.image_at(0) == null, "corrupt image returned an image")
	_cleanup(test_root)
	for failure in failures:
		print("FAIL: " + failure)
	if failures.is_empty():
		print("photo album store audit: PASS — persistence, order, resize, seed isolation, memory mode, malformed data and write failure")
	quit(0 if failures.is_empty() else 1)


func _cleanup(path: String) -> void:
	for filename in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(filename))
	for directory in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(directory))
	DirAccess.remove_absolute(path)
