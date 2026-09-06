shader_type spatial;
render_mode cull_disabled;

// LED jackpot ticker: valid, stable seven-segment numbers on a deep blue
// panel. The old shader lit random segments independently, producing
// impossible glyphs that looked like invented writing.

varying vec3 wpos;
varying vec2 suv;
uniform bool reduced_flashing = false;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	suv = UV;
}

float hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float draw_digit(vec2 g, int d) {
	float ha = (d != 1 && d != 4) ? 1.0 : 0.0;
	float hb = (d != 5 && d != 6) ? 1.0 : 0.0;
	float hc = (d != 2) ? 1.0 : 0.0;
	float hd = (d != 1 && d != 4 && d != 7) ? 1.0 : 0.0;
	float he = (d == 0 || d == 2 || d == 6 || d == 8) ? 1.0 : 0.0;
	float hf = (d != 1 && d != 2 && d != 3 && d != 7) ? 1.0 : 0.0;
	float hg = (d != 0 && d != 1 && d != 7) ? 1.0 : 0.0;
	float segs = 0.0;
	segs += ha * step(abs(g.y - 0.92), 0.065) * step(0.24, g.x) * step(g.x, 0.76);
	segs += hg * step(abs(g.y - 0.50), 0.065) * step(0.24, g.x) * step(g.x, 0.76);
	segs += hd * step(abs(g.y - 0.08), 0.065) * step(0.24, g.x) * step(g.x, 0.76);
	segs += hf * step(abs(g.x - 0.19), 0.07) * step(0.52, g.y) * step(g.y, 0.88);
	segs += hb * step(abs(g.x - 0.81), 0.07) * step(0.52, g.y) * step(g.y, 0.88);
	segs += he * step(abs(g.x - 0.19), 0.07) * step(0.12, g.y) * step(g.y, 0.48);
	segs += hc * step(abs(g.x - 0.81), 0.07) * step(0.12, g.y) * step(g.y, 0.48);
	return clamp(segs, 0.0, 1.0);
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
		vec2 g = vec2(dp.x, (dp.y - 0.2) / 0.6);
		int tier = int(floor(mh * 4.0));
		int value = 12500;
		if (tier == 1) value = 25000;
		if (tier == 2) value = 100000;
		if (tier == 3) value = 250000;
		float divisor = pow(10.0, 7.0 - cell);
		int digit = int(mod(floor(float(value) / divisor), 10.0));
		float lit = draw_digit(g, digit);
		c = mix(c, vec3(1.0, 0.60, 0.10), lit);
		em = mix(em, 2.0, lit);
	}

	float pulse = step(0.92, fract(TIME / 7.0 + mh));
	em *= reduced_flashing ? 1.0 : (1.0 + pulse * 0.8);
	float b = 1.0 - smoothstep(0.008, 0.03, min(min(suv.x, 1.0 - suv.x), min(suv.y, 1.0 - suv.y)));
	c = mix(c, vec3(0.90, 0.75, 0.30), b);
	ALBEDO = c * 0.62;
	EMISSION = c * max(em - 0.42, 0.0) * 0.72;
	ROUGHNESS = 0.27;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
