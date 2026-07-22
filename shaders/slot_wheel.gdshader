shader_type spatial;
render_mode unshaded, cull_disabled;

// Wheel-of-fortune style bonus wheel topper: colored wedges with white
// separators and number blocks, a black rim with chasing lamps, and a gold
// hub. Idles, then periodically spins with an ease-out and lands somewhere
// new. Drawn on a quad, cut to a circle with discard.

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
	vec2 p = (suv - 0.5) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float mh = hashf(floor(wpos.xz * 2.0));
	float ang = atan(p.y, p.x);

	float cyc = TIME / 13.0 + mh * 7.0;
	float cf = fract(cyc);
	float ease = 1.0 - pow(1.0 - smoothstep(0.05, 0.5, cf), 3.0);
	float rot = (floor(cyc) + ease) * 2.3999;
	float a = fract((ang + rot) / 6.2831);

	vec3 c;
	float em = 0.95;
	if (r > 0.86) {
		// rim with chasing lamps
		c = vec3(0.03, 0.03, 0.04);
		float li = fract(a * 40.0);
		float lamp = step(length(vec2(li - 0.5, (r - 0.93) / 0.07 * 0.5)), 0.28);
		float chase = step(0.5, fract(a * 8.0 - TIME * 0.9));
		c = mix(c, vec3(1.0, 0.95, 0.8), lamp * (0.25 + 0.75 * chase));
		em = mix(0.4, 1.6, lamp * chase);
	} else if (r > 0.32) {
		float seg = floor(a * 18.0);
		float m6 = mod(seg, 6.0);
		if (m6 < 1.0) c = vec3(0.90, 0.10, 0.50);
		else if (m6 < 2.0) c = vec3(0.10, 0.70, 0.90);
		else if (m6 < 3.0) c = vec3(0.95, 0.80, 0.10);
		else if (m6 < 4.0) c = vec3(0.90, 0.40, 0.10);
		else if (m6 < 5.0) c = vec3(0.50, 0.20, 0.80);
		else c = vec3(0.20, 0.75, 0.30);
		// white separators
		float sep = min(fract(a * 18.0), 1.0 - fract(a * 18.0));
		c = mix(vec3(0.95), c, smoothstep(0.02, 0.06, sep));
		// white number blocks with dark ticks
		float across = abs(fract(a * 18.0) - 0.5);
		float numblk = step(across, 0.16) * step(0.55, r) * step(r, 0.78);
		c = mix(c, vec3(0.98), numblk * 0.9);
		float tick = step(abs(fract(r * 14.0) - 0.5), 0.22) * numblk * step(across, 0.10);
		c = mix(c, vec3(0.1), tick * 0.85);
	} else {
		// gold hub with red pin
		float g = 1.0 - r / 0.32;
		c = mix(vec3(0.55, 0.40, 0.12), vec3(1.0, 0.85, 0.40), g);
		if (r < 0.1) c = vec3(0.9, 0.15, 0.2);
	}
	ALBEDO = c * em;
}
