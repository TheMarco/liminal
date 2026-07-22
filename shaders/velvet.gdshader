shader_type spatial;

// Fabric with velvet rim sheen: grazing angles brighten toward a lighter
// tint, the way pile fabric catches light. Parameterized so one shader
// covers maroon sofas, rust chairs and charcoal office seating.

uniform vec3 albedo : source_color = vec3(0.32, 0.06, 0.11);
uniform vec3 sheen_col : source_color = vec3(0.85, 0.5, 0.45);
uniform float sheen_amount = 0.4;

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);
	ALBEDO = albedo + sheen_col * fres * sheen_amount;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
