shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley;

uniform sampler2D effect_mask : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 effect_color : source_color = vec3(0.24, 0.16, 0.08);
uniform float strength : hint_range(0.0, 1.0) = 0.45;
uniform vec2 atlas_scale = vec2(1.0);
uniform vec2 atlas_offset = vec2(0.0);
uniform float quarter_turns = 0.0;
// Damage decals must dissolve before reaching their geometry boundary. This is
// evaluated in full-mask UV space, so atlas tiles join without internal seams.
uniform float edge_feather : hint_range(0.01, 0.30) = 0.12;
// Break up broad extracted masks at material scale. Carpet uses more of this;
// ceiling water marks keep it low so they still read as soaked panels.
uniform float surface_breakup : hint_range(0.0, 0.5) = 0.06;

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(cell + vec2(1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 rotate_quarters(vec2 uv, float turns) {
	vec2 p = uv - 0.5;
	float a = turns * 1.57079632679;
	float cs = cos(a);
	float sn = sin(a);
	return mat2(vec2(cs, sn), vec2(-sn, cs)) * p + 0.5;
}

void fragment() {
	vec2 local_uv = rotate_quarters(UV, quarter_turns);
	vec2 mask_uv = local_uv * atlas_scale + atlas_offset;
	float authored_mask = texture(effect_mask, mask_uv).r;
	float fibers = value_noise(mask_uv * 83.0) * 0.65
		+ value_noise(mask_uv * 191.0) * 0.35;
	float breakup = (fibers - 0.5) * surface_breakup;
	float mask = clamp(authored_mask + breakup * smoothstep(0.03, 0.82, authored_mask), 0.0, 1.0);
	float boundary_distance = min(
		min(mask_uv.x, 1.0 - mask_uv.x),
		min(mask_uv.y, 1.0 - mask_uv.y));
	float boundary_fade = smoothstep(0.0, edge_feather, boundary_distance);
	// The authored mask controls only discoloration. The original ceiling
	// texture remains visible through the blend instead of being replaced.
	ALBEDO = effect_color;
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
	SPECULAR = 0.12;
	ALPHA = smoothstep(0.045, 0.78, mask) * strength * boundary_fade;
}
