shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D height_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float metres_scale = 1.15;
uniform vec3 vessel_color : source_color = vec3(1.0, 0.015, 0.004);
uniform float pulse_offset = 0.0;

varying vec3 world_pos;
varying vec3 world_nrm;

vec4 triplanar(sampler2D tex, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(7.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	vec4 x = texture(tex, p.yz * metres_scale);
	vec4 y = texture(tex, p.xz * metres_scale);
	vec4 z = texture(tex, p.xy * metres_scale);
	return x * w.x + y * w.y + z * w.z;
}

vec3 triplanar_normal(sampler2D tex, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(7.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	vec3 tx = texture(tex, p.yz * metres_scale).xyz * 2.0 - 1.0;
	vec3 ty = texture(tex, p.xz * metres_scale).xyz * 2.0 - 1.0;
	vec3 tz = texture(tex, p.xy * metres_scale).xyz * 2.0 - 1.0;
	vec3 nx = vec3(tx.z * sign(n.x), tx.x, tx.y);
	vec3 ny = vec3(ty.x, ty.z * sign(n.y), ty.y);
	vec3 nz = vec3(tz.x, tz.y, tz.z * sign(n.z));
	return normalize(nx * w.x + ny * w.y + nz * w.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_nrm);
	vec3 hide = triplanar(skin_tex, world_pos, n).rgb;
	float rough_map = triplanar(rough_tex, world_pos, n).r;
	float height_map = triplanar(height_tex, world_pos, n).r;
	float ao_map = triplanar(ao_tex, world_pos, n).r;
	vec3 mapped_n = triplanar_normal(normal_tex, world_pos, n);
	float wrinkles = dot(hide, vec3(0.24, 0.58, 0.18));
	float vessel_phase = world_pos.y * 4.25 + world_pos.x * 1.17
		+ world_pos.z * 1.43 + (wrinkles - 0.5) * 7.5;
	float vessel_line = abs(sin(vessel_phase));
	float vessel = 1.0 - smoothstep(0.012, 0.052, vessel_line);
	float travelling = 0.55 + 0.45 * sin(TIME * 2.35 - world_pos.y * 1.8
		- world_pos.x * 0.32 + pulse_offset);
	vec3 bruised = mix(vec3(0.003, 0.004, 0.006),
		vec3(0.055, 0.008, 0.010), smoothstep(0.18, 0.86, wrinkles));
	ALBEDO = bruised * mix(0.72, 1.10, smoothstep(0.26, 0.76, height_map));
	ROUGHNESS = clamp(mix(0.12, 0.48, rough_map)
		+ (0.5 - height_map) * 0.10, 0.08, 0.62);
	METALLIC = 0.08;
	SPECULAR = 0.82;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mix(n, mapped_n, 0.68)), 0.0)).xyz);
	AO = mix(0.54, 1.0, ao_map) * mix(0.84, 1.0, height_map);
	AO_LIGHT_AFFECT = 0.62;
	EMISSION = vessel_color * vessel * (0.04 + travelling * 0.34);
}
