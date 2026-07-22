shader_type spatial;

// Moving-walkway pallet surface: ribbed dark metal sliding along local x.
// The belt mesh is a scaled unit box, so local coords are de-normalized by
// the model matrix column lengths. `speed` (m/s, signed) is per-instance so
// paired walkways can run opposite ways from one shared material.

instance uniform float speed = 0.75;

uniform vec3 base_col : source_color = vec3(0.16, 0.16, 0.17);
uniform vec3 groove_col : source_color = vec3(0.05, 0.05, 0.06);

varying vec3 lpos;
varying vec3 wpos;

void vertex() {
	lpos = VERTEX * vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz));
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float x = lpos.x - TIME * speed;
	// fine longitudinal grooves (safety tread running with travel)
	float g = abs(fract(lpos.z / 0.035) - 0.5) * 2.0;
	vec3 c = mix(groove_col, base_col, smoothstep(0.25, 0.55, g));
	// pallet joints crossing the belt every 40cm, moving with it
	float j = abs(fract(x / 0.4) - 0.5) * 0.4;
	c = mix(vec3(0.03), c, smoothstep(0.004, 0.014, j));
	// worn sheen down the middle where feet actually stand
	float wear = exp(-abs(lpos.z) * 3.2);
	c *= 0.9 + 0.25 * wear;
	// speckled grime
	c *= 0.88 + 0.2 * hashf(floor(vec2(x, lpos.z) * 90.0));

	ALBEDO = c;
	ROUGHNESS = 0.45 - wear * 0.18;
	METALLIC = 0.6;
	SPECULAR = 0.4;
}
