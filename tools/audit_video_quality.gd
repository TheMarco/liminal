extends "res://tools/lib/audit_base.gd"
## Headless video budgets through the real settings and presentation host.
const HOST = preload("res://scripts/ntscrt_video_host.gd")
const APPROXIMATION = preload("res://scripts/ntscrt_pipeline.gd")
const CALIBRATION = preload("res://scripts/crt_calibration.gd")
const LIBRARY = preload("res://scripts/video_preset_library.gd")

func configure(host: Control, settings: GameSettings) -> void:
	host.configure_video(settings.values,int(settings.get_value("video_pipeline")),
		bool(settings.get_value("vhs_enabled")),bool(settings.get_value("crt_enabled")),true,false)

func run() -> void:
	check_calibration_migration()
	check_resize_coalescing()
	root.size = Vector2i(1920,1080)
	var settings := GameSettings.new("/tmp/liminal-video-quality-%d.cfg" % OS.get_process_id())
	var host := HOST.new()
	root.add_child(host)
	var approximation := APPROXIMATION.new()
	root.add_child(approximation)
	var signals := [Vector2i(360,240),Vector2i(540,360),Vector2i(720,480),Vector2i(720,480)]
	var outputs := [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]
	for tier in [0,1,2,3,0,3]:
		settings.apply_quality_preset(tier)
		for look in [1,2,3,0]:
			settings.apply_video_look(look)
			var saved := settings.values.duplicate(true)
			configure(host,settings)
			expect(settings.values==saved and settings.matching_video_look()==look,"runtime quality changed the saved look")
			expect(host.presenter.signal_extent==signals[tier],"wrong tape size for tier %d" % tier)
			expect(host.presenter.render_target_size(Vector2i(3840,2160),signals[tier])==outputs[tier],"wrong output budget for tier %d" % tier)
			expect(host.presenter.visible==(look!=0),"Clean did not bypass video work")
			expect(not host.presenter.receiver_enabled,"quality enabled expensive receiver timing")
			expect(host._signal_knobs.scale_with_video_size==(tier<2),"automatic tape damage scaling did not follow/restore the buffer size")
			if look==1:
				var model := "aperture" if tier < 2 else "royale"
				expect(host.presenter.preset_name==model,"Home video's automatic CRT did not follow quality")
				# The host also fills every upstream shader default; verify the
				# authored calibration subset rather than rejecting those defaults.
				for key in GameSettings.HOME_CRT_PARAMETERS[model]:
					expect(is_equal_approx(float(host.presenter.parameters.get(key,NAN)),
						float(GameSettings.HOME_CRT_PARAMETERS[model][key])),"quality changed shadow calibration: "+key)
		approximation.configure(settings.values,true,false,false)
		expect(approximation.buffer_size==signals[tier],"approximation did not resize after a graphics quality change")
	settings.apply_video_look(3)
	settings.apply_quality_preset(3)
	# Explicit lab models must never silently switch with graphics quality.
	for tier in range(4):
		settings.apply_quality_preset(tier)
		for model in [1,6]:
			settings.set_value("crt_shader",model)
			settings.set_value("crt_enabled",true)
			configure(host,settings)
			expect(host.presenter.preset_name==GameSettings.CRT_SHADER_IDS[model],"automatic CRT overrode an explicit developer model")
	settings.apply_video_look(3)
	settings.apply_quality_preset(3)
	settings.set_value("ntsc_quality",0)
	configure(host,settings)
	expect(host.presenter.signal_extent==Vector2i(360,240),"Ultra overrode an explicit Efficient setting")
	settings.set_value("ntsc_quality",1)
	for resolution in [0,1,3,5]:
		settings.set_value("render_resolution",resolution)
		configure(host,settings)
		expect(host.presenter.signal_extent==signals[3] and GraphicsQuality.video_tier(settings.values)==3,
			"Custom graphics unexpectedly changed the previous preset's video budget")
	settings.apply_quality_preset(1)
	settings.set_value("render_resolution",5)
	configure(host,settings)
	expect(host.presenter.signal_extent==signals[1] and host.presenter.output_height_limit==1080,
		"raising Custom world resolution also promoted the video renderer")
	settings.apply_quality_preset(3)
	expect(settings.get_value("video_quality_override")==-1,"selecting a preset did not restore automatic video quality")
	settings.set_value("ntscrt_signal_size",1)
	settings.set_value("ntscrt_signal_width",960.0)
	settings.set_value("ntscrt_scale_mode",2)
	settings.set_value("ntscrs_source_resolution",true)
	configure(host,settings)
	expect(host.presenter.signal_size_mode==1 and host.presenter.signal_width==960
		and host.presenter.source_resolution and host.presenter.presentation_scale==2,"quality lost explicit developer sizing")
	host.presenter.preset_name = "aperture"
	expect(host.presenter.render_target_size(Vector2i(320,180),Vector2i(720,480))==Vector2i(720,480),"tiny window broke the CRT minimum")
	host.presenter.signal_size_mode = 0
	host.presenter.source_resolution = false
	host.presenter.presentation_scale = 0
	host.presenter.signal_extent = Vector2i(720,480)
	expect(host.presenter.effective_signal_size(Vector2i(1280,720))==Vector2i(360,240),"windowed CRT undersampled scanlines")
	expect(host.presenter.effective_signal_size(Vector2i(1920,1080))==Vector2i(540,360),"1080p CRT undersampled scanlines")
	expect(host.presenter.effective_signal_size(Vector2i(3456,2234))==Vector2i(720,480),"Retina CRT lost signal detail")
	host.presenter.presentation_scale = 1
	expect(host.presenter.effective_signal_size(Vector2i(1280,720))==Vector2i(720,480),"explicit original supersampling was changed")
	host.presenter.presentation_scale = 0
	host.presenter.signal_size_mode = 2
	expect(host.presenter.effective_signal_size(Vector2i(1280,720))==host.source.size,"explicit source sizing was changed")
	host.presenter.signal_size_mode = 0
	host.presenter.preset_name = "royale"
	expect(host.presenter.effective_signal_size(Vector2i(1280,720))==Vector2i(720,480),"Royale did not retain its previous signal resolution")
	expect(host.presenter.effective_signal_size(Vector2i(1920,1080))==Vector2i(720,480),"Royale window scaling changed its field cadence")
	host.presenter.preset_name = "none"
	expect(host.presenter.render_target_size(Vector2i(320,180),Vector2i(720,480))==Vector2i(320,180),"small recording window was supersampled")
	expect(host.presenter.effective_signal_size(Vector2i(1280,720))==Vector2i(720,480),"tape-only processing was changed by CRT sizing")
	expect(GraphicsQuality.video_signal_size({})==Vector2i(720,480),"standalone reference callers lost original sizing")
	approximation.free()
	host.free()
	finish("video quality tiers, look preservation, restoration, custom graphics and developer overrides")

