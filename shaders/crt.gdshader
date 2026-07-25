shader_type spatial;
render_mode unshaded;

// Untouched terminals display their ambient dot-matrix activity. Querying one
// instance switches only that CRT to a clean opaque phosphor field so the real
// pixel-font record rendered by chunk.gd never competes with fake information.

instance uniform float queried : hint_range(0.0, 1.0) = 0.0;

varying vec3 wpos;
varying vec2 suv;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	suv = UV;
}

float hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float mh = hashf(floor(wpos.xz * 3.0) + floor(wpos.y * 2.0));
	vec2 uvq = vec2(suv.x, 1.0 - suv.y);
	vec3 c;

	if (queried < 0.5) {
		// Idle mode: the original 8x5 field of wandering dot-matrix data.
		c = vec3(0.010, 0.020, 0.034);
		float em = 0.85;
		vec2 grid = vec2(8.0, 5.0);
		vec2 inset = vec2(0.08, 0.10);
		vec2 gp = (uvq - inset) / (vec2(1.0) - inset * 2.0);
		if (gp.x > 0.0 && gp.x < 1.0 && gp.y > 0.0 && gp.y < 1.0) {
			vec2 cellf = gp * grid;
			vec2 cid = floor(cellf);
			float ch = hashf(cid + floor(mh * 43.0));
			vec2 drift = vec2(
				sin(TIME * 0.8 + ch * 6.28) * 0.10,
				cos(TIME * 0.6 + ch * 9.42) * 0.12);
			vec2 dp = fract(cellf) - 0.5 - drift;
			vec2 mp = (dp + vec2(0.20, 0.30)) / vec2(0.40, 0.60);
			if (mp.x > 0.0 && mp.x < 1.0 && mp.y > 0.0 && mp.y < 1.0) {
				vec2 dot_id = floor(mp * vec2(3.0, 5.0));
				float glyph_seed = floor(TIME * 0.15 + ch * 9.0);
				float on = step(0.45, hashf(dot_id * 3.3 + vec2(ch * 91.0, glyph_seed)));
				vec2 dcen = fract(mp * vec2(3.0, 5.0)) - 0.5;
				float dot_m = step(length(dcen), 0.32) * on;
				c = mix(c, vec3(0.35, 0.95, 1.0), dot_m);
				em = mix(em, 1.6, dot_m);
			}
			float sel = floor(hashf(vec2(floor(TIME / 5.0 + mh * 13.0), mh * 7.0)) * 40.0);
			if (cid.y * 8.0 + cid.x == sel) {
				vec2 bp = abs(fract(cellf) - 0.5);
				float border = step(0.42, max(bp.x, bp.y));
				c = mix(c, vec3(0.5, 1.0, 1.0), border);
				em = mix(em, 1.8, border);
			}
		}
		c *= em;
	} else {
		// Query mode: the same cyan-blue phosphor, deliberately empty behind
		// the actual record rather than changing to a different monitor mood.
		c = vec3(0.010, 0.020, 0.034) * 0.85;
		float pool = 1.0 - smoothstep(0.0, 0.78,
			length((suv - 0.5) * vec2(1.0, 0.8)));
		c += vec3(0.006, 0.018, 0.024) * pool;
	}

	// Both modes remain part of the same tired, softly flickering CRT.
	c *= 0.90 + 0.10 * sin(uvq.y * 460.0);
	c *= 0.975 + 0.025 * sin(TIME * 59.0 + mh * 20.0);
	vec2 vq = abs(suv - 0.5) * 2.0;
	c *= 1.0 - smoothstep(0.6, 1.05, max(vq.x, vq.y)) * 0.6;

	ALBEDO = c;
}
