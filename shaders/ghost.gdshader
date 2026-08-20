shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

// A human silhouette on a camera-facing plane, but never a crisp cardboard
// cutout. Source alpha is convolved with a small screen-aware kernel so the
// outline stays softly out of focus at any distance. When noticed, coherent
// upward-flowing noise erodes the body into smoky islands instead of merely
// multiplying the whole figure by a linear opacity.

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
// The scene behind the figure. It is not painted black over the image; it takes
// light OUT of the image. See the absorb block in fragment().
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
// Fraction of the light behind it that survives, and it runs with the light.
// Against a bright wall there is contrast to spare, so it spends it on being
// visibly see-through — the room reads through the body and it stops being a
// sticker. Against a dim one the only contrast available IS its darkness, and
// translucency is exactly what would throw that away, so it closes down to a
// hole. Per pixel, so a figure straddling a lit wall and a dark wainscot is
// both at once, the way a real one photographs.
uniform float absorb_lit = 0.165;
uniform float absorb_dark = 0.020;
// Transmission multiplier for the recording mode. The RECOVERED TAPE pass
// lifts black, adds grain and washes colour, so a figure tuned for the clean
// tube loses its contrast there; the tape look closes the body down
// (<1.0 = darker) to buy it back. 1.0 on the clean tube.
uniform float density = 1.0;
// Past the bottom of that range there is no light left to remove and black on
// black is nothing at all. Only there, a noise-broken trace of value. Linear,
// pre-tonemap.
uniform float body_floor = 0.010;
uniform float unlit_luma = 0.012;
// The artwork's interior luminance as a density map. `form_scale` is where the
// art's brightest fold sits (measured across the sheets: ~0.30), `form_gain`
// how much more light a fully lit fold passes than a black cavity.
uniform float form_scale = 0.30;
uniform float form_gain = 2.6;
uniform float edge_transmit = 1.9;
uniform float chroma = 0.06;
// Relief and refraction, both derived from the same height field.
uniform float relief_scale = 2.4;
uniform float refract_amt = 0.006;
uniform float scatter = 0.055;
uniform float torch_gain = 0.16;
// Two of the sheets have a ground shadow painted into the artwork, below a
// clean gap under the hem. The figures are not supposed to cast one, so the
// cell is cut off above it. Zero for sheets that were drawn without one.
uniform float base_cut = 0.0;
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
// Negative keeps ordinary ghosts on their authored loop. Passing shadows set
// this explicitly from script, advancing once from frame 0 to the final frame
// so their walk can never wrap back to the entrance side.
instance uniform float flip_frame = -1.0;
// Opt-in temporal interpolation. Passers blend their one-shot walk; hostile
// ghosts blend their loop too since 2026-08-15 — the 12fps step against a
// 60fps world was the single loudest tell that they were sprites.
instance uniform float flip_blend = 0.0;
// Looping sheets blend the last frame back into the first instead of clamping
// there. One-shot passer sheets keep the clamp: their walk must never wrap.
instance uniform float flip_loop = 0.0;
// Temporal echo: the two previous poses linger faintly inside the silhouette,
// an analog smear that only shows against movement. Zero costs nothing.
instance uniform float trail_amt = 0.0;
// Animated heat-haze shimmer in the soft skirt just outside the body, so the
// room wavers around the figure instead of ending at a cutout edge.
uniform float aura_amt = 0.016;
instance uniform float fade = 1.0;
instance uniform float flip = 0.0;
instance uniform float dissolve_seed = 0.0;
// Corner sightings get a stronger black smoke breakup that disperses in place.
// It never emits light; the warm luminous path remains exclusive to flashlight kills.
instance uniform float dissolve_smoke = 0.0;
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
// How hard the beam is on it, fed from script. Distinct from `burn`, which is
// the charge toward a kill: the torch reveals the surface long before it has
// built enough heat to consume it.
instance uniform float torch = 0.0;


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
	// The kill eats upward from the hem, so the mass above loses its footing
	// as it goes. Settling the card toward the floor — top most, feet not at
	// all — reads as a body going down rather than a picture fading out.
	float slump = ignite > 0.5
		? (1.0 - clamp(fade, 0.0, 1.0)) * foot * 0.16
		: 0.0;
	vec3 wpos = obj + right * (VERTEX.x + lean) * sx
		+ up * (VERTEX.y - slump) * sy;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(wpos, 1.0));
}


