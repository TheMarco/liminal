extends SceneTree
## Static contract for runtime-created lights. Every persistent or temporary
## Light3D must name the visible fixture/effect that owns it. The audit cannot
## judge art, but it prevents a new anonymous fill/spot light from quietly
## entering the game after the visual pass that established this convention.
##
## godot --headless --path . --script tools/audit_visible_light_sources.gd

const LOOK_AHEAD := 45
const CENTRAL_FILL_BUILDERS := [
	"office_level_builder.gd", "annex_level_builder.gd", "airport_level_builder.gd",
	"asylum_level_builder.gd", "school_level_builder.gd", "mall_level_builder.gd",
	"prison_level_builder.gd"]

var _constructor := RegEx.new()
var _failures: Array[String] = []


func _init() -> void:
	_constructor.compile("^\\s*(?:var\\s+)?([A-Za-z_][A-Za-z0-9_]*)(?:\\s*:\\s*[A-Za-z_][A-Za-z0-9_]*)?\\s*(?::=|=)\\s*(?:OmniLight3D|SpotLight3D|DirectionalLight3D|FlickerLight)\\.new\\(")
	_scan_directory("res://scripts")
	if _failures.is_empty():
		print("PASS visible_light_sources")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _scan_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		_failures.append("could not open %s" % path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if directory.current_is_dir():
				_scan_directory(child)
			elif entry.ends_with(".gd"):
				_scan_file(child)
		entry = directory.get_next()
	directory.list_dir_end()


func _scan_file(path: String) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	if path.get_file() in CENTRAL_FILL_BUILDERS:
		for index in lines.size():
			if lines[index].contains("scene.main_light(") or lines[index].contains("_make_main_light("):
				_failures.append("%s:%d uses legacy central light API; use fixture_light" % [path, index + 1])
	for index in lines.size():
		var match := _constructor.search(lines[index])
		if match == null:
			continue
		var variable := match.get_string(1)
		var marker := variable + ".set_meta(\"visible_source\""
		var marked := false
		for look in range(index + 1, mini(lines.size(), index + LOOK_AHEAD + 1)):
			# Reusing the same local for another constructor ends this light's block.
			var next_match := _constructor.search(lines[look])
			if next_match != null and next_match.get_string(1) == variable:
				break
			if lines[look].contains(marker):
				marked = true
				break
		if not marked:
			_failures.append("%s:%d creates `%s` without a visible_source contract" % [
				path, index + 1, variable])
