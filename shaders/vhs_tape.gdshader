shader_type spatial;
render_mode unshaded, cull_back;
// The CRT face of the ritual television. Idle it runs analog snow; playing it
// runs one of eight procedural recordings: a degraded fixed-camera view of a
// dark corridor with something at the far end that is nearer every time the
// tracking settles. Content is abstract on purpose — a tape is a mood, not a
// cutscene, and it must loop through a 24-second play without authored video.

uniform float playing : hint_range(0.0, 1.0) = 0.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float variant = 0.0;
uniform float watched : hint_range(0.0, 1.0) = 0.0;
// Authored footage: the live texture of a VideoStreamPlayer rendering in a
// SubViewport. When use_footage is set the recording is the video, and the
// procedural corridor is only the fallback for tapes with no file.
uniform sampler2D tape_tex : source_color, filter_linear;
uniform float use_footage = 0.0;
// Fade the luminous raster into the tube's dark glass. Keeping this as a
// colour/emission mask (rather than material transparency) preserves correct
// depth against the model's separate curved-glass mesh.
uniform float edge_feather : hint_range(0.0, 0.08) = 0.036;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 snow(vec2 uv, float t) {
	float n = hash21(uv * vec2(191.0, 227.0) + vec2(fract(t * 61.0), fract(t * 47.0)) * 113.0);
	float band = 0.85 + 0.15 * sin(uv.y * 400.0 + t * 9.0);
	return vec3(n * band);
}

vec3 tape_frame(vec2 uv, float t) {
	// Fixed camera down a corridor: converging walls as vertical gradients, a
	// flickering overhead fixture band, and a silhouette that closes with
	// progress. Variant shifts geometry, tint and the figure's drift.
	float v = variant;
	float sway = sin(t * 0.31 + v) * 0.03;
	vec2 p = uv - vec2(0.5 + sway, 0.5);
	float depth = clamp(1.0 - abs(p.y) * 2.1, 0.0, 1.0);
	float corridor = smoothstep(0.5, 0.06 + 0.04 * sin(v * 2.7), abs(p.x));
	vec3 wall_tint = mix(vec3(0.32, 0.33, 0.30), vec3(0.30, 0.28, 0.34),
		fract(v * 0.37));
	vec3 col = wall_tint * (0.22 + 0.55 * corridor * depth);
	// Ceiling fixtures: bright cells marching away, occasionally guttering.
	float fixture = smoothstep(0.965, 1.0,
		sin((p.y + 0.42) * 40.0 + v) * step(p.y, -0.28));
	float gutter = step(0.35, vnoise(vec2(floor(t * 3.0), v * 7.0)));
	col += vec3(0.9, 0.87, 0.72) * fixture * gutter * 0.8;
	// The figure: a dark occlusion at the vanishing point, wider and taller
	// with progress, with a slow lateral drift keyed to the variant.
	float near = clamp(progress * 1.12, 0.0, 1.0);
	vec2 fig = p - vec2(sin(t * 0.17 + v * 3.1) * 0.10 * (1.0 - near), 0.06 - near * 0.04);
	float fig_w = mix(0.012, 0.16, near * near);
	float fig_h = mix(0.05, 0.42, near);
	float body = smoothstep(fig_w, fig_w * 0.35, abs(fig.x))
		* smoothstep(fig_h, fig_h * 0.5, abs(fig.y + fig_h * 0.2));
	col = mix(col, vec3(0.015), body * 0.92);
	// The last second cuts to the figure filling the frame.
	float lunge = smoothstep(0.955, 0.985, progress);
	col = mix(col, vec3(0.01), lunge);
	// Tape damage: grain, tracking tear at the bottom, crease lines, vignette.
	float grain = (hash21(uv * 251.0 + fract(t * 39.0)) - 0.5) * 0.16;
	col += grain;
	float tear = step(uv.y, 0.06) * step(0.4, vnoise(vec2(t * 7.0, uv.y * 90.0)));
	col = mix(col, snow(uv, t), tear * 0.8);
	float crease = smoothstep(0.008, 0.0,
		abs(fract(uv.y * 1.0 + t * 0.04 + v * 0.5) - 0.5) - 0.485);
	col += vec3(0.10) * crease;
	float vig = smoothstep(0.95, 0.45, length(p) * 1.35);
	return col * (0.35 + 0.65 * vig);
}

