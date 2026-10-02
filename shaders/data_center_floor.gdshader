shader_type spatial;
// Raised antistatic access panels with inset joints, flush fasteners and
// intermittent perforated cooling grilles. Every feature is metre scaled.
uniform sampler2D detail_tex : repeat_enable, filter_linear_mipmap;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_pos.xz / 0.60;
	vec2 panel = floor(p);
	vec2 q = fract(p);
	vec2 e = min(q, 1.0 - q);
	float edge = min(e.x, e.y);
	float aa = max(fwidth(edge), 0.0005);
	float face = smoothstep(0.003 - aa, 0.008 + aa, edge);
	float noise = texture(detail_tex, world_pos.xz * 0.7).r;
	float variation = fract(sin(dot(panel, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 color = vec3(0.18, 0.205, 0.21) * (0.84 + noise * 0.25 + variation * 0.12);
	float grille = step(0.5, mod(panel.x, 5.0)) * (1.0 - step(1.5, mod(panel.x, 5.0)));
	vec2 hole_uv = fract(q * 12.0) - 0.5;
	float hole_d = length(hole_uv);
	float holes = 1.0 - smoothstep(0.19 - fwidth(hole_d), 0.22 + fwidth(hole_d), hole_d);
	holes *= grille * smoothstep(0.055, 0.085, edge);
	vec2 bolt_uv = e - vec2(0.045);
	float bolt = 1.0 - smoothstep(0.010, 0.010 + max(fwidth(length(bolt_uv)), 0.002), length(bolt_uv));
	ALBEDO = mix(vec3(0.026, 0.037, 0.040), color, face) * (1.0 - holes * 0.76);
	ALBEDO = mix(ALBEDO, vec3(0.42, 0.46, 0.47), bolt);
	ROUGHNESS = mix(0.76, 0.58 + noise * 0.12, face);
	METALLIC = 0.22 + bolt * 0.48;
	SPECULAR = 0.42;
}
