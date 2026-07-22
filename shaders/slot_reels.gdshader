shader_type spatial;
render_mode unshaded;

// Main slot machine face: three reels behind glass that idle, then spin and
// stop with a stagger; blinking credit display below, glowing title strip
// above, gold border, fake glass streak. Per-machine phase comes from world
// position so no two machines are in sync.

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
	float mh = hashf(floor(wpos.xz * 2.0));
	float v = 1.0 - suv.y; // 0 = bottom of face
	float x = suv.x;
	vec3 c = vec3(0.05, 0.06, 0.12);
	float em = 0.35;

	float border = 1.0 - smoothstep(0.015, 0.045, min(min(x, 1.0 - x), min(v, 1.0 - v)));

	vec2 w0 = vec2(0.08, 0.30);
	vec2 w1 = vec2(0.92, 0.88);
	if (x > w0.x && x < w1.x && v > w0.y && v < w1.y) {
		float rx = (x - w0.x) / (w1.x - w0.x);
		float rv = (v - w0.y) / (w1.y - w0.y);
		float reel = floor(rx * 3.0);
		float fx2 = fract(rx * 3.0);
		if (fx2 < 0.06 || fx2 > 0.94) {
			c = vec3(0.02, 0.02, 0.04); // reel divider
			em = 0.2;
		} else {
			// long idle, then a spin whose reels stop left-to-right
			float cyc = TIME / 9.0 + mh * 13.7;
			float cf = fract(cyc);
			float stop_t = 0.30 + reel * 0.12;
			float spin = smoothstep(0.06, 0.10, cf) - smoothstep(stop_t, stop_t + 0.06, cf);
			float steps_n = 8.0 + reel * 3.0;
			float pos = (floor(cyc) + smoothstep(0.06, stop_t + 0.03, cf)) * steps_n;
			float row = rv * 3.0 + pos;
			float sid = hashf(vec2(floor(row) * 7.31, reel * 3.7 + floor(mh * 91.0)));
			vec2 sp = vec2(fx2, fract(row));

			c = vec3(0.93, 0.91, 0.86); // reel paper
			em = 1.0;
			vec2 q = sp - vec2(0.5);
			float m4 = floor(fract(sid * 7.0) * 4.0);
			vec3 scol = vec3(0.0);
			float shape = 0.0;
			if (m4 < 1.0) {
				// BAR: red block with white band
				shape = step(abs(q.x), 0.30) * step(abs(q.y), 0.16);
				scol = (abs(q.y) < 0.055) ? vec3(0.95) : vec3(0.80, 0.10, 0.12);
			} else if (m4 < 2.0) {
				// SEVEN: top bar + diagonal stroke
				float topbar = step(abs(q.y - 0.20), 0.055) * step(abs(q.x), 0.20);
				float diag = step(abs(q.x + (q.y - 0.20) * 0.55), 0.075)
					* step(q.y, 0.22) * step(-0.30, q.y);
				shape = max(topbar, diag);
				scol = (fract(sid * 13.0) < 0.5) ? vec3(0.85, 0.10, 0.15) : vec3(0.15, 0.30, 0.80);
			} else if (m4 < 3.0) {
				// CHERRIES: two fruits and a stem
				float f1 = step(length(q - vec2(-0.10, -0.12)), 0.13);
				float f2 = step(length(q - vec2(0.12, -0.16)), 0.12);
				float stem = step(abs(q.x - q.y * 0.4 - 0.02), 0.03)
					* step(-0.05, q.y) * step(q.y, 0.28);
				shape = max(max(f1, f2), stem);
				scol = (max(f1, f2) > 0.5) ? vec3(0.75, 0.05, 0.10) : vec3(0.20, 0.50, 0.15);
			} else {
				// DIAMOND
				shape = step(abs(q.x) * 0.9 + abs(q.y), 0.26);
				scol = vec3(0.90, 0.70, 0.15);
			}
			c = mix(c, scol, shape);
			c = mix(c, vec3(0.60, 0.58, 0.55), spin * 0.7);           // motion blur
			c = mix(c, vec3(0.9, 0.1, 0.1), (1.0 - smoothstep(0.012, 0.03, abs(rv - 0.5))) * 0.5);
			c *= 0.75 + 0.5 * sin(rv * 3.1415);                       // reel curvature shading
		}
	} else if (v < 0.24 && v > 0.06 && x > 0.12 && x < 0.88) {
		// blinking segmented credit display
		float seg = step(0.5, hashf(vec2(floor(x * 14.0), floor(mh * 31.0) + floor(TIME * 1.5 + mh * 5.0))));
		c = mix(vec3(0.08, 0.03, 0.02), vec3(1.0, 0.55, 0.1), seg);
		em = mix(0.3, 1.6, seg);
	} else if (v > 0.92) {
		// title strip
		vec3 tc = mix(vec3(0.9, 0.2, 0.4), vec3(0.2, 0.6, 0.9), step(0.5, mh));
		c = tc * (0.7 + 0.3 * sin(TIME * 3.0 + mh * 9.0 + x * 6.0));
		em = 1.2;
	}

	c = mix(c, vec3(1.0, 0.85, 0.4), border);
	em = mix(em, 1.3, border);

	// glass streak
	float streak = 1.0 - smoothstep(0.02, 0.12, abs(fract((x + v) * 0.7 + 0.15) - 0.5));
	c += vec3(0.10) * streak;

	ALBEDO = c * em;
}
