extends SceneTree
## Verify the authored Poolrooms mineral atlases and their runtime wiring.
## Run: godot --headless --path . --script tools/audit_pool_minerals.gd

const GROUT_PATH := "res://textures/pool/minerals/grout_mineral_atlas.png"
const WATERLINE_PATH := "res://textures/pool/minerals/waterline_mineral_atlas.png"


func _init() -> void:
	var failures: Array[String] = []
	_check_atlas(GROUT_PATH, Vector2i(2048, 1024), failures)
	_check_atlas(WATERLINE_PATH, Vector2i(4096, 1024), failures)
	var material := Mats.pool_tile()
	if material.get_shader_parameter("grout_mineral_atlas") == null:
		failures.append("pool material has no grout mineral atlas")
	if material.get_shader_parameter("waterline_mineral_atlas") == null:
		failures.append("pool material has no waterline mineral atlas")
	var code := material.shader.code
	for contract in ["grout_mineral(", "waterline_mineral(",
			"surface_metres.y - water_y", "tile_coord = uv * 10.0"]:
		if not code.contains(contract):
			failures.append("pool shader is missing contract: " + contract)
	for failure in failures:
		print("  FAIL " + failure)
	if not failures.is_empty():
		quit(1)
		return
	print("pool mineral audit: PASS — 16 masks, safe borders, tile-grid wiring")
	quit()


func _check_atlas(path: String, expected_size: Vector2i,
		failures: Array[String]) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		failures.append("cannot load " + path)
		return
	if Vector2i(image.get_width(), image.get_height()) != expected_size:
		failures.append("%s has size %s, expected %s" % [
			path, Vector2i(image.get_width(), image.get_height()), expected_size])
		return
	var occupied := false
	for y in range(0, image.get_height(), 16):
		for x in range(0, image.get_width(), 16):
			if image.get_pixel(x, y).a > 0.08:
				occupied = true
				break
		if occupied:
			break
	if not occupied:
		failures.append(path + " contains no visible mineral mask")
	for x in range(image.get_width()):
		if image.get_pixel(x, 0).a > 0.01 \
				or image.get_pixel(x, image.get_height() - 1).a > 0.01:
			failures.append(path + " has a visible horizontal atlas edge")
			break
	for y in range(image.get_height()):
		if image.get_pixel(0, y).a > 0.01 \
				or image.get_pixel(image.get_width() - 1, y).a > 0.01:
			failures.append(path + " has a visible vertical atlas edge")
			break
