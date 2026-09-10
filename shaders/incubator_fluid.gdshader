shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
instance uniform float phase = 0.0;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float t = TIME * 0.13 + phase;
	float cloud = sin(local_position.x * 18.0 + sin(local_position.y * 11.0 + t)) * sin(local_position.z * 15.0 - t);
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.5);
	ALBEDO = mix(vec3(0.21, 0.29, 0.07), vec3(0.13, 0.44, 0.27), cloud * 0.5 + 0.5);
	EMISSION = ALBEDO * 0.13;
	ROUGHNESS = 0.22;
	ALPHA = 0.105 + cloud * 0.024 + rim * 0.12;
}
