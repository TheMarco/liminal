shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

// A human silhouette on a camera-facing plane, but never a crisp cardboard
// cutout. Source alpha is convolved with a small screen-aware kernel so the
// outline stays softly out of focus at any distance. When noticed, coherent
// upward-flowing noise erodes the body into smoky islands instead of merely
// multiplying the whole figure by a linear opacity.

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float erode_amt = 0.22;
uniform float edge0 = 0.08;
uniform float edge1 = 0.72;
uniform float edge_blur = 3.0;

// Flipbook. `tex` is a grid of frames rather than one silhouette when
// `flip_cols` is above zero: Godot's only video codec is Theora, which carries
// no alpha, so an animated apparition has to be a sprite sheet. Frames are
// cycled by offsetting UVs, which costs nothing over a static cutout.
uniform float flip_cols = 0.0;
uniform float flip_rows = 1.0;
uniform float flip_count = 0.0;
uniform float flip_fps = 12.0;
// Some of the source art carries its own colour — glowing eyes, mostly — that
// would be lost to the pure-black silhouette treatment below.
uniform float keep_colour = 0.0;
uniform float colour_gain = 1.0;
instance uniform float flip_phase = 0.0;
instance uniform float fade = 1.0;
instance uniform float flip = 0.0;
instance uniform float dissolve_seed = 0.0;
// 0..1 while the torch is on it, and it falls again the moment the beam slips
// off. Because it runs both ways it may only ever HEAT the figure — never eat
// it — or a wavering aim reads as the thing blinking out and back.
instance uniform float burn = 0.0;
// Latched at the kill. The consuming front hangs off this and off `fade`, both
// of which only ever travel one way.
instance uniform float ignite = 0.0;
// Signed lean, fed from script. Zero whenever the figure is in frame: a thing
// that holds perfectly still under your gaze and shifts its weight the moment
// you look away is worse than one that never moves at all.
instance uniform float sway = 0.0;


void vertex() {
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 obj = MODEL_MATRIX[3].xyz;
	vec3 to_cam = cam - obj;
	to_cam.y = 0.0;
	float l = length(to_cam);
	to_cam = l > 0.001 ? to_cam / l : vec3(0.0, 0.0, 1.0);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, to_cam));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	// Lean from the feet: shear grows with height so the shoulders travel and
	// the soles stay planted. A whole-quad slide would look like it was on ice.
	float foot = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	float lean = sway * 0.035 * foot * foot;
	vec3 wpos = obj + right * (VERTEX.x + lean) * sx + up * VERTEX.y * sy;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(wpos, 1.0));
}


// Origin and size of the sprite-sheet cell showing this instant's pose. A
// static cutout is simply the whole texture, so everything downstream can work
// in one coordinate system without branching.
void flip_cell(out vec2 org, out vec2 size) {
	if (flip_cols < 0.5) {
		org = vec2(0.0);
		size = vec2(1.0);
		return;
	}
	float n = max(flip_count, 1.0);
	float f = floor(mod(TIME * flip_fps + flip_phase * n, n));
	size = vec2(1.0 / flip_cols, 1.0 / flip_rows);
	org = vec2(mod(f, flip_cols), floor(f / flip_cols)) * size;
}


// Thirteen bilinear samples produce a soft photographic edge. The derivative
// floor keeps the blur at least a couple of screen pixels wide when the ghost
// is far away, rather than shrinking back into a razor-edged silhouette.
#define SAMPLE(c, w) (texture(tex, org + clamp((c), pad, 1.0 - pad) * size).a * (w))
float soft_alpha(vec2 uv, vec2 org, vec2 size) {
	vec2 source_px = vec2(1.0) / vec2(textureSize(tex, 0));
	vec2 px = max(source_px * edge_blur, fwidth(uv) * 1.6);
	// Half a texel in from the cell edge: bilinear filtering reaches one texel,
	// so an unclamped blur tap would drag a sliver of the neighbouring pose in
	// along the seams.
	vec2 pad = (source_px * 0.5) / size;
	float a = 0.0;
	a += SAMPLE(uv,                          0.22);
	a += SAMPLE(uv + vec2( px.x, 0.0),       0.10);
	a += SAMPLE(uv + vec2(-px.x, 0.0),       0.10);
	a += SAMPLE(uv + vec2(0.0,  px.y),       0.10);
	a += SAMPLE(uv + vec2(0.0, -px.y),       0.10);
	a += SAMPLE(uv + vec2( px.x,  px.y),     0.065);
	a += SAMPLE(uv + vec2(-px.x,  px.y),     0.065);
	a += SAMPLE(uv + vec2( px.x, -px.y),     0.065);
	a += SAMPLE(uv + vec2(-px.x, -px.y),     0.065);
	a += SAMPLE(uv + vec2( px.x * 2.0, 0.0), 0.03);
	a += SAMPLE(uv + vec2(-px.x * 2.0, 0.0), 0.03);
	a += SAMPLE(uv + vec2(0.0,  px.y * 2.0), 0.03);
	a += SAMPLE(uv + vec2(0.0, -px.y * 2.0), 0.03);
	return a;
}


