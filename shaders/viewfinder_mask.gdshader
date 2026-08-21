shader_type canvas_item;
render_mode unshaded;

uniform vec2 window_fraction = vec2(0.60, 0.66);
uniform vec4 surround_color : source_color = vec4(0.008, 0.008, 0.01, 0.995);
uniform float maximum_feather_px = 150.0;

// Signed distance to a softly rounded optical window. Working in pixels keeps
// the curve circular instead of stretching it with the viewport aspect ratio.
float rounded_box_distance(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + vec2(radius);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}

void fragment() {
	vec2 viewport_px = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 point_px = (UV - vec2(0.5)) * viewport_px;
	vec2 half_window_px = viewport_px * window_fraction * 0.5;
	vec2 margin_px = viewport_px * (vec2(1.0) - window_fraction) * 0.5;
	float feather_px = min(maximum_feather_px,
		max(1.0, min(margin_px.x, margin_px.y) * 0.92));
	float corner_px = min(half_window_px.x, half_window_px.y) * 0.07;
	float distance_px = rounded_box_distance(point_px, half_window_px,
		corner_px);

	// A little falloff enters the live window, like an eyecup sitting just out
	// of focus; the outer edge always reaches the opaque surround.
	float alpha = smoothstep(-feather_px * 0.18, feather_px, distance_px);
	COLOR = vec4(surround_color.rgb, surround_color.a * alpha);
}
