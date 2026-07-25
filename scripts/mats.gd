class_name Mats
## Shared material cache. Everything is procedural — shader materials for the
## big surfaces, tuned StandardMaterial3D for props. Materials are created once
## and reused across all chunks.

static var _c := {}
static var _wall_art_textures := {}
static var _wall_art_preloads_requested := false


static func _shader(key: String, path: String) -> ShaderMaterial:
	if _c.has(key):
		return _c[key]
	var m := ShaderMaterial.new()
	m.shader = load(path)
	_c[key] = m
	return m


static func _std(key: String, fn: Callable) -> StandardMaterial3D:
	if _c.has(key):
		return _c[key]
	var m := StandardMaterial3D.new()
	fn.call(m)
	_c[key] = m
	return m


## Shared seamless mipmapped noise — micro surface detail that filters
## correctly at distance, unlike per-pixel math noise.
static func detail_noise() -> NoiseTexture2D:
	if _c.has("detail_noise"):
		return _c["detail_noise"]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.02
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 512
	t.height = 512
	t.seamless = true
	t.generate_mipmaps = true
	_c["detail_noise"] = t
	return t


static func carpet() -> Material:
	var m := _shader("carpet", "res://shaders/carpet.gdshader")
	m.set_shader_parameter("detail_tex", detail_noise())
	return m


static func wallpaper() -> Material:
	var m := _shader("wallpaper", "res://shaders/wallpaper.gdshader")
	m.set_shader_parameter("detail_tex", detail_noise())
	return m


## Coarse districts use one of three related dye lots. They are deliberately
## close enough to belong to the same hotel, but distinct enough that a long
## walk does not feel wrapped in one infinitely repeated roll of paper.
static func wallpaper_variant(idx: int) -> Material:
	idx = posmod(idx, 3)
	if idx == 0:
		return wallpaper()
	var key := "wallpaper_variant_%d" % idx
	if _c.has(key):
		return _c[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/wallpaper.gdshader")
	m.set_shader_parameter("detail_tex", detail_noise())
	if idx == 1:
		m.set_shader_parameter("col_a", Color(0.43, 0.39, 0.29))
		m.set_shader_parameter("col_b", Color(0.27, 0.24, 0.17))
		m.set_shader_parameter("col_flock", Color(0.46, 0.34, 0.15))
		m.set_shader_parameter("col_wood", Color(0.20, 0.11, 0.06))
		m.set_shader_parameter("col_trim", Color(0.57, 0.41, 0.15))
	else:
		m.set_shader_parameter("col_a", Color(0.47, 0.32, 0.29))
		m.set_shader_parameter("col_b", Color(0.30, 0.16, 0.18))
		m.set_shader_parameter("col_flock", Color(0.57, 0.36, 0.15))
		m.set_shader_parameter("col_wood", Color(0.21, 0.105, 0.06))
		m.set_shader_parameter("col_trim", Color(0.63, 0.42, 0.14))
	_c[key] = m
	return m


## The hotel circulation variant is quieter than the gaming rooms: the same
## old flocked paper, but faded by decades of low light and repeated cleaning.
## Keeping its height field shallow stops the wall reading as carved stone at
## grazing angles while the actual door/trim geometry supplies the relief.
static func hall_wallpaper() -> Material:
	if _c.has("hall_wallpaper"):
		return _c["hall_wallpaper"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/wallpaper.gdshader")
	m.set_shader_parameter("detail_tex", detail_noise())
	m.set_shader_parameter("col_a", Color(0.34, 0.27, 0.22))
	m.set_shader_parameter("col_b", Color(0.22, 0.13, 0.12))
	m.set_shader_parameter("col_flock", Color(0.34, 0.22, 0.10))
	m.set_shader_parameter("col_wood", Color(0.14, 0.075, 0.045))
	m.set_shader_parameter("col_trim", Color(0.46, 0.31, 0.11))
	m.set_shader_parameter("bump_strength", 0.09)
	m.set_shader_parameter("peel_amount", 0.45)
	_c["hall_wallpaper"] = m
	return m


static func hall_wallpaper_variant(idx: int) -> Material:
	idx = posmod(idx, 3)
	if idx == 0:
		return hall_wallpaper()
	var key := "hall_wallpaper_variant_%d" % idx
	if _c.has(key):
		return _c[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/wallpaper.gdshader")
	m.set_shader_parameter("detail_tex", detail_noise())
	if idx == 1:
		m.set_shader_parameter("col_a", Color(0.30, 0.29, 0.22))
		m.set_shader_parameter("col_b", Color(0.17, 0.16, 0.11))
		m.set_shader_parameter("col_flock", Color(0.31, 0.25, 0.11))
		m.set_shader_parameter("col_wood", Color(0.13, 0.075, 0.04))
		m.set_shader_parameter("col_trim", Color(0.42, 0.31, 0.11))
	else:
		m.set_shader_parameter("col_a", Color(0.33, 0.23, 0.22))
		m.set_shader_parameter("col_b", Color(0.19, 0.10, 0.12))
		m.set_shader_parameter("col_flock", Color(0.36, 0.23, 0.10))
		m.set_shader_parameter("col_wood", Color(0.14, 0.07, 0.045))
		m.set_shader_parameter("col_trim", Color(0.47, 0.30, 0.10))
	m.set_shader_parameter("bump_strength", 0.09)
	m.set_shader_parameter("peel_amount", 0.45)
	_c[key] = m
	return m


## The casino gets coffered plaster, not the office's drop tiles.
static func ceiling() -> Material:
	var m := _shader("ceiling", "res://shaders/casino_ceiling.gdshader")
	m.set_shader_parameter("detail_tex", detail_noise())
	return m


static func marble() -> Material:
	return _shader("marble", "res://shaders/marble.gdshader")


static func slot_screen() -> Material:
	return _shader("slot_screen", "res://shaders/slot_screen.gdshader")


## Original fictional cabinet art generated for this project. Each texture has
## a real, readable theme instead of procedural pseudo-copy, while the shared
## shader keeps it part of the physically lit cabinet rather than an unshaded
## billboard.
static func slot_artwork(idx: int) -> Material:
	idx = posmod(idx, 3)
	var key := "slot_artwork_%d" % idx
	if _c.has(key):
		return _c[key]
	var paths := [
		"res://textures/slots/midnight_7.png",
		"res://textures/slots/desert_fortune.png",
		"res://textures/slots/neon_jackpot.png",
	]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/slot_artwork.gdshader")
	m.set_shader_parameter("artwork", load(paths[idx]))
	m.set_shader_parameter("glow_strength", [0.58, 0.48, 0.70][idx])
	m.set_shader_parameter("age", [0.24, 0.34, 0.14][idx])
	_c[key] = m
	return m


static func panel_on() -> StandardMaterial3D:
	return _std("panel_on", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.95, 0.9, 0.8)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.85, 0.62)
		m.emission_energy_multiplier = 2.6)


static func panel_dead() -> StandardMaterial3D:
	return _std("panel_dead", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.3, 0.29, 0.26)
		m.roughness = 0.6)


