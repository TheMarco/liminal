shader_type spatial;
// Quiet indoor water with the lingering movement of a recently used pool.
// Opaque scene colour already contains lighting
// and fog, so transmit it once through EMISSION instead of lighting it again
// as albedo and alpha-blending a second copy of the basin into it.
// Static room probes supply reflections; transparent water cannot use SSR.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley,
	specular_schlick_ggx, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;

// Centimetre-scale swell. Wavelengths are metres; speeds are cycles/second.
// World-space phases keep both height and lighting continuous at cell joins.
uniform float wave_height = 0.012;
uniform float wave_speed_a = 0.58;
uniform float wave_speed_b = 0.47;
uniform float wave_length_a = 2.6;
uniform float wave_length_b = 1.7;

uniform float normal_scale_a = 0.12;
uniform float normal_scale_b = 0.29;
uniform float normal_speed_a = -0.017;
uniform float normal_speed_b = 0.020;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.05;

uniform vec3 shallow_colour : source_color = vec3(0.08, 0.32, 0.29);
uniform vec3 deep_colour : source_color = vec3(0.022, 0.105, 0.095);
// Dense teal water: nearby submerged edges remain legible, but the basin
// floor falls into colour and shadow instead of reading like clear glass.
uniform float depth_fade = 1.45;
uniform float opacity_min : hint_range(0.0, 1.0) = 0.12;
uniform float opacity_max : hint_range(0.0, 1.0) = 0.56;
uniform float refraction = 0.065;
uniform float fresnel_power = 5.0;
uniform float fresnel_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 foam_colour : source_color = vec3(0.90, 0.94, 0.92);
uniform float foam_distance = 0.02;
uniform float foam_softness = 0.55;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.0;
uniform float water_roughness : hint_range(0.0, 1.0) = 0.12;
uniform float water_specular : hint_range(0.0, 1.0) = 0.25;

// Assigned only to nearby disturbed surfaces. All other basins keep zero
// events on their shared material and skip the loop entirely.
uniform float fx_clock = 0.0;
uniform int fx_count = 0;
uniform vec4 fx_events[12]; // world XZ, birth, strength
uniform vec4 fx_shapes[12]; // travel direction, entry/step, surface height
uniform vec4 fx_body = vec4(0.0); // world XZ, surface height, speed
uniform vec3 fx_motion = vec3(0.0); // direction, immersion depth

varying vec3 world_pos;
const vec2 SWELL_DIR_A = vec2(0.939693, 0.342020);
const vec2 SWELL_DIR_B = vec2(-0.422618, 0.906308);

vec2 swell_phase(vec2 p, float time) {
	return 6.2831853 * vec2(
		dot(p, SWELL_DIR_A) / max(wave_length_a, 0.01) - time * wave_speed_a,
		dot(p, SWELL_DIR_B) / max(wave_length_b, 0.01) - time * wave_speed_b)
		+ vec2(0.0, 1.83);
}

