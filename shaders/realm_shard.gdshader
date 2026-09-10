shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

varying float erosion;

void vertex() {
	erosion = INSTANCE_CUSTOM.x;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0));
}

void fragment() {
	// One continuous outline across the triangulated face: interior mesh
	// edges must not turn each fragment into a glowing wireframe pyramid.
	float face_edge = segment_distance(UV, vec2(-0.55, -0.25), vec2(0.32, -0.35));
	face_edge = min(face_edge, segment_distance(UV, vec2(0.32, -0.35), vec2(0.55, 0.20)));
	face_edge = min(face_edge, segment_distance(UV, vec2(0.55, 0.20), vec2(-0.12, 0.65)));
	face_edge = min(face_edge, segment_distance(UV, vec2(-0.12, 0.65), vec2(-0.45, 0.18)));
	face_edge = min(face_edge, segment_distance(UV, vec2(-0.45, 0.18), vec2(-0.55, -0.25)));
	float rim = 1.0 - smoothstep(0.004, 0.02, face_edge);
	float grain = sin(UV.x * 31.0 + UV.y * 13.0) * sin(UV.y * 27.0 - UV.x * 9.0);
	float body = smoothstep(erosion - 0.12, erosion + 0.03, face_edge * 2.8 + grain * 0.05);
	ALBEDO = mix(vec3(0.015, 0.021, 0.028) * (1.0 + grain * 0.3), COLOR.rgb * 1.5, rim);
	ALPHA = COLOR.a * body;
}