static func darkwood() -> StandardMaterial3D:
	return _std("darkwood", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.16, 0.09, 0.05)
		m.roughness = 0.4
		m.clearcoat_enabled = true
		m.clearcoat = 0.4)


static func crown() -> StandardMaterial3D:
	return _std("crown", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.78, 0.73, 0.65)
		m.roughness = 0.6)


static func brass() -> StandardMaterial3D:
	return _std("brass", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.71, 0.52, 0.22)
		m.metallic = 0.9
		m.roughness = 0.3
		m.anisotropy_enabled = true
		m.anisotropy = 0.5)


static func _velvet(key: String, col: Color, sheen: Color, amt: float) -> ShaderMaterial:
	if _c.has(key):
		return _c[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/velvet.gdshader")
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("sheen_col", sheen)
	m.set_shader_parameter("sheen_amount", amt)
	_c[key] = m
	return m


static func velvet() -> Material:
	return _velvet("velvet", Color(0.32, 0.06, 0.11), Color(0.85, 0.5, 0.45), 0.4)


static func velvet2() -> Material:
	return _velvet("velvet2", Color(0.22, 0.045, 0.085), Color(0.7, 0.4, 0.38), 0.35)


static func fabric_charcoal() -> Material:
	return _velvet("fabric_charcoal", Color(0.15, 0.15, 0.16), Color(0.55, 0.57, 0.6), 0.3)


static func slot_body() -> StandardMaterial3D:
	return _std("slot_body", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.14, 0.04, 0.12)
		m.metallic = 0.45
		m.roughness = 0.35
		m.clearcoat_enabled = true
		m.clearcoat = 0.5)


## Worn powder-coated cabinet finishes. Real machines are predominantly dark
## serviceable appliances; their color comes from the display and restrained
## edge lighting, not a uniformly glossy candy shell.
static func slot_cabinet_variant(idx: int) -> Material:
	idx = posmod(idx, 5)
	var key := "slot_cabinet_%d" % idx
	if _c.has(key):
		return _c[key]
	var palettes := [
		[Color(0.048, 0.052, 0.058), 0.42, 0.46, 0.30], # graphite
		[Color(0.16, 0.035, 0.042), 0.34, 0.48, 0.42],  # faded oxblood
		[Color(0.035, 0.065, 0.105), 0.40, 0.42, 0.26], # midnight blue
		[Color(0.13, 0.105, 0.075), 0.48, 0.39, 0.34],  # smoked bronze
		[Color(0.075, 0.06, 0.082), 0.37, 0.47, 0.38],  # aubergine black
	]
	var p: Array = palettes[idx]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/slot_cabinet.gdshader")
	m.set_shader_parameter("base_color", p[0])
	m.set_shader_parameter("metalness", p[1])
	m.set_shader_parameter("base_roughness", p[2])
	m.set_shader_parameter("wear", p[3])
	_c[key] = m
	return m


static func slot_molded_plastic() -> StandardMaterial3D:
	return _std("slot_molded_plastic", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.026, 0.029, 0.032)
		m.metallic = 0.08
		m.roughness = 0.54
		m.metallic_specular = 0.62)


static func slot_brushed_metal() -> StandardMaterial3D:
	return _std("slot_brushed_metal", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.34, 0.35, 0.36)
		m.metallic = 0.92
		m.roughness = 0.31
		m.anisotropy_enabled = true
		m.anisotropy = 0.72)


static func slot_accent_amber() -> StandardMaterial3D:
	return _std("slot_accent_amber", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.16, 0.075, 0.018)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.43, 0.085)
		m.emission_energy_multiplier = 1.45
		m.roughness = 0.34)


static func slot_accent_cyan() -> StandardMaterial3D:
	return _std("slot_accent_cyan", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.012, 0.065, 0.075)
		m.emission_enabled = true
		m.emission = Color(0.12, 0.66, 0.78)
		m.emission_energy_multiplier = 1.35
		m.roughness = 0.34)


static func slot_status_blue() -> StandardMaterial3D:
	return _std("slot_status_blue", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.01, 0.055, 0.12)
		m.emission_enabled = true
		m.emission = Color(0.08, 0.42, 1.0)
		m.emission_energy_multiplier = 1.8)


static func slot_service_label() -> StandardMaterial3D:
	return _std("slot_service_label", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.67, 0.63, 0.48)
		m.roughness = 0.9)


static func pot() -> StandardMaterial3D:
	return _std("pot", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.18, 0.13, 0.1)
		m.metallic = 0.5
		m.roughness = 0.5)


static func plant() -> StandardMaterial3D:
	return _std("plant", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.06, 0.17, 0.07)
		m.roughness = 1.0)


static func bulb() -> StandardMaterial3D:
	return _std("bulb", func(m: StandardMaterial3D):
		m.albedo_color = Color(1.0, 0.95, 0.85)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.82, 0.6)
		m.emission_energy_multiplier = 4.0)


static func shade() -> StandardMaterial3D:
	return _std("shade", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.9, 0.8, 0.65)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.8, 0.55)
		m.emission_energy_multiplier = 1.1)


static func neon_pink() -> StandardMaterial3D:
	return _std("neon_pink", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.1, 0.02, 0.05)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.25, 0.55)
		m.emission_energy_multiplier = 5.0)


static func neon_amber() -> StandardMaterial3D:
	return _std("neon_amber", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.1, 0.06, 0.02)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.6, 0.15)
		m.emission_energy_multiplier = 5.0)


static func chand() -> StandardMaterial3D:
	return _std("chand", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.71, 0.52, 0.22)
		m.metallic = 0.9
		m.roughness = 0.25
		m.emission_enabled = true
		m.emission = Color(1.0, 0.68, 0.3)
		m.emission_energy_multiplier = 0.45)


static func slot_reels() -> Material:
	return _shader("slot_reels", "res://shaders/slot_reels.gdshader")


static func slot_wheel() -> Material:
	return _shader("slot_wheel", "res://shaders/slot_wheel.gdshader")


static func paytable() -> Material:
	return _shader("paytable", "res://shaders/slot_paytable.gdshader")


static func ticker() -> Material:
	return _shader("ticker", "res://shaders/slot_ticker.gdshader")


static func gold_mirror() -> StandardMaterial3D:
	return _std("gold_mirror", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.9, 0.7, 0.28)
		m.metallic = 0.6
		m.roughness = 0.35
		m.clearcoat_enabled = true
		m.clearcoat = 0.6)


