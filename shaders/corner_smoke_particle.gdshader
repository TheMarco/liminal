shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

varying float particle_seed;


float hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hashf(i), hashf(i + vec2(1.0, 0.0)), u.x),
		mix(hashf(i + vec2(0.0, 1.0)), hashf(i + vec2(1.0, 1.0)), u.x),
		u.y);
}


void vertex() {
	particle_seed = hashf(MODEL_MATRIX[3].xz + MODEL_MATRIX[3].yy);
	// CPUParticles supplies each mote's scale through MODEL_MATRIX. Preserve it
	// while replacing its basis with a full camera-facing billboard.
	VERTEX *= vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz));
	mat4 billboard = mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
}


void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float radius = length(p);
	float coarse = value_noise(UV * 4.2 + vec2(particle_seed * 7.3));
	float fine = value_noise(UV * 9.1 + vec2(-particle_seed * 11.7));
	float ragged_radius = radius + (coarse - 0.5) * 0.30 + (fine - 0.5) * 0.12;
	float soft_disc = 1.0 - smoothstep(0.38, 1.02, ragged_radius);
	// COLOR.a is the particle lifetime ramp. These motes absorb light and can
	// only become more transparent; there is deliberately no emission path.
	ALBEDO = vec3(0.0);
	ALPHA = soft_disc * COLOR.a * 0.82;
}
