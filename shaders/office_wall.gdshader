shader_type spatial;

// Sterile off-white office wall: near-featureless flat paint with the
// faintest broad tonal variation and panel seams. Deliberately plain —
// the emptiness is the point.

uniform vec3 base_col : source_color = vec3(0.88, 0.87, 0.83);
uniform float ceil_h = 3.0;

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
	float u = wpos.x + wpos.z;
	float y = wpos.y;
	vec3 c = base_col;
	// faint vertical panel seams every 1.5m
	float seam = abs(fract(u / 1.5) - 0.5) * 1.5;
	c *= mix(0.975, 1.0, smoothstep(0.0, 0.025, seam));
	// broad, soft tonal variation
	c *= 0.985 + 0.025 * vnoise(vec2(u * 0.5, y * 0.5));
	// slight shadowing at the ceiling line
	c *= 1.0 - smoothstep(0.25, 0.0, ceil_h - y) * 0.06;

	ALBEDO = c;
	ROUGHNESS = 0.42;
	SPECULAR = 0.35;
}
