class_name NtscrtPipeline
extends Control
## A bounded GPU signal atlas in the viewport's backbuffer. Intermediate quads
## are overwritten by the final display in the same frame. This avoids source
## readback, viewport feedback, reparenting the world/HUD, and extra frame lag.
## Encoded video occupies the top-left; two quarter-size bloom tiles sit below.

const RECEIVER = preload("res://scripts/ntscrt_receiver.gd")
const ENCODE = preload("res://shaders/ntscrt_encode.gdshader")
const DECODE = preload("res://shaders/ntscrt_decode.gdshader")
const TRANSPORT = preload("res://shaders/ntscrt_transport.gdshader")
const BLOOM = preload("res://shaders/ntscrt_bloom.gdshader")
const DISPLAY = preload("res://shaders/ntscrt_display.gdshader")
var receiver := RECEIVER.new()
var buffer_size := Vector2i(720,480)
var bloom_size := Vector2i(180,120)
var last_cpu_usec := 0
var _knobs: Dictionary = {}
var _signal := true
var _crt := true
var _reduced := false
var _wear := 1.0
var _curvature := false
var _stress := 0.0
var _entity_pos := Vector2(0.5,0.5)
var _entity_radius := 0.0
var _entity_amount := 0.0
var _materials: Array[ShaderMaterial] = []
var _quads: Array[ColorRect] = []
var _copies: Array[BackBufferCopy] = []
var _source_copy: BackBufferCopy
var _bloom_h: ColorRect
var _bloom_v: ColorRect
var _bloom_copy_h: BackBufferCopy
var _bloom_copy_v: BackBufferCopy
var _built := false

func _ready() -> void:
	name = "NTSCRTExperimental"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_source_copy = _copy("NTSCRTSource", true)
	for pair in [[ENCODE,"Encode"],[DECODE,"Decode"],[TRANSPORT,"Receiver"]]:
		var quad := _quad(pair[0], pair[1])
		_quads.append(quad)
		_copies.append(_copy(pair[1]+"Copy"))
	_bloom_h = _quad(BLOOM,"BloomHorizontal")
	_bloom_copy_h = _copy("BloomHorizontalCopy")
	_bloom_v = _quad(BLOOM,"BloomVertical")
	_bloom_copy_v = _copy("BloomVerticalCopy")
	var display := _quad(DISPLAY,"Display")
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_built = true
	get_viewport().size_changed.connect(_resize)
	_resize()
	_apply_parameters()

func _quad(shader: Shader, label: String) -> ColorRect:
	var quad := ColorRect.new()
	quad.name = label
	quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = shader
	quad.material = material
	_materials.append(material)
	add_child(quad)
	return quad

func _copy(label: String, full := false) -> BackBufferCopy:
	var copy := BackBufferCopy.new()
	copy.name = label
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if full else BackBufferCopy.COPY_MODE_RECT
	add_child(copy)
	return copy

func configure(knobs: Dictionary, signal_on: bool, crt_on: bool, curved: bool) -> void:
	if _knobs == knobs and _signal == signal_on and _crt == crt_on and _curvature == curved:
		return
	var old_size := GraphicsQuality.video_signal_size(_knobs)
	_knobs = knobs.duplicate()
	_signal = signal_on
	_crt = crt_on
	_curvature = curved
	_reduced = bool(knobs.get("reduced_flashing",false))
	_wear = clampf(float(knobs.get("vhs_distortion",0.5))*2.0,0.0,2.0)
	if _built:
		if old_size != GraphicsQuality.video_signal_size(knobs): _resize()
		_apply_parameters()

func set_game_state(corruption: float, presence: float, damage: float, burst: bool,
		noise: float, entity_pos: Vector2, entity_radius: float, entity_amount: float) -> void:
	_stress = clampf(maxf(maxf(corruption*0.6,presence*0.7),maxf(damage,1.0 if burst else 0.0))
		+ maxf(0.0,noise-1.0)*0.06,0.0,1.0)
	_entity_pos = entity_pos
	_entity_radius = entity_radius
	_entity_amount = entity_amount

func _resize() -> void:
	if not _built: return
	var extent := get_viewport().get_visible_rect().size
	var target := Vector2(GraphicsQuality.video_signal_size(_knobs))
	# Reserve a quarter-height strip for two bloom tiles. Tiny windows retain
	# a complete, bounded atlas instead of clipping signal rows offscreen.
	var scale_factor := minf(1.0,minf(extent.x/target.x,extent.y/(target.y*1.25)))
	buffer_size = Vector2i(maxi(8,int(target.x*scale_factor)/4*4),maxi(8,int(target.y*scale_factor)/4*4))
	bloom_size = buffer_size/4
	for i in _quads.size():
		_quads[i].size = buffer_size
		_copies[i].rect = Rect2(Vector2.ZERO,Vector2(buffer_size))
	var origin_h := Vector2(0,buffer_size.y)
	var origin_v := Vector2(bloom_size.x,buffer_size.y)
	_bloom_h.position = origin_h
	_bloom_h.size = bloom_size
	_bloom_copy_h.rect = Rect2(origin_h,Vector2(bloom_size))
	_bloom_v.position = origin_v
	_bloom_v.size = bloom_size
	_bloom_copy_v.rect = Rect2(origin_v,Vector2(bloom_size))
	for material in _materials:
		material.set_shader_parameter("buffer_size",Vector2(buffer_size))
		material.set_shader_parameter("atlas_pixel_size",Vector2.ONE/extent.max(Vector2.ONE))
	_materials[3].set_shader_parameter("source_origin",Vector2.ZERO)
	_materials[3].set_shader_parameter("source_size",Vector2(buffer_size))
	_materials[3].set_shader_parameter("direction",Vector2(1,0))
	_materials[3].set_shader_parameter("first_pass",true)
	_materials[4].set_shader_parameter("source_origin",origin_h)
	_materials[4].set_shader_parameter("source_size",Vector2(bloom_size))
	_materials[4].set_shader_parameter("direction",Vector2(0,1))
	_materials[4].set_shader_parameter("first_pass",false)
	_materials[5].set_shader_parameter("bloom_origin",origin_v)
	_materials[5].set_shader_parameter("bloom_size",Vector2(bloom_size))
	receiver.reset()
	_process(0.0)

