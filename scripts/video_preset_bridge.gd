extends RefCounted
## Shared JSON schema; game-only render/camera controls are captured as context.
const PROFILE = preload("res://scripts/video_preset_profile.gd")
const LIBRARY = preload("res://scripts/video_preset_library.gd")
const CAMERA_NAMES := ["Clean", "Camcorder", "VHS on TV"]
const CAMERA_RECIPES := [0, 3, 14]
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
	"pipeline":"video_pipeline",
}
const SCENE_KEYS := GameSettings.QUALITY_KEYS + ["hdr_enabled","hdr_brightness",
	"field_of_view","head_bob","handheld_camera","handheld_strength"]

static func from_settings(settings: GameSettings, overrides: Dictionary = {}) -> NtscrtProfile:
	var profile := PROFILE.new()
	var look := settings.matching_tape_look(overrides)
	profile.tape = maxi(1,look) if bool(overrides.get("vhs_enabled",settings.get_value("vhs_enabled"))) else 0
	for key: String in MAP: profile.set(key,overrides.get(MAP[key],settings.get_value(MAP[key])))
	profile.quality = GraphicsQuality.video_tier(settings.values)
	var model := int(settings.get_value("crt_shader"))
	profile.crt_model = model if model in range(1,8) else 0
	profile.ntsc_overrides = GameSettings.FULL_SETTINGS.sanitize_ntsc(settings.get_value("ntscrs_settings"))
	profile.receiver_overrides = GameSettings.FULL_SETTINGS.sanitize_receiver(settings.get_value("receiver_settings"))
	var models := {}
	# Make the game's shared calibration explicit before saved overrides.
	for name: String in PROFILE.CRT_NAMES.slice(1):
		var knobs := {}
		var descriptors := PROFILE.crt_descriptors(name)
		for key: String in descriptors:
			knobs[key] = descriptors[key].default
		knobs.merge(PROFILE.CRT_CALIBRATION.get(name,{}),true)
		knobs.merge(settings.get_value("crt_shader_parameters").get(name,{}),true)
		models[name] = knobs
	profile.crt_parameters = models
	return profile

static func apply_camera_look(index: int, settings: GameSettings, notify := true) -> void:
	if index < 0 or index >= CAMERA_RECIPES.size(): return
	var profile := LIBRARY.make_profile(CAMERA_RECIPES[index])
	if index == 1: profile.pipeline = GameSettings.VIDEO_CAMCORDER
	profile.quality = GraphicsQuality.video_tier(settings.values)
	apply(profile, settings, notify)

static func matching_camera_look(snapshot: Dictionary) -> int:
	var library_settings := snapshot
	if snapshot.pipeline == GameSettings.VIDEO_CAMCORDER:
		library_settings = snapshot.duplicate()
		library_settings.pipeline = 2
	var index := CAMERA_RECIPES.find(LIBRARY.matching_settings(library_settings))
	if index < 0 or snapshot.pipeline != (GameSettings.VIDEO_CAMCORDER if index == 1 else 2): return -1
	return index

static func apply(profile: NtscrtProfile, settings: GameSettings, notify := true) -> bool:
	var next := settings.values.duplicate(true)
	for key: String in MAP:
		if key != "reduced_flashing": next[MAP[key]] = profile.get(key)
	# The portable width is an integer; the game's saved slider uses a float.
	next.ntscrt_signal_width = float(profile.signal_width)
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
	if next == settings.values: return false
	settings.values = next
	if notify: settings.changed.emit()
	return true

static func capture_settings(settings: GameSettings) -> Dictionary:
	var result := {}
	for key: String in GameSettings.DEFAULTS:
		if key in SCENE_KEYS or key.begins_with("ntsc") or key.begins_with("receiver_") or key.begins_with("crt_") or key.begins_with("video_") or key in ["vhs_enabled","vhs_distortion","film_grain","quality_preset","reduced_flashing"]:
			result[key] = settings.get_value(key)
	return result.duplicate(true)
