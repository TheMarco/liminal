shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
#include "res://shaders/realm_data_glyph.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

float leak_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453);
}

void fragment() {
	vec2 metres = (UV - 0.5) * vec2(2.5, 1.65);
	vec2 grid = metres / 0.09;
	vec2 cell = floor(grid);
	float random = leak_hash(cell);
	float column = leak_hash(vec2(cell.x, 0.0));
	// Uneven columns and islands leave an organic tear, never a door outline
	// or a rectangular glowing sign pasted onto the wall.
	float ragged = (column - 0.5) * 0.32 + (random - 0.5) * 0.10;
	float edge = length(metres * vec2(0.85, 1.1)) + ragged;
	float patch = 1.0 - smoothstep(0.64, 0.93, edge);
	float envelope = smoothstep(0.0, 0.24, progress) * (1.0 - smoothstep(0.60, 1.0, progress));
	// Leave a readable residue between swells instead of an empty six-second
	// window in which a passing player has nothing to discover.
	envelope = mix(0.28, 1.0, envelope);
	float sweep_y = mix(-1.2, 1.2, progress);
	float wake = exp(-abs(metres.y - sweep_y + column * 0.14) * 3.8);
	float glyph = data_glyph(fract(grid), random);
	float islands = smoothstep(0.12, 0.38, random);
	float ink = glyph * (0.65 + wake * 0.35) * islands;
	vec3 colour = mix(vec3(0.12, 0.44, 1.0), vec3(0.50, 0.18, 0.95), column * 0.65);
	ALBEDO = colour * 4.5;
	ALPHA = patch * envelope * ink * strength;
}
