shader_type spatial;

// Dead midway asphalt: cold gray, hairline cracks, weeds pushing through
// at the seams, and rain-wet patches that catch the lamp light.

uniform vec3 base_col : source_color = vec3(0.155, 0.155, 0.165);
uniform vec3 grass_col : source_color = vec3(0.10, 0.14, 0.06);
uniform sampler2D detail_tex : hint_default_white;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hashf(i), hashf(i + vec2(1.0, 0.0)), u.x),
		mix(hashf(i + vec2(0.0, 1.0)), hashf(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 c = base_col;
	c *= 0.88 + 0.2 * vnoise(p * 0.4);
	c *= 0.93 + 0.12 * texture(detail_tex, p * 0.5).r;

	// hairline cracks: thin dark ridges of two noise fields
	float cr1 = abs(vnoise(p * 0.9) * 2.0 - 1.0);
	float cr2 = abs(vnoise(p * 2.3 + 31.0) * 2.0 - 1.0);
	float crack = smoothstep(0.05, 0.015, cr1) + smoothstep(0.045, 0.012, cr2) * 0.6;
	c *= 1.0 - 0.5 * clamp(crack, 0.0, 1.0);

	// weeds through the bigger cracks and along patch borders
	float weed = smoothstep(0.66, 0.8, vnoise(p * 0.55 + 7.0)) * smoothstep(0.02, 0.05, crack + 0.03);
	weed = max(weed, smoothstep(0.83, 0.93, vnoise(p * 0.9 + 77.0)));
	c = mix(c, grass_col * (0.7 + 0.5 * vnoise(p * 6.0)), weed);

	// standing rain: broad glossy patches
	float wet = smoothstep(0.52, 0.78, vnoise(p * 0.35 + 51.0));
	c *= 1.0 - 0.25 * wet;

	ALBEDO = c;
	ROUGHNESS = mix(mix(0.85, 0.18, wet), 1.0, weed);
	SPECULAR = 0.45;
}