static func lamp_amber() -> StandardMaterial3D:
	return _std("lamp_amber", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.3, 0.18, 0.04)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.6, 0.15)
		m.emission_energy_multiplier = 1.6)


static func lamp_red() -> StandardMaterial3D:
	return _std("lamp_red", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.25, 0.03, 0.02)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.12, 0.08)
		m.emission_energy_multiplier = 1.6)


static func ring_pink() -> StandardMaterial3D:
	return _std("ring_pink", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.1, 0.02, 0.05)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.25, 0.55)
		m.emission_energy_multiplier = 2.2)


static func ring_cyan() -> StandardMaterial3D:
	return _std("ring_cyan", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.02, 0.08, 0.1)
		m.emission_enabled = true
		m.emission = Color(0.2, 0.8, 1.0)
		m.emission_energy_multiplier = 2.2)


static func lamp_green() -> StandardMaterial3D:
	return _std("lamp_green", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.02, 0.15, 0.04)
		m.emission_enabled = true
		m.emission = Color(0.2, 1.0, 0.3)
		m.emission_energy_multiplier = 2.0)


static func glass() -> StandardMaterial3D:
	return _std("glass", func(m: StandardMaterial3D):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 1.0, 1.0, 0.07)
		m.roughness = 0.05
		m.metallic_specular = 0.8)


## Visibly tinted balustrade glass — reads as a panel, not empty air, so the
## handrail above it never looks like a floating line.
static func glass_tint() -> StandardMaterial3D:
	return _std("glass_tint", func(m: StandardMaterial3D):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.65, 0.72, 0.75, 0.3)
		m.roughness = 0.08
		m.metallic_specular = 0.8)


## Public-facing airport safety glass. The generic architectural glass is
## deliberately almost invisible, but that made full-height terminal panes
## read as empty space even though they correctly blocked the player.
static func airport_glass() -> StandardMaterial3D:
	return _std("airport_glass", func(m: StandardMaterial3D):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.48, 0.64, 0.72, 0.24)
		m.roughness = 0.16
		m.metallic_specular = 0.88
		m.clearcoat_enabled = true
		m.clearcoat = 0.35)


## Pale ceramic manifestation dots bonded to full-height glazing at eye level.
static func airport_glass_marker() -> StandardMaterial3D:
	return _std("airport_glass_marker", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.72, 0.81, 0.84)
		m.roughness = 0.42
		m.metallic_specular = 0.7)


static func body_black() -> StandardMaterial3D:
	return _std("body_black", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.06, 0.06, 0.07)
		m.metallic = 0.4
		m.roughness = 0.25
		m.clearcoat_enabled = true
		m.clearcoat = 0.8)


static func body_red() -> StandardMaterial3D:
	return _std("body_red", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.45, 0.06, 0.09)
		m.metallic = 0.5
		m.roughness = 0.3
		m.clearcoat_enabled = true
		m.clearcoat = 0.8)


static func body_purple() -> StandardMaterial3D:
	return _std("body_purple", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.28, 0.09, 0.38)
		m.metallic = 0.5
		m.roughness = 0.3
		m.clearcoat_enabled = true
		m.clearcoat = 0.8)


static func body_blue() -> StandardMaterial3D:
	return _std("body_blue", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.08, 0.14, 0.4)
		m.metallic = 0.5
		m.roughness = 0.3
		m.clearcoat_enabled = true
		m.clearcoat = 0.8)


static func velvet_rust() -> Material:
	return _velvet("velvet_rust", Color(0.55, 0.25, 0.1), Color(1.0, 0.7, 0.45), 0.4)


static func neon_cyan() -> StandardMaterial3D:
	return _std("neon_cyan", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.02, 0.08, 0.1)
		m.emission_enabled = true
		m.emission = Color(0.2, 0.8, 1.0)
		m.emission_energy_multiplier = 5.0)


static func chrome() -> StandardMaterial3D:
	return _std("chrome", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.75, 0.75, 0.78)
		m.metallic = 0.95
		m.roughness = 0.15)


static func neon_red() -> StandardMaterial3D:
	return _std("neon_red", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.12, 0.02, 0.02)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.12, 0.08)
		m.emission_energy_multiplier = 4.0)


static func red_knob() -> StandardMaterial3D:
	return _std("red_knob", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.7, 0.08, 0.08)
		m.roughness = 0.25
		m.clearcoat_enabled = true
		m.clearcoat = 0.8)


static func sign_housing() -> StandardMaterial3D:
	return _std("sign_housing", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.06, 0.06, 0.06)
		m.roughness = 0.6)


static func band_paint() -> StandardMaterial3D:
	return _std("band_paint", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.3, 0.1, 0.13)
		m.roughness = 0.85)


# --- office theme -----------------------------------------------------------

static func office_carpet() -> Material:
	var m := _shader("office_carpet", "res://shaders/office_carpet.gdshader")
	m.set_shader_parameter("detail_tex", detail_noise())
	return m


