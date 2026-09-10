shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never, shadows_disabled;
#include "res://shaders/realm_data_glyph.gdshaderinc"
varying vec3 glyph_position;
varying vec3 glyph_normal;

void vertex() {
	glyph_position = VERTEX;
	glyph_normal = abs(NORMAL);
}

void fragment() {
	vec2 plane = glyph_position.xy;
	if (glyph_normal.x > glyph_normal.y && glyph_normal.x > glyph_normal.z) {
		plane = glyph_position.zy;
	} else if (glyph_normal.y > glyph_normal.z) {
		plane = glyph_position.xz;
	}
	vec2 grid = plane / 0.07;
	float seed = fract(sin(dot(floor(grid), vec2(12.9898, 78.233))) * 43758.5453);
	float code = data_glyph(fract(grid), seed);
	float side = 1.0 - glyph_normal.z;
	ALBEDO = mix(vec3(0.20, 0.60, 1.0), vec3(0.58, 0.20, 1.0), side * 0.75 + seed * 0.20) * 2.7;
	ALPHA = code * 0.85;
}
