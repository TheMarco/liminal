shader_type spatial;
render_mode cull_disabled;

// Original fictional cabinet artwork. The image remains physically lit so the
// printed glass picks up room light and reflections; only the bright portions
// contribute a restrained internal glow.
uniform sampler2D artwork : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.72;
uniform float age : hint_range(0.0, 1.0) = 0.18;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// `_mquad` already supplies image-space UVs in display orientation.
	vec2 uv = UV;
	vec3 art = texture(artwork, uv).rgb;
	float luma = dot(art, vec3(0.2126, 0.7152, 0.0722));

	// Subtle glass age and uneven backlight. This is deliberately much finer
	// than the global CRT pass and does not turn the cabinet art into scanlines.
	float grain = hashf(floor((uv + wpos.xz * 0.003) * vec2(780.0, 520.0)));
	float edge = smoothstep(0.0, 0.13, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	float backlight = mix(0.90, 1.0, edge) * mix(0.965, 1.015, grain);
	vec3 aged = art * backlight;
	aged = mix(aged, aged * vec3(0.84, 0.78, 0.66), age * 0.16);

	float attract = 0.96 + 0.04 * sin(TIME * 0.43 + hashf(floor(wpos.xz * 2.0)) * 6.2831);
	float luminous = smoothstep(0.16, 0.78, luma) * glow_strength * attract;
	ALBEDO = aged * 0.72;
	EMISSION = aged * luminous;
	ROUGHNESS = 0.23;
	METALLIC = 0.0;
	SPECULAR = 0.68;
}
