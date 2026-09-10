shader_type spatial;
render_mode blend_mix, cull_back;
instance uniform float phase = 0.0;
varying float height;
void vertex() {
	VERTEX.y = 0.62 + mod(VERTEX.y - 0.62 + TIME * 0.066 + phase * 0.11, 1.01);
	height = VERTEX.y;
}
void fragment() {
	ALBEDO = vec3(0.28, 0.66, 0.43);
	EMISSION = vec3(0.08, 0.18, 0.09);
	ROUGHNESS = 0.14;
	ALPHA = 0.4 * smoothstep(0.62, 0.68, height) * (1.0 - smoothstep(1.55, 1.63, height));
}