func _apply_parameters() -> void:
	if not _built: return
	var linear := get_viewport().use_hdr_2d
	_materials[0].set_shader_parameter("linear_input",linear)
	_materials[5].set_shader_parameter("linear_output",linear)
	for index in [0,1,2]: _materials[index].set_shader_parameter("signal_enabled",_signal)
	_materials[0].set_shader_parameter("interlaced",bool(_knobs.get("ntsc_interlaced",true)) and not _reduced)
	_materials[0].set_shader_parameter("auto_exposure",_knobs.get("ntsc_auto_exposure",0.35))
	_materials[0].set_shader_parameter("brightness",_knobs.get("ntsc_brightness",1.0))
	_materials[0].set_shader_parameter("decoder",_knobs.get("ntsc_decoder",1))
	for key in ["decoder","tape_speed","quality","chroma_bleed","chroma_delay","saturation","sharpness"]:
		_materials[1].set_shader_parameter(key,_knobs.get("ntsc_"+key,_default(key)))
	for key in ["dropouts","dropout_compensation","ghost","ghost_delay","chroma_noise","rf_noise"]:
		_materials[2].set_shader_parameter(key,_knobs.get("ntsc_"+key,_default(key)))
	_materials[2].set_shader_parameter("wear",_wear)
	_materials[2].set_shader_parameter("reduced",_reduced)
	_materials[2].set_shader_parameter("black_level",_knobs.get("ntsc_black_level",0.0))
	_materials[2].set_shader_parameter("caption_data",_knobs.get("ntsc_caption_data",true))
	_materials[5].set_shader_parameter("crt_enabled",_crt)
	_materials[5].set_shader_parameter("curvature_enabled",_curvature)
	_materials[5].set_shader_parameter("interlaced",_knobs.get("ntsc_interlaced",true))
	_materials[5].set_shader_parameter("reduced",_reduced)
	for key in ["quality","mask_type","mask_strength","scanline_strength","bloom","convergence","vignette"]:
		_materials[5].set_shader_parameter(key,_knobs.get("ntsc_"+key,_default(key)))
	_materials[5].set_shader_parameter("diffusion",_knobs.get("ntsc_glass_diffusion",0.08))
	var needs_bloom := _crt and (float(_knobs.get("ntsc_bloom",0.18)) > 0.0 or float(_knobs.get("ntsc_glass_diffusion",0.08)) > 0.0)
	for node in [_bloom_h,_bloom_v,_bloom_copy_h,_bloom_copy_v]: node.visible = needs_bloom

static func _default(key: String) -> Variant:
	var fallback := {"decoder":1,"tape_speed":0,"quality":1,"chroma_bleed":0.5,
		"chroma_delay":1.3,"saturation":0.9,"sharpness":0.25,"dropouts":0.08,
		"dropout_compensation":true,"ghost":0.04,"ghost_delay":2.0,"chroma_noise":0.12,
		"rf_noise":0.02,"mask_type":1,"mask_strength":0.35,"scanline_strength":0.55,
		"bloom":0.18,"convergence":0.2,"vignette":0.18}
	return fallback.get(key,0.0)

func _process(delta: float) -> void:
	if not _built or not visible: return
	var began := Time.get_ticks_usec()
	if _signal or receiver.texture == null:
		receiver.advance(delta,buffer_size.y,_knobs,_stress,_reduced,_wear)
	_materials[2].set_shader_parameter("receiver_rows",receiver.texture)
	_materials[2].set_shader_parameter("stress",0.0 if _reduced else _stress*_wear)
	_materials[2].set_shader_parameter("entity_pos",_entity_pos)
	_materials[2].set_shader_parameter("entity_radius",_entity_radius)
	_materials[2].set_shader_parameter("entity_amount",_entity_amount)
	var dropout := float(_knobs.get("ntsc_dropouts",0.08))
	if receiver.fault_kind == 4: dropout += receiver.fault_amount
	_materials[2].set_shader_parameter("dropouts",dropout)
	for index in [0,1,2,5]: _materials[index].set_shader_parameter("field_index",float(receiver.field_index))
	last_cpu_usec = Time.get_ticks_usec()-began
