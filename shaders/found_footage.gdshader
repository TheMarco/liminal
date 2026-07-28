shader_type canvas_item;
render_mode unshaded;

// Recovered analog/body-camera treatment. This is intentionally separate from
// post.gdshader so B can change the recording medium without disabling the
// screen treatment (V still does that).
uniform sampler2D screen_texture :
	hint_screen_texture,
	repeat_disable,
	filter_linear;

uniform float effect_strength : hint_range(0.0, 1.0) = 0.82;
uniform float time_scale : hint_range(0.0, 3.0) = 1.0;

uniform float lens_distortion : hint_range(-0.25, 0.25) = 0.055;
uniform float zoom : hint_range(0.8, 1.2) = 1.025;
uniform float corner_vignette : hint_range(0.0, 2.0) = 0.75;
uniform float camera_shake : hint_range(0.0, 0.02) = 0.0015;
uniform float camera_shake_speed : hint_range(0.0, 30.0) = 8.0;

uniform float horizontal_jitter : hint_range(0.0, 0.05) = 0.006;
uniform float jitter_speed : hint_range(0.0, 50.0) = 18.0;
uniform float jitter_resolution : hint_range(8.0, 400.0) = 110.0;
uniform float vertical_roll_amount : hint_range(0.0, 0.1) = 0.004;
uniform float vertical_roll_speed : hint_range(-3.0, 3.0) = 0.12;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.0035;
uniform float color_bleed : hint_range(0.0, 0.02) = 0.0025;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.19;
uniform float scanline_count : hint_range(100.0, 1200.0) = 520.0;
uniform float scanline_speed : hint_range(-10.0, 10.0) = 0.35;
uniform float phosphor_strength : hint_range(0.0, 0.5) = 0.07;
uniform float flicker_strength : hint_range(0.0, 0.25) = 0.035;
uniform float flicker_speed : hint_range(0.0, 100.0) = 47.0;

uniform float static_noise : hint_range(0.0, 1.0) = 0.10;
uniform float noise_size : hint_range(0.5, 8.0) = 2.0;
uniform float tracking_damage : hint_range(0.0, 1.0) = 0.18;
uniform float tracking_speed : hint_range(0.0, 4.0) = 0.45;
uniform float tracking_width : hint_range(0.001, 0.25) = 0.055;
uniform float dropout_strength : hint_range(0.0, 1.0) = 0.12;
uniform float dropout_frequency : hint_range(1.0, 100.0) = 28.0;
uniform float exposure_pumping : hint_range(0.0, 0.5) = 0.06;
uniform float crushed_blacks : hint_range(0.0, 0.3) = 0.045;
uniform float saturation : hint_range(0.0, 2.0) = 0.72;
uniform float contrast : hint_range(0.5, 2.0) = 1.14;
uniform vec3 color_tint = vec3(0.92, 1.0, 0.91);


float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}


float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


float smooth_noise(float value) {
	float cell = floor(value);
	float local = fract(value);
	float eased = local * local * (3.0 - 2.0 * local);
	return mix(hash11(cell), hash11(cell + 1.0), eased);
}


vec2 distort_lens(vec2 uv, float amount, vec2 pixel_size) {
	vec2 centered = uv * 2.0 - 1.0;
	float aspect = pixel_size.y / pixel_size.x;
	centered.x *= aspect;
	float radius_squared = dot(centered, centered);
	centered *= 1.0 + amount * radius_squared;
	centered.x /= aspect;
	return centered * 0.5 + 0.5;
}


vec2 apply_camera_motion(vec2 uv, float time) {
	float shake_x = smooth_noise(time * camera_shake_speed) * 2.0 - 1.0;
	float shake_y = smooth_noise(time * camera_shake_speed + 19.7) * 2.0 - 1.0;
	uv += vec2(shake_x, shake_y) * camera_shake;
	return uv;
}


float horizontal_signal_offset(float y, float time) {
	float row = floor(y * jitter_resolution);
	float row_noise = hash11(row + floor(time * jitter_speed));
	float slow_wave = sin(y * 37.0 + time * 2.4) * 0.5 + 0.5;
	float burst = smoothstep(0.84, 1.0, row_noise);
	float offset = (row_noise - 0.5) * horizontal_jitter
		* (0.15 + burst * 2.4);
	offset += sin(y * 180.0 + time * 13.0) * horizontal_jitter
		* 0.08 * slow_wave;
	return offset;
}


float tracking_band_mask(float y, float time) {
	float band_position = fract(time * tracking_speed);
	float distance_to_band = abs(fract(y - band_position + 0.5) - 0.5);
	return 1.0 - smoothstep(
		tracking_width * 0.25,
		tracking_width,
		distance_to_band
	);
}


float horizontal_dropout(vec2 uv, float time) {
	float row = floor(uv.y * dropout_frequency);
	float frame = floor(time * 8.0);
	float random_value = hash21(vec2(row, frame));
	float line_candidate = step(0.94, random_value);
	float broken_segment = step(hash21(vec2(row + 41.0, frame)), uv.x);
	float thin_line = 1.0 - smoothstep(
		0.0,
		0.008,
		abs(fract(uv.y * dropout_frequency) - 0.5)
	);
	return line_candidate * broken_segment * thin_line;
}


