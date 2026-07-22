shader_type spatial;

// Backlit advertising lightbox: a soft duotone photograph-shaped glow with a
// pale headline bar and a few lines of unreadable body text. Reads perfectly
// as an ad from walking distance, resolves into nothing up close — which is
// exactly how airport ads feel. UV-mapped onto a quad.

uniform vec3 col_a : source_color = vec3(0.16, 0.32, 0.55);
uniform vec3 col_b : source_color = vec3(0.85, 0.75, 0.55);
uniform float glow = 1.15;
uniform float seed = 0.0;

float hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.7) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hashf(i), hashf(i + vec2(1.0, 0.0)), u.x),
		mix(hashf(i + vec2(0.0, 1.0)), hashf(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	// blurred "photograph": big soft blobs of the two brand colours
	float n = vnoise(uv * 3.0 + seed * 5.0);
	float n2 = vnoise(uv * 6.5 + 9.0 + seed * 3.0);
	vec3 c = mix(col_a, col_b, smoothstep(0.3, 0.75, n));
	c = mix(c, col_a * 0.55, smoothstep(0.6, 0.9, n2) * 0.5);
	// bright key subject glow off-centre
	vec2 sc = vec2(0.38 + 0.2 * hashf(vec2(seed, 1.0)), 0.6);
	c += vec3(0.9, 0.88, 0.8) * exp(-length((uv - sc) * vec2(2.6, 3.2)) * 2.6) * 0.32;
	// headline bar
	float hl = smoothstep(0.255, 0.25, abs(uv.y - 0.24) - 0.028);
	float hw = step(uv.x, 0.12 + 0.5 * hashf(vec2(seed, 2.0))) * step(0.08, uv.x);
	c = mix(c, vec3(0.96, 0.96, 0.94), hl * hw * 0.9);
	// two lines of fake body text
	for (int i = 0; i < 2; i++) {
		float ty = 0.155 - float(i) * 0.045;
		float ln = smoothstep(0.011, 0.009, abs(uv.y - ty));
		float words = step(0.55, hashf(vec2(floor(uv.x * 26.0), float(i) + seed)));
		c = mix(c, vec3(0.9), ln * words * step(0.08, uv.x) * step(uv.x, 0.7) * 0.55);
	}
	// tiny logo block bottom-right
	float lg = step(0.82, uv.x) * step(uv.x, 0.93) * step(0.06, uv.y) * step(uv.y, 0.115);
	c = mix(c, vec3(0.95), lg * 0.85);
	// edge falloff of the backlight
	float edge = smoothstep(0.0, 0.06, uv.x) * smoothstep(1.0, 0.94, uv.x)
		* smoothstep(0.0, 0.06, uv.y) * smoothstep(1.0, 0.94, uv.y);

	ALBEDO = c * 0.25;
	EMISSION = c * glow * (0.55 + 0.45 * edge);
	ROUGHNESS = 0.2;
	SPECULAR = 0.4;
}
