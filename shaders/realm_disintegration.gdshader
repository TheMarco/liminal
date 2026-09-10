shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float collapse : hint_range(0.0, 1.0) = 0.0;
uniform bool reduced_flashing = false;

vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

// Two nearest cells produce irregular fracture edges, anchored to surfaces
// in metres rather than to the screen. Turning the camera doesn't slide them.
vec3 fracture(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float first = 10.0;
	float second = 10.0;
	float seed = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbour = vec2(float(x), float(y));
			vec2 random = hash22(cell + neighbour);
			vec2 delta = neighbour + 0.16 + random * 0.68 - local;
			float distance_squared = dot(delta, delta);
			if (distance_squared < first) {
				second = first;
				first = distance_squared;
				seed = random.x;
			} else {
				second = min(second, distance_squared);
			}
		}
	}
	return vec3(sqrt(second) - sqrt(first), seed, sqrt(first));
}

void vertex() {
	// Reverse-Z near plane. The node still follows the camera for CPU culling.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(scene_depth, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		ndc.z = depth * 2.0 - 1.0;
	#endif
	vec4 view_h = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 view_position = view_h.xyz / max(abs(view_h.w), 0.00001);
	vec3 world_position = (INV_VIEW_MATRIX * vec4(view_position, 1.0)).xyz;
	vec3 derivative_normal = cross(dFdx(world_position), dFdy(world_position));
	vec3 surface_normal = abs(derivative_normal / max(length(derivative_normal), 0.00001));
	vec2 plane = world_position.xz;
	if (surface_normal.x > surface_normal.y && surface_normal.x > surface_normal.z) {
		plane = world_position.zy;
	} else if (surface_normal.z > surface_normal.y) {
		plane = world_position.xy;
	}
	// Gently bend the fractures so they don't form a uniform wireframe cage.
	vec2 cracked_plane = plane * 1.05 + vec2(sin(plane.y * 2.7), sin(plane.x * 3.1)) * 0.10;
	vec3 cell = fracture(cracked_plane);
	float p = clamp(collapse, 0.0, 1.0);
	float stress = smoothstep(cell.y * 0.28, cell.y * 0.28 + 0.22, p);
	float edge_width = mix(0.015, 0.033, cell.y);
	float antialias = clamp(fwidth(cell.x) * 0.6, 0.006, 0.018);
	float distance_fade = 1.0 - smoothstep(10.0, 24.0, length(view_position));
	float edge = (1.0 - smoothstep(edge_width, edge_width + antialias, cell.x)) * stress * distance_fade;
	float fringe = (1.0 - smoothstep(0.025, 0.12, cell.x)) * stress * distance_fade;
	float terminal = smoothstep(0.76, 0.98, p);
	// Each piece disappears on its own beat. Edges erode toward its centre;
	// no radial zoom, screen-space rays, or convergence on the camera.
	float break_at = 0.40 + cell.y * 0.42;
	float erosion = clamp(cell.x * 2.0, 0.0, 0.16);
	float holes = smoothstep(break_at + erosion, break_at + erosion + 0.055, p);
	vec2 centred = SCREEN_UV - vec2(0.5);
	float radius = length(centred * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0));
	// Keep the threat-reading centre and immediate walking surface intact
	// until the protected finish. The real floor collision never changes.
	float centre_protection = (1.0 - smoothstep(0.13, 0.42, radius)) * (1.0 - terminal);
	float foot_protection = (1.0 - smoothstep(2.0, 5.0, length(view_position)))
		* step(world_position.y, CAMERA_POSITION_WORLD.y - 0.65) * (1.0 - terminal);
	holes *= 1.0 - max(centre_protection, foot_protection);
	vec3 cyan = vec3(0.32, 0.94, 1.0);
	vec3 violet = vec3(0.38, 0.055, 0.95);
	float brightness = reduced_flashing ? 1.1 : 2.8;
	vec2 drift = vec2(cell.y - 0.5, -0.35 - cell.y * 0.3)
		* smoothstep(break_at - 0.12, break_at + 0.20, p)
		* (reduced_flashing ? 0.004 : 0.013);
	vec3 displaced = texture(scene_color, clamp(SCREEN_UV + drift, vec2(0.001), vec2(0.999))).rgb;
	vec3 void_color = vec3(0.001, 0.0015, 0.005);
	float intact = 1.0 - holes;
	vec3 colour = mix(displaced * 0.75, void_color, holes);
	// The fracture lines go with the missing wall, leaving isolated remnants
	// rather than a glowing skeleton of the room all the way to the last frame.
	float rim = (1.0 - smoothstep(0.025, 0.10, abs(p - break_at - erosion))) * stress;
	colour += (violet * fringe * 0.24 + cyan * edge * brightness) * intact;
	colour += mix(violet, cyan, cell.y) * rim * intact * (reduced_flashing ? 0.06 : 0.15);
	float swallow = smoothstep(0.985, 1.0, p);
	colour = mix(colour, void_color, swallow);
	ALBEDO = colour;
	ALPHA = clamp(max(max(edge * 0.9, max(fringe * 0.22, rim * 0.15)), max(holes, swallow)), 0.0, 1.0);
}
