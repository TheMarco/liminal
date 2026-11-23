class_name GraphicsQuality
extends RefCounted
## Runtime quality overrides layered onto authored floor environments. Never
## rebuild world geometry or alter a floor's palette/exposure to change quality.

const RESOLUTION_HEIGHTS := [360.0, 480.0, 720.0, 1080.0, 1440.0, 0.0]
const VIDEO_SIGNAL_SIZES := [Vector2i(360,240), Vector2i(540,360), Vector2i(720,480), Vector2i(720,480)]
const VIDEO_OUTPUT_HEIGHTS := [720,1080,1440,0]
const PREVIEW_SHADOW_ATLAS_SIZE := 2048
const PRACTICAL_LIGHTS := &"quality_practical_lights"
const AIRPORT_FILL_LIGHTS := &"airport_ceiling_fill_lights"
const AREA_LIGHT_BANKS := &"quality_area_light_banks"
const SPOT_LIGHT_BANKS := &"quality_spot_light_banks"
const RECTANGULAR_SHADOW_SIZE := 0.08
const ROOM_REFLECTIONS := &"quality_room_reflections"
const AUTHORED_LIGHT_FADE := &"_quality_authored_light_fade"
const AUTHORED_META := &"_quality_authored_environment"
const AUTHORED_KEYS := ["sdfgi_enabled", "sdfgi_cascades", "sdfgi_min_cell_size",
	"ssao_enabled", "ssr_enabled", "ssr_max_steps", "volumetric_fog_enabled"]

## World effects follow the lighting budget even with a custom resolution or
## video look. Changing CRT/tape quality must not rebuild the room's particles.
static func atmosphere_tier(values: Dictionary) -> int:
	return clampi(int(values.get("shadow_quality", 1)), 0, 3)

## Walls must occlude fixture light on every tier, including specular highlights.
static func configure_practical_light(light: Light3D, shadow_tier: int) -> void:
	light.set_meta("practical_shadow_tier", shadow_tier)
	_register_room_light(light)
	apply_practical_light(light, GameSettings.current.values if GameSettings.current != null else {})

## Ultra uses the physical strip wherever a fixture offers both light shapes.
static func use_rectangular_strips(values: Dictionary) -> bool:
	return int(values.get("shadow_quality", 3)) == 3 and not bool(values.get("cheap_lighting", false))

## Select a light shape without changing the ballast, emitter, or blackout state.
static func strip_light_bank(parent: Node3D, rectangular: bool) -> Node3D:
	var bank := Node3D.new()
	bank.name = "AreaLights" if rectangular else "SpotLights"
	bank.add_to_group(AREA_LIGHT_BANKS if rectangular else SPOT_LIGHT_BANKS)
	var sync := func() -> void:
		var settings: Dictionary = GameSettings.current.values if GameSettings.current != null else {}
		bank.visible = rectangular == use_rectangular_strips(settings)
	sync.call()
	bank.tree_entered.connect(sync)
	parent.add_child(bank)
	return bank

## Secondary panels cast blocking shadows on every preset.
static func airport_fill_shadow_size(values: Dictionary) -> float:
	return RECTANGULAR_SHADOW_SIZE if use_rectangular_strips(values) else 0.0

static func configure_airport_fill(light: Light3D) -> void:
	light.add_to_group(AIRPORT_FILL_LIGHTS)
	_sync_practical_light(light)

## Capture the finished room's normal distances, including any streaming extension.
## Emitting meshes and gameplay-controlled visibility/energy remain independent.
static func configure_room_accent(light: Light3D) -> void:
	if light.has_meta("practical_shadow_tier") or light.has_meta(AUTHORED_LIGHT_FADE):
		return
	light.set_meta(AUTHORED_LIGHT_FADE, [light.distance_fade_enabled, light.distance_fade_begin,
		light.distance_fade_length, light.distance_fade_shadow])
	_register_room_light(light)
	apply_practical_light(light, GameSettings.current.values if GameSettings.current != null else {})

static func _register_room_light(light: Light3D) -> void:
	if not light.is_in_group(PRACTICAL_LIGHTS):
		light.add_to_group(PRACTICAL_LIGHTS)
		# A partially built or parked room can miss an in-menu quality switch.
		light.tree_entered.connect(_sync_practical_light.bind(light))

static func _sync_practical_light(light: Light3D) -> void:
	var values: Dictionary = GameSettings.current.values if GameSettings.current != null else {}
	if light.is_in_group(AIRPORT_FILL_LIGHTS):
		var size := airport_fill_shadow_size(values)
		if not is_equal_approx(light.light_size, size):
			light.light_size = size
	if light.get_meta(&"cheap_lighting") != values.get("cheap_lighting", false):
		apply_practical_light(light, values)

