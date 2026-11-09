class_name GraphicsQuality
extends RefCounted
## Runtime quality overrides layered onto authored floor environments. Never
## rebuild world geometry or alter a floor's palette/exposure to change quality.

const RESOLUTION_HEIGHTS := [360.0, 480.0, 720.0, 1080.0, 1440.0, 0.0]
const VIDEO_SIGNAL_SIZES := [Vector2i(360,240), Vector2i(540,360), Vector2i(720,480), Vector2i(720,480)]
const VIDEO_OUTPUT_HEIGHTS := [720,1080,1440,0]
const AUTHORED_META := &"_quality_authored_environment"
const AUTHORED_KEYS := ["sdfgi_enabled", "sdfgi_cascades", "sdfgi_min_cell_size",
	"ssao_enabled", "ssr_enabled", "ssr_max_steps", "volumetric_fog_enabled"]

## World effects follow the lighting budget even with a custom resolution or
## video look. Changing CRT/tape quality must not rebuild the room's particles.
static func atmosphere_tier(values: Dictionary) -> int:
	return clampi(int(values.get("shadow_quality", 1)), 0, 3)

## Walls must occlude fixture light on every tier, including specular highlights.
## Quality scales the atlas/filter, never whether a source shines through walls.
## The authored tier is retained as metadata for source audits.
static func configure_practical_light(light: Light3D, shadow_tier: int) -> void:
	light.set_meta("practical_shadow_tier", shadow_tier)
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = light.distance_fade_begin
	var values: Dictionary = GameSettings.current.values if GameSettings.current != null else {"shadow_quality":2}
	apply_practical_light(light, values)

static func apply_practical_light(light: Light3D, _values: Dictionary) -> void:
	if not light.has_meta("practical_shadow_tier"): return
	light.shadow_enabled = true
	light.shadow_opacity = 1.0
	# Fading the blocker earlier than the source reintroduces phantom highlights.
	light.distance_fade_shadow = light.distance_fade_begin

static func video_tier(values: Dictionary) -> int:
	var explicit := int(values.get("video_quality_override",-1))
	if explicit in range(4): return explicit
	# Standalone/reference callers without game quality retain original sizing.
	var preset := int(values.get("quality_preset",3))
	if preset in range(4): return preset
	# Custom keeps a predictable budget based on the saved world resolution.
	# The look's temporary world cap must not promote/demote the video tier.
	return [0,1,2,2,2,3][clampi(int(values.get("render_resolution",1)),0,5)]

static func video_signal_size(values: Dictionary) -> Vector2i:
	# The developer's Efficient choice can reduce the budget further. Explicit
	# custom/source sizing still takes precedence in the GPU presenter.
	if int(values.get("ntsc_quality",1)) == 0: return VIDEO_SIGNAL_SIZES[0]
	return VIDEO_SIGNAL_SIZES[video_tier(values)]

static func video_output_height(values: Dictionary) -> int:
	return VIDEO_OUTPUT_HEIGHTS[video_tier(values)]

static func crt_model(values: Dictionary) -> int:
	var selected := int(values.get("crt_shader",0))
	if selected != GameSettings.CRT_AUTOMATIC: return selected
	return 6 if video_tier(values) >= 2 else 1

static func apply_environment(environment: Environment, settings: GameSettings) -> void:
	if environment == null or settings == null:
		return
	if not environment.has_meta(AUTHORED_META):
		var authored := {}
		for key in AUTHORED_KEYS:
			authored[key] = environment.get(key)
		environment.set_meta(AUTHORED_META, authored)
	var base: Dictionary = environment.get_meta(AUTHORED_META)
	var gi := int(settings.get_value("global_illumination"))
	# Configure before enabling: switching from Low to Ultra should allocate
	# only the destination GI grid, rather than an intermediate one.
	environment.sdfgi_cascades = 2 if gi == 1 else int(base.sdfgi_cascades)
	environment.sdfgi_min_cell_size = 0.3 if gi == 1 else float(base.sdfgi_min_cell_size)
	environment.sdfgi_enabled = bool(base.sdfgi_enabled) and gi > 0
	environment.ssao_enabled = bool(base.ssao_enabled) and int(settings.get_value("ambient_occlusion")) > 0
	var reflections := int(settings.get_value("reflections"))
	environment.ssr_max_steps = mini(16, int(base.ssr_max_steps)) if reflections == 1 else int(base.ssr_max_steps)
	environment.ssr_enabled = bool(base.ssr_enabled) and reflections > 0
	environment.volumetric_fog_enabled = bool(base.volumetric_fog_enabled) and int(settings.get_value("volumetric_fog")) > 0
	# Ordinary distance fog, direct lights and emissive glow remain authored:
	# even Low keeps navigable rooms and a concealed streaming horizon.

