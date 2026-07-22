shader_type spatial;

// The world past the gate glass at 3 a.m.: black apron, a scatter of distant
// taxiway and runway lights on the horizon line, red obstruction beacons,
// and one aircraft slowly taxiing. The wet concrete below the horizon smears
// each light into a vertical streak. Applied to a panel just inside the real
// wall behind the curtain-wall glass; almost everything here is emission.

uniform float horizon = 1.35;      // world-space y of the far light line
uniform float u_scale = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hashf(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

float hashv(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One row of distant point lights along coordinate u at height y0.
// Returns intensity; col picked per light.
vec3 light_row(float u, float y, float y0, float spacing, float p_lit, float seed) {
	float cellf = floor(u / spacing);
	vec3 acc = vec3(0.0);
	for (int k = -1; k <= 1; k++) {
		float c = cellf + float(k);
		float h = hashf(c * 7.13 + seed);
		if (h > p_lit) { continue; }
		float lx = (c + 0.15 + 0.7 * hashf(c * 3.7 + seed + 9.0)) * spacing;
		float ly = y0 + (hashf(c * 5.1 + seed + 4.0) - 0.5) * 0.14;
		float dist = length(vec2(u - lx, (y - ly) * 1.6));
		float sz = 0.03 + 0.035 * hashf(c * 9.4 + seed + 2.0);
		float it = sz / max(dist, 0.004) - 0.28;
		it = clamp(it, 0.0, 3.2);
		float warm = hashf(c * 11.3 + seed + 6.0);
		vec3 lc = warm < 0.45 ? vec3(1.0, 0.72, 0.4) : (warm < 0.8 ? vec3(0.95, 0.98, 1.0) : vec3(0.35, 0.55, 1.0));
		// wet-apron smear: mirror streak fading downward below the horizon
		if (y < ly) {
			float streak = exp(-abs(u - lx) * 26.0) * exp(-(ly - y) * 1.4);
			acc += lc * streak * 0.30;
		}
		acc += lc * it;
	}
	return acc;
}

void fragment() {
	float u = (wpos.x + wpos.z) * u_scale;
	float y = wpos.y;

	// night gradient: deep blue band at the horizon fading to black above
	float sky = smoothstep(3.4, 0.6, y);
	vec3 c = vec3(0.010, 0.016, 0.032) * sky + vec3(0.002, 0.003, 0.006);
	// ground below the horizon is almost nothing
	c = mix(c, vec3(0.004, 0.005, 0.007), smoothstep(horizon + 0.1, horizon - 0.4, y));

	vec3 e = vec3(0.0);
	// far runway/taxiway edge lights — two staggered rows
	e += light_row(u, y, horizon, 1.9, 0.75, 1.0) * 0.8;
	e += light_row(u * 0.63 + 40.0, y, horizon + 0.22, 2.6, 0.55, 13.0) * 0.45;
	// red obstruction beacons up on unseen masts
	e += light_row(u * 0.41 + 90.0, y, horizon + 1.5, 7.0, 0.4, 29.0) * vec3(1.0, 0.12, 0.08) * 0.7;
	// one aircraft taxiing far out: a slow bright pair drifting along
	float tx = mod(TIME * 0.55, 90.0) - 10.0;
	float td = length(vec2(u - tx, (y - horizon - 0.06) * 1.7));
	e += vec3(0.95, 0.97, 1.0) * clamp(0.05 / max(td, 0.006) - 0.3, 0.0, 2.5);
	float tb = length(vec2(u - tx + 0.55, (y - horizon - 0.28) * 1.7));
	float blink = step(0.82, fract(TIME * 0.9));
	e += vec3(1.0, 0.1, 0.08) * clamp(0.03 / max(tb, 0.006) - 0.3, 0.0, 2.0) * blink;

	// parked heavies on the far stands: what a night aircraft actually is —
	// a strip of lit cabin windows, a glow on the tail, a breathing beacon
	for (int p = 0; p < 2; p++) {
		float seed = 31.0 + float(p) * 17.0;
		// anchor each plane to a fixed world position on a 53m cycle
		float cx = (floor((u + 26.5 + 23.0 * float(p)) / 53.0)) * 53.0 - 23.0 * float(p) + hashf(seed) * 20.0;
		float wu = u - cx;
		if (abs(wu) > 3.0) { continue; }
		// dark hull blocking the horizon glow behind it
		float hull = exp(-wu * wu * 0.5) * smoothstep(0.5, 0.15, abs(y - horizon - 0.14));
		c *= 1.0 - 0.7 * hull;
		// cabin window strip: a dotted line of warm points
		float dotp = (abs(fract(wu * 5.0) - 0.5)) / 5.0;
		float wy = (y - (horizon + 0.12)) * 2.4;
		float strip = exp(-wu * wu * 0.45);
		float wint = clamp(0.012 / max(length(vec2(dotp, wy)), 0.006) - 0.35, 0.0, 1.4);
		e += vec3(0.95, 0.88, 0.72) * wint * strip * 0.9;
		// tail fin catching stray apron light
		float fint = clamp(0.045 / max(length(vec2((wu - 1.7) * 0.9, (y - horizon - 0.5) * 1.2)), 0.01) - 0.2, 0.0, 0.4);
		e += vec3(0.5, 0.6, 0.8) * fint;
		// beacon on the crown, each plane on its own clock
		float bl = step(0.86, fract(TIME * 0.7 + hashf(seed + 3.0)));
		float bint = clamp(0.025 / max(length(vec2(wu + 0.4, (y - horizon - 0.4) * 1.6)), 0.006) - 0.3, 0.0, 1.6);
		e += vec3(1.0, 0.1, 0.08) * bint * bl;
	}

	// faint drizzle-haze granularity so the black is never flat
	e *= 0.85 + 0.3 * hashv(floor(vec2(u, y) * 60.0));

	ALBEDO = vec3(0.0);
	EMISSION = c + e * 1.6;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
