shader_type spatial;
render_mode unshaded, cull_disabled;

// Soft pulsing glow pooled on the floor beneath a portal.

uniform vec3 col : source_color = vec3(1.0, 0.45, 0.2);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float pulse = 0.85 + 0.15 * sin(TIME * 1.3);
	float g = exp(-r * r * 3.2) * pulse;
	// faint rotating rays
	float ang = atan(p.y, p.x);
	g *= 0.8 + 0.2 * sin(ang * 6.0 - TIME * 0.8);
	ALBEDO = col * g * 1.4;
	ALPHA = clamp(g, 0.0, 0.55);
}
