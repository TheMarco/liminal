shader_type canvas_item;

// CRT composite — a widescreen 720x480 anamorphic signal running as 480i.
// The 3D view is rendered at 480 lines (main.gd), horizontally resampled to
// 720 signal samples, and emitted as alternating even/odd 240-line fields.
// Curvature,
// beam scanlines, subtle phosphor texture, RGB convergence error, halation,
// vignette, interlace flicker, rolling scan band, signal noise, rounded
// tube corners.
//   strength = 0 -> passthrough, 1 -> full CRT. V toggles the whole rect.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// Brightness compensation for scanline/vignette darkening.
uniform float bright_boost : hint_range(0.5, 2.5) = 1.18;
// Master dial for all signal/RF noise (snow, shimmer, sparkles, chroma).
uniform float noise_amount : hint_range(0.0, 3.0) = 1.0;

const float H_RES = 720.0;      // anamorphic widescreen signal samples
const float V_RES = 480.0;      // two interlaced 240-line fields
const float HARD_SCAN = -6.0;   // fine 480-line beam, not the old coarse comb
const float BARREL = 0.018;     // tube curvature
const float ABERRATION = 1.05;  // RGB convergence error in output px at edge
const float HALATION = 0.055;   // glass glow bleed around bright areas
const float NOISE_AMP = 0.014;  // composite per-line signal shimmer
const float SNOW_AMP = 0.007;   // fine RF snow at 720x480
const float CORNER_R = 0.018;   // rounded tube corner radius

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 uv0 = SCREEN_UV;
	vec3 normal_input = texture(screen_tex, uv0).rgb;

	// ── Tube curvature: barrel-warp the sample position ──
	vec2 d = uv0 - 0.5;
	vec2 uvc = 0.5 + d * (1.0 + BARREL * dot(d, d) * 4.0);

	// A fixed 720x480 anamorphic signal. On unusually small windows, reduce
	// rows only far enough to avoid unstable sub-pixel scanline shimmer.
	float rows = min(V_RES, screen_size.y * 0.75);
	float cols = H_RES;
	float pitch = screen_size.y / rows;

	// ── 480i source: snap to 720 horizontal samples and 480 line positions.
	//    Alternate line parity at the NTSC field rate. Phosphor persistence
	//    keeps the previous field present rather than blacking every other row.
	float field_phase = mod(floor(TIME * 59.94), 2.0);
	float line_index = floor(uvc.y * rows);
	float quantized_y = (floor(uvc.y * rows) + 0.5) / rows;
	float quantized_x = (floor(uvc.x * cols) + 0.5) / cols;
	vec2 scan_uv = vec2(quantized_x, quantized_y);

	// ── CRT beam: 5-tap horizontal Gaussian blur with RGB convergence error
	//    (R/B splay outward with radius) ──
	float beam = 0.6 / cols;
	vec3 t0 = texture(screen_tex, vec2(scan_uv.x - beam * 2.0, scan_uv.y)).rgb;
	vec3 t1 = texture(screen_tex, vec2(scan_uv.x - beam, scan_uv.y)).rgb;
	vec3 t2 = texture(screen_tex, scan_uv).rgb;
	vec3 t3 = texture(screen_tex, vec2(scan_uv.x + beam, scan_uv.y)).rgb;
	vec3 t4 = texture(screen_tex, vec2(scan_uv.x + beam * 2.0, scan_uv.y)).rgb;
	vec3 beam_color = t0 * 0.06 + t1 * 0.24 + t2 * 0.40 + t3 * 0.24 + t4 * 0.06;

	// Convergence: red pulls outward, blue inward, growing toward the edges.
	float r2 = dot(d, d);
	vec2 conv = d * r2 * (ABERRATION * 2.0 / screen_size.x) * 4.0;
	beam_color.r = mix(beam_color.r, texture(screen_tex, scan_uv + conv).r, 0.75);
	beam_color.b = mix(beam_color.b, texture(screen_tex, scan_uv - conv).b, 0.75);

	vec3 normal_scene = texture(screen_tex, uvc).rgb;
	vec3 input_node = mix(normal_scene, beam_color, 0.88);

	// ── Halation: wide soft bleed from the glass face ──
	float hal_r = 2.2 / cols;
	vec3 hal = texture(screen_tex, uvc + vec2(hal_r, hal_r * 0.6)).rgb
		+ texture(screen_tex, uvc + vec2(-hal_r, hal_r * 0.6)).rgb
		+ texture(screen_tex, uvc + vec2(0.0, -hal_r * 0.9)).rgb;
	input_node += hal * (HALATION / 3.0);

	// ── Rounded-rect tube boundary in warped space ──
	vec2 rect_d = abs(uvc - 0.5) * 2.0 - vec2(1.0 - CORNER_R * 2.0);
	float corner_dist = min(max(rect_d.x, rect_d.y), 0.0) + length(max(rect_d, vec2(0.0))) - CORNER_R * 2.0;
	float corner_mask = 1.0 - smoothstep(-0.006, 0.002, corner_dist);

	// ── Scanlines (softened in dark areas so the dark floors stay visible) ──
	float virtual_y = uvc.y * rows;
	float scan_phase = fract(virtual_y) - 0.5;
	float bright = max(max(input_node.r, input_node.g), input_node.b);
	float scan_h = mix(HARD_SCAN * 0.32, HARD_SCAN * 0.65, bright);
	float scan_weight = exp(scan_phase * scan_phase * scan_h);
	float pitch_fade = smoothstep(1.05, 1.55, pitch) * 0.72;
	vec3 c = mix(input_node, input_node * scan_weight, pitch_fade);

	// A faint irregular phosphor grain gives the glass texture without
	// producing a persistent vertical grille over the entire picture.
	float phosphor = hash12(vec2(floor(uvc.x * cols * 0.5),
		floor(virtual_y * 0.5))) - 0.5;
	c *= 1.0 + phosphor * 0.018 * pitch_fade;

	// ── Warm consumer-CRT colour temperature ──
	c *= vec3(0.98, 0.95, 0.93);

	// ── Vignette + curvature edge falloff ──
	float vignette = 1.0 - r2 * 4.0 * 0.16;
	c *= vignette;

	// ── Interlace: the active field is a touch brighter while the other field
	//    persists in the phosphor. This reads in motion without harsh combing. ──
	float active_field = 1.0 - step(0.5,
		abs(mod(line_index, 2.0) - field_phase));
	c *= mix(0.965, 1.015, active_field * pitch_fade);

	// ── Rolling scan band ──
	float band_pos = fract(uvc.y * 0.5 - TIME * 0.08);
	float band = smoothstep(0.0, 0.15, band_pos) * smoothstep(0.45, 0.15, band_pos);
	c *= band * 0.15 + 1.0;

	// ── Composite signal noise — per-line shimmer over RF snow ──
	float noise = hash12(vec2(floor(virtual_y), floor(TIME * 60.0))) - 0.5;
	c *= 1.0 + noise * NOISE_AMP * noise_amount;
	// snow: fine per-signal-sample static at 720x480, breathing with a slow
	// interference band drifting down the picture
	vec2 cellp = vec2(floor(uvc.x * cols), floor(virtual_y));
	float snow = hash12(cellp + vec2(fract(TIME * 61.7) * 289.0, fract(TIME * 23.3) * 173.0));
	float ib_pos = fract(uvc.y * 0.7 + TIME * 0.043);
	float ib = smoothstep(0.0, 0.2, ib_pos) * smoothstep(0.5, 0.2, ib_pos);
	c += (snow - 0.5) * SNOW_AMP * (1.0 + ib * 2.2) * noise_amount;
	// stray analog sparkles — single hot pixels blinking in and out
	float spark2 = step(0.9998, hash12(cellp + vec2(fract(TIME * 41.3) * 97.0, 7.0)));
	c += spark2 * 0.28 * noise_amount;
	// faint per-line chroma wander — the colour never quite locks
	float cn = hash12(vec2(floor(virtual_y), floor(TIME * 30.0) + 31.0)) - 0.5;
	c.r *= 1.0 + cn * 0.03 * noise_amount;
	c.b *= 1.0 - cn * 0.025 * noise_amount;

	// ── Power-supply flicker ──
	float ps = sin(TIME * 13.7) * 0.5 + sin(TIME * 7.3) * 0.3 + sin(TIME * 23.1) * 0.2;
	c *= ps * 0.01 + 1.0;

	// ── Brightness compensation ──
	c *= bright_boost;

	// ── Tube corner mask ──
	c *= corner_mask;

	// ── Final strength mix (0 = original image, 1 = full CRT) ──
	vec3 out_color = mix(normal_input, max(c, vec3(0.0)), strength);
	COLOR = vec4(out_color, 1.0);
}
