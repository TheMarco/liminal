extends SceneTree
## Original sign faces, production placement/fallback and commercial export exclusions.
## godot --headless --path . --script tools/audit_mall_signs.gd

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_assets()
	_check_presets()
	var chunk := Chunk.new(WorldGen.level_seed(4242, 7), Vector2i.ZERO, 7)
	get_root().add_child(chunk)
	var builder: RefCounted = chunk._level_builder
	for dir in range(4):
		for index in range(9):
			var before: int = chunk.get_child_count()
			var ok: bool = builder._mall_painted_sign(dir, 0.0, 6.0, index, 3.0)
			if not ok:
				_fail("painted sign failed dir=%d index=%d" % [dir, index])
				continue
			var after: int = chunk.get_child_count()
			if after != before + 1:
				_fail("painted sign child delta=%d dir=%d index=%d" % [after - before, dir, index])
			var node: Node = chunk.get_child(after - 1)
			_check_painted(node, index)
	var fallback_before: int = chunk.get_child_count()
	builder._mall_unit_sign(0, 0.0, 6.0, 0, 3.0, -1)
	var fallback_found := false
	for i in range(fallback_before, chunk.get_child_count()):
		var candidate: Node = chunk.get_child(i)
		if candidate is Label3D and not (candidate as Label3D).text.is_empty():
			fallback_found = true
	if not fallback_found:
		_fail("generated Label3D fallback missing or empty")
	chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures:
		push_error("MALL_SIGNS: " + failure)
	if failures.is_empty():
		print("MALL_SIGNS PASS")
	quit(1 if not failures.is_empty() else 0)


func _check_assets() -> void:
	if Chunk.MALL_SIGN_DIR != "res://textures/authored/mall_signs/":
		_fail("unexpected MALL_SIGN_DIR: " + Chunk.MALL_SIGN_DIR)
	var keys: Array[String] = []
	for entry: Array in Chunk.MALL_SIGN_FACES:
		var key: String = str(entry[0])
		if keys.has(key):
			_fail("duplicate sign key: " + key)
		keys.append(key)
		if float(entry[1]) != 6.0:
			_fail("declared aspect is not 6.0: " + key)
		var path := Chunk.MALL_SIGN_DIR + "sign_%s.webp" % key
		var texture := load(path) as Texture2D
		if texture == null:
			_fail("missing/unloadable texture: " + path)
		elif texture.get_width() != 1536 or texture.get_height() != 256:
			_fail("wrong dimensions %s: %dx%d" % [path, texture.get_width(), texture.get_height()])
		elif not texture.get_image().has_mipmaps():
			_fail("missing mipmaps for distant storefront readability: " + path)
	if keys.size() != 9:
		_fail("expected 9 unique sign keys, got %d" % keys.size())


func _check_painted(node: Node, index: int) -> void:
	var expected: String = str(Chunk.MALL_SIGN_FACES[index][0])
	if not node.has_meta("mall_painted_sign") or str(node.get_meta("mall_painted_sign")) != expected:
		_fail("wrong sign metadata for index %d" % index)
	if not node is MeshInstance3D:
		_fail("painted sign is not MeshInstance3D")
		return
	var mesh_node := node as MeshInstance3D
	var material := mesh_node.material_override as StandardMaterial3D
	if material == null or material.albedo_texture == null:
		_fail("painted sign has no StandardMaterial3D texture for " + expected)
	else:
		var actual_path: String = material.albedo_texture.resource_path
		var expected_path := Chunk.MALL_SIGN_DIR + "sign_%s.webp" % expected
		if actual_path != expected_path:
			_fail("wrong texture path: %s" % actual_path)
	var fit: Vector2 = mesh_node.get_meta("mall_sign_fit", Vector2.ZERO)
	if not is_equal_approx(mesh_node.scale.x / maxf(mesh_node.scale.y, 0.00001), 6.0):
		_fail("wrong painted sign aspect for " + expected)
	if fit.x > Chunk.MALL_SIGN_MAX_W + 0.001 or fit.y > Chunk.MALL_SIGN_MAX_H + 0.001:
		_fail("painted sign exceeds bounds for " + expected)


func _check_presets() -> void:
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		_fail("could not load export_presets.cfg")
		return
	var checked := 0
	for section: String in config.get_sections():
		if not section.begins_with("preset.") or not config.has_section_key(section, "exclude_filter"):
			continue
		checked += 1
		var patterns: PackedStringArray = str(config.get_value(section, "exclude_filter")).split(",", false)
		# The former NC signs are deleted. Keep the exclusion as a guard against
		# accidentally importing another NC asset into a commercial export.
		if not _matches_any(patterns, "textures/cc_by_nc/example/example.webp"):
			_fail("preset %s does not exclude NC texture pattern" % section)
		if not _matches_any(patterns, "models/cc_by_nc/example/example.glb"):
			_fail("preset %s does not exclude NC model pattern" % section)
	if checked < 2:
		_fail("fewer than 2 export presets checked")


func _matches_any(patterns: PackedStringArray, path: String) -> bool:
	for pattern: String in patterns:
		if path.match(pattern.strip_edges()):
			return true
	return false


func _fail(message: String) -> void:
	failures.append(message)
