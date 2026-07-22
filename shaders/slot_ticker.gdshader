shader_type spatial;
render_mode unshaded;

// LED jackpot ticker: amber pseudo-7-segment digits counting on a deep blue
// panel, with a periodic jackpot pulse and gold border. Also used for the
// belly glass at a different size, where it reads as a denomination display.

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
	float mh = hashf(floor(wpos.xz * 2.0) + 7.0);
	vec3 c = vec3(0.01, 0.03, 0.22);
	float em = 0.5;
	vec2 uvq = vec2(suv.x, 1.0 - suv.y);

	float nd = 9.0;
	float cell = floor(uvq.x * nd);
	vec2 dp = vec2(fract(uvq.x * nd), uvq.y);
	if (cell >= 1.0 && cell <= 7.0 && dp.y > 0.2 && dp.y < 0.8) {
		float tstep = floor(TIME * 2.5 + mh * 31.0);
		float hsel = hashf(vec2(cell * 3.7, tstep));
		vec2 g = vec2(dp.x, (dp.y - 0.2) / 0.6);
		float segs = 0.0;
		segs += step(abs(g.y - 0.92), 0.07) * step(0.25, g.x) * step(g.x, 0.75) * step(0.2, hsel);
		segs += step(abs(g.y - 0.50), 0.07) * step(0.25, g.x) * step(g.x, 0.75) * step(0.45, fract(hsel * 7.0));
		segs += step(abs(g.y - 0.08), 0.07) * step(0.25, g.x) * step(g.x, 0.75) * step(0.3, fract(hsel * 13.0));
		segs += step(abs(g.x - 0.2), 0.08) * step(0.5, g.y) * step(0.35, fract(hsel * 3.0));
		segs += step(abs(g.x - 0.8), 0.08) * step(0.5, g.y) * step(0.25, fract(hsel * 5.0));
		segs += step(abs(g.x - 0.2), 0.08) * step(g.y, 0.5) * step(0.4, fract(hsel * 11.0));
		segs += step(abs(g.x - 0.8), 0.08) * step(g.y, 0.5) * step(0.35, fract(hsel * 17.0));
		float lit = clamp(segs, 0.0, 1.0);
		c = mix(c, vec3(1.0, 0.60, 0.10), lit);
		em = mix(em, 2.0, lit);
	}

	float pulse = step(0.92, fract(TIME / 7.0 + mh));
	em *= 1.0 + pulse * 0.8;
	float b = 1.0 - smoothstep(0.008, 0.03, min(min(suv.x, 1.0 - suv.x), min(suv.y, 1.0 - suv.y)));
	c = mix(c, vec3(0.90, 0.75, 0.30), b);
	ALBEDO = c * em;
}
