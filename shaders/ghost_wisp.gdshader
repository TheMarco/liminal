shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled,
	shadows_disabled;

// Matter the figure sheds: soft dark motes drifting off the silhouette.
// They obey the same law as the body — they absorb the light behind them
// rather than painting a colour, so they are smoke in a lit room and nearly
// nothing in a dark one — and being true 3D quads in world space they
// parallax correctly, which anchors the flat card into the room.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable,
	filter_linear;
// Fraction of the light that survives through a mote's dense centre.
uniform float absorb = 0.34;

void vertex() {
	// Billboard that keeps the per-particle scale baked into MODEL_MATRIX.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	// COLOR.a carries the particle's lifetime envelope from the ramp.
	float density = smoothstep(1.0, 0.18, d) * COLOR.a;
	vec3 behind = texture(screen_tex, SCREEN_UV).rgb;
	ALBEDO = behind * mix(1.0, absorb, density);
	ALPHA = clamp(density * 0.85, 0.0, 1.0);
}
