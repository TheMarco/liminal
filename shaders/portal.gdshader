shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// Swirling rift to another liminal space. Cylindrical-billboard quad: always
// faces the walker, spiral arms wind into a bright core, edges dissolve into
// sparks. Tinted per destination theme.

uniform vec3 col_edge : source_color = vec3(1.0, 0.45, 0.2);
uniform vec3 col_core : source_color = vec3(1.0, 0.85, 0.6);

float hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hashf(i), hashf(i + vec2(1.0, 0.0)), u.x),
		mix(hashf(i + vec2(0.0, 1.0)), hashf(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// the billboard basis drops node scale — re-apply it to the verts
	VERTEX *= vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz));
	// cylindrical billboard: face the camera, stay upright
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 fwd = normalize((INV_VIEW_MATRIX[3] - MODEL_MATRIX[3]).xyz * vec3(1.0, 0.0, 1.0));
	vec3 right = normalize(cross(up, fwd));
	mat4 bb = mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	// slow breathing bob
	VERTEX.y += sin(TIME * 1.3) * 0.05;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	// two counter-wound spiral arm sets
	float s1 = sin(ang * 3.0 + 20.0 * sqrt(r) - TIME * 2.6);
	float s2 = sin(ang * 5.0 - 13.0 * sqrt(r) + TIME * 1.9 + 2.1);
	float arms = smoothstep(0.4, 0.93, s1 * 0.5 + 0.5) * 0.75
		+ smoothstep(0.5, 0.97, s2 * 0.5 + 0.5) * 0.5;
	// bright singing core
	float core = exp(-r * r * 5.5);
	// turbulent shimmer
	float shimmer = vnoise(p * 5.0 + vec2(TIME * 0.7, -TIME * 0.5));
	// sparks flicking off the rim
	float spark = step(0.985, vnoise(p * 14.0 + vec2(0.0, TIME * 2.2))) * smoothstep(1.05, 0.75, r);

	float body = (arms * (0.5 + 0.5 * shimmer) + core * 1.6) * smoothstep(1.0, 0.72, r);
	vec3 c = mix(col_edge, col_core, clamp(core * 1.8 + arms * 0.2, 0.0, 1.0));
	c += vec3(1.0) * spark * 0.8;

	// unshaded: ALBEDO is the output — push it hot so glow picks it up
	ALBEDO = c * body * 2.4;
	ALPHA = clamp(body * 1.4 + spark, 0.0, 0.92);
}