## A subtly darker carpet-tile run used only inside the office circulation
## spine.  It makes the navigable lane legible without turning it into the
## casino's decorative runner, and continues through real doorway vestibules.
static func office_lane_carpet() -> Material:
	if _c.has("office_lane_carpet"):
		return _c["office_lane_carpet"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/office_carpet.gdshader")
	m.set_shader_parameter("detail_tex", detail_noise())
	m.set_shader_parameter("col_base", Color(0.075, 0.18, 0.13))
	m.set_shader_parameter("col_dark", Color(0.035, 0.105, 0.072))
	m.set_shader_parameter("col_light", Color(0.12, 0.245, 0.17))
	m.set_shader_parameter("bump_strength", 0.22)
	_c["office_lane_carpet"] = m
	return m


static func office_wall() -> Material:
	return _shader("office_wall", "res://shaders/office_wall.gdshader")


static func office_wall_variant(idx: int) -> Material:
	idx = posmod(idx, 3)
	if idx == 0:
		return office_wall()
	var key := "office_wall_variant_%d" % idx
	if _c.has(key):
		return _c[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/office_wall.gdshader")
	m.set_shader_parameter("base_col", Color(0.81, 0.84, 0.80) if idx == 1 \
		else Color(0.86, 0.83, 0.76))
	_c[key] = m
	return m


static func office_ceiling() -> Material:
	return _std("office_ceiling", func(m: StandardMaterial3D):
		# AquaEquinox's source is a 12-triangle demonstration slab. Reusing its
		# authored PBR maps on the existing structural BoxMesh keeps one ceiling
		# and collider per chunk instead of tiling dozens of overlapping models.
		var root := "res://models/cc_by/ceiling_tiles_texture/ceiling_tiles_texture_"
		var albedo := load(root + "0.jpg")
		m.albedo_texture = albedo
		m.albedo_color = Color(1.0, 1.0, 0.98)
		# The fixtures sit below the ceiling, so pure PBR shading leaves the
		# upward-facing slab starved of bounce light. A low, texture-preserving
		# emission approximates that diffuse room fill without making it glow.
		m.emission_enabled = true
		m.emission_texture = albedo
		m.emission = Color(0.24, 0.25, 0.22)
		m.emission_energy_multiplier = 0.55
		m.normal_enabled = true
		m.normal_texture = load(root + "2.png")
		m.normal_scale = 0.8
		var orm := load(root + "1.png")
		m.roughness = 1.0
		m.roughness_texture = orm
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.metallic = 1.0
		m.metallic_texture = orm
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		# The square source image contains a 2 x 2 tile repeat. A tighter repeat
		# keeps the grid from making the three-metre office ceiling feel low.
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / 0.75
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)


## Textured black task chair from 3DModelsCC0/OpenGameArt. The source FBX
## references an absent authoring-time TIFF, so bind the supplied PBR set
## explicitly rather than allowing the importer to render it flat white.
static func office_task_chair() -> StandardMaterial3D:
	return _std("office_task_chair", func(m: StandardMaterial3D):
		var root := "res://models/cc0/office_chair/Office_Chair_"
		m.albedo_texture = load(root + "Base_Color.png")
		m.normal_enabled = true
		m.normal_texture = load(root + "Normal.png")
		m.roughness_texture = load(root + "Roughness.png")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.metallic_texture = load(root + "Metallic.png")
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)


static func crt() -> Material:
	return _shader("crt", "res://shaders/crt.gdshader")


static func office_panel() -> StandardMaterial3D:
	return _std("office_panel", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.95, 0.97, 0.94)
		m.emission_enabled = true
		m.emission = Color(0.92, 1.0, 0.95)
		m.emission_energy_multiplier = 2.4)


## Opaque privacy glass for office-door vision panels.  The milky laminate
## catches the fluorescent light but cannot reveal the intentionally unbuilt
## locked room behind it.
static func office_privacy_glass() -> StandardMaterial3D:
	return _std("office_privacy_glass", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.52, 0.69, 0.62)
		m.roughness = 0.82
		m.metallic_specular = 0.55
		m.emission_enabled = true
		m.emission = Color(0.18, 0.28, 0.23)
		m.emission_energy_multiplier = 0.16)


static func paint_white() -> StandardMaterial3D:
	return _std("paint_white", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.9, 0.9, 0.87)
		m.roughness = 0.5)


static func base_green() -> StandardMaterial3D:
	return _std("base_green", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.05, 0.12, 0.08)
		m.roughness = 0.4)


static func desk_white() -> StandardMaterial3D:
	return _std("desk_white", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.92, 0.92, 0.9)
		m.roughness = 0.35
		m.clearcoat_enabled = true
		m.clearcoat = 0.3)


static func divider_gray() -> StandardMaterial3D:
	return _std("divider_gray", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.72, 0.75, 0.7)
		m.roughness = 0.9)


static func charcoal() -> StandardMaterial3D:
	return _std("charcoal", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.15, 0.15, 0.16)
		m.roughness = 0.8)


static func metal_gray() -> StandardMaterial3D:
	return _std("metal_gray", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.55, 0.56, 0.58)
		m.metallic = 0.7
		m.roughness = 0.4)


static func box_white() -> StandardMaterial3D:
	return _std("box_white", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.8, 0.78, 0.72)
		m.roughness = 0.9)


static func wood_door() -> StandardMaterial3D:
	return _std("wood_door", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.3, 0.17, 0.09)
		m.roughness = 0.35
		m.clearcoat_enabled = true
		m.clearcoat = 0.6)


static func crt_shell() -> StandardMaterial3D:
	return _std("crt_shell", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.82, 0.78, 0.68)
		m.roughness = 0.55)


## Dark brown bezel / key-deck plastic of a VT100-era terminal.
static func crt_dark() -> StandardMaterial3D:
	return _std("crt_dark", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.12, 0.10, 0.09)
		m.roughness = 0.6)


static func jug_blue() -> StandardMaterial3D:
	return _std("jug_blue", func(m: StandardMaterial3D):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.35, 0.55, 0.8, 0.55)
		m.roughness = 0.1)


# --- sewer -------------------------------------------------------------------

static func concrete() -> Material:
	var m := _shader("concrete", "res://shaders/concrete.gdshader")
	m.set_shader_parameter("detail_tex", detail_noise())
	return m


static func concrete_floor() -> Material:
	if _c.has("concrete_floor"):
		return _c["concrete_floor"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/concrete.gdshader")
	m.set_shader_parameter("detail_tex", detail_noise())
	m.set_shader_parameter("base_col", Color(0.34, 0.36, 0.33))
	m.set_shader_parameter("wetness", 0.75)
	_c["concrete_floor"] = m
	return m


static func sewer_water() -> Material:
	return _shader("sewer_water", "res://shaders/sewer_water.gdshader")


static func water_stream() -> Material:
	return _shader("water_stream", "res://shaders/water_stream.gdshader")


static func pipe_rust() -> StandardMaterial3D:
	return _std("pipe_rust", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.36, 0.23, 0.16)
		m.roughness = 0.85
		m.metallic = 0.25)


static func pipe_green() -> StandardMaterial3D:
	return _std("pipe_green", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.22, 0.30, 0.24)
		m.roughness = 0.55
		m.metallic = 0.45)


static func iron_dark() -> StandardMaterial3D:
	return _std("iron_dark", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.13, 0.13, 0.14)
		m.roughness = 0.5
		m.metallic = 0.8)


static func barrel_rust() -> StandardMaterial3D:
	return _std("barrel_rust", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.32, 0.20, 0.12)
		m.roughness = 0.9)


## Standing puddle: near-black gloss, SSR does the rest.
static func puddle() -> StandardMaterial3D:
	return _std("puddle", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.04, 0.05, 0.04)
		m.roughness = 0.04
		m.metallic = 0.1)


# --- shared outdoor ----------------------------------------------------------

## Wet tarmac. The theme park is gone; the airport apron still uses this.
static func asphalt() -> Material:
	var m := _shader("asphalt", "res://shaders/asphalt.gdshader")
	m.set_shader_parameter("detail_tex", detail_noise())
	return m


# --- airport -----------------------------------------------------------------

static func terrazzo() -> Material:
	return _shader("terrazzo", "res://shaders/terrazzo.gdshader")


static func apron_night() -> Material:
	return _shader("apron_night", "res://shaders/apron_night.gdshader")


static func belt() -> Material:
	return _shader("belt", "res://shaders/belt.gdshader")


