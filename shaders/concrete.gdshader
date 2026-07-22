shader_type spatial;

// Cast-in-place sewer concrete: cold gray-green, broad damp blotches,
// horizontal formwork seams, a dark tide line near the waterline and
// glossier patches where the surface stays wet.

uniform vec3 base_col : source_color = vec3(0.44, 0.46, 0.42);
uniform sampler2D detail_tex : hint_default_white;
uniform float seam_every = 0.72;
uniform float wet_line = 0.9;    // damp band height on walls, metres
uniform float wetness = 0.5;     // how much of the surface stays damp/glossy

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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

void fragment() {
	float horiz = step(0.5, abs(wnorm.y));
	vec2 p = mix(vec2(wpos.x + wpos.z, wpos.y), wpos.xz, horiz);

	vec3 c = base_col;
	// broad tonal blotches at two scales
	c *= 0.88 + 0.20 * vnoise(p * 0.33);
	c *= 0.94 + 0.10 * vnoise(p * 1.7 + 13.0);
	// fine aggregate speckle, mipmapped so it calms at distance
	c *= 0.92 + 0.16 * texture(detail_tex, p * 0.45).r;

	// horizontal formwork seams on vertical surfaces
	float seam = abs(fract(wpos.y / seam_every) - 0.5) * seam_every;
	c *= mix(mix(0.82, 1.0, smoothstep(0.0, 0.03, seam)), 1.0, horiz);

	// damp: dark tide band low on walls, plus patchy standing damp everywhere
	float damp = (1.0 - horiz) * (1.0 - smoothstep(0.15, wet_line, wpos.y));
	damp = max(damp, wetness * smoothstep(0.45, 0.75, vnoise(p * 0.8 + 51.0)));
	// drip streaks running down the walls
	float streak = (1.0 - horiz) * smoothstep(0.75, 0.95, vnoise(vec2(p.x * 3.1, p.y * 0.12)));
	damp = clamp(damp + streak * 0.7, 0.0, 1.0);
	c *= 1.0 - 0.45 * damp;
	c = mix(c, c * vec3(0.82, 1.0, 0.85), damp * 0.5);  // green slime tint

	ALBEDO = c;
	ROUGHNESS = mix(0.82, 0.22, damp);
	SPECULAR = 0.4;
}
