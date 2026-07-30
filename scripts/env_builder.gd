class_name EnvBuilder
extends RefCounted
## WorldEnvironment settings per floor.
##
## This was a 210-line if-chain inside main.gd. The shared base and the per-floor
## overrides were hard to tell apart, and changing one floor's haze meant
## scrolling past seven others. The base is applied once here and each floor is a
## named function, so a floor's look is one place to look.
##
## Values are carried over unchanged. The extraction was checked by dumping every
## stored Environment property for every theme before and after.
##
## Theme ids are sparse (3 was the cut theme park). Themes without a function of
## their own fall through to _vegas, which is the original else-branch.


static func build(theme: int) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssr_enabled = true
	env.ssr_max_steps = 32
	env.fog_enabled = true
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	# real-time GI: bounce light, color bleed, emissive surfaces lighting rooms
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = false
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_bounce_feedback = 0.4

	if theme == 9:
		_pool(env)
		return env
	if theme == 7:
		_mall(env)
		return env
	if theme == 8:
		_prison(env)
		return env
	if theme == 6:
		_school(env)
		return env
	if theme == 5:
		_asylum(env)
		return env
	if theme == 4:
		_airport(env)
		return env
	if theme == 2:
		_annex(env)
	elif theme == 1:
		_office(env)
	else:
		_vegas(env)
	return env


static func _pool(env: Environment) -> void:
	# The Poolrooms are lit by daylight from windows that never show
	# anywhere. Bright, humid and slightly overexposed: the haze is doing
	# most of the work, because volumetric fog is what turns the window
	# spots into real shafts rather than painted ones.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.63, 0.61)
	env.ambient_light_energy = 0.425
	env.fog_light_color = Color(0.86, 0.90, 0.87)
	env.fog_density = 0.0027
	env.fog_light_energy = 0.65
	env.volumetric_fog_density = 0.0038
	env.volumetric_fog_albedo = Color(0.94, 0.97, 0.95)
	env.volumetric_fog_emission = Color(0.10, 0.12, 0.11)
	env.volumetric_fog_length = 30.0
	env.volumetric_fog_gi_inject = 0.15
	# Chlorine glare. The windows are emissive well past white, so the
	# bloom is what sells them as daylight instead of as lit panels.
	env.glow_enabled = true
	env.glow_intensity = 0.0
	env.glow_bloom = 0.35
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.4


static func _mall(env: Environment) -> void:
	# A 1980s mall after closing. The sodium warmth belongs to the
	# maintenance FIXTURES, not the air: ambient and fog stay near-neutral
	# so white plaster reads white and the lamps read orange against it —
	# a fully saturated ambient painted every surface the same rust.
	env.background_color = Color(0.010, 0.010, 0.011)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.59, 0.54)
	env.ambient_light_energy = 0.46
	env.tonemap_exposure = 1.24
	env.sdfgi_energy = 1.22
	env.glow_enabled = true
	env.glow_intensity = 0.44
	env.glow_bloom = 0.035
	env.fog_light_color = Color(0.105, 0.095, 0.080)
	env.fog_density = 0.0035
	env.volumetric_fog_density = 0.0015
	env.volumetric_fog_albedo = Color(0.72, 0.66, 0.55)
	env.volumetric_fog_length = 54.0
	env.ssao_radius = 1.45
	env.ssao_intensity = 1.35


static func _prison(env: Environment) -> void:
	# Cold salt-eaten concrete and green institutional lamps. Dark at the
	# ends of blocks, but readable without forcing the flashlight on.
	env.background_color = Color(0.004, 0.006, 0.005)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.58, 0.51)
	env.ambient_light_energy = 0.37
	env.tonemap_exposure = 1.38
	env.sdfgi_energy = 1.16
	env.glow_enabled = true
	env.glow_intensity = 0.36
	env.glow_bloom = 0.025
	env.fog_light_color = Color(0.055, 0.070, 0.060)
	env.fog_density = 0.0045
	env.volumetric_fog_density = 0.0018
	env.volumetric_fog_albedo = Color(0.52, 0.62, 0.54)
	env.volumetric_fog_length = 50.0
	env.ssao_radius = 1.65
	env.ssao_intensity = 1.65


