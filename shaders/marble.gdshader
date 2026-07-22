shader_type spatial;

// Polished cream marble with grey veining and brass inlay seams, used in the
// grand double-height halls. Low roughness so SSR/specular picks up the
// chandeliers and neon coves.

uniform vec3 base_col : source_color = vec3(0.82, 0.79, 0.74);
uniform vec3 vein_col : source_color = vec3(0.42, 0.40, 0.38);
uniform vec3 gold_col : source_color = vec3(0.72, 0.55, 0.22);
uniform float tile = 1.2;
uniform float bump_strength = 0.12;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.13 + vec2(11.7, 5.3);
		a *= 0.5;
	}
	return v;
}

float surf_h(vec2 p2) {
	vec2 g = fract(p2 / tile);
	float seam = min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y));
	return smoothstep(0.0, 0.02, seam) * 0.1;
}

void fragment() {
	vec2 p = wpos.xz;
	float n = fbm(p * 0.7);

	// primary veins
	float v = pow(max(0.0, 1.0 - abs(sin((p.x + p.y * 0.6) * 1.1 + n * 7.0))), 6.0);
	vec3 c = mix(base_col, vein_col, v * 0.85);
	// secondary fine veins
	float v2 = pow(max(0.0, 1.0 - abs(sin((p.y - p.x) * 2.1 + fbm(p * 1.7) * 9.0))), 14.0);
	c = mix(c, vein_col * 0.75, v2 * 0.5);
	// subtle cloudy variation
	c *= 0.94 + 0.1 * fbm(p * 0.3 + 41.0);
	// brass inlay along the tile seams
	vec2 g = fract(p / tile);
	float seam = min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y));
	float inlay = 1.0 - smoothstep(0.008, 0.022, seam);
	c = mix(c, gold_col, inlay);

	vec3 gn = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	vec3 axis = abs(gn.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 t1 = normalize(cross(axis, gn));
	vec3 t2 = cross(gn, t1);
	float e = 0.02;
	float h0 = surf_h(wpos.xz);
	float d1 = (surf_h(wpos.xz + t1.xz * e) - h0) / e;
	float d2 = (surf_h(wpos.xz + t2.xz * e) - h0) / e;
	vec3 wn = normalize(gn - (t1 * d1 + t2 * d2) * bump_strength);
	NORMAL = normalize(mat3(VIEW_MATRIX) * wn);

	ALBEDO = c;
	ROUGHNESS = 0.1 + v * 0.15 + inlay * 0.15;
	METALLIC = inlay * 0.8;
	SPECULAR = 0.6;
}
