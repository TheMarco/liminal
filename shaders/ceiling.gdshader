shader_type spatial;

// Suspended mineral-fibre ceiling: a T-bar grid carrying 0.6m acoustic tiles.
// Each tile is an individual — its own brightness, its own fissure pattern, its
// own set of pinholes — and a few of them sag, stain through, or are missing
// entirely, leaving a black void into the plenum. World-space mapped so the
// grid runs unbroken across chunk seams.

uniform vec3 col : source_color = vec3(0.62, 0.58, 0.51);
uniform vec3 stain : source_color = vec3(0.34, 0.25, 0.15);
uniform vec3 col_rail : source_color = vec3(0.74, 0.73, 0.70);
uniform float tile = 0.6;
uniform float bump_strength = 0.12;
uniform float stain_amount = 1.0;
// how many tiles are gone / hanging open, 0 = a ceiling nobody has touched
uniform float missing_amount = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
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
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// The wandering worm-track fissures pressed into mineral fibre board. Domain
// warp a noise field, then keep only the narrow band either side of a level
// set — that band is the crack.
float fissure(vec2 p, float seed) {
	// real fissures are centimetres wide and centimetres apart — at metre
	// scale they read as marbling, which is exactly wrong
	vec2 q = (p + vec2(seed * 13.7, seed * 7.3)) * 7.0;
	// stretch so the tracks run long rather than blobby
	q.x *= 0.4;
	float w = fbm(q * 2.4);
	float d = abs(fbm(q * 1.3 + w * 0.7) - 0.5);
	return smoothstep(0.035, 0.0, d);
}

// Pinholes: the dense needle-punch stipple across the face of each tile.
float pinholes(vec2 p) {
	vec2 g = p * 62.0;
	vec2 c = floor(g);
	vec2 f = fract(g) - 0.5 - (hash2(c) - 0.5) * 0.55;
	return smoothstep(0.30, 0.06, length(f)) * step(0.35, hashf(c + 4.1));
}

// Per-tile state, kept in one place so height and colour always agree.
// x = missing (1 = open void), y = sag amount, z = per-tile brightness
vec3 tile_state(vec2 id) {
	float rm = hashf(id + 19.7);
	float missing = step(0.985 - 0.025 * missing_amount, rm);
	float sag = smoothstep(0.90, 1.0, hashf(id + 3.3)) * 0.75;
	float bright = 0.88 + 0.24 * hashf(id + 8.9);
	return vec3(missing, sag, bright);
}

float surf_h(vec2 p2) {
	vec2 id = floor(p2 / tile);
	vec2 f = fract(p2 / tile);
	vec3 st = tile_state(id);

	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	// the rail sits proud of the tile face; the tile is recessed below it
	float rail = smoothstep(0.055, 0.022, edge);
	float h = -0.75 * (1.0 - rail);

	// a sagging tile dishes toward its middle
	vec2 d = f - 0.5;
	float dish = (1.0 - dot(d, d) * 4.0);
	h -= st.y * max(dish, 0.0) * 1.4;

	// surface relief within the tile
	h += fissure(p2, hashf(id + 1.3)) * -0.55;
	h += pinholes(p2) * -0.22;
	h = mix(h, -3.0, st.x);   // missing tile: a hole
	return h;
}

void fragment() {
	vec2 id = floor(wpos.xz / tile);
	vec2 f = fract(wpos.xz / tile);
	vec3 st = tile_state(id);

	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float rail = smoothstep(0.055, 0.022, edge);

	// --- the tile face ---
	vec3 c = col * st.z;
	// mineral fibre is not flat colour — it is speckled aggregate
	c *= 0.93 + 0.14 * vnoise(wpos.xz * 26.0);
	float fis = fissure(wpos.xz, hashf(id + 1.3));
	c *= 1.0 - fis * 0.18;
	c *= 1.0 - pinholes(wpos.xz) * 0.22;

	// water stains bleed from tile corners and seams, where the leak runs
	float s1 = fbm(wpos.xz * 0.42);
	float s2 = fbm(wpos.xz * 1.1 + 17.3);
	float st_mask = smoothstep(0.55, 0.86, s1) * 0.8 + smoothstep(0.70, 0.95, s2) * 0.45;
	// a stain darkens hardest at its rim, like a tide mark
	float rim = smoothstep(0.50, 0.58, s1) * (1.0 - smoothstep(0.62, 0.74, s1));
	c = mix(c, stain, clamp(st_mask, 0.0, 1.0) * 0.75 * stain_amount);
	c = mix(c, stain * 0.55, rim * 0.5 * stain_amount);

	// a sagging tile has usually taken water — it goes dark and heavy
	c = mix(c, stain * 0.7, st.y * 0.5);

	float rough = 0.95;
	float metal = 0.0;
	float spec = 0.15;

	// --- the T-bar grid ---
	// painted steel: brighter, smoother, with a fine highlight down the crown
	vec3 rc = col_rail * (0.9 + 0.15 * hashf(id + 27.1));
	rc *= 0.85 + 0.3 * smoothstep(0.03, 0.0, edge);
	c = mix(c, rc, rail);
	rough = mix(rough, 0.45, rail);
	metal = mix(0.0, 0.35, rail);
	spec = mix(spec, 0.5, rail);

	// --- missing tiles: the dark plenum above ---
	// not pure black; a little grime catches whatever light gets up there
	vec3 void_c = vec3(0.020, 0.019, 0.017) * (0.6 + 0.8 * vnoise(wpos.xz * 9.0));
	float open = st.x * (1.0 - rail);
	c = mix(c, void_c, open);
	rough = mix(rough, 1.0, open);
	metal = mix(metal, 0.0, open);

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
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
}
