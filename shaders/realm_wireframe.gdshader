shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float collapse : hint_range(0.0, 1.0) = 0.0;
uniform float cell_size = 0.45;
uniform bool reduced_flashing = false;
uniform vec3 scan_origin;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

#include "res://shaders/realm_data_glyph.gdshaderinc"

vec3 world_at(vec2 uv, mat4 inv_projection, mat4 inv_view) {
	float depth = texture(scene_depth, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		ndc.z = depth * 2.0 - 1.0;
	#endif
	vec4 at = inv_projection * vec4(ndc, 1.0);
	return (inv_view * vec4(at.xyz / max(abs(at.w), 0.00001), 1.0)).xyz;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 world = world_at(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	vec3 right = world_at(SCREEN_UV + vec2(pixel.x, 0.0), INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 left = world_at(SCREEN_UV - vec2(pixel.x, 0.0), INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 above = world_at(SCREEN_UV + vec2(0.0, pixel.y), INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 below = world_at(SCREEN_UV - vec2(0.0, pixel.y), INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 dx = length(right - world) < length(world - left) ? right - world : world - left;
	vec3 dy = length(above - world) < length(world - below) ? above - world : world - below;
	vec3 normal = abs(cross(dx, dy));
	normal /= max(length(normal), 0.00001);
	vec2 plane = world.xz;
	if (normal.x > normal.y && normal.x > normal.z) {
		plane = world.zy;
	} else if (normal.z > normal.y) {
		plane = world.xy;
	}
	// The room is made entirely of code, including its structural bands.
	// Four glyphs per 0.45 m cell keep characters small on nearby surfaces.
	vec2 grid = plane / cell_size;
	vec2 glyph_grid = grid * 4.0;
	vec2 glyph_cell = floor(glyph_grid);
	vec2 glyph_footprint = fwidth(glyph_grid);
	float detail = 1.0 - smoothstep(0.18, 0.65, max(glyph_footprint.x, glyph_footprint.y));
	float camera_distance = length(world - CAMERA_POSITION_WORLD);
	float discontinuity = max(length(right + left - world * 2.0), length(above + below - world * 2.0));
	float silhouette = smoothstep(0.015 + camera_distance * 0.002, 0.055 + camera_distance * 0.01, discontinuity);
	float p = clamp(collapse, 0.0, 1.0);
	float scan_distance = min(length(world - scan_origin), 26.0);
	float strip = smoothstep(scan_distance * 0.002, 0.27 + scan_distance * 0.002, p);
	float voxel_seed = hash3(floor((world - normal * 0.012) / cell_size));
	float column_seed = hash3(vec3(floor(grid.x), floor(world.y * 0.01), floor(world.z / cell_size)));
	float vertical = clamp((world.y - scan_origin.y + 2.0) / 5.0, 0.0, 1.0);
	float break_at = 0.49 + column_seed * 0.14 + (1.0 - vertical) * 0.18 + voxel_seed * 0.03;
	float removed = smoothstep(break_at, break_at + 0.11, p);
	// Data illumination runs down columns on walls and along rows on the
	// floor. Running the same progress backwards reconstructs these streams.
	float stream_seed = hash3(vec3(glyph_cell.x, floor(dot(world, normal) / cell_size), 4.71));
	float head = 44.0 + stream_seed * 28.0 - p * 108.0;
	float behind_head = mod(glyph_grid.y - head, 52.0);
	float stream = 1.0 - smoothstep(0.0, 26.0, behind_head);
	float bright_head = 1.0 - smoothstep(0.0, 2.0, behind_head);
	float glyph_seed = hash3(vec3(glyph_cell, floor(dot(world, normal) / cell_size)));
	float glyph = data_glyph(fract(glyph_grid), glyph_seed) * detail;
	vec2 structural_row = 1.0 - step(vec2(0.5), mod(glyph_cell, 4.0));
	float code_band = max(structural_row.x, structural_row.y);
	vec3 blue = vec3(0.15, 0.52, 1.0);
	vec3 violet = vec3(0.50, 0.13, 1.0);
	vec3 line_color = mix(blue, violet, smoothstep(0.5, 5.0, world.y));
	float fade_distance = 1.0 - smoothstep(18.0, 50.0, camera_distance);
	vec3 original = texture(scene_color, SCREEN_UV).rgb;
	vec3 void_color = vec3(0.0004, 0.0006, 0.002);
	float energy = reduced_flashing ? 1.1 : 2.9;
	float illumination = 0.26 + code_band * 0.42 + stream * 0.95 + silhouette * 0.35;
	vec3 code_color = mix(line_color, vec3(0.55, 0.72, 1.0), bright_head * 0.65);
	vec3 blueprint = void_color + code_color * glyph * fade_distance * illumination * energy;
	// The solid surface drains out completely before the lattice comes apart.
	vec3 colour = mix(original, blueprint, strip);
	colour = mix(colour, void_color, removed * strip);
	colour = mix(colour, void_color, smoothstep(0.95, 1.0, p));
	ALBEDO = colour;
	ALPHA = strip;
}