vec3 adjust_saturation(vec3 color, float amount) {
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(luminance), color, amount);
}


vec3 adjust_contrast(vec3 color, float amount) {
	return (color - 0.5) * amount + 0.5;
}


void fragment() {
	float time = TIME * time_scale;
	vec2 pixel_size = 1.0 / vec2(textureSize(screen_texture, 0));
	vec2 original_uv = SCREEN_UV;
	vec2 uv = original_uv;

	uv = apply_camera_motion(uv, time);
	uv.y = fract(uv.y + time * vertical_roll_speed * vertical_roll_amount);
	uv = (uv - 0.5) / zoom + 0.5;
	uv = distort_lens(uv, lens_distortion, pixel_size);

	float signal_offset = horizontal_signal_offset(uv.y, time);
	uv.x += signal_offset;

	float tracking = tracking_band_mask(uv.y, time);
	float tracking_noise = hash21(vec2(
		floor(uv.y * 280.0),
		floor(time * 18.0)
	)) - 0.5;
	uv.x += tracking * tracking_noise * tracking_damage * 0.075;

	vec2 centered = uv - 0.5;
	vec2 radial_direction = centered / max(length(centered), 0.0001);
	vec2 chroma_offset = radial_direction * chromatic_aberration
		* (0.25 + length(centered));
	chroma_offset.x += signal_offset * 0.42;

	float red = texture(
		screen_texture,
		clamp(uv + chroma_offset, vec2(0.001), vec2(0.999))
	).r;
	float green = texture(
		screen_texture,
		clamp(uv, vec2(0.001), vec2(0.999))
	).g;
	float blue = texture(
		screen_texture,
		clamp(uv - chroma_offset, vec2(0.001), vec2(0.999))
	).b;
	vec3 color = vec3(red, green, blue);

	vec3 bleed_sample = texture(
		screen_texture,
		clamp(
			uv - vec2(color_bleed, 0.0),
			vec2(0.001),
			vec2(0.999)
		)
	).rgb;
	color.r = mix(color.r, bleed_sample.r, 0.38);
	color.b = mix(color.b, bleed_sample.b, 0.24);

	float scanline = sin(
		original_uv.y * scanline_count * 6.2831853
		+ time * scanline_speed
	);
	float scanline_mask = 1.0 - scanline_strength
		* (0.5 + 0.5 * scanline);
	color *= scanline_mask;

	float pixel_x = original_uv.x / pixel_size.x;
	float phosphor_phase = mod(floor(pixel_x), 3.0);
	vec3 phosphor_mask = vec3(1.0);
	if (phosphor_phase < 1.0) {
		phosphor_mask = vec3(1.0, 0.88, 0.88);
	} else if (phosphor_phase < 2.0) {
		phosphor_mask = vec3(0.88, 1.0, 0.88);
	} else {
		phosphor_mask = vec3(0.88, 0.88, 1.0);
	}
	color *= mix(vec3(1.0), phosphor_mask, phosphor_strength);

	vec2 noise_coordinate = floor(
		original_uv / (pixel_size * noise_size)
	);
	float noise = hash21(
		noise_coordinate
		+ vec2(floor(time * 59.94), floor(time * 41.0))
	);
	float monochrome_noise = (noise - 0.5) * static_noise;
	vec3 colored_noise = vec3(
		hash21(noise_coordinate + time * 37.1),
		hash21(noise_coordinate + time * 43.7),
		hash21(noise_coordinate + time * 51.9)
	) - 0.5;
	color += monochrome_noise;
	color += colored_noise * static_noise * 0.18;

	float dropout = horizontal_dropout(original_uv, time)
		* dropout_strength;
	color = mix(color, vec3(0.72 + noise * 0.28), dropout);
	color += tracking * tracking_damage * 0.12 * (noise - 0.25);

	float exposure = 1.0
		+ sin(time * 1.73) * exposure_pumping * 0.35;
	exposure += (smooth_noise(time * 0.83) - 0.5)
		* exposure_pumping;
	color *= exposure;

	float refresh_flicker = 1.0 - flicker_strength
		* (0.5 + 0.5 * sin(time * flicker_speed));
	color *= refresh_flicker;

	color = adjust_saturation(color, saturation);
	color = adjust_contrast(color, contrast);
	color *= color_tint;
	color = max(color - vec3(crushed_blacks), vec3(0.0));

	vec2 vignette_uv = original_uv * (1.0 - original_uv.yx);
	float vignette = pow(
		clamp(vignette_uv.x * vignette_uv.y * 16.0, 0.0, 1.0),
		corner_vignette
	);
	color *= vignette;

	float inside = step(0.0, uv.x) * step(uv.x, 1.0)
		* step(0.0, uv.y) * step(uv.y, 1.0);
	color *= inside;

	vec3 clean_color = texture(screen_texture, original_uv).rgb;
	color = mix(clean_color, color, effect_strength);
	COLOR = vec4(color, 1.0);
}
