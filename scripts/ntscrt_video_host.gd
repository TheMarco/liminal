extends Control
## Stable scene viewport: switching CRT models never reparents a running game.
const PRESENTER = preload("res://scripts/ntscrt_gpu_presenter.gd")
const SEQUENCES = preload("res://scripts/ntscrt_glitch_sequences.gd")
signal pipeline_failed(message: String)
var source: SubViewport
var presenter: TextureRect
var _container: SubViewportContainer
var _classic_tube: Control
var _native_tube: Control
var _signal_knobs: Dictionary = {}
var _receiver_knobs: Dictionary = {}
var _reduced := false
var _wear := 1.0
var _title_covered := false
var _suspended := false
var _gpu_failed := false
var _gpu_wanted := false
var _classic_wanted := false
var _native_wanted := false
var _warmup_frames := 0
var _warmup_ready_after := 0

func _ready() -> void:
	SEQUENCES.prepare()
	name = "VideoHost"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_container)
	source = SubViewport.new()
	source.name = "GameFrame"
	source.own_world_3d = true
	source.use_hdr_2d = get_viewport().use_hdr_2d
	source.audio_listener_enable_3d = true
	source.positional_shadow_atlas_size = get_viewport().positional_shadow_atlas_size
	source.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(source)

func attach(game: Node) -> void:
	game.set_meta("ntscrt_video_host",self)
	source.add_child(game)
	# Main normally inherits pause from the SceneTree, not this always-running
	# presentation host. Explicitly preserve that behavior.
	if game.process_mode == Node.PROCESS_MODE_INHERIT: game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.tree_exited.connect(queue_free)

func set_title_covered(covered: bool) -> void:
	if _title_covered == covered: return
	_title_covered = covered
	# Prepare a couple of frames before sleeping. Otherwise the expensive first
	# shader use would simply move from startup to the player's first click.
	_request_warmup()

func _request_warmup() -> void:
	_suspended = false
	_warmup_frames = 0
	_warmup_ready_after = presenter.ready_frames + 2 if presenter != null else 0
	_apply_visibility()

func _process(_delta: float) -> void:
	if not _title_covered or _suspended: return
	_warmup_frames += 1
	if _gpu_wanted and not _gpu_failed and presenter != null:
		if presenter.ready_frames < _warmup_ready_after: return
	elif _warmup_frames < 3:
		return
	_suspended = true
	_apply_visibility()
	RuntimeDiagnostics.mark("title_render_suspended")

func _apply_visibility() -> void:
	if source == null: return
	# Keep allocated render buffers alive; only stop drawing them. Toggling
	# disable_3d would risk rebuilding those buffers when play resumes.
	source.render_target_update_mode = SubViewport.UPDATE_DISABLED if _suspended else SubViewport.UPDATE_ALWAYS
	if presenter != null: presenter.visible = _gpu_wanted and not _suspended and not _gpu_failed
	if _classic_tube != null: _classic_tube.visible = _classic_wanted and not _suspended and not _gpu_failed
	if _native_tube != null:
		_native_tube.visible = _native_wanted and not _suspended and not _gpu_failed
		_native_tube.set_process(not _suspended and not _gpu_failed)

func _on_pipeline_failed(message: String) -> void:
	_gpu_failed = true
	_apply_visibility()
	pipeline_failed.emit(message)