vec2 rot(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

vec3 view_position(vec2 uv, float depth, mat4 inv_projection) {
	vec4 p = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return p.xyz / p.w;
}

// Gradient of a decaying travelling wave packet, rather than a painted ring.
// Successive alternating foot disturbances naturally overlap into a wake.
vec3 disturbance(vec3 p) {
	vec2 slope = vec2(0.0);
	float froth = 0.0;
	for (int i = 0; i < fx_count; i++) {
		vec4 event = fx_events[i];
		vec4 shape = fx_shapes[i];
		float age = fx_clock - event.z;
		if (abs(p.y - shape.w) > 0.07 || age < 0.0 || age > 2.8) { continue; }
		vec2 delta = p.xz - event.xy;
		if (dot(delta, delta) > 10.24) { continue; }
		// Gentle elongation along the displaced body's travel direction.
		vec2 metric = delta - shape.xy * dot(delta, shape.xy) * shape.z * 0.18;
		float radius = max(length(metric), 0.015);
		vec2 gradient = metric / radius;
		gradient -= shape.xy * dot(gradient, shape.xy) * shape.z * 0.18;
		float q = radius - (0.24 + age * 0.9);
		float width = 0.22 + age * 0.12;
		float packet = exp(-q * q / (width * width));
		float fade = smoothstep(0.0, 0.065, age) * (1.0 - smoothstep(1.5, 2.8, age))
			/ (1.0 + age * 1.9);
		float wave = q * 17.0;
		float derivative = (17.0 * cos(wave) - 2.0 * q / (width * width) * sin(wave));
		slope -= gradient * derivative * packet * fade * event.w * 0.029;
		froth += exp(-radius * radius * 3.4) * max(0.0, 1.0 - age * 1.5)
			* event.w * mix(0.24, 0.04, shape.z);
	}
	if (fx_body.w > 0.05 && abs(p.y - fx_body.z) < 0.07) {
		vec2 delta = p.xz - fx_body.xy;
		float distance = length(delta);
		if (distance > 0.02 && distance < 1.4) {
			float facing = dot(delta / distance, fx_motion.xy);
			float bow = exp(-pow((distance - 0.43) / 0.13, 2.0));
			float amount = min(fx_body.w / 2.0, 1.0) * smoothstep(0.0, 0.35, fx_motion.z);
			float front = smoothstep(-0.35, 0.65, facing);
			slope += delta / distance * bow * (distance - 0.43) * 5.5 * amount * front;
			froth += bow * amount * front * 0.09;
		}
	}
	return vec3(slope, min(froth, 0.28));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 phase = swell_phase(world_pos.xz, TIME);
	VERTEX.y += (sin(phase.x) * 0.55 + sin(phase.y) * 0.45) * wave_height;
}

void fragment() {
	vec2 uv_a = world_pos.xz * normal_scale_a + vec2(TIME * normal_speed_a, 0.0);
	vec2 uv_b = rot(world_pos.xz, 0.75) * normal_scale_b
		+ vec2(0.0, TIME * normal_speed_b);
	vec3 n_a = texture(normal_tex, uv_a).xyz * 2.0 - 1.0;
	vec3 n_b = texture(normal_tex, uv_b).xyz * 2.0 - 1.0;
	// Rotate the second slope back into world space as well as rotating its
	// sampling coordinates. Independent water planes then share one surface.
	vec2 slope = (n_a.xy + rot(n_b.xy, -0.75)) * 0.5 * normal_strength;
	// The same crossing wave trains that move the surface also tilt its
	// reflections. Small drifting ripples above break up their regularity.
	vec2 phase = swell_phase(world_pos.xz, TIME);
	slope -= wave_height * 6.2831853 * (
		SWELL_DIR_A * (0.55 / max(wave_length_a, 0.01)) * cos(phase.x)
		+ SWELL_DIR_B * (0.45 / max(wave_length_b, 0.01)) * cos(phase.y));
	vec3 interaction = disturbance(world_pos);
	slope += interaction.xy;
	vec3 flat_normal = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize((VIEW_MATRIX * vec4(slope.x, 1.0, slope.y, 0.0)).xyz);

	vec3 floor_position = view_position(SCREEN_UV,
		texture(depth_tex, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float column = max(0.0, VERTEX.z - floor_position.z);
	float path_length = min(length(floor_position - VERTEX), 24.0);
	// View-aligned distortion, in perspective. Fade at contacts and screen
	// edges, and reject a refracted sample if it hits foreground deck/walls.
	float contact = smoothstep(0.0, 0.18, column);
	vec2 edge = min(SCREEN_UV, 1.0 - SCREEN_UV);
	float screen_guard = smoothstep(0.0, 0.035, min(edge.x, edge.y));
	vec2 offset = (NORMAL.xy - flat_normal.xy) * refraction
		* vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1])
		* min(path_length, 2.0) / max(-VERTEX.z, 1.0) * contact * screen_guard;
	vec2 refracted_uv = clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999));
	vec3 refracted_position = view_position(refracted_uv,
		texture(depth_tex, refracted_uv).r, INV_PROJECTION_MATRIX);
	float valid = step(refracted_position.z + 0.015, VERTEX.z);
	refracted_uv = mix(SCREEN_UV, refracted_uv, valid);
	vec3 behind = textureLod(screen_tex, refracted_uv, 0.0).rgb;

	float optical_depth = path_length / max(depth_fade, 0.001);
	vec3 transmission = exp(-vec3(1.15, 0.38, 0.34) * optical_depth);
	float absorb = 1.0 - exp(-optical_depth);
	float haze = mix(opacity_min, opacity_max, absorb);
	vec3 tint = mix(shallow_colour, deep_colour, absorb);
	float grazing = pow(1.0 - clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0),
		fresnel_power);
	float f0 = 0.08 * water_specular;
	float reflected = f0 + (1.0 - f0) * grazing * fresnel_strength;
	float foam = (1.0 - smoothstep(0.0, max(foam_distance, 0.001), column))
		* foam_amount;
	// Small broken bubbles, lit by the room and gone quickly. Reuse the
	// normal samples to avoid another full-screen texture fetch for froth.
	float broken_froth = smoothstep(0.28, 0.72, 0.5 + (n_a.x + n_b.y) * 1.4);
	foam = clamp(foam + interaction.z * broken_froth * contact, 0.0, 0.4);

	ALBEDO = mix(tint * haze, foam_colour, foam);
	EMISSION = behind * transmission * (1.0 - reflected) * (1.0 - haze) * (1.0 - foam);
	// Explicit ALPHA retains the screen-reading transparent pass, but it must
	// not blend the un-refracted scene into the result a second time.
	ALPHA = 1.0;
	ROUGHNESS = mix(water_roughness, 0.65, foam);
	SPECULAR = water_specular * (1.0 - foam * 0.7);
	METALLIC = 0.0;
}