## Four cached ad-lightbox variants with different brand palettes.
static func adbox(idx: int) -> ShaderMaterial:
	var key := "adbox%d" % (idx % 4)
	if _c.has(key):
		return _c[key]
	var pals := [
		[Color(0.16, 0.32, 0.55), Color(0.85, 0.75, 0.55)],
		[Color(0.42, 0.12, 0.22), Color(0.9, 0.62, 0.35)],
		[Color(0.08, 0.3, 0.3), Color(0.75, 0.85, 0.8)],
		[Color(0.25, 0.2, 0.4), Color(0.9, 0.85, 0.7)],
	]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/adbox.gdshader")
	m.set_shader_parameter("col_a", pals[idx % 4][0])
	m.set_shader_parameter("col_b", pals[idx % 4][1])
	m.set_shader_parameter("seed", float(idx % 4))
	_c[key] = m
	return m


static func airport_wall() -> Material:
	if _c.has("airport_wall"):
		return _c["airport_wall"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/office_wall.gdshader")
	m.set_shader_parameter("base_col", Color(0.80, 0.81, 0.83))
	m.set_shader_parameter("ceil_h", 5.0)
	_c["airport_wall"] = m
	return m


static func airport_wall_variant(idx: int) -> Material:
	idx = posmod(idx, 3)
	if idx == 0:
		return airport_wall()
	var key := "airport_wall_variant_%d" % idx
	if _c.has(key):
		return _c[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/office_wall.gdshader")
	m.set_shader_parameter("base_col", Color(0.73, 0.77, 0.82) if idx == 1 \
		else Color(0.80, 0.78, 0.71))
	m.set_shader_parameter("ceil_h", 5.0)
	_c[key] = m
	return m


static func airport_ceiling() -> Material:
	if _c.has("airport_ceiling"):
		return _c["airport_ceiling"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ceiling.gdshader")
	m.set_shader_parameter("col", Color(0.68, 0.70, 0.73))
	m.set_shader_parameter("stain_amount", 0.08)
	m.set_shader_parameter("tile", 1.2)
	_c["airport_ceiling"] = m
	return m


## Blue-grey gate-lounge carpet tiles, reusing the office heather weave.
static func airport_carpet() -> Material:
	if _c.has("airport_carpet"):
		return _c["airport_carpet"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/office_carpet.gdshader")
	m.set_shader_parameter("col_base", Color(0.11, 0.14, 0.22))
	m.set_shader_parameter("col_dark", Color(0.06, 0.08, 0.14))
	m.set_shader_parameter("col_light", Color(0.18, 0.22, 0.32))
	m.set_shader_parameter("detail_tex", detail_noise())
	_c["airport_carpet"] = m
	return m


## Gate-seating vinyl: near-black with a tired institutional sheen.
static func seat_black() -> StandardMaterial3D:
	return _std("seat_black", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.07, 0.07, 0.09)
		m.roughness = 0.38
		m.clearcoat_enabled = true
		m.clearcoat = 0.5)


static func steel() -> StandardMaterial3D:
	return _std("steel", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.62, 0.63, 0.65)
		m.metallic = 0.85
		m.roughness = 0.35
		m.anisotropy_enabled = true
		m.anisotropy = 0.6)


## Backlit navy wayfinding sign housing; Label3D text rides on top.
static func sign_navy() -> StandardMaterial3D:
	return _std("sign_navy", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.05, 0.09, 0.22)
		m.roughness = 0.4
		m.emission_enabled = true
		m.emission = Color(0.09, 0.15, 0.38)
		m.emission_energy_multiplier = 1.5)


static func air_panel() -> StandardMaterial3D:
	return _std("air_panel", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.93, 0.96, 1.0)
		m.emission_enabled = true
		m.emission = Color(0.85, 0.92, 1.0)
		m.emission_energy_multiplier = 2.5)


## Dead monitor / FIDS glass — near-black, glossy.
static func screen_dark() -> StandardMaterial3D:
	return _std("screen_dark", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.02, 0.025, 0.03)
		m.roughness = 0.1
		m.metallic = 0.2)


## Live monitor backglow behind amber Label3D rows.
static func screen_glow() -> StandardMaterial3D:
	return _std("screen_glow", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.02, 0.03, 0.06)
		m.emission_enabled = true
		m.emission = Color(0.05, 0.09, 0.2)
		m.emission_energy_multiplier = 1.2)


static func rubber_black() -> StandardMaterial3D:
	return _std("rubber_black", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.06, 0.06, 0.065)
		m.roughness = 0.7)


static func jetway_body() -> StandardMaterial3D:
	return _std("jetway_body", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.4, 0.43, 0.48)
		m.metallic = 0.5
		m.roughness = 0.55)


static func lamp_blue() -> StandardMaterial3D:
	return _std("lamp_blue", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.02, 0.05, 0.12)
		m.emission_enabled = true
		m.emission = Color(0.25, 0.5, 1.0)
		m.emission_energy_multiplier = 3.0)


static func caution_yellow() -> StandardMaterial3D:
	return _std("caution_yellow", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.85, 0.7, 0.1)
		m.roughness = 0.55)


## Card-table baize.
static func felt_green() -> Material:
	return _velvet("felt_green", Color(0.05, 0.24, 0.11), Color(0.35, 0.75, 0.45), 0.25)


## Cached neon tube in any colour — for signs the base palette doesn't cover.
static func neon_col(name_key: String, col: Color) -> StandardMaterial3D:
	var key := "neoncol_" + name_key
	if _c.has(key):
		return _c[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r * 0.1, col.g * 0.1, col.b * 0.1)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 5.0
	_c[key] = m
	return m


# --- portals -----------------------------------------------------------------

const PORTAL_COLS := [
	[Color(1.0, 0.45, 0.2), Color(1.0, 0.85, 0.6)],    # -> casino: hot amber
	[Color(0.6, 1.0, 0.75), Color(0.95, 1.0, 0.97)],   # -> office: sterile mint
	[Color(0.25, 0.9, 0.45), Color(0.75, 1.0, 0.82)],  # -> sewers: drain green
	[Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0)],      # 3 = cut theme park; slot kept so 4/5 still index right
	[Color(0.55, 0.8, 1.0), Color(0.92, 0.97, 1.0)],   # -> airport: ice white
	[Color(0.72, 0.9, 0.38), Color(0.93, 1.0, 0.8)],   # -> asylum: sick fluorescent
	[Color(0.85, 0.22, 0.18), Color(1.0, 0.86, 0.72)], # -> school: the red line
	[Color(0.22, 0.82, 0.78), Color(1.0, 0.68, 0.28)], # -> mall: faded teal / sodium
	[Color(0.36, 0.48, 0.42), Color(0.78, 0.84, 0.76)],# -> prison: oxidised iron
]


