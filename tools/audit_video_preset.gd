extends SceneTree
const BRIDGE = preload("res://scripts/video_preset_bridge.gd")
const LIBRARY = preload("res://scripts/video_preset_library.gd")
const IO = preload("res://scripts/video_preset_io.gd")
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); printerr(label)
func _initialize() -> void:
	var settings := GameSettings.new("/tmp/liminal-preset-unit-%d.cfg" % OS.get_process_id())
	settings.apply_tape_look(3)
	settings.set_value("crt_enabled",true)
	settings.set_value("crt_shader",6)
	settings.set_crt_parameter("royale","lcd_gamma",3.1)
	settings.set_video_parameter("ntscrs","luma_smear",0.71)
	settings.set_video_parameter("receiver","tracking",0.2)
	settings.set_value("receiver_enabled",true)
	for index in LIBRARY.LOOKS.size():
		var isolated := GameSettings.new("/tmp/liminal-curated-bridge-%d-%d.cfg" % [OS.get_process_id(),index])
		BRIDGE.apply(LIBRARY.make_profile(index),isolated)
		check(LIBRARY.matching_index(BRIDGE.from_settings(isolated))==index,"Reopening workshop lost look name: "+str(index))
	var profile := BRIDGE.from_settings(settings)
	var parsed := IO.decode(JSON.parse_string(JSON.stringify(IO.encode(profile,"Game preset"))))
	check(parsed.error.is_empty(),"Game JSON decode")
	var loaded: NtscrtProfile = parsed.profile
	BRIDGE.apply(loaded,settings)
	check(not settings.get_value("ntsc_auto_faults"),"Portable preset must own its glitch schedule")
	check(settings.get_value("crt_shader")==6,"CRT model roundtrip")
	check(is_equal_approx(settings.get_value("crt_shader_parameters").royale.lcd_gamma,3.1),"CRT parameter roundtrip")
	check(is_equal_approx(settings.get_value("ntscrs_settings").luma_smear,0.71),"NTSC roundtrip")
	check(is_equal_approx(settings.get_value("receiver_settings").tracking,0.2),"Receiver base values scaled twice")
	check(loaded.receiver_tape_coupling,"Game wear coupling lost")
	check(is_equal_approx(loaded.receiver_settings().tracking,0.2*loaded.tape_damage*2.0),"Receiver wear coupling")
	loaded.color_saturation = 0.0
	loaded.color_temperature = -0.2
	loaded.color_shadow_lift = 0.025
	loaded.quality = 3
	loaded.auto_world_resolution = false
	BRIDGE.apply(loaded,settings)
	check(BRIDGE.from_settings(settings).color_saturation==0.0 and BRIDGE.from_settings(settings).color_shadow_lift==0.025,"Camera response bridge roundtrip")
	check(GraphicsQuality.video_tier(settings.values)==3,"Independent video budget")
	settings.set_value("render_resolution",5)
	check(GraphicsQuality.resolution_index(settings,true,true)==5,"Manual world resolution")
	var explicit_budget: int = settings.get_value("video_quality_override")
	settings.apply_quality_preset(1)
	check(settings.get_value("video_quality_override")==explicit_budget and GraphicsQuality.video_tier(settings.values)==explicit_budget,"World mode moved the explicit video budget")
	check(settings.get_value("quality_preset")==1,"World mode selection lost")
	settings.set_value("reduced_flashing",true)
	var context := {"game":"liminal","game_settings":BRIDGE.capture_settings(settings)}
	check(context.game_settings.has("crt_shader_parameters") and context.game_settings.has("receiver_settings") and context.game_settings.has("quality_preset"),"Incomplete game settings context")
	check(context.game_settings.has("render_resolution") and context.game_settings.has("hdr_brightness"),"Capture lost world context for inspection")
	check(not context.game_settings.has("sensitivity") and not context.game_settings.has("music_volume"),"Unrelated game settings captured")
	var before := {}
	for key in GameSettings.QUALITY_KEYS + ["quality_preset","hdr_enabled","hdr_brightness","field_of_view","head_bob","handheld_camera","handheld_strength","sensitivity","dialogue_volume","reduced_flashing"]:
		before[key] = settings.get_value(key)
	BRIDGE.apply(LIBRARY.make_profile(0),settings)
	for key in before:
		check(settings.get_value(key)==before[key],"Portable look import overrode "+key)
	BRIDGE.apply_camera_look(1, settings)
	var camcorder_file := IO.encode(BRIDGE.from_settings(settings))
	check(IO.decode(camcorder_file).profile.pipeline == GameSettings.VIDEO_CAMCORDER, "Camcorder file changed recording renderer")
	camcorder_file.settings.erase("pipeline")
	check(IO.decode(camcorder_file).profile.pipeline == 2, "Older portable files lost their full signal renderer")
	settings.set_value("video_quality_override",0)
	settings.save_to_disk()
	var reloaded := GameSettings.new("/tmp/liminal-preset-unit-%d.cfg" % OS.get_process_id())
	check(BRIDGE.matching_camera_look(IO.encode(BRIDGE.from_settings(reloaded)).settings)==1,"Saved file lost the Camcorder look")
	check(reloaded.get_value("video_quality_override")==0 and GraphicsQuality.video_tier(reloaded.values)==0,"Saved file lost the independent video budget")
	DirAccess.remove_absolute("/tmp/liminal-preset-unit-%d.cfg" % OS.get_process_id())
	settings.apply_tape_look(0)
	check(settings.get_value("video_color_saturation")==1.0 and settings.get_value("video_color_shadow_lift")==0.0,"Clean left camera grading active")
	print("VIDEO_PRESET_AUDIT ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
