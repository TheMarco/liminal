shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float collapse = 0.0;
uniform bool reduced_flashing = false;
uniform vec3 scan_origin;
varying vec3 cube_position;
varying vec3 cube_normal;
varying float alive;
varying float cell_seed;

#include "res://shaders/realm_data_glyph.gdshaderinc"

void vertex() {
	cube_position = VERTEX;
	cube_normal = abs(NORMAL);
	cell_seed = INSTANCE_CUSTOM.x;
	float vertical = clamp((MODEL_MATRIX[3].y - scan_origin.y + 2.0) / 5.0, 0.0, 1.0);
	float birth = 0.48 + cell_seed * 0.16 + (1.0 - vertical) * 0.17;
	float age = max(0.0, (collapse - birth) * 5.0);
	float motion = reduced_flashing ? 0.5 : 1.0;
	vec3 direction = vec3(INSTANCE_CUSTOM.yz * 2.0 - 1.0, fract(cell_seed * 19.0) * 2.0 - 1.0);
	direction.xz *= 0.25;
	direction.y = -(0.6 + abs(direction.y) * 0.9);
	// Vertical digital fallout. Reversing progress lifts the same cells back
	// into their original positions, without convergence on the camera.
	vec3 translation = direction * age * age * 0.65 * motion;
	float die = smoothstep(0.80 + cell_seed * 0.12, 0.90 + cell_seed * 0.10, collapse);
	alive = smoothstep(0.0, 0.10, age) * (1.0 - die);
	float shrink = 1.0 - die * 0.8;
	VERTEX *= shrink;
	vec4 at = MODEL_MATRIX * vec4(VERTEX, 1.0);
	at.xyz += translation;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * at;
}

void fragment() {
	vec2 face = cube_position.xy;
	if (cube_normal.x > 0.5) {
		face = cube_position.zy;
	} else if (cube_normal.y > 0.5) {
		face = cube_position.xz;
	}
	// Tiny characters trace the hollow cube's edges. There are no continuous
	// wire segments underneath, so the fallout is made of the same code.
	vec2 grid = (face + 0.5) * 8.0;
	vec2 cell = clamp(floor(grid), vec2(0.0), vec2(7.0));
	float edge = 1.0 - step(0.5, min(min(cell.x, cell.y), min(7.0 - cell.x, 7.0 - cell.y)));
	float random = fract(sin(dot(cell, vec2(12.9898, 78.233)) + cell_seed * 83.17) * 43758.5453);
	vec2 footprint = fwidth(grid);
	float detail = 1.0 - smoothstep(0.18, 0.65, max(footprint.x, footprint.y));
	float code = data_glyph(fract(grid), random) * detail;
	vec3 tint = mix(vec3(0.12, 0.52, 1.0), vec3(0.52, 0.12, 1.0), fract(cell_seed * 7.0));
	ALBEDO = tint * (reduced_flashing ? 1.0 : 2.4);
	ALPHA = code * edge * alive;
}
