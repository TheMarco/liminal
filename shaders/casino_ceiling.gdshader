shader_type spatial;

// Hotel-casino coffered ceiling. Deep recessed panels in a 2.4m grid, each
// stepped down through two mouldings with a gilt bead on the lip, a worn
// medallion pressed into the panel field, and forty years of cigarette smoke
// pooled in the recesses. World-space mapped so coffers run true across cells.

uniform vec3 col_panel : source_color = vec3(0.40, 0.33, 0.27);
uniform vec3 col_beam : source_color = vec3(0.30, 0.24, 0.19);
uniform vec3 col_gilt : source_color = vec3(0.62, 0.45, 0.16);
uniform vec3 col_smoke : source_color = vec3(0.20, 0.15, 0.10);
uniform float coffer = 2.4;
uniform float bump_strength = 0.30;
// 0 = a ceiling that has been cleaned this decade
uniform float grime_amount = 1.0;
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

// Distance from the coffer centre in "square" metric — square coffers need a
// chebyshev falloff, not a radial one, or the mouldings bow at the corners.
float box_d(vec2 f) {
	vec2 d = abs(f - 0.5) * 2.0;
	return max(d.x, d.y);
}

// The plaster medallion pressed into the middle of each panel: an eight-lobe
// rosette inside a plain ring. Deliberately shallow — it should catch a
// grazing highlight, not read as a sculpture.
float medallion(vec2 f, float rot) {
	vec2 d = (f - 0.5) * 2.0;
	float r = length(d);
	float a = atan(d.y, d.x) + rot;
	float lobes = 0.5 + 0.5 * cos(a * 8.0);
	float body = smoothstep(0.46, 0.30, r - lobes * 0.07);
	float ring = smoothstep(0.60, 0.55, r) * smoothstep(0.49, 0.54, r);
	return body * 0.6 + ring * 0.5;
}

float surf_h(vec2 p2) {
	vec2 id = floor(p2 / coffer);
	vec2 f = fract(p2 / coffer);
	float d = box_d(f);

	// stepped profile from beam face (d=1) down into the panel field (d=0)
	float step1 = smoothstep(0.90, 0.84, d);   // first drop off the beam
	float step2 = smoothstep(0.80, 0.74, d);   // second, into the panel
	float h = -(step1 * 0.5 + step2 * 0.5);

	// gilt bead sits proud on the lip of the second step
	float bead = smoothstep(0.80, 0.775, d) * smoothstep(0.74, 0.765, d);
	h += bead * 0.55;

	h -= medallion(f, hashf(id) * 6.28) * 0.42;
	h += fbm(p2 * 5.0) * 0.10;
	return h;
}

void fragment() {
	vec2 id = floor(wpos.xz / coffer);
	vec2 f = fract(wpos.xz / coffer);
	float d = box_d(f);

	float in_panel = smoothstep(0.80, 0.74, d);
	float bead = smoothstep(0.80, 0.775, d) * smoothstep(0.74, 0.765, d);
	float riser = smoothstep(0.90, 0.84, d) - smoothstep(0.80, 0.74, d);

	// base: beam outside, panel inside, with a slightly different plaster tone
	// per coffer so a long hall does not read as a repeating stamp
	vec3 c = mix(col_beam, col_panel * (0.92 + 0.16 * hashf(id + 5.5)), in_panel);

	// plaster tooth
	float tooth = texture(detail_tex, wpos.xz / 0.9).r;
	c *= 0.90 + 0.18 * tooth;
	c *= 0.94 + 0.12 * fbm(wpos.xz * 3.0);

	// the riser faces catch less light and hold more dirt
	c *= 1.0 - riser * 0.22;

	float rough = 0.88;
	float metal = 0.0;

	// medallion: shallow relief, picks up a little of the gilt
	float med = medallion(f, hashf(id) * 6.28) * in_panel;
	c = mix(c, mix(c, col_gilt * 0.7, 0.25), med);

	// gilt bead — worn through to dull plaster in patches, never a clean line
	float wear = smoothstep(0.35, 0.75, fbm(wpos.xz * 2.2 + 9.1));
	vec3 gilt = mix(col_gilt * 0.45, col_gilt, wear);
	c = mix(c, gilt, bead * (0.55 + 0.45 * wear));
	rough = mix(rough, mix(0.62, 0.28, wear), bead);
	metal = mix(metal, 0.75 * wear, bead);

	// --- decades of smoke ---
	// tar pools where air stalls: deep in the coffers and hard into the corners
	float pocket = in_panel * (0.35 + 0.65 * smoothstep(0.7, 0.0, d));
	float blotch = fbm(wpos.xz * 0.5 + 31.7);
	float smoke = clamp(pocket * (0.45 + 0.75 * blotch), 0.0, 1.0);
	c = mix(c, col_smoke, smoke * 0.55 * grime_amount);

	// old water damage creeping out of one corner of some coffers
	float leak = smoothstep(0.62, 0.92, fbm(wpos.xz * 0.33 + 4.2));
	c = mix(c, col_smoke * 1.25, leak * 0.4 * grime_amount);

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
	SPECULAR = 0.35;
}