static func portal(dest: int) -> ShaderMaterial:
	var key := "portal%d" % dest
	if _c.has(key):
		return _c[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/portal.gdshader")
	m.set_shader_parameter("col_edge", PORTAL_COLS[dest][0])
	m.set_shader_parameter("col_core", PORTAL_COLS[dest][1])
	m.render_priority = 1
	_c[key] = m
	return m


static func portal_floor(dest: int) -> ShaderMaterial:
	var key := "portal_floor%d" % dest
	if _c.has(key):
		return _c[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/portal_floor.gdshader")
	m.set_shader_parameter("col", PORTAL_COLS[dest][0])
	_c[key] = m
	return m


## Tiny emissive orbit-spark tinted toward a destination.
static func portal_spark(dest: int) -> StandardMaterial3D:
	var key := "portal_spark%d" % dest
	if _c.has(key):
		return _c[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = PORTAL_COLS[dest][1]
	m.emission_enabled = true
	m.emission = PORTAL_COLS[dest][0]
	m.emission_energy_multiplier = 3.5
	_c[key] = m
	return m


## Warm cabin light behind an airliner's windows — on, for no one.
static func cabin_warm() -> StandardMaterial3D:
	return _std("cabin_warm", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.25, 0.2, 0.12)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.82, 0.5)
		m.emission_energy_multiplier = 2.4)


## Per-instance muted painting canvas — intentionally not cached.
static func canvas(hue: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.from_hsv(hue, 0.3, 0.42)
	m.roughness = 0.85
	return m


## Mipmapped runtime wall art. Source paintings remain in `paintings/`; the
## game uses the 1024px WebP derivatives so a 720x480 presentation never pays
## to decode or retain nineteen 2K/3K PNGs.
static func note_wall_art_preloads_requested() -> void:
	_wall_art_preloads_requested = true


static func wall_art_texture(path: String) -> Texture2D:
	if _wall_art_textures.has(path):
		return _wall_art_textures[path]
	# Chunk preloading requests these images on a worker. Calling load() while
	# that request is still in flight can briefly hand the dummy renderer a null
	# texture, so finish the existing request through the threaded API instead.
	var tex: Texture2D
	if not _wall_art_preloads_requested:
		tex = load(path) as Texture2D
	else:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
				or status == ResourceLoader.THREAD_LOAD_LOADED:
			tex = ResourceLoader.load_threaded_get(path) as Texture2D
		else:
			tex = load(path) as Texture2D
	if tex != null:
		_wall_art_textures[path] = tex
	return tex


static func wall_art(path: String) -> StandardMaterial3D:
	var key := "wall_art:" + path
	if _c.has(key):
		return _c[key]
	var m := StandardMaterial3D.new()
	var tex := wall_art_texture(path)
	if tex != null:
		m.albedo_texture = tex
	m.albedo_color = Color(0.94, 0.94, 0.91)
	m.roughness = 0.72
	m.metallic = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_c[key] = m
	return m


# --- photo materials (CC0, ambientCG) ----------------------------------------
# World-space triplanar mapping: all structural geometry is unit BoxMesh scaled
# through the node transform, so object UVs are useless — world coordinates
# give every wall and floor the same real-metre texture density, continuous
# across chunk borders.

static func _photo(key: String, root: String, folder: String, per_m: float,
		tint: Color, rough := 1.0) -> StandardMaterial3D:
	if _c.has(key):
		return _c[key]
	var m := StandardMaterial3D.new()
	var base := "res://textures/%s/%s/%s_1K-JPG_" % [root, folder, folder]
	m.albedo_texture = load(base + "Color.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(base + "NormalGL.jpg")
	m.roughness = rough
	m.roughness_texture = load(base + "Roughness.jpg")
	if FileAccess.file_exists(base + "AmbientOcclusion.jpg"):
		m.ao_enabled = true
		m.ao_texture = load(base + "AmbientOcclusion.jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * per_m
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_c[key] = m
	return m


## Polished grey marble — casino grand halls and their pillars. Roughness is
## squashed hard so the floor actually mirrors the neon like wet stone.
static func marble_photo() -> StandardMaterial3D:
	return _photo("marble_photo", "cc0", "Marble012", 0.35, Color(0.8, 0.8, 0.85), 0.5)


## Red patterned hotel carpet — corridor runners.
static func carpet_red() -> StandardMaterial3D:
	return _photo("carpet_red", "cc0", "Fabric026", 0.8, Color(0.85, 0.78, 0.78))


## Dirty industrial brick — the older stretches of the sewers.
static func brick_sewer() -> StandardMaterial3D:
	return _photo("brick_sewer", "cc0", "Bricks097", 0.5, Color(0.6, 0.64, 0.6))


## Antique black/white terrazzo — the airport underfoot.
static func terrazzo_photo() -> StandardMaterial3D:
	return _photo("terrazzo_photo", "cc0", "Terrazzo005", 0.45, Color(0.82, 0.82, 0.84))


static func _asy_tex(key: String, folder: String, per_m: float, tint: Color,
		rough := 1.0) -> StandardMaterial3D:
	return _photo(key, "asylum", folder, per_m, tint, rough)


# --- asylum ------------------------------------------------------------------


## Peeling institutional-green paint over plaster and bare brick.
static func asy_wall() -> StandardMaterial3D:
	return _asy_tex("asy_wall", "PaintedPlaster016", 0.42, Color(0.62, 0.72, 0.55))


## The sicklier yellow variant — some rooms rotted differently.
static func asy_wall_sick() -> StandardMaterial3D:
	return _asy_tex("asy_wall_sick", "PaintedPlaster018", 0.42, Color(0.82, 0.78, 0.6))


## Cracked white wall tile — treatment rooms, hydro, wainscots.
static func asy_tile() -> StandardMaterial3D:
	return _asy_tex("asy_tile", "Tiles133C", 0.55, Color(0.78, 0.82, 0.76))


## Stained beige floor tile for the rooms.
static func asy_floor() -> StandardMaterial3D:
	return _asy_tex("asy_floor", "Tiles141", 0.5, Color(0.5, 0.48, 0.42))


## Grimy checkerboard for corridors and the dayroom.
static func asy_checker() -> StandardMaterial3D:
	return _asy_tex("asy_checker", "Tiles012", 0.35, Color(0.42, 0.42, 0.38))


## Water-stained ceiling plaster.
static func asy_ceiling() -> StandardMaterial3D:
	return _asy_tex("asy_ceiling", "PaintedPlaster018", 0.3, Color(0.42, 0.42, 0.36))


## Rust-streaked bare steel — gurney frames, fixtures.
static func asy_metal() -> StandardMaterial3D:
	return _asy_tex("asy_metal", "Metal021", 0.7, Color.WHITE, 0.9)


## Chipped green-painted metal — the doors every asylum shares.
static func asy_metal_green() -> StandardMaterial3D:
	return _asy_tex("asy_metal_green", "PaintedMetal006", 0.65, Color(0.85, 0.9, 0.82))


## Soiled mattress / bedsheet cloth.
static func asy_cloth() -> StandardMaterial3D:
	return _asy_tex("asy_cloth", "Fabric028", 1.1, Color(0.72, 0.68, 0.58))


## Grubby off-white canvas — straitjackets, restraint padding. Kept bright so
## a jacket on a wall still reads across a dark room.
static func asy_canvas() -> StandardMaterial3D:
	return _asy_tex("asy_canvas", "Fabric028", 1.6, Color(1.0, 0.97, 0.88))


## Dark old concrete — isolation, service corners.
static func asy_concrete() -> StandardMaterial3D:
	return _asy_tex("asy_concrete", "Concrete035", 0.5, Color(0.75, 0.75, 0.72))


## Fluorescent tube lens, greener and meaner than the office panels.
static func asy_panel() -> StandardMaterial3D:
	return _std("asy_panel", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.75, 0.82, 0.72)
		m.emission_enabled = true
		m.emission = Color(0.8, 0.95, 0.74)
		m.emission_energy_multiplier = 2.6)


# --- school -------------------------------------------------------------------
# One building, painted over every summer: cream block above a red band, a
# floor ground and sealed until it mirrors the strip lights, and locker runs
# in whatever colour the district bought that decade.


## Cream painted cinder block. The whole school is this, wall after wall —
## flat repainted plaster, not the mottled ruin the asylum is made of.
static func sch_wall() -> Material:
	if _c.has("sch_wall"):
		return _c["sch_wall"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/office_wall.gdshader")
	m.set_shader_parameter("base_col", Color(0.85, 0.82, 0.74))
	_c["sch_wall"] = m
	return m


static func sch_wall_variant(idx: int) -> Material:
	idx = posmod(idx, 3)
	if idx == 0:
		return sch_wall()
	var key := "sch_wall_variant_%d" % idx
	if _c.has(key):
		return _c[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/office_wall.gdshader")
	m.set_shader_parameter("base_col", Color(0.77, 0.81, 0.74) if idx == 1 \
		else Color(0.85, 0.79, 0.66))
	_c[key] = m
	return m


## The accent band, and the paint on the door frames.
static func sch_red() -> StandardMaterial3D:
	return _std("sch_red", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.52, 0.10, 0.09)
		m.roughness = 0.55)


## Faded blue-grey enamel on classroom doors. It belongs to a different
## maintenance decade than either locker colour, which keeps the hall layered.
static func sch_door() -> StandardMaterial3D:
	return _std("sch_door", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.20, 0.29, 0.34)
		m.metallic = 0.18
		m.roughness = 0.58)


## Opaque wired-glass backing for inaccessible classrooms. It catches the hall
## light like old safety glass without revealing the ungenerated room volume.
static func sch_wired_glass() -> StandardMaterial3D:
	return _std("sch_wired_glass", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.28, 0.34, 0.32)
		m.metallic_specular = 0.7
		m.roughness = 0.3)


## Sealed concrete, polished by forty years of shoes. Roughness is pushed
## down hard so the corridor lights streak in it.
static func sch_floor() -> StandardMaterial3D:
	return _asy_tex("sch_floor", "Concrete035", 0.16, Color(0.66, 0.66, 0.67), 0.26)


## Speckled terrazzo — cafeteria, admin, anywhere spills happen.
static func sch_terrazzo() -> StandardMaterial3D:
	return _photo("sch_terrazzo", "cc0", "Terrazzo005", 0.5, Color(0.72, 0.70, 0.66), 0.35)


## Small square tile, walls and floors of the bathrooms.
static func sch_tile() -> StandardMaterial3D:
	return _asy_tex("sch_tile", "Tiles141", 0.75, Color(0.80, 0.82, 0.80), 0.5)


## Acoustic tile on an exposed grid, with a lot of water history.
static func sch_ceiling() -> Material:
	if _c.has("sch_ceiling"):
		return _c["sch_ceiling"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ceiling.gdshader")
	m.set_shader_parameter("col", Color(0.90, 0.89, 0.86))
	m.set_shader_parameter("stain_amount", 0.10)
	m.set_shader_parameter("bump_strength", 0.02)
	m.set_shader_parameter("missing_amount", 0.10)
	_c["sch_ceiling"] = m
	return m


## Mustard locker steel — the colour in the reference. Flat baked enamel, not
## a photo texture: a locker bank is read by its door seams, not its grain.
static func sch_locker() -> StandardMaterial3D:
	return _std("sch_locker", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.66, 0.44, 0.16)
		m.metallic = 0.25
		m.roughness = 0.44)


## The other decade's lockers: institutional blue.
static func sch_locker_blue() -> StandardMaterial3D:
	return _std("sch_locker_blue", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.20, 0.28, 0.40)
		m.metallic = 0.25
		m.roughness = 0.44)


## Opaque moulded polyethylene for the school janitor carts. `jug_blue()` is
## translucent drink-container plastic and made the entire trolley see-through.
static func sch_cart_plastic() -> StandardMaterial3D:
	return _std("sch_cart_plastic", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.13, 0.31, 0.44)
		m.metallic = 0.0
		m.roughness = 0.62)


