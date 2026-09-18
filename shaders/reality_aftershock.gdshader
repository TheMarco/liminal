shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;

vec3 soft_scene(vec2 uv, vec2 radius, vec2 ray, vec2 texel) {
	vec2 lo = texel * 0.5;
	vec2 hi = vec2(1.0) - lo;
	vec3 c = texture(scene, clamp(uv, lo, hi)).rgb * 0.20;
	// Joint defocus and radial smear: nine normalized taps per colour, rather
	// than stacking another full-screen blur pass. Fixed offsets avoid shimmer.
	for (int i = 1; i <= 4; i++) {
		float t = float(i) * 0.25;
		float angle = float(i) * 2.399963;
		vec2 disc = vec2(cos(angle), sin(angle)) * radius * (0.55 + 0.45 * t);
		vec2 offset = ray * t + disc;
		float weight = i == 1 ? 0.15 : (i == 2 ? 0.12 : (i == 3 ? 0.08 : 0.05));
		c += texture(scene, clamp(uv + offset, lo, hi)).rgb * weight;
		c += texture(scene, clamp(uv - offset, lo, hi)).rgb * weight;
	}
	return c;
}

void fragment() {
	vec2 p = SCREEN_UV - vec2(0.5);
	float edge = smoothstep(0.10, 0.56, length(p));
	// Slow, pronounced lens deformation, not a camera rotation or screen shake.
	vec2 bend = vec2(sin(phase * 1.25 + p.y * 4.0), cos(phase * 0.93 + p.x * 3.0));
	vec2 sway = vec2(sin(phase * 1.55), sin(phase * 1.14) * 0.55) * 0.008;
	vec2 uv = SCREEN_UV + (bend * p.yx * (0.075 * mix(0.2, 1.0, edge)) + sway) * strength * motion_scale;
	// Lose focus first, then pull apart into broad coloured layers. The outer
	// envelope still takes the entire effect smoothly back to a clean image.
	float focus_wave = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(phase * 2.4 - 0.8), 2.0);
	float separation = 0.65 * strength * mix(0.55, 1.0, smoothstep(0.75, 1.55, phase));
	// Reference-pixel radius scales with the output: consistent at 720p/Retina.
	vec2 pixel = SCREEN_PIXEL_SIZE / (SCREEN_PIXEL_SIZE.y * 720.0);
	vec2 radius = pixel * strength * focus_wave * mix(9.0, 22.0, edge);
	vec2 ray = p * (0.12 * strength * focus_wave * mix(0.35, 1.0, edge));
	// Broad RGB magnification mismatch, like the owner's corridor references.
	// Much wider than VHS's chroma filter; keep the existing tape/HUD unchanged.
	vec2 split_axis = vec2(1.0 + p.x * 0.35, p.y * 0.55 + sin(phase * 0.8) * 0.18);
	vec2 fringe = pixel * split_axis * separation * mix(10.0, 24.0, edge);
	vec3 centre = soft_scene(uv, radius, ray, SCREEN_PIXEL_SIZE);
	vec3 red = soft_scene(uv + p * 0.20 * separation + fringe, radius * 0.55, ray * 0.65, SCREEN_PIXEL_SIZE);
	vec3 blue = soft_scene(uv - p * 0.16 * separation - fringe, radius * 0.55, ray * 0.65, SCREEN_PIXEL_SIZE);
	COLOR = vec4(red.r, centre.g, blue.b, 1.0);
}
