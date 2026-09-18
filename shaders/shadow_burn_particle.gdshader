shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled,
	shadows_disabled, fog_disabled;

uniform float hdr_peak : hint_range(1.0, 8.0) = 1.6;

varying float seed;


float hashf(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}


void vertex() {
	seed = hashf(MODEL_MATRIX[3].xyz);
	// Preserve each particle's authored scale while making the shard face the
	// camera. A slight per-particle stretch keeps the burst granular rather
	// than turning it into a cloud of identical discs.
	vec3 particle_scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz));
	VERTEX *= particle_scale * vec3(mix(0.55, 1.0, seed),
		mix(1.0, 1.9, seed), 1.0);
	mat4 billboard = mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
}


void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float shard = 1.0 - smoothstep(0.18, 1.0,
		length(vec2(p.x * mix(1.2, 2.2, seed), p.y)));
	float life = COLOR.a;
	vec3 amber = vec3(1.0, 0.32, 0.055);
	vec3 white_hot = vec3(1.0, 0.96, 0.82);
	vec3 colour = mix(amber, white_hot, 0.45 + seed * 0.55);
	// COLOR.a is the one-shot lifetime ramp: flash in, hold while travelling,
	// then dissolve completely. Additive blending lets true HDR values retain
	// their highlight detail instead of becoming an opaque white card.
	ALBEDO = colour * hdr_peak;
	EMISSION = colour * hdr_peak;
	ALPHA = shard * life;
}
