shader_type spatial;
render_mode depth_draw_always;

// Murky flowing sewage: two drifting noise layers build a rippled normal
// map, low roughness hands reflections to SSR, and the per-instance flow
// vector lets every channel stretch scroll in its own direction.

uniform vec3 shallow_col : source_color = vec3(0.13, 0.16, 0.11);
uniform vec3 deep_col : source_color = vec3(0.05, 0.07, 0.05);
instance uniform vec2 flow = vec2(0.35, 0.0);

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

float height(vec2 p) {
	vec2 d = flow * TIME;
	float h = vnoise((p - d) * 2.6);
	h += 0.55 * vnoise((p - d * 1.35) * 5.3 + 7.0);
	// slow cross-ripple so still stretches never look frozen
	h += 0.3 * vnoise(p * 1.3 + vec2(-TIME * 0.07, TIME * 0.05));
	return h;
}

void fragment() {
	vec2 p = wpos.xz;
	float e = 0.06;
	float h0 = height(p);
	float hx = height(p + vec2(e, 0.0));
	float hz = height(p + vec2(0.0, e));
	// tangent-space ripple normal (box top face: U along +x, V along +z)
	vec3 nm = normalize(vec3((h0 - hx) / e * 0.05, (h0 - hz) / e * 0.05, 1.0));
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	ALBEDO = mix(deep_col, shallow_col, h0 * 0.45);
	ALPHA = 0.9;
	ROUGHNESS = 0.05;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
