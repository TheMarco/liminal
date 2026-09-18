shader_type spatial;
render_mode cull_disabled, shadows_disabled, fog_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float hdr_peak : hint_range(1.0, 32.0) = 12.0;

varying float fragment_age;
varying float fragment_seed;
varying float fragment_visible;
varying vec3 fragment_world_normal;
varying vec3 fragment_world_position;


float hashf(float value) {
	return fract(sin(value * 91.713 + 17.17) * 43758.5453);
}


mat3 axis_rotation(vec3 axis, float angle) {
	axis = normalize(axis);
	float s = sin(angle);
	float c = cos(angle);
	float oc = 1.0 - c;
	return mat3(
		vec3(oc * axis.x * axis.x + c,
			oc * axis.x * axis.y - axis.z * s,
			oc * axis.z * axis.x + axis.y * s),
		vec3(oc * axis.x * axis.y + axis.z * s,
			oc * axis.y * axis.y + c,
			oc * axis.y * axis.z - axis.x * s),
		vec3(oc * axis.z * axis.x - axis.y * s,
			oc * axis.y * axis.z + axis.x * s,
			oc * axis.z * axis.z + c));
}


void vertex() {
	fragment_seed = INSTANCE_CUSTOM.a;
	vec3 surface_normal = normalize(INSTANCE_CUSTOM.rgb * 2.0 - 1.0);
	// The intact black mesh and this complete fragment silhouette exchange on
	// one frame. There is no spotted transition state or delayed overlay.
	fragment_visible = 1.0;
	float launch = mix(0.015, 0.175, hashf(fragment_seed + 3.1));
	fragment_age = clamp((progress - launch) / max(0.001, 1.0 - launch), 0.0, 1.0);
	vec3 random_direction = normalize(vec3(
		hashf(fragment_seed + 7.0) * 2.0 - 1.0,
		hashf(fragment_seed + 19.0) * 1.5 - 0.35,
		hashf(fragment_seed + 31.0) * 2.0 - 1.0));
	vec3 actor_normal = normalize(mat3(MODEL_MATRIX) * surface_normal);
	vec3 direction = normalize(actor_normal * 0.62 + random_direction * 0.78);
	float travel = fragment_age * mix(0.05, 0.16, fragment_seed)
		+ fragment_age * fragment_age * mix(0.38, 0.82,
			hashf(fragment_seed + 43.0));
	vec3 drift = direction * travel;
	drift.y += fragment_age * 0.11 - fragment_age * fragment_age * 0.08;

	vec3 axis = normalize(vec3(hashf(fragment_seed + 53.0) - 0.5,
		hashf(fragment_seed + 61.0) - 0.5,
		hashf(fragment_seed + 71.0) - 0.5));
	mat3 tumble = axis_rotation(axis,
		fragment_age * mix(2.0, 8.5, hashf(fragment_seed + 79.0)));
	float shrink = 1.0 - smoothstep(0.48, 1.0, fragment_age) * 0.88;
	vec3 world_offset = tumble * (mat3(MODEL_MATRIX) * (VERTEX * shrink));
	vec3 world_origin = MODEL_MATRIX[3].xyz;
	vec3 world_position = world_origin + world_offset + drift;
	fragment_world_normal = normalize(tumble * (mat3(MODEL_MATRIX) * NORMAL));
	fragment_world_position = world_position;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_position, 1.0);
}


void fragment() {
	float death_start = mix(0.52, 0.72, hashf(fragment_seed + 89.0));
	float alive = 1.0 - smoothstep(death_start, 1.0, fragment_age);
	// Keep the hot shards in the opaque HDR pass so their sub-pixel radiance
	// reaches glow just like the Annex's opaque troffer lens. Staggered fragment
	// death plus geometric shrink supplies the dissolve without alpha blending.
	if (alive < 0.015) {
		discard;
	}
	vec3 view_direction = normalize(CAMERA_POSITION_WORLD - fragment_world_position);
	float rim = pow(1.0 - abs(dot(normalize(fragment_world_normal),
		view_direction)), 1.6);
	float heat = 1.0 - smoothstep(0.08, 0.72, fragment_age);
	vec3 amber = mix(vec3(1.0, 0.23, 0.025), vec3(1.0, 0.62, 0.20),
		hashf(fragment_seed + 97.0));
	vec3 white_hot = vec3(1.0, 0.94, 0.76);
	vec3 colour = mix(amber, white_hot, heat * (0.82 + rim * 0.18));
	// Each tetrahedron is smaller than a screen pixel at ordinary encounter
	// distance. A white-hot unlit face preserves visible coverage while the
	// separate emission channel carries real HDR radiance through tone mapping.
	ALBEDO = colour * heat;
	EMISSION = colour * hdr_peak * heat * (1.50 + rim * 2.50);
}
