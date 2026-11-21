class_name PhotoAlbumStore
extends RefCounted
## Chronological, run-scoped photographs. Only the requested image is decoded.
## Nonpersistent instances never touch disk, including during configure().

const MAX_IMAGE_EDGE := 1600
const MANIFEST_VERSION := 1

var entries: Array[Dictionary] = []
var _images: Array[Image] = []
var _run_seed := 0
var _persistent := false
var _root := ""
var _directory := ""
var _configured := false


# Running captures use private files until one atomic manifest replacement
# publishes them. Only the game thread owns entries and their revision.
var _configuration_id := 0
var _revision := 0
var _live_writes: Array[PhotoWrite] = []


class PhotoWrite:
	var directory: String
	var image_path: String
	var manifest_path: String
	var error := OK
	var jpeg_usec := 0
	var write_usec := 0

	func prepare(source: Image, rows: Array) -> void:
		var started := Time.get_ticks_usec()
		var rgb := source.duplicate() as Image
		error = PhotoAlbumStore._prepare_print(rgb)
		if error != OK:
			return
		var bytes := rgb.save_jpg_to_buffer(0.92)
		jpeg_usec = Time.get_ticks_usec() - started
		if bytes.is_empty():
			error = ERR_FILE_CANT_WRITE
			return
		started = Time.get_ticks_usec()
		error = DirAccess.make_dir_recursive_absolute(directory)
		if error == OK:
			var file := FileAccess.open(image_path, FileAccess.WRITE)
			if file == null:
				error = FileAccess.get_open_error()
			else:
				file.store_buffer(bytes)
				file.flush()
				error = file.get_error()
				file.close()
		write_usec = Time.get_ticks_usec() - started
		if error == OK:
			stage_manifest(rows)

	func stage_manifest(rows: Array) -> void:
		var started := Time.get_ticks_usec()
		error = PhotoAlbumStore._write_manifest_file(manifest_path, rows)
		write_usec += Time.get_ticks_usec() - started

	func discard() -> void:
		if not manifest_path.is_empty() and FileAccess.file_exists(manifest_path):
			DirAccess.remove_absolute(manifest_path)
		if not image_path.is_empty() and FileAccess.file_exists(image_path):
			DirAccess.remove_absolute(image_path)
		manifest_path = ""
		image_path = ""

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and not image_path.is_empty():
			discard()


func _wait_for_job(task: int, tree: SceneTree) -> void:
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)


func add_live_photo(image: Image, metadata: Dictionary, tree: SceneTree) -> Error:
	if not _persistent or image == null or image.is_empty():
		return add_photo(image, metadata)
	var configuration := _configuration_id
	var revision := _revision
	var entry := _photo_entry(metadata)
	var writer := PhotoWrite.new()
	_live_writes.append(writer)
	writer.directory = ProjectSettings.globalize_path(_directory)
	entry["file"] = "photo_%06d_%d_%d.jpg" % [entries.size(), Time.get_ticks_usec(), writer.get_instance_id()]
	writer.image_path = writer.directory.path_join(entry.file)
	writer.manifest_path = writer.image_path + ".manifest.tmp"
	var task := WorkerThreadPool.add_task(writer.prepare.bind(image, _entries_with(entry)), false, "Develop photograph")
	await _wait_for_job(task, tree)
	# Encoding may complete out of order. Publish in shutter order.
	while _live_writes.front() != writer:
		await tree.process_frame
	# An overlapping photo or flash update may have been published while
	# storage was busy. Re-stage just the small manifest with those edits.
	while writer.error == OK and configuration == _configuration_id and revision != _revision:
		revision = _revision
		task = WorkerThreadPool.add_task(writer.stage_manifest.bind(_entries_with(entry)), false, "Update photograph manifest")
		await _wait_for_job(task, tree)
	var error: Error = writer.error
	var started := Time.get_ticks_usec()
	if configuration != _configuration_id:
		error = ERR_SKIP
	elif error == OK:
		error = DirAccess.rename_absolute(writer.manifest_path, writer.directory.path_join("manifest.json"))
	if error != OK:
		task = WorkerThreadPool.add_task(writer.discard, false, "Discard unpublished photograph")
		await _wait_for_job(task, tree)
		_live_writes.pop_front()
		return error
	entries.append(entry)
	writer.manifest_path = ""
	writer.image_path = ""
	_revision += 1
	_live_writes.pop_front()
	RuntimeDiagnostics.mark("photo_album_saved", {"jpeg_worker_ms": writer.jpeg_usec / 1000.0,
		"worker_write_ms": writer.write_usec / 1000.0, "main_write_ms": (Time.get_ticks_usec() - started) / 1000.0})
	return OK


func configure(run_seed: int, persistent: bool, custom_root: String = "") -> void:
	var album_root := custom_root if not custom_root.is_empty() else "user://photo_albums"
	if _configured and _run_seed == run_seed and _persistent == persistent and _root == album_root:
		return
	_configuration_id += 1
	_configured = true
	_run_seed = run_seed
	_persistent = persistent
	_root = album_root
	_directory = album_root.path_join(str(run_seed))
	entries.clear()
	_images.clear()
	if persistent:
		_load_manifest()


