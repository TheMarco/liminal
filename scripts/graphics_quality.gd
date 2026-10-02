class_name GraphicsQuality
extends RefCounted
## Runtime quality overrides layered onto authored floor environments. Never
## rebuild world geometry or alter a floor's palette/exposure to change quality.

const RESOLUTION_HEIGHTS := [360.0, 480.0, 720.0, 1080.0, 1440.0, 0.0]
const AUTHORED_META := &"_quality_authored_environment"
const AUTHORED_KEYS := ["sdfgi_enabled", "sdfgi_cascades", "sdfgi_min_cell_size",
	"ssao_enabled", "ssr_enabled", "ssr_max_steps", "volumetric_fog_enabled"]

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

static func apply_resolution(viewport: Viewport, settings: GameSettings, crt_enabled := false) -> void:
	# CRT is a 480-line television source regardless of the quality preset.
	# Keep the saved resolution intact so switching the tube off restores it.
	var height: float = 480.0 if crt_enabled else RESOLUTION_HEIGHTS[int(settings.get_value("render_resolution"))]
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = clampf(height / maxf(1.0, viewport.get_visible_rect().size.y), 0.05, 1.0) if height > 0.0 else 1.0

static func apply_viewport(viewport: Viewport, settings: GameSettings, disable_taa := false, crt_enabled := false) -> void:
	apply_resolution(viewport, settings, crt_enabled)
	apply_viewport_features(viewport, settings, disable_taa)

## Realm preview textures already follow the main world's pixel density. They
## need the same AA/shadows without a second resolution reduction.
static func apply_viewport_features(viewport: Viewport, settings: GameSettings, disable_taa := false) -> void:
	var aa := int(settings.get_value("anti_aliasing"))
	viewport.use_taa = (aa == 2 or aa == 5) and not disable_taa
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.msaa_3d = Viewport.MSAA_2X if aa == 3 else (Viewport.MSAA_4X if aa == 4 or aa == 5 else Viewport.MSAA_DISABLED)
	viewport.positional_shadow_atlas_size = [1024, 2048, 4096, 8192][int(settings.get_value("shadow_quality"))]

static func apply_global(settings: GameSettings) -> void:
	var shadows := int(settings.get_value("shadow_quality"))
	var shadow_filter: RenderingServer.ShadowQuality = [
		RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][shadows]
	RenderingServer.positional_soft_shadow_filter_set_quality(shadow_filter)
	RenderingServer.directional_soft_shadow_filter_set_quality(shadow_filter)
	var ao := int(settings.get_value("ambient_occlusion"))
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if ao < 2 else RenderingServer.ENV_SSAO_QUALITY_HIGH,
		ao < 2, 0.5, 2, 50.0, 100.0)
	var gi := int(settings.get_value("global_illumination"))
	RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_8 if gi < 2 else RenderingServer.ENV_SDFGI_RAY_COUNT_32)
	RenderingServer.environment_set_sdfgi_frames_to_update_light(RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_8_FRAMES if gi < 2 else RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_4_FRAMES)
	var fog := int(settings.get_value("volumetric_fog"))
	RenderingServer.environment_set_volumetric_fog_volume_size(64 if fog < 2 else 128, 64 if fog < 2 else 128)
	Engine.max_fps = int(settings.get_value("frame_limit"))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings.get_value("vsync")) else DisplayServer.VSYNC_DISABLED)
