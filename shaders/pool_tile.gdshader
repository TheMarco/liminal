shader_type spatial;
// The tile the whole floor is built from — a real photographed white mosaic
// (models/cc_by/white_tiles, CC BY) mapped in world space, so a wall and the
// floor it meets share one continuous grid and no seam appears at the join.
//
// This also owns the caustics, because they belong to the surfaces under the
// water rather than to the water itself. Everything below `water_y` picks up
// the dancing light and a wet darkening; everything above it stays dry chalky
// tile. One material therefore dresses the basin, the piers and the deck
// without anything having to know which side of the waterline it sits on.
// Opaque on purpose: blend_mix put this in the transparent pass, where the
// walls sorted against each other and you could see straight through them.
render_mode cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic,
	repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic,
	repeat_enable;
uniform sampler2D orm_tex : filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec3 tile_tint : source_color = vec3(1.0, 1.0, 0.98);
/// Metres covered by one repeat of the sheet. The sheet is a 10x10 grid, so
/// this divided by ten is the size of a single tile.
uniform float tex_metres = 1.15;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.7;
uniform float roughness_floor : hint_range(0.0, 1.0)  = 0.27;

// Everything under this world height is submerged.
uniform float water_y = 1.05;
uniform vec3 wet_tint : source_color = vec3(0.34, 0.50, 0.44);
uniform float wet_strength : hint_range(0.0, 1.0)  = 0.2075;

uniform float caustic_scale = 0.7666;
uniform float caustic_speed = 0.3488;
uniform float caustic_strength : hint_range(0.0, 3.0)  = 0.765;
uniform vec3 caustic_colour : source_color = vec3(0.72, 0.92, 0.85);

varying vec3 world_pos;
varying vec3 world_normal;


// Cheap dancing caustics: the UV is pushed around by a few sine terms and then
// a sharpened interference pattern is read out of it. Not a simulation — it
// only has to look like sunlight moving on a pool floor.
float caustics(vec2 uv, float t) {
	vec2 p = uv;
	for (int n = 1; n <= 3; n++) {
		float fn = float(n);
		p += vec2(sin(uv.y * fn * 2.3 + t * 0.6),
			cos(uv.x * fn * 1.9 - t * 0.5)) * (0.30 / fn);
	}
	float v = sin(p.x * 4.0) * sin(p.y * 4.0);
	return pow(clamp(v * 0.5 + 0.5, 0.0, 1.0), 6.0);
}


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


void fragment() {
	// World triplanar by dominant axis. The grid is architectural, so it must
	// not swim when a box is scaled or rotated.
	vec3 an = abs(world_normal);
	vec2 uv;
	if (an.y > an.x && an.y > an.z) {
		uv = world_pos.xz;
	} else if (an.x > an.z) {
		uv = world_pos.zy;
	} else {
		uv = world_pos.xy;
	}
	uv /= max(tex_metres, 0.01);

	vec3 col = texture(albedo_tex, uv).rgb * tile_tint;
	vec3 orm = texture(orm_tex, uv).rgb;

	float submerged = 1.0 - smoothstep(water_y - 0.06, water_y + 0.06,
		world_pos.y);
	col = mix(col, col * wet_tint * 1.9, submerged * wet_strength);

	float c = caustics(world_pos.xz * caustic_scale, TIME * caustic_speed);
	// Fade the pattern with depth, the way real caustics spread and weaken the
	// further they travel from the surface.
	float falloff = clamp(1.0 - (water_y - world_pos.y) * 0.22, 0.25, 1.0);
	vec3 caustic_add = caustic_colour * c * caustic_strength * submerged
		* falloff;

	ALBEDO = col + caustic_add * 0.30;
	// No emission: adding it on top of albedo is what produced the blown-out
	// white patches, because a caustic peak was being counted twice.
	EMISSION = vec3(0.0);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	// glTF packs roughness in green. Wet tile is far glossier than dry.
	// Wet tile is glossier than dry, but mirror-smooth turned every lamp into
	// a searing point highlight.
	ROUGHNESS = mix(max(orm.g, roughness_floor), 0.30, submerged);
	SPECULAR = mix(0.45, 0.60, submerged);
	METALLIC = 0.0;
}
