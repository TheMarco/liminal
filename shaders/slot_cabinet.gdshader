shader_type spatial;

// Powder-coated casino cabinet metal. The old machines used uniformly glossy
// car paint, which made every bank read like an arcade prop. This finish keeps
// the chassis dark under normal light, with shallow scuffs, grime around the
// lower service door and fine vertical cleaning marks that only catch at
// grazing angles.

uniform vec3 base_color : source_color = vec3(0.055, 0.06, 0.065);
uniform float metalness : hint_range(0.0, 1.0) = 0.38;
uniform float base_roughness : hint_range(0.05, 1.0) = 0.43;
uniform float wear : hint_range(0.0, 1.0) = 0.28;

varying vec3 local_pos;
varying vec3 world_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fine = value_noise(world_pos * vec3(34.0, 9.0, 34.0));
	float broad = value_noise(world_pos * vec3(2.6, 1.4, 2.6));
	float vertical_wipe = pow(0.5 + 0.5 * sin(
		world_pos.x * 91.0 + world_pos.z * 73.0 + fine * 3.0), 12.0);
	float low_grime = exp(-max(local_pos.y, 0.0) * 2.6) * broad;
	float nick = smoothstep(0.945, 0.995, fine) * wear;

	vec3 c = base_color;
	c *= 0.88 + broad * 0.17;
	c = mix(c, c * vec3(0.46, 0.42, 0.37), low_grime * wear * 0.42);
	c = mix(c, vec3(0.23, 0.22, 0.20), nick * 0.32);

	ALBEDO = c;
	METALLIC = clamp(metalness + nick * 0.25, 0.0, 1.0);
	ROUGHNESS = clamp(base_roughness
		+ low_grime * 0.22
		+ vertical_wipe * wear * 0.08
		- nick * 0.16, 0.08, 0.95);
	SPECULAR = 0.52;
}