static func refresh_practical_lights(tree: SceneTree, values: Dictionary) -> void:
	for light: Light3D in tree.get_nodes_in_group(PRACTICAL_LIGHTS):
		apply_practical_light(light, values)

static func apply_practical_light(light: Light3D, values: Dictionary) -> void:
	var cheap := bool(values.get("cheap_lighting", false))
	light.set_meta(&"cheap_lighting", cheap)
	if light.has_meta(AUTHORED_LIGHT_FADE):
		var base: Array = light.get_meta(AUTHORED_LIGHT_FADE)
		var begin := 16.0 if light.get_meta("stream_room_light", false) else 7.0
		var length := 6.0
		if base[0]:
			begin = minf(begin, base[1])
			length = minf(length, base[2])
		light.distance_fade_enabled = cheap or bool(base[0])
		light.distance_fade_begin = begin if cheap else float(base[1])
		light.distance_fade_length = length if cheap else float(base[2])
		light.distance_fade_shadow = begin + length if cheap else float(base[3])
		return
	if not light.has_meta("practical_shadow_tier"): return
	var begin := 24.0
	var length := 8.0
	if cheap:
		# Keep the main pool of light visible farther down the hall. Secondary
		# fixtures and ceiling bounce yield first as the player moves away.
		var tier := int(light.get_meta("practical_shadow_tier"))
		if light.get_meta("fixture_upward", false):
			begin = 4.0
			length = 5.0
		else:
			begin = 7.0
			if tier <= 1: begin = 16.0
			elif tier == 2: begin = 10.0
			length = 6.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = begin
	light.distance_fade_length = length
	light.shadow_enabled = true
	light.shadow_opacity = 1.0
	# Godot fades shadow opacity separately. If both fades start together,
	# a distant fixture shines through the wall for part of its fade.
	light.distance_fade_shadow = begin + length if cheap else begin

static func video_tier(values: Dictionary) -> int:
	var explicit := int(values.get("video_quality_override",-1))
	if explicit in range(4): return explicit
	# The game's default recording budget is fixed. Standalone reference
	# renderers without game settings use the original full signal size.
	return 1 if values.has("video_quality_override") else 3

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
	var cheap := bool(settings.get_value("cheap_lighting"))
	var gi := int(settings.get_value("global_illumination"))
	# Configure before enabling: switching from Low to Ultra should allocate
	# only the destination GI grid, rather than an intermediate one.
	environment.sdfgi_cascades = 2 if gi == 1 else int(base.sdfgi_cascades)
	environment.sdfgi_min_cell_size = 0.3 if gi == 1 else float(base.sdfgi_min_cell_size)
	environment.sdfgi_enabled = not cheap and bool(base.sdfgi_enabled) and gi > 0
	environment.ssao_enabled = bool(base.ssao_enabled) and int(settings.get_value("ambient_occlusion")) > 0
	var reflections := int(settings.get_value("reflections"))
	environment.ssr_max_steps = mini(16, int(base.ssr_max_steps)) if reflections == 1 else int(base.ssr_max_steps)
	environment.ssr_enabled = bool(base.ssr_enabled) and reflections > 0
	environment.volumetric_fog_enabled = not cheap and bool(base.volumetric_fog_enabled) and int(settings.get_value("volumetric_fog")) > 0
	# Ordinary distance fog, direct lights and emissive glow remain authored:
	# even Low keeps navigable rooms and a concealed streaming horizon.

static func resolution_index(settings: GameSettings, _crt_enabled := false, _tape_enabled := false) -> int:
	return int(settings.get_value("render_resolution"))

static func apply_resolution(viewport: Viewport, settings: GameSettings, _crt_enabled := false, _tape_enabled := false) -> void:
	var height: float = RESOLUTION_HEIGHTS[resolution_index(settings)]
	var scale := clampf(height / maxf(1.0, viewport.get_visible_rect().size.y), 0.05, 1.0) if height > 0.0 else 1.0
	if viewport.scaling_3d_mode != Viewport.SCALING_3D_MODE_BILINEAR:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if not is_equal_approx(viewport.scaling_3d_scale,scale): viewport.scaling_3d_scale = scale

