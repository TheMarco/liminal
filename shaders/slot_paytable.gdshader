shader_type spatial;
render_mode unshaded;

// Backlit pay-table glass: purple-to-blue gradient with a radial glow, an
// arched gold title band, rows of gold/white dashed "text" with a symbol
// column, and a gold border. Content varies per machine via world position.

varying vec3 wpos;
varying vec2 suv;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	suv = UV;
}

float hashf(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float mh = hashf(floor(wpos.xz * 2.0));
	vec2 uvq = vec2(suv.x, 1.0 - suv.y);
	vec3 c = mix(vec3(0.16, 0.03, 0.32), vec3(0.02, 0.08, 0.40), uvq.y);
	c += vec3(0.25, 0.10, 0.30) * max(0.0, 1.0 - length(uvq - vec2(0.5, 0.65)) * 1.3);
	float em = 0.9;

	// title band
	if (uvq.y > 0.78 && uvq.y < 0.95) {
		float bandpos = abs(uvq.y - 0.865) / 0.085;
		float txt = step(0.5, hashf(vec2(floor(uvq.x * 26.0), 3.0 + floor(mh * 17.0))))
			* step(bandpos, 0.6) * step(0.12, uvq.x) * step(uvq.x, 0.88);
		c = mix(c, vec3(1.0, 0.80, 0.20), txt);
		em = mix(em, 1.5, txt);
	}

	// pay rows
	float row = floor(uvq.y * 14.0);
	if (row >= 2.0 && row <= 9.0) {
		float inrow = fract(uvq.y * 14.0);
		float cellx = floor(uvq.x * 22.0);
		float on = step(0.45, hashf(vec2(cellx, row * 3.1 + floor(mh * 29.0))));
		float dash = on * step(0.3, inrow) * step(inrow, 0.7) * step(3.0, cellx) * step(cellx, 19.0);
		vec3 tcol = (mod(row, 3.0) < 1.0) ? vec3(0.95, 0.85, 0.40) : vec3(0.85, 0.90, 1.0);
		c = mix(c, tcol, dash * 0.9);
		// symbol column on the left
		vec2 sp = vec2(fract(uvq.x * 10.0), inrow);
		float blob = step(length(sp - 0.5), 0.3) * step(uvq.x, 0.1);
		c = mix(c, vec3(0.90, 0.12, 0.12), blob);
	}

	// border + shimmer
	float b = 1.0 - smoothstep(0.01, 0.04, min(min(suv.x, 1.0 - suv.x), min(suv.y, 1.0 - suv.y)));
	c = mix(c, vec3(1.0, 0.85, 0.40), b);
	em *= 0.92 + 0.08 * sin(TIME * 1.3 + mh * 9.0);
	ALBEDO = c * em;
}
