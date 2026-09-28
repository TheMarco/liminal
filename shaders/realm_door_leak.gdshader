shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
#include "res://shaders/realm_data_glyph.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform vec2 patch_size = vec2(2.5, 1.65);
uniform vec2 opening_size = vec2(0.0);

float leak_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453);
}

void fragment() {
	vec2 metres = (UV - 0.5) * patch_size;
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
	if (opening_size.x > 0.0) {
		// A narrow, broken edge of light. The broad glyph projection looked
		// like a screen pasted onto the wall and swallowed the actual room view.
		vec2 d = abs(metres) - opening_size * 0.5;
		float edge_distance = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
		float tremor = sin(metres.y * 23.0 + seed) * sin(metres.x * 17.0 - TIME * 1.4) * 0.014;
		edge_distance += tremor;
		float outside = smoothstep(-0.035, 0.035, edge_distance);
		float bleed = exp(-max(edge_distance, 0.0) * 17.0) * outside;
		float filament = exp(-abs(edge_distance) * 38.0) * outside;
		vec2 mote_uv = metres * 29.0 + vec2(0.0, TIME * 1.3);
		float mote = step(0.982, leak_hash(floor(mote_uv)))
			* exp(-length(fract(mote_uv) - 0.5) * 8.0);
		float shimmer = 0.78 + 0.22 * sin(TIME * 2.1 + metres.y * 11.0 + seed);
		ALBEDO = colour * 4.0;
		ALPHA = (bleed * 0.10 + filament * 0.34 + mote * bleed * 0.56)
			* shimmer * strength;
	} else {
		ALBEDO = colour * 4.5;
		ALPHA = patch * envelope * ink * strength;
	}
}
