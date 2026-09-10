shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float collapse : hint_range(0.0, 1.0) = 0.0;
uniform bool reduced_flashing = false;
uniform bool dust = false;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;

varying float life;
varying float seed;
varying float camera_distance;
varying float particle_depth;

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	float spread = INSTANCE_CUSTOM.z;
	float age = max(0.0, (collapse - INSTANCE_CUSTOM.y) * 5.0);
	float duration = dust ? mix(1.1, 2.0, spread) : mix(0.65, 1.5, spread);
	life = clamp(age / duration, 0.0, 1.0);
	float angle = spread * 6.283185;
	float speed = dust ? mix(0.25, 0.75, seed) : mix(1.5, 4.0, seed);
	vec3 local_velocity = vec3(cos(angle) * 0.7, sin(angle) * 0.7, 0.65 + spread) * speed;
	vec3 velocity = mat3(MODEL_MATRIX) * local_velocity;
	float motion = reduced_flashing ? 0.6 : 1.0;
	vec3 displacement = velocity * age * motion;
	displacement.y += (dust ? 0.24 : -0.5) * age * age * motion;
	// A small sideways flutter, tied to particle age, never to camera position.
	displacement += mat3(MODEL_MATRIX) * vec3(sin(age * 5.0 + angle), cos(age * 4.0 + angle), 0.0)
		* (dust ? 0.12 : 0.035) * age * motion;
	vec3 centre = MODEL_MATRIX[3].xyz + displacement;
	vec3 camera_right = INV_VIEW_MATRIX[0].xyz;
	vec3 camera_up = INV_VIEW_MATRIX[1].xyz;
	vec2 streak_direction = vec2(dot(velocity, camera_right), dot(velocity, camera_up));
	streak_direction /= max(length(streak_direction), 0.001);
	vec3 along = camera_right * streak_direction.x + camera_up * streak_direction.y;
	vec3 across = camera_right * -streak_direction.y + camera_up * streak_direction.x;
	float width = dust ? mix(0.35, 0.8, seed) * (0.6 + life * 1.9) : mix(0.012, 0.026, spread);
	float height = dust ? width : mix(0.09, 0.28, seed) * (reduced_flashing ? 0.65 : 1.0);
	vec3 offset = dust ? (camera_right * VERTEX.x + camera_up * VERTEX.y) * width
		: across * VERTEX.x * width + along * VERTEX.y * height;
	vec4 view_position = VIEW_MATRIX * vec4(centre + offset, 1.0);
	particle_depth = -view_position.z;
	camera_distance = length(centre - INV_VIEW_MATRIX[3].xyz);
	POSITION = PROJECTION_MATRIX * view_position;
}

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float shape;
	if (dust) {
		float billow = sin(point.x * 9.0 + seed * 30.0 + life * 2.0)
			* sin(point.y * 7.0 - seed * 17.0 - life * 3.0);
		shape = pow(max(0.0, 1.0 - length(point)), 1.7) * (0.6 + billow * 0.4);
	} else {
		shape = exp(-point.x * point.x * 5.0) * pow(max(0.0, 1.0 - abs(point.y)), 1.4);
	}
	float envelope = smoothstep(0.0, 0.08, life) * (1.0 - smoothstep(0.55, 1.0, life));
	envelope *= 1.0 - smoothstep(0.965, 1.0, collapse);
	// Soften intersections with the real room; don't paint sprites through
	// walls. The terminal wall disappearance itself is handled separately.
	float depth = texture(scene_depth, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		ndc.z = depth * 2.0 - 1.0;
	#endif
	vec4 scene_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_distance = -scene_position.z / max(abs(scene_position.w), 0.00001);
	float intersection = smoothstep(0.0, dust ? 0.4 : 0.08, scene_distance - particle_depth);
	float near_fade = smoothstep(0.35, 1.0, camera_distance);
	// Dense dust remains at the edges while the player is still fighting.
	float centre_distance = length(SCREEN_UV - vec2(0.5));
	float clear_centre = mix(0.25, 1.0, smoothstep(0.08, 0.28, centre_distance));
	float readability = dust ? mix(clear_centre, 1.0, smoothstep(0.76, 0.85, collapse)) : 1.0;
	vec3 tint = mix(vec3(0.2, 0.8, 1.0), vec3(0.52, 0.15, 1.0), fract(seed * 13.0));
	float energy = dust ? 0.9 : 4.0;
	ALBEDO = tint * energy * (reduced_flashing ? 0.48 : 1.0);
	ALPHA = shape * envelope * intersection * near_fade * readability * (dust ? 0.28 : 0.9);
}
