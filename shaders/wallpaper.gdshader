shader_type spatial;

// Hotel corridor wall: dark wood wainscot below the chair rail, flock damask
// above. The damask is a real ogival trellis with a mirrored palmette inside
// each cell, raised in velvet flock over a striped ground — not a dot grid.
// The paper is hung in vertical drops, and every drop is very slightly off its
// neighbour in tone and alignment, which is most of what sells it as paper
// rather than texture. Coordinates are world-space (u = x + z works for all
// axis-aligned walls) so adjoining chunks match perfectly.

uniform vec3 col_a : source_color = vec3(0.50, 0.42, 0.33);
uniform vec3 col_b : source_color = vec3(0.38, 0.24, 0.21);
uniform vec3 col_flock : source_color = vec3(0.55, 0.40, 0.18);
uniform vec3 col_wood : source_color = vec3(0.24, 0.13, 0.075);
uniform vec3 col_trim : source_color = vec3(0.62, 0.45, 0.16);
uniform vec3 col_plaster : source_color = vec3(0.42, 0.38, 0.33);
uniform float rail_h = 1.0;
uniform float ceil_h = 3.2;
uniform float bump_strength = 0.22;
// width of one hung drop of paper, metres
uniform float drop_w = 0.53;
uniform vec2 motif = vec2(0.45, 0.62);
uniform float peel_amount = 1.0;
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

float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float sd_ell(vec2 p, vec2 r) {
	return (length(p / r) - 1.0) * min(r.x, r.y);
}

// One damask cell, p in [-0.5,0.5]^2 of the motif rectangle. Mirrored about
// the vertical axis, the way woven damask actually is.
float damask(vec2 p) {
	vec2 q = vec2(abs(p.x), p.y);

	// ogival trellis: arcs struck from the cell corners, meeting in points at
	// top and bottom — the lattice the ornament hangs inside
	float arc = abs(length(q - vec2(0.5, 0.5)) - 0.5);
	float arc2 = abs(length(q - vec2(0.5, -0.5)) - 0.5);
	float trellis = smoothstep(0.045, 0.012, min(arc, arc2));

	// central palmette: a stack of lobes down the axis
	float body = smoothstep(0.10, 0.0, sd_ell(q - vec2(0.0, 0.02), vec2(0.13, 0.20)));
	float crown = smoothstep(0.07, 0.0, sd_ell(q - vec2(0.0, 0.24), vec2(0.075, 0.10)));

	// side leaves curling out and back toward the axis
	float leaf = smoothstep(0.075, 0.0, sd_ell(
		(q - vec2(0.17, 0.10)) * mat2(vec2(0.87, 0.5), vec2(-0.5, 0.87)),
		vec2(0.135, 0.055)));
	float leaf2 = smoothstep(0.065, 0.0, sd_ell(
		(q - vec2(0.15, -0.14)) * mat2(vec2(0.87, -0.5), vec2(0.5, 0.87)),
		vec2(0.115, 0.048)));

	// stems tying the ornament into the trellis points
	float stem = smoothstep(0.030, 0.008, sd_seg(q, vec2(0.0, 0.30), vec2(0.0, 0.46)));
	float stem2 = smoothstep(0.026, 0.006, sd_seg(q, vec2(0.0, -0.22), vec2(0.0, -0.46)));

	float orn = max(max(max(body, crown), max(leaf, leaf2)), max(stem, stem2));
	return clamp(max(orn, trellis * 0.75), 0.0, 1.0);
}

// Damask mask at a wall point, with the brick-offset row stagger.
float damask_at(vec2 uv) {
	float row = floor(uv.y / motif.y);
	// alternate rows step half a motif sideways
	float sx = uv.x / motif.x + mod(row, 2.0) * 0.5;
	vec2 p = vec2(fract(sx) - 0.5, fract(uv.y / motif.y) - 0.5);
	return damask(p);
}

// Which drop of paper are we on, and how far up its edge has it let go?
// x = drop index, y = peel mask (1 = paper gone, plaster showing)
vec2 drop_at(vec2 uv) {
	float idx = floor(uv.x / drop_w);
	float f = fract(uv.x / drop_w);
	float seam = min(f, 1.0 - f);
	// paper lifts from a seam, worst high on the wall where the paste dried out
	float lift = hashf(vec2(idx, 3.0));
	float high = smoothstep(ceil_h - 1.3, ceil_h - 0.1, uv.y);
	float ragged = fbm(vec2(uv.x * 6.0, uv.y * 3.0));
	// keep it to a narrow tongue right at the seam, on a minority of drops —
	// broad peel patches read as blotchy damage, not as paper letting go
	float peel = smoothstep(0.085, 0.0, seam) * high * smoothstep(0.80, 0.99, lift);
	peel *= smoothstep(0.45, 0.80, ragged);
	return vec2(idx, clamp(peel * peel_amount, 0.0, 1.0));
}