// Origin and size of the sprite-sheet cell showing this instant's pose. A
// static cutout is simply the whole texture, so everything downstream can work
// in one coordinate system without branching.
vec2 cell_origin(float f, vec2 size) {
	return vec2(mod(f, flip_cols), floor(f / flip_cols)) * size;
}

void flip_cells(out vec2 org, out vec2 next_org, out vec2 prev_org,
		out vec2 prev2_org, out vec2 size, out float frame_mix) {
	if (flip_cols < 0.5) {
		org = vec2(0.0);
		next_org = org;
		prev_org = org;
		prev2_org = org;
		size = vec2(1.0);
		frame_mix = 0.0;
		return;
	}
	float n = max(flip_count, 1.0);
	float raw_frame;
	if (flip_frame >= 0.0) {
		raw_frame = clamp(flip_frame, 0.0, n - 1.0);
	} else {
		raw_frame = mod(TIME * flip_fps + flip_phase * n, n);
	}
	float f = floor(raw_frame);
	float next_f = flip_loop > 0.5 ? mod(f + 1.0, n) : min(f + 1.0, n - 1.0);
	float prev_f = flip_loop > 0.5 ? mod(f - 1.0 + n, n) : max(f - 1.0, 0.0);
	float prev2_f = flip_loop > 0.5 ? mod(f - 2.0 + n, n) : max(f - 2.0, 0.0);
	frame_mix = flip_blend * fract(raw_frame);
	size = vec2(1.0 / flip_cols, 1.0 / flip_rows);
	org = cell_origin(f, size);
	next_org = cell_origin(next_f, size);
	prev_org = cell_origin(prev_f, size);
	prev2_org = cell_origin(prev2_f, size);
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
	vec2 next_cell_org;
	vec2 prev_cell_org;
	vec2 prev2_cell_org;
	vec2 cell_size;
	float frame_mix;
	flip_cells(cell_org, next_cell_org, prev_cell_org, prev2_cell_org,
		cell_size, frame_mix);

	float remaining = clamp(fade, 0.0, 1.0);
	float dissolve = 1.0 - remaining;
	float seed = dissolve_seed * 17.31;

	// During the dissolve the source silhouette rises slightly and bends on
	// two moving noise fields. Sampling lower source pixels into higher output
	// pixels makes the remnants fray like smoke without sliding the whole card.
	float bend_a = texture(noise_tex,
		uv * vec2(1.7, 1.15) + vec2(seed, -TIME * 0.055)).r;
	float bend_b = texture(noise_tex,
		uv * vec2(4.8, 2.3) + vec2(-seed * 0.37, -TIME * 0.11)).r;
	vec2 smoke_uv = uv;
	float smoke_boost = 1.0 + dissolve_smoke * 0.85;
	smoke_uv.x += ((bend_a - 0.5) * dissolve * 0.075
		+ (bend_b - 0.5) * dissolve * 0.022) * smoke_boost;
	// Corner smoke remains anchored. Its turbulence deforms the silhouette
	// sideways, but neither the card nor its texture drifts upward.
	smoke_uv.y += dissolve * (1.0 - dissolve_smoke) * (0.018 + bend_a * 0.045);

	float a = soft_alpha(smoke_uv, cell_org, cell_size);
	if (frame_mix > 0.001) {
		float next_a = soft_alpha(smoke_uv, next_cell_org, cell_size);
		a = mix(a, next_a, frame_mix);
	}
	// The echo is two raw taps, not two more blur kernels: it only has to
	// thicken the coverage where the previous poses stood, and the erosion
	// below chews its edge ragged anyway.
	if (trail_amt > 0.001 && flip_cols > 0.5) {
		vec2 t_uv = clamp(smoke_uv, vec2(0.0), vec2(1.0));
		float ta = texture(tex, prev_cell_org + t_uv * cell_size).a;
		float ta2 = texture(tex, prev2_cell_org + t_uv * cell_size).a;
		a = max(a, max(ta * 0.40, ta2 * 0.20) * trail_amt);
	}
	a *= smoothstep(base_cut, base_cut + 0.018, smoke_uv.y);
	float n1 = texture(noise_tex,
		smoke_uv * vec2(2.15, 1.15) + vec2(seed + TIME * 0.012, -TIME * 0.075 * (1.0 - dissolve_smoke))).r;
	float n2 = texture(noise_tex,
		smoke_uv * vec2(6.2, 3.7) + vec2(-seed * 0.61 - TIME * 0.021, -TIME * 0.13 * (1.0 - dissolve_smoke))).r;
	float edge_noise = n1 * 0.62 + n2 * 0.38;
	float bite = edge_noise * erode_amt;
	float shape = smoothstep(edge0, edge1, a - bite + 0.10);

	// Coarse islands vanish at different times. Ordinary ghosts retain a slight
	// bottom-to-top bias; corner smoke breaks apart uniformly in place.
	float smoke_field = n1 * 0.58 + n2 * 0.42
		+ (1.0 - smoke_uv.y) * 0.16 * (1.0 - dissolve_smoke);
	float threshold = mix(-0.24, 1.08, dissolve);
	float survive = smoothstep(threshold - 0.14, threshold + 0.14, smoke_field);

	// A broader, dimmer rim remains around the broken pieces, making the holes
	// feather into wisps rather than revealing a hard animated dissolve line.
	float haze_shape = smoothstep(0.015, 0.46, a - bite * 0.45);
	float haze = max(haze_shape - shape, 0.0)
		* (0.34 + dissolve * (0.36 + dissolve_smoke * 0.24));
	float opacity = max(shape * survive, haze * survive);
	opacity *= smoothstep(0.0, 0.10, remaining);

	// The apparition absorbs light rather than being painted over it. Flat black
	// is a sticker: it holds the same value whether it stands in a lit atrium or
	// an unlit corridor, so in one it is a bold cutout and in the other it is
	// nothing at all. Multiplying the light behind it instead makes it carry the
	// room's own gradients, grain and falloff — the wall's texture survives
	// inside the silhouette at a fraction of its brightness, which is what an
	// absence in a photograph actually looks like. Structure still lives in
	// alpha; this only decides what the covered pixels become. No blue-grey rim:
	// the tint is the scene's, never the shader's.
	// The artwork is not a flat stencil: inside the silhouette it carries a
	// fully modelled figure — robe folds, a shadowed face cavity, hands, a
	// rippling hem — painted as luminance from 0 to about 0.3. Treating every
	// covered pixel to one uniform multiply throws all of that away and is
	// exactly why a pure absence reads as a flat layer at some opacity.
	//
	// So the source luminance becomes a density map. Where the art is bright
	// the material is lit and thin, and more of the room survives through it;
	// where it is black — the hollow of the hood, the gaps between folds —
	// almost nothing does. The form was always in the sheet; this only stops
	// discarding it.
	vec3 src = texture(tex, cell_org
		+ clamp(smoke_uv, vec2(0.0), vec2(1.0)) * cell_size).rgb;
	if (frame_mix > 0.001) {
		vec3 next_src = texture(tex, next_cell_org
			+ clamp(smoke_uv, vec2(0.0), vec2(1.0)) * cell_size).rgb;
		src = mix(src, next_src, frame_mix);
	}
	float form = clamp(dot(src, vec3(0.2126, 0.7152, 0.0722)) / form_scale,
		0.0, 1.0);

	// That same luminance doubles as a height field, so the folds have a
	// gradient and therefore a surface normal. Four taps: enough for relief,
	// and the alpha blur above already costs thirteen.
	vec2 step_uv = cell_size / vec2(textureSize(tex, 0)) * 2.0;
	float hx0 = dot(texture(tex, cell_org + clamp(smoke_uv - vec2(step_uv.x, 0.0),
		vec2(0.0), vec2(1.0)) * cell_size).rgb, vec3(0.333));
	float hx1 = dot(texture(tex, cell_org + clamp(smoke_uv + vec2(step_uv.x, 0.0),
		vec2(0.0), vec2(1.0)) * cell_size).rgb, vec3(0.333));
	float hy0 = dot(texture(tex, cell_org + clamp(smoke_uv - vec2(0.0, step_uv.y),
		vec2(0.0), vec2(1.0)) * cell_size).rgb, vec3(0.333));
	float hy1 = dot(texture(tex, cell_org + clamp(smoke_uv + vec2(0.0, step_uv.y),
		vec2(0.0), vec2(1.0)) * cell_size).rgb, vec3(0.333));
	vec3 nrm = normalize(vec3((hx0 - hx1) * relief_scale,
		(hy0 - hy1) * relief_scale, 1.0));

	// A body of a different density to air bends what is behind it. Offsetting
	// the screen sample along the surface normal — hardest at the silhouette,
	// where the surface turns away fastest — makes the room visibly swim as it
	// passes behind the figure. Nothing else in the frame says as clearly that
	// the thing occupies space rather than being pasted at that depth.
	// In the soft skirt outside the body the same two noise fields drive an
	// animated shimmer, so the room wavers around the silhouette the way air
	// does around something the wrong temperature. Inside the body the relief
	// normal keeps sole ownership of the refraction.
	float rim = clamp(haze_shape - shape, 0.0, 1.0);
	vec2 aura = vec2(bend_b - 0.5, bend_a - 0.5) * aura_amt
		* rim * (0.6 + 0.4 * edge_noise);
	vec2 warp = nrm.xy * refract_amt * (0.35 + 0.65 * (1.0 - shape)) + aura;
	vec3 behind = texture(screen_tex, SCREEN_UV + warp).rgb;
	float bg_luma = dot(behind, vec3(0.2126, 0.7152, 0.0722));
	float absorb = mix(absorb_dark, absorb_lit, smoothstep(0.0, 0.22, bg_luma));
	// Thin at the rim as well as at the lit folds. A body of finite depth has
	// less of itself to see through where its silhouette turns away, and the
	// coverage the blur already computed is a serviceable stand-in for that.
	absorb *= (1.0 + form * form_gain) * mix(edge_transmit, 1.0, shape);
	absorb *= density;
	// Absorption is never perfectly neutral. Letting a little more blue through
	// than red leaves the thin material faintly cold without the shader ever
	// choosing a colour of its own — the tint is still the room's.
	vec3 albedo = behind * absorb * vec3(1.0 - chroma, 1.0, 1.0 + chroma);
	// The lift is gated on the background being genuinely unlit, or it would
	// undo the black the dim case just bought. Broken up by the same drifting
	// noise that eats the edge, so where it does come in the body is veiled
	// rather than filled — a flat grey fill would be a worse sticker than the
	// flat black one this replaced.
	float unlit = 1.0 - smoothstep(0.0, unlit_luma, bg_luma);
	float veil = body_floor * unlit * mix(0.35, 1.30, n1 * 0.6 + n2 * 0.4);
	albedo += vec3(max(veil - dot(albedo, vec3(0.2126, 0.7152, 0.0722)), 0.0));

	// Not all the light that enters thin material is absorbed; some of it
	// scatters forward and leaves on this side. Where the room behind is bright
	// and the fold is thin, a little of it bleeds through as diffuse glow rather
	// than clean transmission — the difference between a filter and a body.
	albedo += behind * scatter * form * form * (0.30 + 0.70 * (1.0 - shape));

	// Relief, revealed by the torch. The beam is mounted on the camera, so its
	// light always arrives from the viewer; a fixed key just off that axis is
	// what gives the folds a readable direction. This is the one moment the
	// figure is a surface rather than an absence, and it is bought with the
	// same gesture that kills it: aim, and you see what you are aiming at.
	if (torch > 0.001) {
		vec3 key = normalize(vec3(-0.34, 0.52, 0.78));
		float lambert = max(dot(nrm, key), 0.0);
		float relief = pow(lambert, 1.6) * form;
		albedo += vec3(1.0, 0.92, 0.80) * relief * torch * torch_gain;
	}
	float emit = 0.0;

	// Artwork that carries its own colour keeps it — the animated wraith has
	// lit eyes, and flattening those to black throws away the one feature the
	// silhouette treatment cannot reproduce. Only saturated pixels survive, so
	// the body stays a true black cutout instead of turning into grey photo.
	if (keep_colour > 0.5) {
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
		albedo = mix(albedo, tint, lit);
		emit = lit * colour_gain;
	}

	float ember = n1 * 0.55 + n2 * 0.45;

	// Holding the beam on it heats the silhouette: embers catch across the body
	// and spread as the charge builds. The body itself stays whole, so easing
	// off only cools it back down instead of restoring something that had
	// visibly come apart.
	if (burn > 0.0) {
		float heat = burn * burn;
		// Thin material catches first. The hem and the outer folds are where the
		// artwork is brightest, so `form` puts the first embers exactly where a
		// real thing would start to go, instead of scattering them at random
		// across the mass.
		float catches = ember * (0.55 + form * 0.75);
		float speckle = smoothstep(0.62 - heat * 0.50, 0.99 - heat * 0.34,
			catches);
		float glow = clamp(speckle * heat, 0.0, 1.0);
		emit = glow * 1.25;
		// Only the pixels actually alight take the ember colour. Handing it to
		// the whole card turned the body pale the instant the beam touched it,
		// which spent the reveal before the charge had built.
		albedo = mix(albedo, vec3(1.0, 0.80, 0.52), glow);
	}

	// The kill, and only the kill, consumes. Driven by `dissolve`, which only
	// advances.
	//
	// A front that is only a function of height is a wipe: a horizontal bar
	// travelling up a shape. Real material goes in the order its own structure
	// dictates, so the front is pulled forward by `form` — the thin, lit hem
	// and the outer folds are alight while the mass of the robe has not caught
	// yet — and broken up by two noise fields at different scales so its edge
	// is ragged rather than a line.
	if (ignite > 0.5) {
		float front = dissolve * 1.58
			- (1.0 - smoke_uv.y) * 0.78
			+ form * 0.22
			- ember * 0.18
			- n2 * 0.10;
		float consumed = smoothstep(0.0, 0.13, front);

		// Three zones instead of one flat tan. Immediately behind the front the
		// material is charring; at the front itself it runs orange; and the
		// leading millimetre is white-hot. A single rim colour is what made the
		// old kill read as a coloured wipe rather than something burning.
		float core = smoothstep(-0.015, 0.005, front)
			* (1.0 - smoothstep(0.005, 0.045, front));
		float flame = smoothstep(-0.055, 0.0, front)
			* (1.0 - smoothstep(0.02, 0.15, front));
		float char_ = smoothstep(0.02, 0.11, front)
			* (1.0 - smoothstep(0.15, 0.42, front));

		// Sparks: a sparse set of the hottest noise peaks keep burning for a
		// while after the front has gone past them, so the wake is not simply
		// empty. They rise, because the noise fields already drift upward.
		float spark = smoothstep(0.90, 0.995, ember)
			* smoothstep(0.01, 0.10, front)
			* (1.0 - smoothstep(0.18, 0.60, front));

		opacity *= 1.0 - consumed * 0.97;
		opacity = max(opacity, (flame * 0.80 + spark * 0.85) * shape);
		opacity = max(opacity, char_ * 0.55 * shape);

		vec3 hot = mix(vec3(1.0, 0.42, 0.10), vec3(1.0, 0.78, 0.42),
			clamp(flame * 1.3, 0.0, 1.0));
		hot = mix(hot, vec3(1.0, 0.97, 0.90), clamp(core * 1.5, 0.0, 1.0));
		float lit_amt = clamp(flame * 1.5 + core + spark, 0.0, 1.0);
		// What the front has already passed is charred, not gone: a dark, dead
		// band that trails the flame and then dissolves with the rest.
		albedo = mix(albedo, vec3(0.05, 0.03, 0.03),
			clamp(char_ * 0.9, 0.0, 1.0));
		albedo = mix(albedo, hot, lit_amt);
		emit = max(emit, flame * (0.26 + ember * 0.34) + core * 0.80
			+ spark * 1.05);
	}

	// This shader is unshaded, so EMISSION is never read: the hot front has to
	// be carried by ALBEDO itself, pushed above 1.0 so the glow buffer catches
	// it and it blooms instead of merely turning pale.
	ALBEDO = albedo * (1.0 + emit * 4.5);
	ALPHA = clamp(opacity * 1.04, 0.0, 1.0);
}
