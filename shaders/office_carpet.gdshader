shader_type spatial;

// Corporate heather carpet in institutional teal-green: dense fine-grain
// fiber with subtle 0.5m carpet-tile seams. World-space mapped.

uniform vec3 col_base : source_color = vec3(0.10, 0.22, 0.16);
uniform vec3 col_dark : source_color = vec3(0.06, 0.14, 0.10);
uniform vec3 col_light : source_color = vec3(0.16, 0.30, 0.22);
uniform float bump_strength = 0.3;
uniform sampler2D detail_tex : filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hashf(i), hashf(i + vec2(1.0, 0.0)), u.x),
		mix(hashf(i + vec2(0.0, 1.0)), hashf(i + vec2(1.0, 1.0)), u.x), u.y);
}

float surf_h(vec2 p) {
	return texture(detail_tex, p / 0.9).r * 0.6 + vnoise(p * 11.0) * 0.4;
}

void fragment() {
	vec2 p = wpos.xz;
	float fine = texture(detail_tex, p / 0.9).r;
	float mid = vnoise(p * 7.0);
	vec3 c = mix(col_base, col_light, fine * 0.55);
	c = mix(c, col_dark, smoothstep(0.55, 0.9, mid) * 0.45);
	// carpet tile seams
	vec2 g = fract(p / 0.5);
	float seam = min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y));
	c *= mix(0.9, 1.0, smoothstep(0.0, 0.04, seam));

	vec3 gn = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	vec3 axis = abs(gn.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 t1 = normalize(cross(axis, gn));
	vec3 t2 = cross(gn, t1);
	float e = 0.02;
	float h0 = surf_h(wpos.xz);
	float d1 = (surf_h(wpos.xz + t1.xz * e) - h0) / e;
	float d2 = (surf_h(wpos.xz + t2.xz * e) - h0) / e;
	vec3 wn = normalize(gn - (t1 * d1 + t2 * d2) * bump_strength);
	NORMAL = normalize(mat3(VIEW_MATRIX) * wn);

	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
