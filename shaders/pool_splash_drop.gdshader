shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;
uniform float fx_clock = 0.0;
varying float visibility;

void vertex() {
	float elapsed = fx_clock - INSTANCE_CUSTOM.w;
	float age = clamp(elapsed, 0.0, 0.85);
	vec3 v = INSTANCE_CUSTOM.xyz;
	vec3 path = v * age - vec3(0.0, 4.9 * age * age, 0.0);
	visibility = step(0.0, elapsed) * step(elapsed, 0.85) * smoothstep(-0.015, 0.035, path.y);
	// Stretch along the flight direction, so spray reads as moving water.
	vec3 up = normalize(v - vec3(0.0, 9.8 * max(age, 0.0), 0.0));
	vec3 side = normalize(cross(up, vec3(0.0, 0.0, 1.0)));
	mat3 orientation = mat3(side, up, normalize(cross(side, up)));
	VERTEX = orientation * VERTEX + path;
	NORMAL = orientation * NORMAL;
}

void fragment() {
	if (visibility < 0.01) { discard; }
	ALBEDO = vec3(0.06, 0.11, 0.10);
	ROUGHNESS = 0.055;
	SPECULAR = 0.8;
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALPHA = (0.12 + 0.48 * rim) * visibility;
}
