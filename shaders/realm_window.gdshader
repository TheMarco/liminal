shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D realm_view : source_color, filter_linear;
// The temporary next-level doorway uses the untouched live view. The
// same-room return bends it slightly so the familiar room feels displaced.
uniform float impossible_return : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 view_colour = texture(realm_view, UV).rgb;
	if (impossible_return > 0.0) {
		float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		float seam = 1.0 - smoothstep(0.015, 0.22, edge);
		float wave = sin(UV.y * 20.0 + TIME * 1.35 + sin(UV.x * 9.0));
		vec2 bend = vec2(wave * 0.011, sin(UV.x * 15.0 - TIME * 0.85) * 0.004)
			* (0.25 + seam * 0.75) * impossible_return;
		vec2 shifted = clamp(UV + bend, vec2(0.001), vec2(0.999));
		float split = 0.0035 * seam * impossible_return;
		vec3 refracted = vec3(
			texture(realm_view, clamp(shifted + vec2(split, 0.0), vec2(0.001), vec2(0.999))).r,
			texture(realm_view, shifted).g,
			texture(realm_view, clamp(shifted - vec2(split, 0.0), vec2(0.001), vec2(0.999))).b);
		float cold = seam * (0.05 + 0.02 * sin(TIME * 1.6 + UV.y * 16.0));
		view_colour = mix(refracted, vec3(0.14, 0.24, 0.55), cold);
	}
	ALBEDO = view_colour;
}