## Sprung maple — the gym, and nothing else in the building.
static func sch_gymfloor() -> StandardMaterial3D:
	return _photo("sch_gymfloor", "cc0", "Planks039", 0.85, Color(0.86, 0.66, 0.38), 0.32)


## Varnished desk and bench tops.
static func sch_desk() -> StandardMaterial3D:
	return _photo("sch_desk", "cc0", "Planks039", 0.7, Color(0.62, 0.50, 0.36), 0.45)


## Green chalkboard, never quite wiped clean.
static func sch_board() -> StandardMaterial3D:
	return _std("sch_board", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.10, 0.19, 0.15)
		m.roughness = 0.82)


## Whiteboard, and the porcelain of the bathrooms.
static func sch_white() -> StandardMaterial3D:
	return _std("sch_white", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.90, 0.90, 0.88)
		m.roughness = 0.3)


## Anodised trim, locker banks' feet, door furniture, bench frames.
static func sch_trim() -> StandardMaterial3D:
	return _std("sch_trim", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.36, 0.37, 0.39)
		m.metallic = 0.7
		m.roughness = 0.42)


## Moulded plastic chair shells — one hue per room, seeded by the caller.
static func sch_chair(hue: float) -> StandardMaterial3D:
	return _std("sch_chair%.2f" % hue, func(m: StandardMaterial3D):
		m.albedo_color = Color.from_hsv(hue, 0.34, 0.50)
		m.roughness = 0.45)


