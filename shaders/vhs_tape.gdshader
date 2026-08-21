shader_type spatial;
render_mode unshaded, cull_back;
// The spatial face of the ritual television. Authored footage arrives already
// processed by the shared found-footage pass and is presented without another
// signal simulation. Idle snow and the procedural no-file fallback stay here.

uniform float playing : hint_range(0.0, 1.0) = 0.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float variant = 0.0;
uniform float watched : hint_range(0.0, 1.0) = 0.0;
// Authored footage: the high-resolution, post-processed SubViewport texture.
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
	// Authored footage arrives already processed by the game's recovered-tape
	// shader. Idle snow and the procedural fallback retain the tube's local
	// warp; applying it to authored video would bend and degrade the signal twice.
	if (use_footage <= 0.5) {
		vec2 c = uv - 0.5;
		uv = c * (1.0 + dot(c, c) * 0.18) + 0.5;
	}
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
		recording = texture(tape_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	} else {
		recording = tape_frame(uv, t);
	}
	vec3 col = mix(idle, recording, playing);
	// Procedural material keeps its own tube scan. Authored video already carries
	// the shared found-footage shader's field and scan-line treatment.
	float scan = 0.76 + 0.24 * sin(uv.y * 240.0 * TAU);
	col *= mix(scan * tube_aperture, 1.0, use_footage);
	ALBEDO = col * 0.9;
	EMISSION = col * mix(0.55, 1.1, playing);
}