func configure_video(settings: Dictionary, pipeline: int, signal_on: bool, crt_on: bool, presentation_on: bool, curved: bool) -> void:
	var model := GraphicsQuality.crt_model(settings)
	var full_signal := signal_on and pipeline == 2
	var receiver_on := presentation_on and bool(settings.get("receiver_enabled",false))
	var original_crt := crt_on and model in range(1,8)
	var gpu := (full_signal or receiver_on or original_crt) and not _gpu_failed
	_gpu_wanted = gpu
	_reduced = bool(settings.get("reduced_flashing",false))
	_wear = clampf(float(settings.get("vhs_distortion",0.5))*2.0,0.0,2.0)
	if gpu and presenter == null:
		presenter = PRESENTER.new()
		presenter.source = source
		presenter.visible = false
		presenter.pipeline_failed.connect(_on_pipeline_failed)
		add_child(presenter)
	if presenter != null:
		presenter.visible = gpu
		presenter.signal_enabled = full_signal
		presenter.receiver_enabled = receiver_on
		presenter.configure_ambient_faults(float(settings.get("video_fault_rate",0.0)),
			float(settings.get("video_fault_strength",0.5))*_wear,int(settings.get("video_fault_kind",2)),
			_reduced or not full_signal)
		presenter.signal_extent = GraphicsQuality.video_signal_size(settings)
		presenter.output_height_limit = GraphicsQuality.video_output_height(settings)
		presenter.signal_size_mode = int(settings.get("ntscrt_signal_size",0))
		presenter.signal_width = int(settings.get("ntscrt_signal_width",720))
		presenter.downscale_method = int(settings.get("ntscrt_downscale_filter",0))-1
		presenter.source_resolution = bool(settings.get("ntscrs_source_resolution",false))
		presenter.presentation_scale = int(settings.get("ntscrt_scale_mode",0))
		presenter.preset_name = GameSettings.CRT_SHADER_IDS[model] if original_crt else "none"
		# Send defaults too, so removing a workshop override resets the live shader.
		presenter.parameters = {}
		if original_crt:
			for key: String in GameSettings.crt_presets()[presenter.preset_name].parameters:
				presenter.parameters[key] = GameSettings.crt_presets()[presenter.preset_name].parameters[key].default
		presenter.parameters.merge(GameSettings.HOME_CRT_PARAMETERS.get(presenter.preset_name,{}),true)
		presenter.parameters.merge(settings.get("crt_shader_parameters",{}).get(presenter.preset_name,{}),true)
		_signal_knobs = GameSettings.FULL_SETTINGS.sanitize_ntsc(settings.get("ntscrs_settings",{}))
		# Automatic smaller buffers retain the same relative tape damage and
		# bandwidth. Otherwise Low doubles defect sizes and excessive blur.
		# Explicit custom/source-size processing retains the original controls.
		if presenter.signal_size_mode == 0 and not presenter.source_resolution and presenter.signal_extent.y < 480:
			_signal_knobs["scale_with_video_size"] = true
		_signal_knobs["field_history"] = bool(settings.get("ntscrs_field_history",false)) and not _reduced
		_receiver_knobs = GameSettings.FULL_SETTINGS.sanitize_receiver(settings.get("receiver_settings",{}))
		for key in ["composite_noise_intensity","luma_noise_intensity","chroma_noise_intensity","snow_intensity","chroma_phase_noise_intensity","vhs_edge_wave","vhs_chroma_loss","head_switching_horizontal_shift","tracking_noise_wave_intensity","tracking_noise_snow_intensity","tracking_noise_noise_intensity"]:
			_signal_knobs[key] = float(_signal_knobs[key])*_wear
		if bool(settings.get("receiver_tape_coupling",true)):
			for key in ["head_switch","timebase_jitter","crinkle","head_clog","tracking","dropouts"]: _receiver_knobs[key] = float(_receiver_knobs[key])*_wear
		if _reduced:
			_signal_knobs["use_field"] = 3
			for key in ["head_switching","tracking_noise","vhs_edge_wave_enabled","composite_noise","luma_noise","chroma_noise"]: _signal_knobs[key] = false
			for key in ["snow_intensity","vhs_chroma_loss","chroma_phase_noise_intensity"]: _signal_knobs[key] = 0.0
			for key in ["head_switch","timebase_jitter","crinkle","head_clog","tracking","dropouts","horizontal_hold","vertical_hold","hum"]: _receiver_knobs[key] = 0.0
			_receiver_knobs["signal_strength"] = 1.0
		set_game_state(0.0,Vector2(0.5,0.5),0.0,0.0)
	var native := crt_on and not _gpu_failed and (model == 8 or (model == 0 and gpu and pipeline == 1))
	var classic := crt_on and not _gpu_failed and model == 0 and gpu and pipeline != 1
	_native_wanted = native
	_classic_wanted = classic
	if classic and _classic_tube == null:
		_classic_tube = PostProcessController.add_crt_display_pass(self,PostProcessController.FOUND_FOOTAGE_RESOLUTION,curved)
	if _classic_tube != null:
		_classic_tube.visible = classic
		(_classic_tube.get_node("Display").material as ShaderMaterial).set_shader_parameter("curvature_enabled",curved)
	if native and _native_tube == null:
		_native_tube = preload("res://scripts/ntscrt_pipeline.gd").new()
		add_child(_native_tube)
	if _native_tube != null:
		_native_tube.visible = native
		_native_tube.configure(settings,false,true,curved)
	# Lazy construction order must not put a newly created presenter above the
	# final native/classic tube when changing combinations during gameplay.
	if _classic_tube != null: move_child(_classic_tube,get_child_count()-1)
	if _native_tube != null: move_child(_native_tube,get_child_count()-1)
	if _title_covered: _request_warmup()
	else: _apply_visibility()

func set_game_state(stress: float, position: Vector2, radius: float, amount: float, fault: Dictionary = {}) -> void:
	if presenter == null: return
	stress = 0.0 if _reduced else stress*_wear
	var signal_values := _signal_knobs.duplicate()
	var receiver_values := _receiver_knobs.duplicate()
	if stress > 0.0:
		signal_values["composite_noise"] = true
		signal_values["composite_noise_intensity"] = maxf(float(signal_values.get("composite_noise_intensity",0.0)),stress*0.15)
		signal_values["chroma_phase_noise_intensity"] = maxf(float(signal_values.get("chroma_phase_noise_intensity",0.0)),stress*0.06)
		receiver_values["signal_strength"] = minf(float(receiver_values.get("signal_strength",1.0)),1.0-stress*0.5)
		receiver_values["tracking"] = maxf(float(receiver_values.get("tracking",0.0)),stress*0.22)
	if not _reduced and presenter.signal_enabled:
		SEQUENCES.apply_to(signal_values,str(fault.get("sequence","")),
			float(fault.get("phase",0.0)),float(fault.get("sequence_strength",0.0))*_wear)
	presenter.signal_settings = signal_values
	presenter.receiver_settings = receiver_values
	presenter.game_state = {"entity_x":position.x,"entity_y":position.y,"entity_radius":radius,"entity_amount":0.0 if _reduced else amount*_wear,"field_index":floor(presenter._clock*60000.0/1001.0)}
	# Transient faults use the existing GPU preparation pass, never the costly
	# receiver timing simulation. Keep kind/phase instead of reducing to noise.
	presenter.game_state.merge({"fault_kind":float(fault.get("kind",0)),
		"fault_amount":0.0 if _reduced or not presenter.signal_enabled else clampf(float(fault.get("amount",0.0))*_wear,0.0,1.0),
		"fault_phase":float(fault.get("phase",0.0)),"fault_origin":float(fault.get("origin",0.5))})
