shader_type spatial;

// Printed, time-faded damask above stained vertical timber boards. The ink
// has NO relief: only paper fibres and shallow wood joints affect normals.
// Heights are in metres, not arbitrary pattern-mask amplitudes. Coordinates
// are world-space so both paper drops and planks continue across chunk joins.

uniform vec3 col_a : source_color = vec3(0.43, 0.28, 0.265);
uniform vec3 col_b : source_color = vec3(0.37, 0.225, 0.22);
uniform vec3 col_ink : source_color = vec3(0.55, 0.435, 0.29);
uniform vec3 col_wood : source_color = vec3(0.29, 0.16, 0.085);
uniform vec3 col_trim : source_color = vec3(0.62, 0.45, 0.16);
uniform vec3 col_plaster : source_color = vec3(0.42, 0.38, 0.33);
uniform float rail_h = 1.0;
uniform float ceil_h = 3.2;
uniform float paper_relief = 0.00012;
uniform float wood_relief = 0.00018;
uniform float board_width = 0.18;
uniform float joint_depth = 0.0008;
// width of one hung drop of paper, metres
uniform float drop_w = 0.53;
uniform vec2 motif = vec2(0.45, 0.62);
uniform float peel_amount = 0.35;
uniform sampler2D detail_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

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

float printed_leaf(vec2 p, vec2 a, vec2 b, float width, float aa) {
	vec2 axis = b - a;
	float len = length(axis);
	axis /= len;
	vec2 delta = p - a;
	float along = dot(delta, axis);
	float across = abs(dot(delta, vec2(-axis.y, axis.x)));
	float profile = sin(clamp(along / len, 0.0, 1.0) * 3.141593);
	float d = max(across - width * profile, max(-along, along - len));
	return 1.0 - smoothstep(-aa, aa, d);
}