## Cork noticeboard, layered with paper nobody will read.
static func sch_cork() -> StandardMaterial3D:
	return _std("sch_cork", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.55, 0.38, 0.20)
		m.roughness = 0.9)


## The strip lights: colder and cheaper than the office troffers.
static func sch_panel() -> StandardMaterial3D:
	return _std("sch_panel", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.86, 0.88, 0.84)
		m.emission_enabled = true
		m.emission = Color(0.92, 0.96, 0.88)
		m.emission_energy_multiplier = 3.0)


## The smear a board keeps after it has been wiped — chalk ground into the
## slate rather than removed. Barely there, and always in the same places.
static func sch_chalkdust() -> StandardMaterial3D:
	return _std("sch_chalkdust", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.62, 0.68, 0.60, 0.16)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.95)


# --- abandoned mall ----------------------------------------------------------

static func mall_floor() -> StandardMaterial3D:
	return _photo("mall_floor", "cc0", "Terrazzo005", 0.34,
		Color(0.72, 0.68, 0.61), 0.42)


static func mall_wall() -> StandardMaterial3D:
	# Clean off-white painted plaster — a mall is maintained right up until the
	# day it closes, so the decay lives in the light and the shutters, not the
	# walls. (The old PaintedPlaster018 read as a rusted cave.)
	return _photo("mall_wall", "mall", "Plaster001", 0.5,
		Color(0.87, 0.85, 0.80), 0.92)


static func mall_ceiling() -> Material:
	# A real suspended T-bar grid like the office and airport, not a glossy
	# slab: dingier tiles, heavy smoke staining, and more of them missing.
	if _c.has("mall_ceiling"):
		return _c["mall_ceiling"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ceiling.gdshader")
	m.set_shader_parameter("col", Color(0.72, 0.71, 0.66))
	m.set_shader_parameter("stain", Color(0.30, 0.24, 0.16))
	m.set_shader_parameter("stain_amount", 0.25)
	m.set_shader_parameter("missing_amount", 1.6)
	# grazing sodium light exaggerates the tile relief into pressed tin —
	# keep the grid, flatten the surface
	m.set_shader_parameter("bump_strength", 0.045)
	_c["mall_ceiling"] = m
	return m


static func mall_shutter() -> StandardMaterial3D:
	# Galvanized roller-shutter steel, dusty from years down.
	return _photo("mall_shutter", "mall", "CorrugatedSteel005", 1.1,
		Color(0.72, 0.71, 0.67), 0.55)


static func mall_brick() -> StandardMaterial3D:
	# Navy painted brick — the cinema block and anchor-store accent band.
	return _photo("mall_brick", "mall", "PaintedBricks001", 0.45,
		Color(0.85, 0.88, 0.95), 0.85)


static func mall_skylight() -> StandardMaterial3D:
	# Night sky through dirty laylight glass — barely-blue, faintly luminous.
	return _std("mall_skylight", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.04, 0.06, 0.11)
		m.roughness = 0.3
		m.emission_enabled = true
		m.emission = Color(0.10, 0.16, 0.30)
		m.emission_energy_multiplier = 0.9)


static func mall_sign_face() -> StandardMaterial3D:
	# A dead storefront lightbox: the acrylic face of a sign whose tubes went
	# out years ago. The faint emission keeps the lettering legible.
	return _std("mall_sign_face", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.80, 0.78, 0.71)
		m.roughness = 0.35
		m.emission_enabled = true
		m.emission = Color(0.72, 0.68, 0.58)
		m.emission_energy_multiplier = 0.22)


## Backing for a painted fascia board. The lightbox face above is pale and
## faintly lit, so it shows past a painted sign's own edges as two glowing
## strips; a painted board was screwed onto dark-painted ply instead.
static func mall_sign_board() -> StandardMaterial3D:
	return _std("mall_sign_board", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.11, 0.10, 0.09)
		m.roughness = 0.82)


static func mall_trim() -> StandardMaterial3D:
	return _std("mall_trim", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.12, 0.24, 0.24)
		m.metallic = 0.72
		m.roughness = 0.36)


static func mall_glass() -> StandardMaterial3D:
	return _std("mall_glass", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.12, 0.24, 0.23, 0.34)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.15
		m.roughness = 0.16)


static func mall_panel() -> StandardMaterial3D:
	return _std("mall_panel", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.82, 0.78, 0.66)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.72, 0.38)
		m.emission_energy_multiplier = 2.2)


# --- island prison -----------------------------------------------------------

static func prison_wall() -> StandardMaterial3D:
	# Smooth trowelled concrete, lighter than the old salt-black — the dark
	# lives in the corners now, not in every surface
	return _photo("prison_wall", "prison", "Concrete016", 0.40,
		Color(0.68, 0.69, 0.66), 0.95)


static func prison_dado() -> StandardMaterial3D:
	# The institutional green paint band every prison wall carries to
	# shoulder height, worn semi-gloss
	return _photo("prison_dado", "prison", "Concrete016", 0.40,
		Color(0.42, 0.53, 0.43), 0.5)


static func prison_floor() -> StandardMaterial3D:
	return _photo("prison_floor", "prison", "Concrete016", 0.55,
		Color(0.45, 0.46, 0.44), 0.55)


static func prison_ceiling() -> StandardMaterial3D:
	return _asy_tex("prison_ceiling", "PaintedPlaster018", 0.28,
		Color(0.35, 0.37, 0.34), 1.0)


static func prison_iron() -> StandardMaterial3D:
	return _asy_tex("prison_iron", "Metal021", 0.86,
		Color(0.38, 0.42, 0.39), 0.82)


static func prison_green() -> StandardMaterial3D:
	return _asy_tex("prison_green", "PaintedMetal006", 0.70,
		Color(0.55, 0.64, 0.54), 0.80)


## Yellowed institutional handset plastic. The downloaded desk phone ships with
## no maps at all, so the whole model takes this one material.
static func prison_handset() -> StandardMaterial3D:
	return _asy_tex("prison_handset", "PaintedMetal006", 0.52,
		Color(0.72, 0.69, 0.58), 0.46)


static func prison_tile() -> StandardMaterial3D:
	# Plain square tile under a film of grime — the shower block, distinct
	# from the asylum's cracked hydro tile
	return _photo("prison_tile", "prison", "Tiles107", 0.45,
		Color(0.58, 0.63, 0.58), 0.6)


static func prison_panel() -> StandardMaterial3D:
	return _std("prison_panel", func(m: StandardMaterial3D):
		m.albedo_color = Color(0.70, 0.75, 0.68)
		m.emission_enabled = true
		m.emission = Color(0.68, 0.82, 0.70)
		m.emission_energy_multiplier = 2.6)
