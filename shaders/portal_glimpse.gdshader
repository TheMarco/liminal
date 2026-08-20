// Camera-only wall tear (PhotoAnomaly PORTAL). Through the ragged opening
// you look out into a photographed 360 panorama (CC0 Poly Haven HDRIs, see
// textures/portals/SOURCE.md), sampled by the TRUE view ray through the
// hole — geometrically correct perspective and parallax, like a window cut
// into a skybox of the real world. The image is the CAMERA'S claim, so the
// mystery contract holds. GI-disabled and lens-only via render layers set
// by the spawner; fog_disabled because the tear is not in this room's air.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform sampler2D pano : source_color, filter_linear, repeat_enable;
uniform float yaw_offset = 0.0;
uniform float exposure = 0.5;
uniform float seed_phase = 0.0;
uniform vec3 grade : source_color = vec3(0.92, 0.94, 0.92);

float h21(vec2 p){
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
		mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment(){
	// True view ray, world space: from the eye through this fragment.
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 dir = normalize(world_pos - eye);

	// Equirectangular lookup with a seeded yaw so each tear faces its own
	// slice of the world.
	float u = atan(dir.z, dir.x) / (2.0 * PI) + 0.5 + yaw_offset;
	float v = acos(clamp(dir.y, -1.0, 1.0)) / PI;
	vec3 col = texture(pano, vec2(u, v)).rgb;

	// Kill the sun: Reinhard on luminance, then a dead grade — the world
	// out there is overcast even when the photograph wasn't.
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col *= (1.0 / (1.0 + l)) * exposure;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 0.55) * grade;

	// Grain that never settles.
	vec2 base_uv = UV - 0.5;
	col += vec3(h21(base_uv * 371.0 + fract(TIME) * vec2(13.7, 7.9)) - 0.5)
		* 0.02;

	// The silhouette is a FISSURE, not a window: a tall angular zigzag
	// polyline (linear interp between stepped noise gives hard corners)
	// that needles out at both tips, with a faint luminous seam along the
	// broken edge. A soft-edged rectangle read as "a blanket hanging"
	// (owner, 2026-08-20).
	float yn = base_uv.y * 2.0;                  // -1 .. 1 top to bottom
	float step_y = (yn + 1.0) * 3.5;             // 7 zigzag segments
	float i0 = floor(step_y);
	float cx = mix(h21(vec2(i0, seed_phase)) - 0.5,
		h21(vec2(i0 + 1.0, seed_phase)) - 0.5, fract(step_y)) * 0.42;
	// Widest at the waist, needle tips at the ends; a breath of pulse.
	float widthc = 0.21 * pow(max(1.0 - abs(yn), 0.0), 1.4)
		* (0.75 + 0.25 * noise2(vec2(yn * 3.0, seed_phase + 5.0)))
		* (0.94 + 0.06 * sin(TIME * 1.7 + seed_phase));
	float dist = abs(base_uv.x - cx);
	float inside = step(dist, widthc);
	// Luminous seam just inside the broken edge — energy along the crack.
	float seam = smoothstep(widthc, widthc * 0.72, dist)
		- smoothstep(widthc * 0.55, widthc * 0.2, dist);
	col = mix(col, vec3(0.85, 0.92, 1.0), clamp(seam, 0.0, 1.0) * 0.55);
	// Vertical clip so needle tips truly end.
	inside *= step(abs(yn), 1.0);

	ALBEDO = col;
	ALPHA = inside;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
