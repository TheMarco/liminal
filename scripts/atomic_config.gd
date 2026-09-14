extends RefCounted
## Replace a complete config only after the temporary write succeeds. Optional
## backup rotation leaves the old live file intact if any preparation fails.
static func save_config(config: ConfigFile, path: String, backup_existing := false) -> Error:
	var temporary := "%s.tmp.%d" % [path, OS.get_process_id()]
	var error := config.save(temporary)
	if error != OK:
		_cleanup(temporary)
		return error
	if backup_existing and FileAccess.file_exists(path):
		var backup_temp := temporary + ".backup"
		error = DirAccess.copy_absolute(path, backup_temp)
		if error == OK:
			error = DirAccess.rename_absolute(backup_temp, path + ".bak")
		if error != OK:
			_cleanup(backup_temp)
			_cleanup(temporary)
			return error
	error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		_cleanup(temporary)
	return error

static func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