func check_resize_coalescing() -> void:
	var presenter := HOST.PRESENTER.new()
	expect(presenter._layout_ready("1280x720",1000),"initial video setup was delayed")
	expect(not presenter._layout_ready("1281x720",2000),"one-pixel resize rebuilt video immediately")
	expect(not presenter._layout_ready("1372x803",150000),"drag did not reset resize debounce")
	expect(not presenter._layout_ready("1372x803",300000),"unstable dimensions rebuilt video")
	expect(presenter._layout_ready("1372x803",350000),"settled resize was never admitted")
	expect(not presenter._layout_ready("1280x720",400000),"next resize bypassed debounce")
	expect(presenter._layout_ready("1372x803",410000),"returning to current layout stalled playback")
	expect(presenter._pending_layout.is_empty(),"cancelled resize remained queued")
	presenter.free()

func check_calibration_migration() -> void:
	check_royale_restoration()
	var previous := {
		15:{"SCANLINE_CUTOFF":400.0,"SCANLINE_STRENGTH":0.35,"SCANLINE_BRIGHT_MIN":0.5,"SCANLINE_BRIGHT_MAX":0.8},
		18:{"SCANLINES_CUTOFF":400.0,"SCANLINES_STRENGTH":0.3},
		19:{"CRTMask_Scale":1.0,"Tuning_Mask_Brightness":0.5,"Tuning_Mask_Opacity":0.0,"mask_toggle":0.0},
	}
	for index in previous:
		var profile := LIBRARY.make_profile(index)
		var model := profile.selected_crt_model()
		var expected := profile.active_crt_parameters()
		var old := expected.duplicate(true)
		old.merge(previous[index],true)
		var saved := {model:old}
		var result := CALIBRATION.upgrade_saved(saved)
		expect(result[model]==expected,"old authored CRT did not upgrade: "+model)
		expect(saved[model]==old and saved!=result,"upgrade mutated source settings")
		expect(CALIBRATION.upgrade_saved(result)==result,"CRT upgrade is not idempotent")
		# An intentionally changed model stays exactly as authored.
		old[previous[index].keys()[0]] += 0.001
		expect(CALIBRATION.upgrade_saved(saved)==saved,"custom CRT tuning was overwritten")
	var path := "/tmp/liminal-old-crt-%d.cfg"%OS.get_process_id()
	var config := ConfigFile.new()
	config.set_value("settings","crt_shader_parameters",CALIBRATION.LEGACY_HOME)
	config.set_value("settings","render_resolution",5)
	config.set_value("settings","show_fps",true)
	config.save(path)
	var loaded := GameSettings.new(path)
	expect(loaded.get_value("crt_shader_parameters")==CALIBRATION.DEFAULTS,"old Home CRT did not upgrade on load")
	expect(loaded.get_value("show_fps") and loaded.get_value("render_resolution")==5,"CRT upgrade changed unrelated preferences")
	DirAccess.remove_absolute(path)

