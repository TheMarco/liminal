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


func configure(run_seed: int, persistent: bool, custom_root: String = "") -> void:
	var album_root := custom_root if not custom_root.is_empty() else "user://photo_albums"
	if _configured and _run_seed == run_seed and _persistent == persistent and _root == album_root:
		return
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
	var entry := metadata.duplicate(true)
	entry["floor"] = maxi(1, int(metadata.get("floor", 1)))
	entry["theme"] = str(metadata.get("theme", ""))
	entry["caption"] = str(metadata.get("caption", ""))
	entry.erase("file")
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
		return image_error
	entry["file"] = filename
	var next_entries := entries.duplicate(true)
	next_entries.append(entry)
	var manifest_error := _save_manifest(next_entries)
	if manifest_error != OK:
		DirAccess.remove_absolute(image_path)
		return manifest_error
	entries.append(entry)
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


func _save_manifest(next_entries: Array) -> Error:
	var destination := _directory.path_join("manifest.json")
	var temporary := _directory.path_join("manifest.json.tmp")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": MANIFEST_VERSION, "entries": next_entries}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return write_error
	var rename_error := DirAccess.rename_absolute(temporary, destination)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary)
	return rename_error


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
