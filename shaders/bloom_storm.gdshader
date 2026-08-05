shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec3 deep_color : source_color = vec3(0.018, 0.0, 0.002);
uniform vec3 storm_color : source_color = vec3(0.40, 0.004, 0.001);
uniform float phase = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p = p * 2.07 + vec2(13.7, 7.9);
		a *= 0.48;
	}
	return v;
}

void fragment() {
	vec2 p = UV * vec2(4.4, 2.65);
	float broad = fbm(p * 0.72 + vec2(TIME * 0.021, -TIME * 0.012) + phase);
	vec2 warp = vec2(fbm(p * 1.31 + broad * 2.1 + phase),
		fbm(p * 1.07 - broad * 1.7 - phase));
	float clouds = fbm(p + (warp - 0.5) * 1.45 + vec2(TIME * 0.034, 0.0));
	float horizon = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.7);
	float banks = smoothstep(0.47, 0.64,
		clouds + (broad - 0.5) * 0.48);
	float torn = smoothstep(0.48, 0.68,
		broad + sin(UV.y * 9.0 + warp.x * 4.0) * 0.15);
	float rift = smoothstep(0.24, 0.62, abs(clouds - broad) * 2.2);
	float storm = clamp(banks * (0.46 + rift * 0.64)
		+ torn * 0.31 + horizon * 0.16, 0.0, 1.0);
	float bolt_time = pow(max(0.0, sin(TIME * 0.43 + phase * 9.0)), 44.0);
	float bolt_path = abs(UV.x - 0.56 - sin(UV.y * 18.0 + phase) * 0.035);
	float bolt = smoothstep(0.018, 0.002, bolt_path) * smoothstep(0.25, 0.95, UV.y)
		* bolt_time;
	float ghost_bolt = smoothstep(0.014, 0.003, bolt_path)
		* smoothstep(0.18, 0.94, UV.y) * 0.065;
	float fork_path = abs(UV.x - 0.56 - (0.95 - UV.y) * 0.27
		- sin(UV.y * 23.0 + phase * 1.7) * 0.022);
	float fork = smoothstep(0.011, 0.0025, fork_path)
		* smoothstep(0.38, 0.76, UV.y) * (0.045 + bolt_time * 0.9);
	vec3 col = mix(deep_color, storm_color, storm);
	col *= mix(0.24, 1.32, storm) * (0.62 + broad * 0.52);
	col += vec3(0.30, 0.006, 0.003) * horizon * (0.18 + warp.y * 0.28);
	col += vec3(1.0, 0.15, 0.08) * (ghost_bolt + fork);
	col += vec3(1.0, 0.19, 0.10) * bolt * 8.0;
	ALBEDO = col;
	EMISSION = col * (1.55 + banks * 0.42 + bolt * 5.0);
}
