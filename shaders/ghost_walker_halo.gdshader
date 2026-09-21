shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

uniform float manifestation : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float burn : hint_range(0.0, 1.0) = 0.0;
uniform float ignite : hint_range(0.0, 1.0) = 0.0;
uniform float fragmented : hint_range(0.0, 1.0) = 0.0;
uniform float torch : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float halo_width : hint_range(0.0, 0.2) = 0.05;
uniform float halo_alpha : hint_range(0.0, 1.0) = 0.2;
uniform float halo_emission : hint_range(0.0, 2.0) = 0.5;

varying vec3 object_position;

void vertex() {
	object_position = VERTEX;
	// Expand the skinned silhouette radially. The blur remains stable rather
	// than waving as a visibly separate material around the walker.
	float width = halo_width * effect_strength;
	vec3 radial = normalize(vec3(VERTEX.x, (VERTEX.y - 0.85) * 0.35,
		VERTEX.z));
	VERTEX += normalize(mix(NORMAL, radial, 0.18)) * width;
	// Constant depth bias toward the camera so the shell never grazes the
	// body's prepass depth and flickers as the view moves. Far too small
	// to break real occlusion against furniture.
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z -= 0.0006 * POSITION.w;
}

void fragment() {
	float master = clamp(manifestation * fade * (1.0 - fragmented), 0.0, 1.0);
	float burn_progress = (1.0 - fade) * ignite;
	float alive = 1.0 - smoothstep(0.03, 0.42, burn_progress);
	float burn_envelope = smoothstep(0.0, 0.025, burn_progress)
		* (1.0 - smoothstep(0.82, 1.0, burn_progress));
	float burn_visibility = 1.0 - smoothstep(0.72, 1.0, burn_progress);
	// A smooth rim-weighted veil: bright at the silhouette edge, nearly
	// gone over the facing surface, so the authored body shows through
	// cleanly instead of drowning in patchy frost.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = 1.0 - smoothstep(0.0, 0.7, facing);
	float veil = halo_alpha * (0.18 + 0.82 * rim);
	// Near-static breakup keeps the stacked shells from reading as
	// discrete rings without visibly shimmering; each shell sits out of
	// register with the rest.
	float drift = texture(noise_tex,
		object_position.xy * 2.4 + vec2(TIME * 0.012, phase * 3.1)
		+ halo_width * 17.0).r;
	veil *= 0.88 + 0.22 * drift;
	float strength = master * alive * effect_strength;
	float burn_strength = manifestation * burn_visibility * burn_envelope
		* (1.0 - fragmented)
		* effect_strength;
	ALBEDO = vec3(0.55, 0.68, 0.85);
	EMISSION = vec3(0.30, 0.42, 0.60) * (halo_emission * 2.0) * strength * (0.3 + 0.7 * rim);
	ALPHA = clamp(strength * veil
		+ burn_strength * veil * 1.55, 0.0, min(0.92, veil * 1.55));
}
