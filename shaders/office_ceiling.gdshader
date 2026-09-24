shader_type spatial;

// Approved Scenario mineral-fibre finish on the existing seamless 0.75m
// ceiling lattice. The structural slab remains one mesh per generated cell.
uniform sampler2D scenario_ceiling_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float pitch = 0.75;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grid = fract(wpos.xz / pitch);
	float cross_distance = min(abs(grid.x - 0.5), abs(grid.y - 0.5)) * pitch;
	float edge_distance = min(min(grid.x, 1.0 - grid.x), min(grid.y, 1.0 - grid.y)) * pitch;
	float bar = 1.0 - smoothstep(0.027, 0.041, cross_distance);
	float edge = 1.0 - smoothstep(0.002, 0.006, edge_distance);
	vec3 panel = texture(scenario_ceiling_tex, wpos.xz / pitch).rgb;
	vec3 c = mix(panel, vec3(0.53, 0.54, 0.53), bar);
	c *= 1.0 - edge * 0.18;
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.22;
	EMISSION = c * 0.18;
}
