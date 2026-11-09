extends "res://scripts/screen_ui.gd"
const PANEL = preload("res://scripts/video_preset_workshop_panel.gd")
const BRIDGE = preload("res://scripts/video_preset_bridge.gd")
signal closed
var panel: Control
var settings: GameSettings
var host: Control
var _layout: Control
var _cue: Dictionary = {}
var _cue_time := 0.0

func setup(model: GameSettings, video_host: Control) -> void:
	settings = model
	host = video_host
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 115
	_layout = Control.new()
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout)
	panel = PANEL.new()
	panel.profile = BRIDGE.from_settings(settings)
	panel.allow_close = true
	panel.apply_profile = func(value: NtscrtProfile):
		_cue.clear()
		BRIDGE.apply(value,settings)
		if host.presenter!=null: host.set_game_state(0.0,Vector2(0.5,0.5),0.0,0.0)
	panel.capture_image = _capture_image
	panel.capture_context = func(): return {
		"game":"liminal","game_settings":BRIDGE.capture_settings(settings),
		"source_width":host.source.size.x,"source_height":host.source.size.y,
		"world_scale":host.source.scaling_3d_scale}
	panel.restore_context = func(context: Dictionary): BRIDGE.restore_scene_context(context,settings)
	panel.renderer_error = func(): return host.presenter.last_error if host.presenter!=null else ""
	panel.play_glitch = _play_glitch
	panel.preview_damage = func():
		if host.presenter!=null: host.presenter.preview_ambient_fault()
	panel.closed.connect(func(): closed.emit())
	_layout.add_child(panel)
	host.get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var extent := host.get_viewport().get_visible_rect().size
	var ui_scale := maxf(1.0,minf(extent.y/900.0,extent.x/1440.0))
	_layout.size = extent/ui_scale
	_layout.scale = Vector2.ONE*ui_scale

func _capture_image() -> Image:
	visible = false
	for frame in 4:
		await get_tree().process_frame
		RenderingServer.force_draw()
	var image := host.get_viewport().get_texture().get_image()
	visible = true
	return image

func _play_glitch(identifier: String,duration: float) -> void:
	if not bool(settings.get_value("vhs_enabled")) or bool(settings.get_value("reduced_flashing")): return
	_cue = {"sequence":identifier,"duration":duration}
	_cue_time = 0.0

func _process(delta: float) -> void:
	if _cue.is_empty(): return
	_cue_time += delta
	var phase := clampf(_cue_time/float(_cue.duration),0.0,1.0)
	if phase>=1.0:
		_cue.clear()
		host.set_game_state(0.0,Vector2(0.5,0.5),0.0,0.0)
	else:
		host.set_game_state(0.0,Vector2(0.5,0.5),0.0,0.0,{
			"kind":0,"amount":smoothstep(0.0,0.12,phase)*(1.0-smoothstep(0.25,1.0,phase)),
			"phase":phase,"origin":0.6,"sequence":_cue.sequence,"sequence_strength":1.0})

func _input(event: InputEvent) -> void:
	if visible and PauseMenu.is_pause_event(event) and not panel._load_dialog.visible:
		panel.close()
		host.get_viewport().set_input_as_handled()
