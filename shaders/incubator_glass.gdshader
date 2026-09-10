shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
void fragment() {
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	ALBEDO = vec3(0.33, 0.59, 0.54);
	ROUGHNESS = 0.09;
	METALLIC = 0.13;
	ALPHA = 0.025 + rim * 0.24;
}
