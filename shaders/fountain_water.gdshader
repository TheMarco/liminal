shader_type spatial;
// Original shallow fountain treatment, kept independent of Poolrooms tuning.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley,
	specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;

// --- swell ------------------------------------------------------------------
uniform float wave_height = 0.0;
uniform float wave_speed_a = 0.38;
uniform float wave_speed_b = 0.29;
uniform float wave_length_a = 6.5;
uniform float wave_length_b = 3.1;

// --- surface detail ---------------------------------------------------------
uniform float normal_scale_a = 0.1291;
uniform float normal_scale_b = 0.3220;
uniform float normal_speed_a = -0.0172;
uniform float normal_speed_b = 0.0225;
uniform float normal_strength : hint_range(0.0, 2.0)  = 2.0;

// --- colour and absorption --------------------------------------------------
uniform vec3 shallow_colour : source_color = vec3(0.42, 0.60, 0.55);
uniform vec3 deep_colour : source_color = vec3(0.055, 0.145, 0.125);
uniform float depth_fade = 0.707;
uniform float opacity_min : hint_range(0.0, 1.0)  = 0.5825;
uniform float opacity_max : hint_range(0.0, 1.0)  = 0.9825;

// --- refraction -------------------------------------------------------------
uniform float refraction = 0.0362;

// --- fresnel ----------------------------------------------------------------
uniform float fresnel_power = 4.4188;
uniform float fresnel_strength : hint_range(0.0, 1.0)  = 0.9525;

// --- foam -------------------------------------------------------------------
uniform vec3 foam_colour : source_color = vec3(0.90, 0.94, 0.92);
uniform float foam_distance = 0.02;
uniform float foam_softness = 0.55;
uniform float foam_amount : hint_range(0.0, 1.0)  = 0.0;

// --- surface response -------------------------------------------------------
uniform float water_roughness : hint_range(0.0, 1.0)  = 0.193;
uniform float water_specular : hint_range(0.0, 1.0)  = 0.8;

varying vec3 world_pos;


// Cheap value noise. The spec prefers procedural breakup over a second
// texture, and foam only needs to avoid drawing a straight line.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


vec2 rot(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Barely any vertical travel. At any real amplitude the whole sheet heaves
	// up and down together — a 12m room is smaller than the wavelength, so it
	// reads as the water level rising and falling rather than as ripple. The
	// ripple you actually see is carried entirely by the normal maps below.
	float a = sin(world_pos.x / wave_length_a + TIME * wave_speed_a);
	float b = sin((world_pos.z * 0.82 + world_pos.x * 0.35) / wave_length_b
		+ TIME * wave_speed_b);
	VERTEX.y += (a * 0.6 + b * 0.4) * wave_height;
}


void fragment() {
	// --- two normal samples, second one rotated so the tiling never lines up
	vec2 uv_a = world_pos.xz * normal_scale_a + vec2(TIME * normal_speed_a, 0.0);
	vec2 uv_b = rot(world_pos.xz, 0.75) * normal_scale_b
		+ vec2(0.0, TIME * normal_speed_b);
	vec3 n_a = texture(normal_tex, uv_a).xyz * 2.0 - 1.0;
	vec3 n_b = texture(normal_tex, uv_b).xyz * 2.0 - 1.0;
	vec3 packed = normalize(mix(n_a, n_b, 0.5));
	NORMAL_MAP = packed * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;

	// --- how much water is standing between this pixel and the tile below it
	vec2 suv = SCREEN_UV;
	float raw = texture(depth_tex, suv).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(suv * 2.0 - 1.0, raw, 1.0);
	view.xyz /= view.w;
	float column = max(0.0, (-view.z) - (-VERTEX.z));

	// --- refraction, faded out in the shallows so the tile does not shear
	// away from the wall it is joined to
	float shallow_guard = clamp(column / max(foam_distance, 0.001), 0.0, 1.0);
	vec2 offset = packed.xy * refraction * shallow_guard;
	vec3 behind = texture(screen_tex, suv + offset).rgb;

	// --- absorption. Light is removed with distance travelled rather than the
	// surface simply being made see-through, which is what keeps the deep
	// water reading as green-black instead of as grey glass.
	float absorb = 1.0 - exp(-column / max(depth_fade, 0.001));
	vec3 tint = mix(shallow_colour, deep_colour, absorb);
	float opacity = mix(opacity_min, opacity_max, absorb);

	// --- contact foam. Procedural, drifting, and never a straight line.
	float edge = 1.0 - clamp(column / max(foam_distance, 0.001), 0.0, 1.0);
	float grain = vnoise(world_pos.xz * 3.1 + vec2(TIME * 0.05, TIME * -0.04));
	grain = mix(grain, vnoise(world_pos.xz * 7.3 - TIME * 0.03), 0.45);
	float foam = smoothstep(1.0 - foam_softness, 1.0,
		edge * (0.55 + grain * 0.75)) * foam_amount;

	ALBEDO = mix(behind * tint, tint, opacity);
	ALBEDO = mix(ALBEDO, foam_colour, foam);
	ALPHA = clamp(max(opacity, foam), 0.0, 1.0);
	ROUGHNESS = mix(water_roughness, 0.65, foam);
	SPECULAR = water_specular * (1.0 - foam * 0.7);
	METALLIC = 0.0;

	// --- Fresnel. Straight down you see the floor; along the surface it turns
	// into a mirror, which is the single biggest realism contributor here.
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0),
		fresnel_power);
	RIM = f * fresnel_strength * (1.0 - foam);
	RIM_TINT = 0.35;
}
