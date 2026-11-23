extends RefCounted
## The game thread submits immutable JSON lines. Only the writer touches the file.

const MAX_PENDING := 512

var _thread := Thread.new()
var _wake := Semaphore.new()
var _mutex := Mutex.new()
var _pending := PackedStringArray()
var _closing := false
var _failed := false
var _dropped := 0
var _last_disk_usec := 0
var _max_disk_usec := 0

var _path: String
var _max_bytes: int
var _file: FileAccess


func start(path: String, max_bytes: int) -> Error:
	_path = path
	_max_bytes = max_bytes
	return _thread.start(_run)


func submit(line: String, final_record := false) -> Error:
	_mutex.lock()
	if _failed or _closing:
		_mutex.unlock()
		return ERR_UNAVAILABLE
	if _pending.size() >= MAX_PENDING and not final_record:
		_dropped += 1
		_mutex.unlock()
		return ERR_BUSY
	var wake := _pending.is_empty()
	_pending.append(line)
	_mutex.unlock()
	if wake: _wake.post()
	return OK


func disk_stats() -> Dictionary:
	_mutex.lock()
	var stats := {"last": _last_disk_usec / 1000.0, "max": _max_disk_usec / 1000.0, "dropped_records": _dropped}
	_mutex.unlock()
	return stats


func close() -> void:
	if not _thread.is_started(): return
	_mutex.lock()
	_closing = true
	_mutex.unlock()
	_wake.post()
	_thread.wait_to_finish()


func _run() -> void:
	while true:
		_wake.wait()
		_mutex.lock()
		var batch := _pending
		_pending = PackedStringArray()
		var closing := _closing
		_mutex.unlock()
		var last := 0
		var longest := 0
		for line in batch:
			var started := Time.get_ticks_usec()
			var error := _store_line(line)
			if error != OK:
				_mutex.lock()
				_failed = true
				_pending.clear()
				_mutex.unlock()
				_file = null
				push_warning("Performance diagnostics stopped writing: %s" % error_string(error))
				return
			last = Time.get_ticks_usec() - started
			longest = maxi(longest, last)
		if not batch.is_empty():
			_mutex.lock()
			_last_disk_usec = last
			_max_disk_usec = maxi(_max_disk_usec, longest)
			_mutex.unlock()
		if closing: break
	_file = null


func _store_line(line: String) -> Error:
	if _file == null or _file.get_position() >= _max_bytes:
		_file = null  # Windows needs the old handle closed before renaming it.
		var error := _open_next_log()
		if error != OK: return error
	if not _file.store_line(line): return ERR_FILE_CANT_WRITE
	_file.flush()
	return _file.get_error()


func _open_next_log() -> Error:
	var error := DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	if error != OK: return error
	if FileAccess.file_exists(_path + ".2"):
		error = DirAccess.remove_absolute(_path + ".2")
		if error != OK: return error
	for suffix in [".1", ""]:
		var source := _path + str(suffix)
		if FileAccess.file_exists(source):
			var destination := _path + (".2" if suffix == ".1" else ".1")
			error = DirAccess.rename_absolute(source, destination)
			if error != OK: return error
	_file = FileAccess.open(_path, FileAccess.WRITE)
	return FileAccess.get_open_error() if _file == null else OK