void fragment() {
	vec2 uv = UV;
	// Slight barrel curvature so the flat quad reads as a tube.
	vec2 c = uv - 0.5;
	uv = c * (1.0 + dot(c, c) * 0.18) + 0.5;
	// The barrel warp naturally rounds the corners. Distance from its warped
	// edge gives the raster a soft falloff instead of exposing a sharp quad.
	float edge_distance = min(min(uv.x, 1.0 - uv.x),
		min(uv.y, 1.0 - uv.y));
	float tube_aperture = smoothstep(-edge_feather * 0.18,
		edge_feather, edge_distance);
	float t = TIME;
	vec3 idle = snow(uv, t) * mix(0.5, 0.12, watched);
	vec3 recording;
	if (use_footage > 0.5) {
		// The footage goes through the tape, not just onto the glass:
		// per-line jitter with rare violent rows, a slow rolling tracking
		// band, chroma bleed, washed VHS colour, grain, sparkle dropouts,
		// head-switching noise at the bottom, and the tube's vignette.
		vec2 fuv = clamp(uv, vec2(0.0), vec2(1.0));
		float row = floor(fuv.y * 240.0);
		float jitter = (hash21(vec2(row, floor(t * 24.0))) - 0.5) * 0.006;
		float rough = step(0.972, hash21(vec2(row * 0.37, floor(t * 13.0))));
		jitter += rough * (hash21(vec2(row, floor(t * 31.0))) - 0.5) * 0.065;
		fuv.x += jitter + sin(fuv.y * 9.0 + t * 1.7) * 0.0016;
		// Keep smoothstep's edges ordered. Reversed edges are undefined GLSL
		// and made the principal tracking band disappear on some renderers.
		float band_center = fract(t * 0.061);
		float band_dist = abs(fract(fuv.y - band_center + 0.5) - 0.5);
		float band = 1.0 - smoothstep(0.018, 0.115, band_dist);
		float band_shift = hash21(vec2(floor(fuv.y * 84.0),
			floor(t * 16.0))) - 0.5;
		fuv.x += band * band_shift * 0.038;
		float ca = 0.0035 + band * 0.0045;
		vec3 src;
		src.r = texture(tape_tex, fuv + vec2(ca, 0.0)).r;
		src.g = texture(tape_tex, fuv).g;
		src.b = texture(tape_tex, fuv - vec2(ca, 0.0)).b;
		float luma = dot(src, vec3(0.299, 0.587, 0.114));
		recording = mix(vec3(luma), src, 0.76);
		recording = recording * vec3(1.04, 0.99, 0.94) * 0.92 + vec3(0.04);
		recording += band * 0.085;
		recording += (hash21(uv * 251.0 + fract(t * 39.0)) - 0.5) * 0.18;
		float sparkle = step(0.9985,
			hash21(vec2(row, floor(t * 47.0)) + uv.x));
		recording = mix(recording, vec3(0.95), sparkle * 0.8);
		float tear = step(uv.y, 0.045)
			* step(0.35, vnoise(vec2(t * 7.0, uv.y * 90.0)));
		recording = mix(recording, snow(uv, t), tear * 0.8);
		vec2 pc = uv - 0.5;
		recording *= 0.45 + 0.55 * smoothstep(0.95, 0.45, length(pc) * 1.30);
	} else {
		recording = tape_frame(uv, t);
	}
	vec3 col = mix(idle, recording, playing);
	// 240 visible lines — the vertical resolution a VHS tape actually carried.
	float scan = 0.76 + 0.24 * sin(uv.y * 240.0 * TAU);
	col *= scan * tube_aperture;
	ALBEDO = col * 0.9;
	EMISSION = col * mix(0.55, 1.1, playing);
}
