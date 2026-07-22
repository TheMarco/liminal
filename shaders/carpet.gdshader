shader_type spatial;

// Garish casino carpet: deep burgundy field, gold diamond lattice, teal
// medallions, heavy mottling and per-pixel pile bump. Pattern is sampled in
// world space so it tiles seamlessly across chunk boundaries.

uniform vec3 col_base : source_color = vec3(0.30, 0.05, 0.10);
uniform vec3 col_dark : source_color = vec3(0.10, 0.02, 0.05);
uniform vec3 col_gold : source_color = vec3(0.6, 0.44, 0.14);
uniform vec3 col_teal : source_color = vec3(0.05, 0.30, 0.28);
uniform float tile = 1.6;
uniform float bump_strength = 0.45;
uniform sampler2D detail_tex : filter_linear_mipmap_anisotropic, repeat_enable;

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

float surf_h(vec2 p2) {
	vec2 p = p2 / tile;
	vec2 g = fract(p) - 0.5;
	vec2 q = fract(p + 0.5) - 0.5;
	float dia = abs(g.x) + abs(g.y);
	float dia2 = abs(q.x) + abs(q.y);
	float lines = smoothstep(0.045, 0.0, abs(dia - 0.46))
		+ smoothstep(0.04, 0.0, abs(dia2 - 0.46));
	float r = length(g);
	float ring = smoothstep(0.025, 0.0, abs(r - 0.20));
	float med = smoothstep(0.16, 0.14, r);
	float fib = texture(detail_tex, p2 / 1.2).r;
	return lines * 0.25 + ring * 0.2 + med * 0.15 + fib * 0.45;
}

void fragment() {
	vec2 p = wpos.xz / tile;
	vec2 g = fract(p) - 0.5;
	vec2 q = fract(p + 0.5) - 0.5;
	float dia = abs(g.x) + abs(g.y);
	float dia2 = abs(q.x) + abs(q.y);

	vec3 c = col_base;
	// large-scale wear / grime mottling
	float m = vnoise(wpos.xz * 0.19);
	c = mix(c, col_dark, smoothstep(0.45, 0.9, m) * 0.65);
	float m2 = vnoise(wpos.xz * 0.6 + 31.7);
	c = mix(c, col_dark, smoothstep(0.6, 0.95, m2) * 0.35);
	// gold diamond lattice
	c = mix(c, col_gold, smoothstep(0.035, 0.0, abs(dia - 0.46)));
	c = mix(c, col_gold * 0.85, smoothstep(0.03, 0.0, abs(dia2 - 0.46)) * 0.8);
	// teal medallions with gold rings
	float r = length(g);
	c = mix(c, col_teal, smoothstep(0.16, 0.14, r));
	c = mix(c, col_gold, smoothstep(0.02, 0.0, abs(r - 0.20)));
	float r2 = length(q);
	c = mix(c, col_gold * 0.9, smoothstep(0.05, 0.03, r2));
	// carpet fibre variation (mipmapped so it stays calm at distance)
	float fib = texture(detail_tex, wpos.xz / 1.2).r;
	c *= 0.85 + 0.25 * fib;

	// height-field bump: perturb the world normal, then back to view space
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
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
