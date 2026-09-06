shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx;
uniform float fx_clock = 0.0;
uniform float born = -100.0;
uniform float impact = 0.5;
uniform float seed_phase = 0.0;
uniform vec2 drift = vec2(0.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
varying float fade;
varying float crest;

void vertex() {
	float age = max(fx_clock - born, 0.0);
	float angle = UV.x * 6.2831853;
	vec2 radial = vec2(cos(angle), sin(angle));
	float lobe = 0.72 + 0.18 * sin(angle * 7.0 + seed_phase)
		+ 0.1 * sin(angle * 13.0 - seed_phase);
	float height = max(0.0, (1.9 + impact * 1.25) * age - 4.9 * age * age);
	float radius = 0.24 + age * (0.7 + impact * 0.35) * UV.y;
	vec2 p = radial * radius + drift * age;
	VERTEX = vec3(p.x, height * UV.y * lobe, p.y);
	NORMAL = normalize(vec3(radial.x, -0.35, radial.y));
	float flight = (1.9 + impact * 1.25) / 4.9;
	fade = smoothstep(0.0, 0.035, age) * (1.0 - smoothstep(flight * 0.5, flight, age));
	crest = lobe;
}

void fragment() {
	// Ragged tips break into drops; no opaque white crown or emissive foam.
	float torn = 1.0 - smoothstep(crest * 0.83, crest * 0.83 + 0.15, UV.y);
	float fingers = smoothstep(-0.3, 0.55, sin(UV.x * 43.9823 + seed_phase)
		+ sin(UV.x * 81.6814 - seed_phase) * 0.3);
	float openings = mix(1.0, fingers, smoothstep(0.15, 0.7, UV.y));
	vec2 corrugation = texture(normal_tex, UV * vec2(3.0, 0.8)
		+ vec2(0.0, (fx_clock - born) * 0.5)).xy * 2.0 - 1.0;
	NORMAL = normalize(NORMAL + vec3(corrugation * 0.22, 0.0));
	float grazing = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	ALBEDO = vec3(0.025, 0.04, 0.035);
	ROUGHNESS = 0.055;
	SPECULAR = 0.8;
	ALPHA = fade * torn * openings * (0.13 + grazing * 0.32);
}
