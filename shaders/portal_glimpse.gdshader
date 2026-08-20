// Camera-only crack in spacetime (PhotoAnomaly PORTAL). Through the
// fissure you look out into a photographed 360 panorama (CC0 Poly Haven,
// textures/portals/SOURCE.md) sampled by the TRUE view ray — correct
// perspective and parallax into a real place. The image is the CAMERA'S
// claim, so the mystery contract holds. Lens-only via render layers,
// GI-disabled, fog_disabled. The soft outer energy bleed lives on a
// second additive quad (portal_glow.gdshader) because the opaque
// alpha-scissor pipeline cannot feather outward.
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

float noise1(float x, float seed_v){
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(h21(vec2(i, seed_v)), h21(vec2(i + 1.0, seed_v)), f);
}

// Fissure centreline and lips. yn in -1..1 top to bottom.
// Coarse angular zigzag (linear interp = hard kinks) + fine serration,
// with a slow S-drift so the bolt is not pole-straight.
float crack_cx(float yn, float seed_v){
	float step_y = (yn + 1.0) * 3.5;
	float i0 = floor(step_y);
	float coarse = mix(h21(vec2(i0, seed_v)) - 0.5,
		h21(vec2(i0 + 1.0, seed_v)) - 0.5, fract(step_y)) * 0.40;
	float fine = (noise1((yn + 1.0) * 22.0, seed_v + 3.0) - 0.5) * 0.045;
	float drift = sin(yn * 2.2 + seed_v) * 0.05;
	return coarse + fine + drift;
}

// Independent lip widths: the crack pinches and bellies organically.
vec2 crack_lips(float yn, float seed_v){
	float taper = pow(max(1.0 - abs(yn), 0.0), 1.1);
	float wl = 0.5 + 0.6 * noise1((yn + 1.0) * 6.0, seed_v + 11.0);
	float wr = 0.5 + 0.6 * noise1((yn + 1.0) * 6.0, seed_v + 17.0);
	return vec2(wl, wr) * 0.30 * taper;
}

void fragment(){
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 dir = normalize(world_pos - eye);
	float u = atan(dir.z, dir.x) / (2.0 * PI) + 0.5 + yaw_offset;
	float v = acos(clamp(dir.y, -1.0, 1.0)) / PI;
	vec3 col = texture(pano, vec2(u, v)).rgb;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col *= (1.0 / (1.0 + l)) * exposure;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 0.55) * grade;

	vec2 base_uv = UV - 0.5;
	col += vec3(h21(base_uv * 371.0 + fract(TIME) * vec2(13.7, 7.9)) - 0.5)
		* 0.02;

	float yn = base_uv.y * 2.0;
	float cx = crack_cx(yn, seed_phase);
	vec2 lips = crack_lips(yn, seed_phase);
	float dx = base_uv.x - cx;
	float inside = step(-lips.x, dx) * step(dx, lips.y)
		* step(abs(yn), 1.0);
	// Seam: bright at the lip, flaring at kinks and tips, breathing.
	float lip_d = min(dx + lips.x, lips.y - dx);
	float wsum = lips.x + lips.y + 1e-4;
	float kink = abs(crack_cx(yn + 0.02, seed_phase)
		- crack_cx(yn - 0.02, seed_phase)) * 22.0;
	float flare = 0.45 + 0.9 * kink + 0.8 * pow(abs(yn), 3.0);
	flare *= 0.85 + 0.15 * sin(TIME * 2.3 + yn * 4.0 + seed_phase);
	float seam = exp(-lip_d / (wsum * 0.07)) * flare;
	col = mix(col, vec3(0.88, 0.95, 1.05), clamp(seam, 0.0, 0.85));

	ALBEDO = col;
	ALPHA = inside;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
