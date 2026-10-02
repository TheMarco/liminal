shader_type spatial;
// Metre-scaled glazed ceramic. Analytic joints are pixel filtered; fine surface
// variation comes from a mipmapped texture so distant tiles do not sparkle.
uniform vec3 tile_color : source_color = vec3(0.12, 0.31, 0.28);
uniform vec2 tile_size = vec2(0.30, 0.15);
uniform sampler2D detail_tex : repeat_enable, filter_linear_mipmap;
uniform float glaze = 0.29;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = abs(normalize(world_normal));
	vec2 p = n.y > 0.7 ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	vec2 uv = p / tile_size;
	vec2 cell = floor(uv);
	vec2 edge = min(fract(uv), 1.0 - fract(uv)) * tile_size;
	float dist = min(edge.x, edge.y);
	float aa = max(fwidth(dist), 0.0004);
	float face = smoothstep(0.0015 - aa, 0.0035 + aa, dist);
	float variation = fract(sin(dot(cell, vec2(27.13, 91.71))) * 43758.5453);
	float grain = texture(detail_tex, p * 0.7).r;
	vec3 ceramic = tile_color * (0.91 + variation * 0.16 + grain * 0.08);
	ALBEDO = mix(vec3(0.20, 0.22, 0.20), ceramic, face);
	ROUGHNESS = mix(0.88, glaze + grain * 0.12, face);
	SPECULAR = 0.48;
}
