extends SceneTree
## GPU execution-stage audit for VHS exposure. Run with a GPU renderer:
## godot --path . --minimized --disable-render-loop \
##   --script tools/audit_vhs_exposure_render.gd
## A headless renderer is rejected because this compares rendered pixel bytes.

var oracle_view: SubViewport
var real_view: SubViewport
var oracle_mat: ShaderMaterial
var real_mat: ShaderMaterial
var oracle_source: TextureRect
var real_source: TextureRect

func _init() -> void:
	call_deferred("run")

func _stage(material: ShaderMaterial) -> Array:
	var view := SubViewport.new()
	view.size = Vector2i(720, 480)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var source := TextureRect.new()
	source.size = view.size
	source.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.add_child(source)
	var effect :=  ColorRect.new()
	effect.size = view.size
	effect.material = material
	view.add_child(effect)
	return [view, source]

func _material_with_shader(shader: Shader) -> ShaderMaterial:
	var mat := PostProcessController.make_live_found_footage_material()
	mat.shader = shader
	return mat

func _source(case_id: int) -> ImageTexture:
	var image := Image.create(720, 480, false, Image.FORMAT_RGBA8)
	var energy := 0.035 if case_id % 3 == 0 else (0.4 if case_id % 3 == 1 else 1.0)
	for y in 480:
		for x in 720:
			image.set_pixel(x, y, Color(float(x % 61) / 60.0 * energy,
				float(y % 83) / 82.0 * energy,
				float((x + y + case_id * 17) % 97) / 96.0 * energy))
	return ImageTexture.create_from_image(image)

func _params(mat: ShaderMaterial, case_id: int) -> void:
	mat.set_shader_parameter("tape_time", 3.37 + case_id * 0.27)
	mat.set_shader_parameter("auto_exposure", 0.0 if case_id == 0 else 0.85)
	mat.set_shader_parameter("resolution", Vector2(344, 240) if case_id % 2 else Vector2(720, 480))
	mat.set_shader_parameter("entity_amt", 0.7 if case_id >= 4 else 0.0)
	mat.set_shader_parameter("entity_radius", 0.25)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("VHS pixel audit requires a GPU renderer (omit --headless).")
		quit(1)
		return
	var current_post := FileAccess.get_file_as_string("res://shaders/post.gdshader")
	var include := FileAccess.get_file_as_string("res://shaders/vhs_signal.gdshaderinc")
	var reference := Shader.new()
	reference.code = current_post.replace(
		'#include "res://shaders/vhs_signal.gdshaderinc"', include)
	reference.code = reference.code.replace(
		"clr *= bright_boost * tape_exposure_gain;",
		"clr *= bright_boost * tape_exposure();")
	reference.code = reference.code.replace(
		"tape_exposure_gain = tape_signal ? tape_exposure() : 1.0;",
		"tape_exposure_gain = 1.0;")
	oracle_mat = _material_with_shader(reference)
	real_mat = _material_with_shader(Shader.new())
	real_mat.shader.code = current_post.replace(
		'#include "res://shaders/vhs_signal.gdshaderinc"', include)
	var oracle_stage := _stage(oracle_mat)
	var real_stage := _stage(real_mat)
	oracle_view = oracle_stage[0]
	oracle_source = oracle_stage[1]
	real_view = real_stage[0]
	real_source = real_stage[1]
	var worst := 0
	for case_id in 8:
		var texture := _source(case_id)
		oracle_source.texture = texture
		real_source.texture = texture
		_params(oracle_mat, case_id)
		_params(real_mat, case_id)
		for _warmup in 2:
			await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
		var a := oracle_view.get_texture().get_image().get_data()
		var b := real_view.get_texture().get_image().get_data()
		if a.is_empty() or a.size() != b.size():
			push_error("VHS readback missing or mismatched")
			quit(1)
			return
		var maximum := 0
		var changed := 0
		for i in a.size():
			var error := absi(int(a[i]) - int(b[i]))
			maximum = maxi(maximum, error)
			if error > 0:
				changed += 1
		worst = maxi(worst, maximum)
		print("VHS_COMPARE case=%d max_channel_error=%d changed_bytes=%d" % [case_id, maximum, changed])
	oracle_view.queue_free()
	real_view.queue_free()
	await process_frame
	quit(0 if worst <= 1 else 1)