func add_photo(image: Image, metadata: Dictionary) -> Error:
	if not _configured or image == null or image.is_empty():
		return ERR_INVALID_PARAMETER
	var photo := image.duplicate() as Image
	var error := _prepare_print(photo)
	if error != OK:
		return error
	return _append_photo(photo, metadata)


static func _prepare_print(photo: Image) -> Error:
	if photo.is_compressed():
		var decompress_error := photo.decompress()
		if decompress_error != OK:
			return decompress_error
	var longest := maxi(photo.get_width(), photo.get_height())
	if longest > MAX_IMAGE_EDGE:
		var scale_factor := float(MAX_IMAGE_EDGE) / float(longest)
		photo.resize(maxi(1, roundi(photo.get_width() * scale_factor)),
			maxi(1, roundi(photo.get_height() * scale_factor)), Image.INTERPOLATE_LANCZOS)
	photo.convert(Image.FORMAT_RGB8)
	return OK


func _photo_entry(metadata: Dictionary) -> Dictionary:
	var entry := metadata.duplicate(true)
	entry["floor"] = maxi(1, int(metadata.get("floor", 1)))
	entry["theme"] = str(metadata.get("theme", ""))
	entry["caption"] = str(metadata.get("caption", ""))
	entry.erase("file")
	return entry


func _entries_with(entry: Dictionary) -> Array[Dictionary]:
	var rows := entries.duplicate(true)
	rows.append(entry)
	return rows


func _append_photo(photo: Image, metadata: Dictionary) -> Error:
	var entry := _photo_entry(metadata)
	if not _persistent:
		entries.append(entry)
		_images.append(photo)
		return OK
	var directory_error := DirAccess.make_dir_recursive_absolute(_directory)
	if directory_error != OK:
		return directory_error
	var filename := "photo_%06d_%d.jpg" % [entries.size(), Time.get_ticks_usec()]
	var image_path := _directory.path_join(filename)
	var image_error := photo.save_jpg(image_path, 0.92)
	if image_error != OK:
		DirAccess.remove_absolute(image_path)
		return image_error
	entry["file"] = filename
	var manifest_error := _save_manifest(_entries_with(entry))
	if manifest_error != OK:
		DirAccess.remove_absolute(image_path)
		return manifest_error
	entries.append(entry)
	_revision += 1
	return OK


func set_flash_status(anomaly_id: String, status: String) -> void:
	if anomaly_id.is_empty():
		return
	var changed := false
	for entry in entries:
		if anomaly_id in entry.get("anomaly_ids", []):
			entry["flash_status"] = status
			changed = true
	if changed and _persistent:
		_revision += 1
		_save_manifest(entries)


func image_at(index: int) -> Image:
	if index < 0 or index >= entries.size():
		return null
	if not _persistent:
		return _images[index].duplicate() as Image
	var filename := str(entries[index].get("file", ""))
	if not _safe_filename(filename):
		return null
	var path := _directory.path_join(filename)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK or image.is_empty():
		return null
	return image


## Export is an explicit copy, separate from the run's image and manifest.
## Only the save dialog may authorize replacing an existing chosen file.
func export_photo(index: int, path: String, overwrite_confirmed := false) -> Error:
	if not path.is_absolute_path() or path.get_extension().to_lower() != "png":
		return ERR_INVALID_PARAMETER
	if FileAccess.file_exists(path) and not overwrite_confirmed:
		return ERR_ALREADY_EXISTS
	var photo := image_at(index)
	if photo == null or photo.is_empty():
		return ERR_FILE_NOT_FOUND
	return photo.save_png(path)


func _save_manifest(next_entries: Array) -> Error:
	var destination := _directory.path_join("manifest.json")
	var temporary := _directory.path_join("manifest.json.tmp")
	var write_error := _write_manifest_file(temporary, next_entries)
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return write_error
	var rename_error := DirAccess.rename_absolute(temporary, destination)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary)
	return rename_error


static func _write_manifest_file(temporary: String, next_entries: Array) -> Error:
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": MANIFEST_VERSION, "entries": next_entries}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	return write_error


func _load_manifest() -> void:
	var path := _directory.path_join("manifest.json")
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or parsed.get("version") != MANIFEST_VERSION:
		return
	var rows: Variant = parsed.get("entries")
	if not rows is Array:
		return
	for row: Variant in rows:
		if not row is Dictionary:
			continue
		if not row.get("file") is String or not _safe_filename(row["file"]):
			continue
		if not (row.get("floor") is int or row.get("floor") is float):
			continue
		if float(row["floor"]) < 1.0 or not row.get("theme") is String or not row.get("caption") is String:
			continue
		entries.append(row)


func _safe_filename(filename: String) -> bool:
	return not filename.is_empty() and filename == filename.get_file() \
		and not filename.contains("\\") and filename.begins_with("photo_") \
		and filename.ends_with(".jpg") and not filename.contains("..")
