shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back,
	shadows_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic,
	repeat_enable;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float manifestation : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float burn : hint_range(0.0, 1.0) = 0.0;
uniform float ignite : hint_range(0.0, 1.0) = 0.0;
uniform float fragmented : hint_range(0.0, 1.0) = 0.0;
uniform float torch : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
uniform float burn_peak : hint_range(1.0, 8.0) = 1.25;
uniform float foot_base = 0.0;

varying vec3 object_position;
varying vec2 albedo_uv;

void vertex() {
	object_position = VERTEX;
	albedo_uv = UV;
}

void fragment() {
	float broad = texture(noise_tex,
		object_position.xz * 0.78 + vec2(TIME * 0.022, phase * 4.13)).r;
	float fine = texture(noise_tex,
		object_position.xy * 6.2 + vec2(-TIME * 0.031, phase * 7.91)).g;

	float burn_progress = (1.0 - fade) * ignite;
	float erosion_noise = broad * 0.68 + fine * 0.32;
	float erosion_at = mix(0.20, 0.76, erosion_noise);
	float burn_visibility = 1.0 - smoothstep(erosion_at, erosion_at + 0.13,
		burn_progress);
	float master = clamp(manifestation * mix(fade, burn_visibility, ignite)
		* (1.0 - fragmented), 0.0, 1.0);
	// Coalesce in irregular patches all over the moving body, rather than pop
	// in a complete mannequin and wait. At full manifestation this is neutral.
	float reveal_threshold = (broad * 0.72 + fine * 0.28) * 0.55 - 0.18;
	float arrival = smoothstep(reveal_threshold, reveal_threshold + 0.30, manifestation);
	float arrival_edge = (1.0 - smoothstep(0.0, 0.10,
		abs(manifestation - reveal_threshold - 0.15)))
		* (1.0 - smoothstep(0.82, 1.0, manifestation));
	float foot = smoothstep(0.005, 0.075,
		object_position.y - foot_base + (broad - 0.5) * 0.025);
	float ignition_envelope = smoothstep(0.0, 0.08, burn_progress)
		* (1.0 - smoothstep(0.42, 0.76, burn_progress));
	float flare = ignition_envelope * (0.52 + broad * 0.28 + fine * 0.20);
	// A cold apparition: the authored texture keeps almost its full value
	// under a whisper of moonlit cast. A stronger multiplicative tint would
	// apply twice where limbs overlap the torso and read as dark patches,
	// so the tint stays near white and the veils carry the ghost read.
	vec3 authored = texture(albedo_tex, albedo_uv).rgb;
	vec3 ghost_tint = mix(vec3(1.0), vec3(0.70, 0.79, 0.92), 0.35);
	vec3 body = authored * ghost_tint;
	vec3 flare_colour = vec3(0.90, 0.96, 1.0);
	ALBEDO = mix(body, flare_colour, flare);
	ROUGHNESS = 0.96;
	METALLIC = 0.0;

	EMISSION = flare_colour * flare * manifestation * 0.85
		+ ghost_tint * 0.04 * arrival_edge * master;
	// Nearly solid, with a whisper of translucency and slightly denser
	// silhouette edges: the facing factor is the inverse of the shadow body's.
	// Alpha stays this high so stacked limbs composite almost identically to
	// single surfaces instead of printing dark overlap patches.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - smoothstep(0.0, 0.55, facing);
	float alpha = (0.94 + 0.06 * edge) * (0.97 + 0.03 * fine);
	alpha = mix(alpha, 1.0, flare);
	alpha = clamp(master * arrival * foot * alpha, 0.0, 1.0);
	ALPHA = alpha;
}
