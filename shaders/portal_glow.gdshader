// Additive outer energy of the spacetime crack: a soft cold bleed onto
// the wall around the fissure, flickering faintly. Paired with
// portal_glimpse.gdshader (same centreline math, same seed) on a second,
// slightly larger quad. Lens-only, GI-disabled, no depth write.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, blend_add, depth_draw_never;

uniform float seed_phase = 0.0;

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
	float taper = pow(max(1.0 - abs(yn), 0.0), 1.6);
	float wl = 0.5 + 0.6 * noise1((yn + 1.0) * 6.0, seed_v + 11.0);
	float wr = 0.5 + 0.6 * noise1((yn + 1.0) * 6.0, seed_v + 17.0);
	return vec2(wl, wr) * 0.17 * taper;
}

void fragment(){
	vec2 base_uv = UV - 0.5;
	// The glow quad is 1.35x the crack quad: rescale into crack space.
	vec2 cuv = base_uv * 1.35;
	float yn = cuv.y * 2.0;
	float cx = crack_cx(yn, seed_phase);
	vec2 lips = crack_lips(yn, seed_phase);
	float dx = cuv.x - cx;
	float lip_d = max(max(-lips.x - dx, dx - lips.y), 0.0);
	float tip = smoothstep(1.25, 1.0, abs(yn));
	float halo = exp(-lip_d * 16.0) * 0.30 * tip;
	halo *= 0.75 + 0.25 * sin(TIME * 2.3 + yn * 4.0 + seed_phase);
	ALBEDO = vec3(0.55, 0.68, 0.85) * halo;
	ALPHA = clamp(halo, 0.0, 1.0);
}

