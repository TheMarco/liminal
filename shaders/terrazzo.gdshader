shader_type spatial;

// Polished airport terrazzo: pale grey ground with multicolour stone chips,
// large-format tiles with fine seams, buffed to a soft mirror so SSR carries
// the lights and the night glass. World-space mapped.

uniform vec3 base_col : source_color = vec3(0.68, 0.67, 0.64);
uniform vec3 chip_a : source_color = vec3(0.42, 0.40, 0.38);
uniform vec3 chip_b : source_color = vec3(0.82, 0.80, 0.75);
uniform vec3 chip_c : source_color = vec3(0.35, 0.38, 0.44);
uniform float tile = 1.5;
uniform float bump_strength = 0.08;

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

// Voronoi-ish chip field: nearest feature distance drives chip shape.
float chips(vec2 p, out float id) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d = 8.0;
	id = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = g + vec2(hashf(i + g), hashf(i + g + 7.3)) - f;
			float dd = dot(o, o);
			if (dd < d) {
				d = dd;
				id = hashf(i + g + 3.1);
			}
		}
	}
	return sqrt(d);
}

float surf_h(vec2 p2) {
	vec2 g = fract(p2 / tile);
	float seam = min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y));
	return smoothstep(0.0, 0.015, seam) * 0.08;
}

void fragment() {
	vec2 p = wpos.xz;
	float id;
	float d = chips(p * 16.0, id);
	// chips: irregular flecks pressed flush into the ground
	float chip = 1.0 - smoothstep(0.16 + 0.2 * id, 0.34 + 0.2 * id, d);
	vec3 cc = chip_a;
	if (id > 0.66) { cc = chip_b; }
	else if (id > 0.33) { cc = chip_c; }
	vec3 c = mix(base_col, cc, chip * 0.55);
	// second, finer generation of chips
	float id2;
	float d2 = chips(p * 34.0 + 31.0, id2);
	float chip2 = 1.0 - smoothstep(0.12, 0.3, d2);
	c = mix(c, mix(chip_a, chip_b, id2), chip2 * 0.3);
	// broad clouding from years of buffing
	c *= 0.95 + 0.08 * vnoise(p * 0.35 + 11.0);
	// tile seams
	vec2 g = fract(p / tile);
	float seam = min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y));
	c *= mix(0.72, 1.0, smoothstep(0.004, 0.02, seam));

	vec3 gn = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	vec3 axis = abs(gn.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 t1 = normalize(cross(axis, gn));
	vec3 t2 = cross(gn, t1);
	float e = 0.02;
	float h0 = surf_h(wpos.xz);
	float d1 = (surf_h(wpos.xz + t1.xz * e) - h0) / e;
	float dd2 = (surf_h(wpos.xz + t2.xz * e) - h0) / e;
	vec3 wn = normalize(gn - (t1 * d1 + t2 * dd2) * bump_strength);
	NORMAL = normalize(mat3(VIEW_MATRIX) * wn);

	ALBEDO = c;
	// scuffed matte lanes where trolleys run, glassy elsewhere
	float scuff = smoothstep(0.55, 0.85, vnoise(p * 0.9 + 53.0));
	ROUGHNESS = 0.09 + scuff * 0.25;
	SPECULAR = 0.55;
}