void fragment() {
	vec2 uv = UV;
	uv.x = mix(uv.x, 1.0 - uv.x, flip);

	vec2 cell_org;
	vec2 cell_size;
	flip_cell(cell_org, cell_size);

	float remaining = clamp(fade, 0.0, 1.0);
	float dissolve = 1.0 - remaining;
	float seed = dissolve_seed * 17.31;

	// During the dissolve the source silhouette rises slightly and bends on
	// two moving noise fields. Sampling lower source pixels into higher output
	// pixels makes the remnants climb like smoke without sliding the whole card.
	float bend_a = texture(noise_tex,
		uv * vec2(1.7, 1.15) + vec2(seed, -TIME * 0.055)).r;
	float bend_b = texture(noise_tex,
		uv * vec2(4.8, 2.3) + vec2(-seed * 0.37, -TIME * 0.11)).r;
	vec2 smoke_uv = uv;
	smoke_uv.x += (bend_a - 0.5) * dissolve * 0.075
		+ (bend_b - 0.5) * dissolve * 0.022;
	smoke_uv.y += dissolve * (0.018 + bend_a * 0.045);

	float a = soft_alpha(smoke_uv, cell_org, cell_size);
	float n1 = texture(noise_tex,
		smoke_uv * vec2(2.15, 1.15) + vec2(seed + TIME * 0.012, -TIME * 0.075)).r;
	float n2 = texture(noise_tex,
		smoke_uv * vec2(6.2, 3.7) + vec2(-seed * 0.61 - TIME * 0.021, -TIME * 0.13)).r;
	float edge_noise = n1 * 0.62 + n2 * 0.38;
	float bite = edge_noise * erode_amt;
	float shape = smoothstep(edge0, edge1, a - bite + 0.10);

	// Coarse islands vanish at different times. A small upward bias leaves the
	// head and shoulders hanging for a beat while the legs disperse first.
	float smoke_field = n1 * 0.58 + n2 * 0.42 + (1.0 - smoke_uv.y) * 0.16;
	float threshold = mix(-0.24, 1.08, dissolve);
	float survive = smoothstep(threshold - 0.14, threshold + 0.14, smoke_field);

	// A broader, dimmer rim remains around the broken pieces, making the holes
	// feather into wisps rather than revealing a hard animated dissolve line.
	float haze_shape = smoothstep(0.015, 0.46, a - bite * 0.45);
	float haze = max(haze_shape - shape, 0.0) * (0.34 + dissolve * 0.36);
	float opacity = max(shape * survive, haze * survive);
	opacity *= smoothstep(0.0, 0.10, remaining);

	// The apparition absorbs light. All structure lives in alpha: the core is
	// absolute black and only the soft photographic edge/smoke dissolve reveals
	// the scene through partial coverage. No blue-grey rim survives grading.
	vec3 albedo = vec3(0.0);
	float emit = 0.0;

	// Artwork that carries its own colour keeps it — the animated wraith has
	// lit eyes, and flattening those to black throws away the one feature the
	// silhouette treatment cannot reproduce. Only saturated pixels survive, so
	// the body stays a true black cutout instead of turning into grey photo.
	if (keep_colour > 0.5) {
		vec3 src = texture(tex, cell_org
			+ clamp(smoke_uv, vec2(0.0), vec2(1.0)) * cell_size).rgb;
		float peak = max(src.r, max(src.g, src.b));
		float sat = peak - min(src.r, min(src.g, src.b));
		float lit = smoothstep(0.045, 0.18, sat);
		// Only the saturated pixels keep their colour. Handing every pixel its
		// source value painted the artwork's pale smoke onto the scene as a
		// white aura around the figure — the body has to stay a black absence
		// and let the eyes alone burn through it.
		//
		// Lit pixels are normalised to full brightness in their own hue rather
		// than used raw: several of the sheets paint their eyes a dark red
		// around 0.3, which after the saturation ramp came out barely above the
		// black body and read as no eyes at all. Hue is the artwork's business;
		// how brightly a lit eye burns is this shader's.
		vec3 tint = src / max(peak, 0.001);
		albedo = mix(vec3(0.0), tint, lit);
		emit = lit * colour_gain;
	}

	float ember = n1 * 0.55 + n2 * 0.45;

	// Holding the beam on it heats the silhouette: embers catch across the body
	// and spread as the charge builds. The body itself stays whole, so easing
	// off only cools it back down instead of restoring something that had
	// visibly come apart.
	if (burn > 0.0) {
		float heat = burn * burn;
		float speckle = smoothstep(0.62 - heat * 0.50, 0.99 - heat * 0.34, ember);
		emit = speckle * heat * 1.25;
		albedo = vec3(1.0, 0.80, 0.52);
	}

	// The kill, and only the kill, consumes. A ragged front runs up the body
	// and everything behind it is gone; the material just ahead of it glows
	// white-hot on the way through. Driven by `dissolve`, which only advances.
	if (ignite > 0.5) {
		float front = dissolve * 1.45 - (1.0 - smoke_uv.y) * 0.40 - ember * 0.28;
		float consumed = smoothstep(0.0, 0.20, front);
		float rim = smoothstep(0.0, 0.14, front)
			* (1.0 - smoothstep(0.14, 0.42, front));
		opacity *= 1.0 - consumed * 0.96;
		opacity = max(opacity, rim * 0.90 * shape);
		emit = max(emit, rim * (0.70 + ember * 0.95));
		albedo = vec3(1.0, 0.86, 0.62);
	}

	// This shader is unshaded, so EMISSION is never read: the hot front has to
	// be carried by ALBEDO itself, pushed above 1.0 so the glow buffer catches
	// it and it blooms instead of merely turning pale.
	ALBEDO = albedo * (1.0 + emit * 4.5);
	ALPHA = clamp(opacity * 1.04, 0.0, 1.0);
}