func check_royale_restoration() -> void:
	var automatic: Dictionary = {}
	for key: String in GameSettings.crt_presets().royale.parameters:
		automatic[key] = GameSettings.crt_presets().royale.parameters[key].default
	automatic.merge(CALIBRATION.LEGACY_HOME.royale,true)
	var authored := LIBRARY.make_profile(14).active_crt_parameters()
	expect(is_equal_approx(float(authored.mask_type),2.0),"authored Royale did not use mask type 2")
	# The rollback fixture predates the new default mask; saved choices persist.
	authored.mask_type = 1.0
	expect(is_equal_approx(float(automatic.interlace_detect_toggle),1.0)
		and is_equal_approx(float(automatic.beam_max_sigma),0.3),"automatic Royale baseline changed")
	expect(is_equal_approx(float(authored.interlace_detect_toggle),1.0)
		and is_equal_approx(float(authored.beam_max_sigma),0.32),"authored Royale baseline changed")
	var path := "/tmp/liminal-restore-royale-%d.cfg"%OS.get_process_id()
	for expected: Dictionary in [automatic,authored,CALIBRATION.LEGACY_HOME.royale]:
		var rejected := expected.duplicate(true)
		rejected.merge({"interlace_detect_toggle":0.0,"beam_max_sigma":0.28},true)
		var saved := {"royale":rejected,"aperture":{"MASK_STRENGTH":0.123}}
		var result := CALIBRATION.upgrade_saved(saved)
		expect(result.royale==expected,"rejected Royale tuning was not restored")
		expect(saved.royale==rejected and saved!=result,"Royale restoration mutated its input")
		expect(result.aperture==saved.aperture,"Royale restoration changed another model")
		expect(CALIBRATION.upgrade_saved(result)==result,"Royale restoration is not idempotent")
		var config := ConfigFile.new()
		config.set_value("settings","crt_shader_parameters",saved)
		config.set_value("settings","render_resolution",5)
		config.set_value("settings","show_fps",true)
		config.save(path)
		var loaded := GameSettings.new(path)
		expect(loaded.get_value("crt_shader_parameters").royale==expected,"saved Royale was not restored on load")
		expect(loaded.get_value("show_fps") and loaded.get_value("render_resolution")==5,"Royale restoration changed unrelated preferences")
		saved.royale.beam_max_sigma = 0.281
		expect(CALIBRATION.upgrade_saved(saved)==saved,"deliberate custom Royale was overwritten")
	DirAccess.remove_absolute(path)
