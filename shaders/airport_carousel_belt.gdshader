shader_type spatial;
render_mode cull_disabled;
instance uniform float belt_speed = 0.115;
void fragment() {
	float u = (UV.x - TIME * belt_speed) * 8.0;
	float seam = smoothstep(0.035, 0.035 + fwidth(u), fract(u));
	float edge = 1.0 - smoothstep(0.060, 0.09, fract(u));
	float grain = sin(UV.y * 460.0) * 0.0015;
	ALBEDO = vec3(0.021, 0.026, 0.028) * (0.38 + seam * 0.62) + vec3(edge * 0.009 + grain);
	ROUGHNESS = 0.78;
	METALLIC = 0.03;
}