static func _school(env: Environment) -> void:
	# after hours: the strips are still on, cold and even, and the polished
	# floor throws them back. Bright enough to see all the way down, which
	# is the problem.
	env.background_color = Color(0.02, 0.021, 0.024)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.75, 0.80)
	env.ambient_light_energy = 0.46
	env.tonemap_exposure = 1.2
	env.sdfgi_energy = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.30
	env.glow_bloom = 0.03
	env.fog_light_color = Color(0.12, 0.13, 0.14)
	env.fog_density = 0.006
	env.volumetric_fog_density = 0.0025
	env.volumetric_fog_albedo = Color(0.80, 0.82, 0.86)
	env.volumetric_fog_length = 48.0
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.3


static func _asylum(env: Environment) -> void:
	# the asylum: bile-green dark, dust hanging in dead fluorescent light
	env.background_color = Color(0.005, 0.007, 0.004)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.58, 0.44)
	env.ambient_light_energy = 0.17
	env.tonemap_exposure = 1.25
	env.sdfgi_energy = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.fog_light_color = Color(0.05, 0.065, 0.045)
	env.fog_density = 0.011
	env.volumetric_fog_density = 0.005
	env.volumetric_fog_albedo = Color(0.62, 0.72, 0.55)
	env.volumetric_fog_length = 30.0
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6


static func _airport(env: Environment) -> void:
	# 3 a.m. departure hall: cold white light dissolving into black glass
	env.background_color = Color(0.006, 0.009, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.70, 0.85)
	env.ambient_light_energy = 0.22
	env.tonemap_exposure = 1.25
	env.sdfgi_energy = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.03
	env.fog_light_color = Color(0.10, 0.12, 0.16)
	env.fog_density = 0.005
	env.volumetric_fog_density = 0.002
	env.volumetric_fog_albedo = Color(0.75, 0.82, 0.95)
	env.volumetric_fog_length = 56.0
	env.ssao_radius = 1.3
	env.ssao_intensity = 1.1


static func _annex(env: Environment) -> void:
	# The Annex: warm, institutional Backrooms yellow. Local troffers carry
	# the bright spaces while lower ambient fill lets sparse fixture zones
	# fall visibly darker.
	env.background_color = Color(0.53, 0.47, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.96, 0.84, 0.53)
	env.ambient_light_energy = 0.20
	env.tonemap_exposure = 1.16
	env.sdfgi_energy = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.26
	env.glow_bloom = 0.018
	env.fog_light_color = Color(0.69, 0.60, 0.33)
	env.fog_density = 0.0022
	env.volumetric_fog_density = 0.0012
	env.volumetric_fog_albedo = Color(0.88, 0.78, 0.49)
	env.volumetric_fog_length = 52.0
	# Even contact-scale SSAO turned the two-centimetre skirting projection
	# into a detached dark wedge across the carpet. The Annex already has
	# SDFGI for structural depth, so remove this redundant screen-space pass.
	env.ssao_enabled = false
	# SDFGI's 15cm occlusion cells still expanded a zero-gap wall/floor
	# contact into thick, rectangular dark bands. Keep its bounce light and
	# color bleed, but drop only the coarse occlusion term for this floor.
	env.sdfgi_use_occlusion = false


static func _office(env: Environment) -> void:
	# sterile daylight-white: corridors dissolve into bright haze
	env.background_color = Color(0.55, 0.58, 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 0.86)
	env.ambient_light_energy = 0.45
	env.tonemap_exposure = 1.25
	env.sdfgi_energy = 1.3
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.02
	env.fog_light_color = Color(0.72, 0.76, 0.72)
	env.fog_density = 0.003
	env.volumetric_fog_density = 0.0012
	env.volumetric_fog_albedo = Color(0.9, 0.95, 0.9)
	env.volumetric_fog_length = 48.0
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.0


static func _vegas(env: Environment) -> void:
	# warm smoky casino dusk
	env.background_color = Color(0.02, 0.013, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.36, 0.30)
	env.ambient_light_energy = 0.19
	env.tonemap_exposure = 1.3
	env.sdfgi_energy = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.05
	env.fog_light_color = Color(0.23, 0.15, 0.11)
	env.fog_density = 0.009
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(0.9, 0.78, 0.62)
	env.volumetric_fog_length = 48.0
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.4
