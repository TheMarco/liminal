shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, unshaded,
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
// Set from the active display. SDR gets a restrained bloom-safe peak; a true
// HDR window can use the monitor's additional linear headroom.
uniform float burn_peak : hint_range(1.0, 8.0) = 1.25;
// Seam clip: world-space plane, abc the kept-side normal. Fragments with a
// negative signed distance are discarded while enabled. The default plane
// keeps the whole world even if enabled before it is set.
uniform vec4 clip_plane = vec4(0.0, 1.0, 0.0, 1000000.0);
uniform float clip_enabled = 0.0;

varying vec3 object_position;
varying vec3 world_position;

void vertex() {
	object_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (clip_enabled > 0.5
			&& dot(world_position, clip_plane.xyz) + clip_plane.w < 0.0) {
		discard;
	}
	float broad = texture(noise_tex,
		object_position.xz * 0.78 + vec2(TIME * 0.022, phase * 4.13)).r;
	float fine = texture(noise_tex,
		object_position.xy * 6.2 + vec2(-TIME * 0.031, phase * 7.91)).g;

	float burn_progress = (1.0 - fade) * ignite;
	// The complete silhouette flashes first. Then noise breaks it into islands
	// while the matching particles leave the same volume; there is no interval
	// where an invisible actor illuminates the room.
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
	float foot = smoothstep(0.005, 0.075, object_position.y + (broad - 0.5) * 0.025);
	// Once the charge completes the entire creature catches at once. The old
	// vertical consuming front looked like a shader wipe on a humanoid body;
	// this is one violent full-body flare followed by a coherent fade.
	float ignition_envelope = smoothstep(0.0, 0.08, burn_progress)
		* (1.0 - smoothstep(0.42, 0.76, burn_progress));
	float flame = ignition_envelope * (0.52 + broad * 0.28 + fine * 0.20);
	// The body is a genuine absence: room lights and the flashlight cannot reveal
	// its authored texture. Shape readability comes only from the neutral blur.
	vec3 charcoal = vec3(0.0);
	float heat = clamp(0.42 + broad * 0.34 + fine * 0.24, 0.0, 1.0);
	vec3 flame_colour = mix(vec3(1.0, 0.42, 0.10), vec3(1.0, 0.78, 0.42), heat);
	// Charging the kill does not pepper the body with preview embers. It remains
	// one uninterrupted black mass until the terminal fragment handoff.
	ALBEDO = mix(charcoal, flame_colour, flame);
	ROUGHNESS = 0.96;
	METALLIC = 0.0;

	// The visible body owns the initial flash. On HDR displays this can exceed
	// SDR white; otherwise it stays only slightly above the bloom threshold.
	vec3 fire_light = flame_colour * flame * (0.65 + heat * 1.20) * manifestation;
	EMISSION = fire_light * burn_peak + vec3(0.045) * arrival_edge * master;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge_density = mix(0.68, 1.0, smoothstep(0.0, 0.38, facing));
	edge_density = mix(edge_density, 1.0, flame);
	ALPHA = clamp(master * arrival * foot * edge_density, 0.0, 1.0);
}