## Match the pixels the opening actually occupies in the source world's 3D
## image. Keep the off-axis frustum and its output texture at their original
## aspect. Only the destination's internal 3D buffers change resolution.
static func doorway_render_scale(camera: Camera3D, window: MeshInstance3D,
		preview: SubViewport) -> float:
	var aperture := (window.mesh as QuadMesh).size
	var half_x := window.global_basis.x * aperture.x * 0.5
	var half_y := window.global_basis.y * aperture.y * 0.5
	var centre := window.global_position
	var top_left := centre - half_x + half_y
	var top_right := centre + half_x + half_y
	var bottom_left := centre - half_x - half_y
	var bottom_right := centre + half_x - half_y
	if camera.is_position_behind(top_left) or camera.is_position_behind(top_right) \
			or camera.is_position_behind(bottom_left) or camera.is_position_behind(bottom_right):
		return 1.0
	var top_left_pixel := camera.unproject_position(top_left)
	var top_right_pixel := camera.unproject_position(top_right)
	var bottom_left_pixel := camera.unproject_position(bottom_left)
	var bottom_right_pixel := camera.unproject_position(bottom_right)
	var width := maxf(top_left_pixel.distance_to(top_right_pixel), bottom_left_pixel.distance_to(bottom_right_pixel))
	var height := maxf(top_left_pixel.distance_to(bottom_left_pixel), top_right_pixel.distance_to(bottom_right_pixel))
	var density := maxf(width / preview.size.x, height / preview.size.y) * camera.get_viewport().scaling_3d_scale
	# Switch up before exhausting texel density and down only after moving
	# farther away. Looking around a threshold must not reallocate every frame.
	for tier: float in [0.25, 0.5, 0.75]:
		var headroom := 0.8 if tier < preview.scaling_3d_scale else 0.92
		if density <= tier * headroom:
			return tier
	return 1.0


static func apply_viewport(viewport: Viewport, settings: GameSettings, disable_taa := false) -> void:
	apply_resolution(viewport, settings)
	apply_viewport_features(viewport, settings, disable_taa)

## Realm preview textures already follow the main world's pixel density. They
## need the same AA/shadows without a second resolution reduction.
static func apply_viewport_features(viewport: Viewport, settings: GameSettings, disable_taa := false, atlas_limit := 0) -> void:
	var aa := int(settings.get_value("anti_aliasing"))
	viewport.use_taa = (aa == 2 or aa == 5) and not disable_taa
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.msaa_3d = Viewport.MSAA_2X if aa == 3 else (Viewport.MSAA_4X if aa == 4 or aa == 5 else Viewport.MSAA_DISABLED)
	# 4K retains fixture blockers without Ultra's fourfold atlas allocation.
	var shadows := int(settings.get_value("shadow_quality"))
	# Uniform 8x8 quadrants (see configure_shadow_atlas): every tile is 1/16 of
	# the atlas edge, so 128/256/512/512 pixels per fixture.
	var atlas_size: int = [2048, 4096, 8192, 8192][shadows]
	if settings.get_value("cheap_lighting"):
		atlas_size = mini(atlas_size, 4096)
	if atlas_limit > 0:
		atlas_size = mini(atlas_size, atlas_limit)
	if viewport.positional_shadow_atlas_size != atlas_size:
		viewport.positional_shadow_atlas_size = atlas_size
	configure_shadow_atlas(viewport)
	# The world is at most 480/720 lines under the default looks: a two to
	# three pixel LOD error and 4x anisotropy are invisible there, but they cut
	# vertex work and texture bandwidth on entry-level GPUs.
	viewport.mesh_lod_threshold = [3.0, 2.0, 1.0, 1.0][shadows]
	viewport.anisotropic_filtering_level = [Viewport.ANISOTROPY_2X, Viewport.ANISOTROPY_4X,
		Viewport.ANISOTROPY_8X, Viewport.ANISOTROPY_16X][shadows]

## Godot's default atlas mixes tile sizes (4/4/16/64 per quadrant). A light
## parked in a quadrant other than its ideal one is moved to another slot on
## EVERY frame once the ideal quadrant is full, and each move re-renders its
## shadow. Every fixture here is a blocker, so busy rooms overflow at once:
## 10,000+ shadow draw calls per frame in the Casino and Prison with nothing
## moving, on every preset. With one tile size no quadrant is "better", so a
## cached shadow stays cached. 256 slots; omni lights take two.
static func configure_shadow_atlas(viewport: Viewport) -> void:
	for quadrant in 4:
		if viewport.get_positional_shadow_atlas_quadrant_subdiv(quadrant) != Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_64:
			viewport.set_positional_shadow_atlas_quadrant_subdiv(quadrant, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_64)

static func apply_global(settings: GameSettings) -> void:
	var shadows := int(settings.get_value("shadow_quality"))
	var shadow_filter: RenderingServer.ShadowQuality = [
		RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][shadows]
	if settings.get_value("cheap_lighting"):
		shadow_filter = RenderingServer.SHADOW_QUALITY_HARD
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
	apply_frame_pacing(settings)

static func apply_frame_pacing(settings: GameSettings) -> void:
	Engine.max_fps = int(settings.get_value("frame_limit"))
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.VSYNC_ENABLED if bool(settings.get_value("vsync")) else DisplayServer.VSYNC_DISABLED
	# A redundant VSync request makes Vulkan recreate the window's swapchain.
	if DisplayServer.window_get_vsync_mode() != mode:
		DisplayServer.window_set_vsync_mode(mode)
