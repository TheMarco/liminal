shader_type spatial;

// Preserve the authored per-vertex RGB colours: glTF cannot express an
// emission colour driven by Blender's vertex-colour node. One shared material
// provides a gentle attract-light chase with a different phase per cabinet.
varying float phase;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	phase = dot(origin.xz, vec2(1.37, 2.71)) + VERTEX.y * 3.1 + VERTEX.x * 2.5;
}

void fragment() {
	float attract = 0.88 + 0.12 * sin(TIME * 2.2 + phase);
	ALBEDO = COLOR.rgb * 0.4;
	EMISSION = COLOR.rgb * (2.7 * attract);
	ROUGHNESS = 0.25;
	METALLIC = 0.0;
}