float surf_h(vec3 wp) {
	float u = wp.x + wp.z;
	float y = wp.y;
	if (y < rail_h) {
		return vnoise(vec2(u * 6.0, y * 1.5)) * 0.45;
	}
	vec2 uv = vec2(u, y);
	vec2 dp = drop_at(uv);
	// each drop hangs a hair off its neighbour
	uv.y += hashf(vec2(dp.x, 7.0)) * 0.012;
	float dm = damask_at(uv);
	float ground = step(0.5, fract(u * 3.0)) * 0.12;
	float fabric = texture(detail_tex, uv / 1.1).r;
	// flock pile stands proud of the ground — but it is a few millimetres of
	// velvet, so keep it shallow or the wall reads as carved panelling
	float h = dm * 0.45 + ground + fabric * 0.18;
	// a seam is a shallow ridge; peeled paper drops away to plaster
	float seamf = fract(u / drop_w);
	h += smoothstep(0.03, 0.0, min(seamf, 1.0 - seamf)) * 0.25;
	h = mix(h, -0.5, dp.y);
	return h;
}

void fragment() {
	float u = wpos.x + wpos.z;
	float y = wpos.y;
	vec3 c;
	float rough = 0.85;
	float metal = 0.0;

	if (y < rail_h) {
		// wainscot: quartered panels of dark stained wood
		float grain = vnoise(vec2(u * 6.0, y * 1.5));
		float grain2 = vnoise(vec2(u * 40.0, y * 3.0));
		c = col_wood * (0.7 + 0.45 * grain) * (0.88 + 0.2 * grain2);
		rough = 0.45;
	} else if (y < rail_h + 0.07) {
		c = col_trim;
		rough = 0.3;
		metal = 0.6;
	} else {
		vec2 uv = vec2(u, y);
		vec2 dp = drop_at(uv);
		float dropr = hashf(vec2(dp.x, 7.0));
		// per-drop: a hair of vertical slip, and a slightly different dye lot
		uv.y += dropr * 0.012;

		// striped ground under the ornament — the cheap part of the paper
		float s = step(0.5, fract(u * 3.0));
		c = mix(col_a, col_b, s * 0.75);
		c *= 0.93 + 0.14 * dropr;             // dye lot drift between drops

		float dm = damask_at(uv);
		// flock: matte velvet pile, so it goes DARKER and rougher than ground
		vec3 fl = col_flock * (0.55 + 0.5 * vnoise(uv * 30.0));
		c = mix(c, fl, dm * 0.85);
		rough = mix(mix(0.9, 0.62, s), 0.98, dm);

		// sun-bleaching: the ornament fades faster than the ground
		float bleach = smoothstep(0.4, 1.0, fbm(uv * 0.22 + 11.0));
		c = mix(c, mix(c, vec3(dot(c, vec3(0.33))), 0.5), bleach * dm * 0.45);

		// seams between drops: a fine dark line, sometimes lifted and bright
		float seamf = fract(u / drop_w);
		float seam = smoothstep(0.022, 0.0, min(seamf, 1.0 - seamf));
		c *= 1.0 - seam * 0.28;

		// water damage running down from the ceiling in tongues
		float run = fbm(vec2(u * 1.6, y * 0.35) + 5.0);
		float tongue = smoothstep(0.55, 0.85, run) * smoothstep(ceil_h - 1.8, ceil_h, y);
		c = mix(c, c * vec3(0.72, 0.62, 0.5), tongue * 0.7);

		// scuffs and trolley knocks at hip height
		float scuff = smoothstep(0.55, 0.9, fbm(vec2(u * 3.0, y * 8.0) + 21.0));
		scuff *= smoothstep(0.55, 0.95, y - rail_h) * smoothstep(1.5, 0.9, y - rail_h);
		c = mix(c, c * 0.7, scuff * 0.5);

		// where the paper has let go, bare plaster and old paste
		vec3 plaster = col_plaster * (0.85 + 0.3 * fbm(uv * 7.0));
		plaster = mix(plaster, plaster * vec3(1.05, 0.98, 0.88), 0.5);
		c = mix(c, plaster, dp.y);
		rough = mix(rough, 0.95, dp.y);
	}

	// grime near floor and ceiling
	float grime = smoothstep(0.35, 0.0, y) * 0.5
		+ smoothstep(0.4, 0.0, ceil_h - y) * 0.3;
	float gn2 = vnoise(vec2(u * 2.3, y * 2.3));
	c *= 1.0 - grime * (0.35 + 0.4 * gn2);

	// embossed bump
	vec3 gn = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	vec3 axis = abs(gn.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 t1 = normalize(cross(axis, gn));
	vec3 t2 = cross(gn, t1);
	float e = 0.02;
	float h0 = surf_h(wpos);
	float d1 = (surf_h(wpos + t1 * e) - h0) / e;
	float d2 = (surf_h(wpos + t2 * e) - h0) / e;
	vec3 wn = normalize(gn - (t1 * d1 + t2 * d2) * bump_strength);
	NORMAL = normalize(mat3(VIEW_MATRIX) * wn);

	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.4;
}
