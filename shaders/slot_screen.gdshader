shader_type spatial;
render_mode unshaded;

// Animated slot machine face: scrolling neon gradient with reel cutouts and a
// desynced attract-mode blink. Phase is derived from world position so every
// machine flashes on its own beat. Output is >1.0 so bloom picks it up.

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
	float phase = hashf(floor(wpos.xz * 2.0)) * 6.2831;
	float t = TIME * 1.7 + phase;

	vec3 c1 = vec3(1.0, 0.15, 0.45);
	vec3 c2 = vec3(1.0, 0.75, 0.15);
	vec3 c3 = vec3(0.15, 0.85, 1.0);

	float band = fract(suv.y * 3.0 - t * 0.6);
	vec3 c = mix(c1, c2, smoothstep(0.0, 0.45, band));
	c = mix(c, c3, smoothstep(0.55, 1.0, band));

	// reel windows
	vec2 rp = vec2(fract(suv.x * 3.0), fract(suv.y * 4.0));
	float box = step(0.15, rp.x) * step(rp.x, 0.85) * step(0.2, rp.y) * step(rp.y, 0.8);
	c = mix(c * 0.3, c, box);

	float blink = 0.75 + 0.25 * step(0.5, fract(t * 0.9));
	ALBEDO = c * blink * 1.5;
}
