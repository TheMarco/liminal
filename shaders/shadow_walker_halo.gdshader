shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_front, unshaded, shadows_disabled;

uniform float manifestation : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float burn : hint_range(0.0, 1.0) = 0.0;
uniform float ignite : hint_range(0.0, 1.0) = 0.0;
uniform float fragmented : hint_range(0.0, 1.0) = 0.0;
uniform float torch : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
// Unused here; declared so the shared halo builder can set it blindly.
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
}

void fragment() {
	float master = clamp(manifestation * fade * (1.0 - fragmented), 0.0, 1.0);
	float burn_progress = (1.0 - fade) * ignite;
	float alive = 1.0 - smoothstep(0.03, 0.42, burn_progress);
	float burn_envelope = smoothstep(0.0, 0.025, burn_progress)
		* (1.0 - smoothstep(0.82, 1.0, burn_progress));
	float burn_visibility = 1.0 - smoothstep(0.72, 1.0, burn_progress);
	// These shells are the Gaussian alpha kernel itself. A background sample
	// may be mathematically blurred but looks like glass or plastic; repeated
	// low-opacity black silhouettes create the soft-focus subject in the
	// supplied reference without a detached refractive layer.
	float strength = master * alive * effect_strength;
	float burn_strength = manifestation * burn_visibility * burn_envelope
		* (1.0 - fragmented)
		* effect_strength;
	ALBEDO = vec3(0.001);
	// Ordinary shells are non-emissive black alpha. Together their overlapping
	// weights form a continuous Gaussian tail around the opaque body.
	EMISSION = vec3(0.0);
	ALPHA = clamp(strength * halo_alpha
		+ burn_strength * halo_alpha * 1.55, 0.0, min(0.92, halo_alpha * 1.55));
}
