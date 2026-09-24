shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;

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
	// Use the screen copy's blurred mip levels instead of 27 texture reads per
	// output pixel. This keeps the effect responsive at Retina resolutions.
	vec2 pixel = SCREEN_PIXEL_SIZE / (SCREEN_PIXEL_SIZE.y * 720.0);
	float blur_px = strength * focus_wave * mix(9.0, 22.0, edge);
	float blur_lod = log2(1.0 + blur_px * 0.55);
	vec2 ray = p * (0.04 * strength * focus_wave * mix(0.35, 1.0, edge));
	// Broad RGB magnification mismatch, like the owner's corridor references.
	// Much wider than VHS's chroma filter; keep the existing tape/HUD unchanged.
	vec2 split_axis = vec2(1.0 + p.x * 0.35, p.y * 0.55 + sin(phase * 0.8) * 0.18);
	vec2 fringe = pixel * split_axis * separation * mix(10.0, 24.0, edge);
	vec2 lo = SCREEN_PIXEL_SIZE * 0.5;
	vec2 hi = vec2(1.0) - lo;
	vec3 centre = textureLod(scene, clamp(uv, lo, hi), blur_lod).rgb;
	vec3 red = textureLod(scene, clamp(uv + p * 0.20 * separation + fringe + ray, lo, hi), blur_lod * 0.65).rgb;
	vec3 blue = textureLod(scene, clamp(uv - p * 0.16 * separation - fringe - ray, lo, hi), blur_lod * 0.65).rgb;
	COLOR = vec4(red.r, centre.g, blue.b, 1.0);
}
