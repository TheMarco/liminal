shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

// A real human silhouette on a cylindrical billboard. The figure always
// presents its outline to the camera — the way an apparition is only ever
// seen, never inspected. Drifting noise eats the edges so the shape never
// fully commits to being there. It does not otherwise move: a billboard that
// shifts is a cutout on rails, and stillness is worse anyway.

// no mipmaps on the cutout: thin limbs and hair average away to nothing at
// distance otherwise, and the figure quietly stops existing before its time
uniform sampler2D tex : source_color, filter_linear;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float erode_amt = 0.28;
// The window of source alpha that becomes the visible edge. The traced
// cutouts are effectively binary, so a tight window carves an outline out of
// the noise. The painted ones are all edge — smoke, hair, blurred hands — and
// need a window as wide as the range or their haze snaps into a hard rim.
uniform float edge0 = 0.16;
uniform float edge1 = 0.58;
instance uniform float fade = 1.0;
instance uniform float flip = 0.0;

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
	vec3 wpos = obj + right * VERTEX.x * sx + up * VERTEX.y * sy;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(wpos, 1.0));
}

void fragment() {
	vec2 uv = UV;
	uv.x = mix(uv.x, 1.0 - uv.x, flip);
	float a = texture(tex, uv).a;
	// two scales of slow-crawling noise erode the outline
	float n1 = texture(noise_tex, uv * vec2(2.2, 1.1) + vec2(TIME * 0.017, TIME * 0.011)).r;
	float n2 = texture(noise_tex, uv * vec2(5.0, 3.2) - vec2(TIME * 0.008, TIME * 0.021)).r;
	float bite = (n1 * 0.6 + n2 * 0.4) * erode_amt;
	float shape = smoothstep(edge0, edge1, a - bite + 0.1);
	// the interior is not quite uniform — something moves inside the dark
	float body = 1.0 - 0.18 * texture(noise_tex, uv * 1.4 + vec2(0.0, TIME * 0.006)).r;
	ALBEDO = vec3(0.006, 0.007, 0.011) * body;
	ALPHA = shape * fade * 0.97;
}