static func resolution_limit(crt_enabled: bool, tape_enabled: bool) -> int:
	# Indices follow RESOLUTION_HEIGHTS; Native (5) means no cap.
	return 1 if crt_enabled else (2 if tape_enabled else 5)

static func resolution_index(settings: GameSettings, crt_enabled: bool, tape_enabled: bool) -> int:
	if not bool(settings.get_value("video_auto_resolution")):
		return int(settings.get_value("render_resolution"))
	# A degraded recording cannot retain native/Retina world detail. Keep
	# lower quality choices lower, and preserve the saved choice for Clean.
	return mini(int(settings.get_value("render_resolution")), resolution_limit(crt_enabled,tape_enabled))

static func apply_resolution(viewport: Viewport, settings: GameSettings, crt_enabled := false, tape_enabled := false) -> void:
	var height: float = RESOLUTION_HEIGHTS[resolution_index(settings,crt_enabled,tape_enabled)]
	var scale := clampf(height / maxf(1.0, viewport.get_visible_rect().size.y), 0.05, 1.0) if height > 0.0 else 1.0
	if viewport.scaling_3d_mode != Viewport.SCALING_3D_MODE_BILINEAR:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if not is_equal_approx(viewport.scaling_3d_scale,scale): viewport.scaling_3d_scale = scale

static func apply_viewport(viewport: Viewport, settings: GameSettings, disable_taa := false, crt_enabled := false, tape_enabled := false) -> void:
	apply_resolution(viewport, settings, crt_enabled, tape_enabled)
	apply_viewport_features(viewport, settings, disable_taa)

## Realm preview textures already follow the main world's pixel density. They
## need the same AA/shadows without a second resolution reduction.
static func apply_viewport_features(viewport: Viewport, settings: GameSettings, disable_taa := false) -> void:
	var aa := int(settings.get_value("anti_aliasing"))
	viewport.use_taa = (aa == 2 or aa == 5) and not disable_taa
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.msaa_3d = Viewport.MSAA_2X if aa == 3 else (Viewport.MSAA_4X if aa == 4 or aa == 5 else Viewport.MSAA_DISABLED)
	# 4K retains fixture blockers without Ultra's fourfold atlas allocation.
	viewport.positional_shadow_atlas_size = [1024, 2048, 4096, 4096][int(settings.get_value("shadow_quality"))]

static func apply_global(settings: GameSettings) -> void:
	var shadows := int(settings.get_value("shadow_quality"))
	var shadow_filter: RenderingServer.ShadowQuality = [
		RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][shadows]
	RenderingServer.positional_soft_shadow_filter_set_quality(shadow_filter)
	RenderingServer.directional_soft_shadow_filter_set_quality(shadow_filter)
	var ao := int(settings.get_value("ambient_occlusion"))
	# High keeps the richer sample pattern, reconstructed from half-size AO.
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if ao < 2 else RenderingServer.ENV_SSAO_QUALITY_HIGH,
		true, 0.5, 2, 50.0, 100.0)
	var gi := int(settings.get_value("global_illumination"))
	# Keep the authored GI grid/detail; reduce temporal sampling work instead.
	RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_8 if gi < 2 else RenderingServer.ENV_SDFGI_RAY_COUNT_16)
	RenderingServer.environment_set_sdfgi_frames_to_update_light(RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_8_FRAMES if gi < 2 else RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_4_FRAMES)
	var fog := int(settings.get_value("volumetric_fog"))
	RenderingServer.environment_set_volumetric_fog_volume_size(64 if fog < 2 else 96, 64 if fog < 2 else 96)
	Engine.max_fps = int(settings.get_value("frame_limit"))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings.get_value("vsync")) else DisplayServer.VSYNC_DISABLED)