// One damask cell, p in [-0.5,0.5]^2 of the motif rectangle. Mirrored about
// the vertical axis, the way woven damask actually is.
float damask(vec2 p) {
	vec2 q = vec2(abs(p.x), p.y);
	float aa = clamp(max(fwidth(p.x), fwidth(p.y)) * 0.65, 0.001, 0.018);

	// ogival trellis: arcs struck from the cell corners, meeting in points at
	// top and bottom — the lattice the ornament hangs inside
	float arc = abs(length(q - vec2(0.5, 0.5)) - 0.5);
	float arc2 = abs(length(q - vec2(0.5, -0.5)) - 0.5);
	float trellis = 1.0 - smoothstep(0.014 - aa, 0.014 + aa, min(arc, arc2));

	// Tapered botanical leaves instead of the old swollen ellipse stack. The
	// fine negative-space vein makes this read as an engraved printing block.
	float body = printed_leaf(q, vec2(0.0, -0.12), vec2(0.0, 0.37), 0.059, aa);
	float vein = 1.0 - smoothstep(0.003, 0.003 + aa, sd_seg(q, vec2(0.0, -0.04), vec2(0.0, 0.29)));
	body *= 1.0 - vein * 0.8;
	float crown = printed_leaf(q, vec2(0.0, 0.03), vec2(0.16, 0.28), 0.033, aa);
	float leaf = printed_leaf(q, vec2(0.0, -0.10), vec2(0.235, 0.10), 0.040, aa);
	float leaf2 = printed_leaf(q, vec2(0.0, -0.23), vec2(0.205, -0.13), 0.028, aa);

	// stems tying the ornament into the trellis points
	float stem = 1.0 - smoothstep(0.009 - aa, 0.009 + aa, sd_seg(q, vec2(0.0, 0.30), vec2(0.0, 0.46)));
	float stem2 = 1.0 - smoothstep(0.007 - aa, 0.007 + aa, sd_seg(q, vec2(0.0, -0.22), vec2(0.0, -0.46)));

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

// Anti-aliased joint masks keep 1–3 mm features from sparkling at distance.
float board_edge(float u) {
	float local = fract(u / board_width) * board_width;
	return min(local, board_width - local);
}

float fine_line(float distance_to_line, float width, float footprint) {
	return 1.0 - smoothstep(max(0.0, width - footprint), width + footprint, distance_to_line);
}

// Reuse the supplied hardwood, turned so the grain runs up each board. Each
// board samples a different strip, with no artificial horizontal end joints.
float timber_grain(vec2 uv, float footprint) {
	float board = floor(uv.x / board_width);
	float seed = hashf(vec2(board, 43.0));
	float x = fract(uv.x / board_width);
	vec2 grain_uv = vec2(uv.y / 1.6 + seed * 0.71, x * 0.16 + seed * 0.79);
	// A world-space footprint excludes per-board UV jumps from mip selection;
	// otherwise the very edges of every board acquire blurry halos.
	vec2 texel_density = vec2(textureSize(wood_tex, 0)) * vec2(1.0 / 1.6, 0.16 / board_width);
	float lod = max(0.0, log2(max(footprint, 0.0001) * max(texel_density.x, texel_density.y)));
	vec3 grain = textureLod(wood_tex, grain_uv, lod).rgb;
	return clamp(sqrt(dot(grain, vec3(0.2126, 0.7152, 0.0722))) * 2.3, 0.08, 0.95);
}

float timber_height(vec2 uv, float footprint) {
	float bevel = fine_line(board_edge(uv.x), 0.0018, max(0.001, footprint));
	return timber_grain(uv, footprint) * wood_relief - bevel * joint_depth;
}

float paper_height(vec2 uv) {
	// The printed ornament, hanging seams and stains deliberately do not enter
	// the height field. A paper surface must never shade like carved plaster.
	return texture(detail_tex, uv * 3.0).r * paper_relief;
}

void fragment() {
	float u = wpos.x + wpos.z;
	float y = wpos.y;
	vec3 c;
	float rough = 0.85;
	float metal = 0.0;
	float specular = 0.24;
	float footprint = max(length(dFdx(wpos)), length(dFdy(wpos)));

	if (y < rail_h) {
		float board = floor(u / board_width);
		float tone = hashf(vec2(board, 19.0));
		float grain = timber_grain(vec2(u, y), footprint);
		c = col_wood * (0.85 + tone * 0.28) * (0.58 + grain * 0.90);
		// Slight warm/cool stain variation, not alternating light/dark slats.
		c *= mix(vec3(0.94, 0.97, 1.02), vec3(1.04, 1.0, 0.94), tone);
		float joint = fine_line(board_edge(u), 0.00065, max(0.0003, footprint * 0.5));
		float bevel = fine_line(board_edge(u), 0.0022, max(0.0006, footprint * 0.5));
		// Subpixel seams fade to their actual coverage instead of widening into
		// black bars when the camera moves away.
		joint *= min(1.0, 0.0013 / max(footprint, 0.0013));
		c *= 1.0 - joint * 0.40 - bevel * 0.07;
		float polish = vnoise(vec2(u * 2.0, y * 4.0));
		rough = 0.43 + tone * 0.07 + polish * 0.09;
		specular = 0.34;
	} else if (y < rail_h + 0.07) {
		c = col_trim;
		rough = 0.3;
		metal = 0.6;
		specular = 0.4;
	} else {
		vec2 uv = vec2(u, y);
		vec2 dp = drop_at(uv);
		float dropr = hashf(vec2(dp.x, 7.0));
		// per-drop: a hair of vertical slip, and a slightly different dye lot
		uv.y += dropr * 0.012;

		// A restrained tonal ground; the old hard alternating stripes fought
		// the ornament and made every drop look ribbed.
		float s = 0.5 + 0.5 * cos(u * 6.283185 / drop_w);
		c = mix(col_a, col_b, 0.3 + s * 0.15);
		c *= 0.97 + 0.06 * dropr;

		float dm = damask_at(uv);
		// Antique-gold INK, not metal or raised flock. Ink and paper share the
		// same matte finish so the pattern survives without specular embossing.
		float fibre = texture(detail_tex, uv * 3.0).r;
		vec3 ink = col_ink * (0.96 + fibre * 0.08);
		c = mix(c, ink, dm * 0.68);
		c *= 0.985 + fibre * 0.03;
		rough = 0.91 + fibre * 0.035;

		// sun-bleaching: the ornament fades faster than the ground
		float bleach = smoothstep(0.4, 1.0, fbm(uv * 0.22 + 11.0));
		c = mix(c, mix(c, vec3(dot(c, vec3(0.33))), 0.5), bleach * dm * 0.45);

		// seams between drops: a fine dark line, sometimes lifted and bright
		float seamf = fract(u / drop_w);
		float seam = fine_line(min(seamf, 1.0 - seamf) * drop_w,
			0.0008, max(0.0004, footprint * 0.5));
		seam *= min(1.0, 0.0016 / max(footprint, 0.0016));
		c *= 1.0 - seam * 0.12;

		// water damage running down from the ceiling in tongues
		float run = fbm(vec2(u * 1.6, y * 0.35) + 5.0);
		float tongue = smoothstep(0.55, 0.85, run) * smoothstep(ceil_h - 1.8, ceil_h, y);
		c = mix(c, c * vec3(0.82, 0.76, 0.66), tongue * 0.4);

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

	// Sub-millimetre material relief only. Sample the current material on both
	// sides: crossing the chair rail must not create an artificial normal spike.
	vec3 gn = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	vec3 axis = abs(gn.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 t1 = normalize(cross(axis, gn));
	vec3 t2 = cross(gn, t1);
	float e = clamp(footprint, 0.0025, 0.025);
	vec2 uv0 = vec2(u, y);
	vec2 uv1 = uv0 + vec2(t1.x + t1.z, t1.y) * e;
	vec2 uv2 = uv0 + vec2(t2.x + t2.z, t2.y) * e;
	float h0 = 0.0;
	float h1 = 0.0;
	float h2 = 0.0;
	if (y < rail_h) {
		h0 = timber_height(uv0, footprint);
		h1 = timber_height(uv1, footprint);
		h2 = timber_height(uv2, footprint);
	} else if (y >= rail_h + 0.07) {
		h0 = paper_height(uv0);
		h1 = paper_height(uv1);
		h2 = paper_height(uv2);
	}
	vec3 wn = normalize(gn - t1 * ((h1 - h0) / e) - t2 * ((h2 - h0) / e));
	NORMAL = normalize(mat3(VIEW_MATRIX) * wn);

	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = specular;
}
