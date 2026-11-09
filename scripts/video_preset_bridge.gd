extends RefCounted
## Shared JSON schema; game-only render/camera controls are captured as context.
const PROFILE = preload("res://scripts/video_preset_profile.gd")
const MAP := {
	"ambient_fault_rate":"video_fault_rate", "ambient_fault_strength":"video_fault_strength",
	"ambient_fault_kind":"video_fault_kind",
	"color_saturation":"video_color_saturation", "color_temperature":"video_color_temperature",
	"color_shadow_lift":"video_color_shadow_lift",
	"tape_damage":"vhs_distortion", "film_grain":"film_grain", "crt_enabled":"crt_enabled",
	"reduced_flashing":"reduced_flashing", "receiver_enabled":"receiver_enabled",
	"receiver_tape_coupling":"receiver_tape_coupling",
	"field_history":"ntscrs_field_history", "source_resolution":"ntscrs_source_resolution",
	"downscale_filter":"ntscrt_downscale_filter", "signal_size_mode":"ntscrt_signal_size",
	"signal_width":"ntscrt_signal_width", "presentation_scale":"ntscrt_scale_mode",
	"auto_world_resolution":"video_auto_resolution",
}
const SCENE_KEYS := ["render_resolution","anti_aliasing","shadow_quality","global_illumination",
	"ambient_occlusion","reflections","volumetric_fog","hdr_enabled","hdr_brightness",
	"field_of_view","head_bob","handheld_camera","handheld_strength"]

static func from_settings(settings: GameSettings) -> NtscrtProfile:
	var profile := PROFILE.new()
	var look := settings.matching_tape_look()
	profile.tape = maxi(1,look) if bool(settings.get_value("vhs_enabled")) else 0
	for key: String in MAP: profile.set(key,settings.get_value(MAP[key]))
	profile.quality = GraphicsQuality.video_tier(settings.values)
	var model := int(settings.get_value("crt_shader"))
	profile.crt_model = model if model in range(1,8) else 0
	profile.ntsc_overrides = GameSettings.FULL_SETTINGS.sanitize_ntsc(settings.get_value("ntscrs_settings"))
	profile.receiver_overrides = GameSettings.FULL_SETTINGS.sanitize_receiver(settings.get_value("receiver_settings"))
	var models := {}
	# Make the game's shared calibration explicit before saved overrides.
	for name: String in PROFILE.CRT_NAMES.slice(1):
		var knobs := {}
		for key: String in PROFILE.crt_descriptors(name):
			knobs[key] = PROFILE.crt_descriptors(name)[key].default
		knobs.merge(PROFILE.CRT_CALIBRATION.get(name,{}),true)
		knobs.merge(settings.get_value("crt_shader_parameters").get(name,{}),true)
		models[name] = knobs
	profile.crt_parameters = models
	return profile

static func apply(profile: NtscrtProfile, settings: GameSettings) -> void:
	var next := settings.values.duplicate(true)
	for key: String in MAP: next[MAP[key]] = profile.get(key)
	next.video_pipeline = 2
	# The portable look owns recurring defects. Keep legacy random tape faults
	# from adding VHS glitches to clean digital captures; encounter cues remain.
	next.ntsc_auto_faults = false
	next.vhs_enabled = profile.tape!=PROFILE.Tape.OFF
	next.crt_shader = GameSettings.CRT_AUTOMATIC if profile.crt_model==0 else profile.crt_model
	next.video_quality_override = profile.quality
	next.ntsc_quality = 1
	next.ntscrs_settings = profile.canonical_ntsc_settings()
	next.receiver_settings = GameSettings.FULL_SETTINGS.sanitize_receiver(profile.receiver_overrides)
	next.crt_shader_parameters = {}
	for model: String in PROFILE.CRT_NAMES.slice(1):
		next.crt_shader_parameters[model] = profile.canonical_crt_parameters(model)
	if next!=settings.values:
		settings.values = next
		settings.changed.emit()

static func capture_settings(settings: GameSettings) -> Dictionary:
	var result := {}
	for key: String in GameSettings.DEFAULTS:
		if key in SCENE_KEYS or key.begins_with("ntsc") or key.begins_with("receiver_") or key.begins_with("crt_") or key.begins_with("video_") or key in ["vhs_enabled","vhs_distortion","film_grain","quality_preset","reduced_flashing"]:
			result[key] = settings.get_value(key)
	return result.duplicate(true)

static func restore_scene_context(context: Dictionary, settings: GameSettings) -> void:
	# Shared profile fields remain authoritative when a game capture has since
	# been edited in the standalone workshop. Restore only game-specific extras.
	if context.get("game")!="liminal" or not context.get("game_settings") is Dictionary: return
	settings.set_block_signals(true)
	for key: String in SCENE_KEYS:
		if not context.game_settings.has(key): continue
		var value: Variant = context.game_settings[key]
		if GameSettings.ENUM_VALUES.has(key) and (value is int or value is float):
			if not is_finite(float(value)) or float(value)!=floor(float(value)): continue
			value = int(value)
		settings.set_value(key,value)
	settings.set_block_signals(false)
	settings.changed.emit()
