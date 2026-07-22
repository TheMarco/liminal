shader_type spatial;
render_mode cull_disabled, unshaded, blend_mix;

// Falling water column from an outfall pipe: pale translucent bands
// rushing straight down, fading toward the edges and the splash point.

varying vec3 wpos;
varying vec2 suv;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	suv = UV;
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

void fragment() {
	// bands race downward; lateral coordinate from world so all faces agree
	float lat = wpos.x + wpos.z;
	float band = vnoise(vec2(lat * 9.0, wpos.y * 2.2 + TIME * 3.4));
	band = 0.45 + 0.55 * band;
	// thin the sheet toward its side edges and bottom
	float edge = smoothstep(0.0, 0.25, suv.x) * smoothstep(1.0, 0.75, suv.x);
	float tail = smoothstep(0.0, 0.18, suv.y);
	ALBEDO = vec3(0.55, 0.66, 0.58) * band;
	ALPHA = 0.42 * band * edge * tail;
}
