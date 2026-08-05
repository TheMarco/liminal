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
uniform sampler2D grout_mineral_atlas : source_color,
	filter_linear_mipmap_anisotropic,
	repeat_disable;
uniform sampler2D waterline_mineral_atlas : source_color,
	filter_linear_mipmap_anisotropic,
	repeat_disable;

uniform vec3 tile_tint : source_color = vec3(1.0, 1.0, 0.98);
/// Metres covered by one repeat of the sheet. The sheet is a 10x10 grid, so
/// this divided by ten is the size of a single tile.
uniform float tex_metres = 1.15;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.7;
uniform float roughness_floor : hint_range(0.0, 1.0)  = 0.27;

// Authored mineral masks are packed 4x2. Placement is procedural, but every
// placement is derived from the same world-space tile grid as the material:
// crosses can only occur at grout intersections and waterlines can only run
// horizontally through vertical tile faces.
uniform float grout_mineral_density : hint_range(0.0, 1.0) = 0.46;
uniform float waterline_mineral_density : hint_range(0.0, 1.0) = 0.68;
uniform float mineral_strength : hint_range(0.0, 1.0) = 0.68;

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


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


vec4 atlas_mineral(sampler2D atlas, vec2 local_uv, float variant) {
	if (local_uv.x <= 0.0 || local_uv.x >= 1.0 ||
			local_uv.y <= 0.0 || local_uv.y >= 1.0) {
		return vec4(0.0);
	}
	vec2 cell = vec2(mod(variant, 4.0), floor(variant * 0.25));
	// Stay inside the cell even on low mips. The authored masks already reach
	// zero before this inset, so the adjustment cannot expose an atlas seam.
	vec2 safe_uv = mix(vec2(0.003), vec2(0.997), local_uv);
	return texture(atlas, (cell + safe_uv) / vec2(4.0, 2.0));
}


vec4 grout_mineral(vec2 tile_coord, float axis_seed) {
	// One candidate at the exact centre intersection of each 6x6-tile block.
	// The authored scans are re-cropped so their grout cross sits exactly at
	// the cell centre; 1.5 tiles of footprint keeps the deposit hugging its
	// crossing instead of blanketing the four tiles around it.
	vec2 block = floor((tile_coord + vec2(3.0)) / 6.0);
	vec2 centre = block * 6.0;
	vec2 local_uv = (tile_coord - centre) / 1.5 + vec2(0.5);
	float placement = step(hash21(block + vec2(axis_seed, axis_seed * 0.37)),
		grout_mineral_density);
	float variant = floor(hash21(block + vec2(91.7 + axis_seed, 38.2)) * 8.0);
	vec4 mineral = atlas_mineral(grout_mineral_atlas, local_uv, variant);
	mineral.a *= placement;
	return mineral;
}


vec4 waterline_mineral(vec2 surface_metres, float wall_lane,
		float axis_seed, float vertical_face) {
	// One atlas cell maps onto SEGMENT_LENGTH x BAND_HEIGHT of wall. The cells
	// are packed 2:1, so the pair must stay in that ratio or the authored
	// crust stretches.
	const float SEGMENT_LENGTH = 2.20;
	const float BAND_HEIGHT = 1.10;
	float segment = floor(surface_metres.x / SEGMENT_LENGTH);
	float lane = floor(wall_lane / 2.0);
	vec2 id = vec2(segment + axis_seed, lane);
	float placement = step(hash21(id + vec2(17.3, 83.1)),
		waterline_mineral_density);
	float variant = floor(hash21(id + vec2(61.9, 12.7)) * 8.0);
	vec2 local_uv = vec2(fract(surface_metres.x / SEGMENT_LENGTH),
		(surface_metres.y - water_y) / BAND_HEIGHT + 0.5);
	vec4 mineral = atlas_mineral(waterline_mineral_atlas, local_uv, variant);
	mineral.a *= placement * vertical_face;
	return mineral;
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
	float axis_seed;
	float wall_lane;
	if (an.y > an.x && an.y > an.z) {
		uv = world_pos.xz;
		axis_seed = 0.0;
		wall_lane = world_pos.y;
	} else if (an.x > an.z) {
		uv = world_pos.zy;
		axis_seed = 137.0;
		wall_lane = world_pos.x;
	} else {
		uv = world_pos.xy;
		axis_seed = 271.0;
		wall_lane = world_pos.z;
	}
	vec2 surface_metres = uv;
	uv /= max(tex_metres, 0.01);

	vec3 col = texture(albedo_tex, uv).rgb * tile_tint;
	vec3 orm = texture(orm_tex, uv).rgb;

	float submerged = 1.0 - smoothstep(water_y - 0.06, water_y + 0.06,
		world_pos.y);
	col = mix(col, col * wet_tint * 1.9, submerged * wet_strength);

	vec2 tile_coord = uv * 10.0;
	float vertical_face = 1.0 - smoothstep(0.50, 0.82, an.y);
	vec4 grout_layer = grout_mineral(tile_coord, axis_seed);
	vec4 waterline_layer = waterline_mineral(surface_metres, wall_lane,
		axis_seed, vertical_face);
	// Reject the low-alpha photographed tile texture. Only the stronger,
	// irregular extracted deposit survives into the game material.
	float grout_crust = smoothstep(0.14, 0.50, grout_layer.a);
	float waterline_crust = smoothstep(0.18, 0.55, waterline_layer.a);
	float grout_alpha = grout_crust * mineral_strength * 1.05;
	// The crust colour sits close to the tile's own brightness, so it needs a
	// near-full blend where it is dense — at half strength it disappears
	// tone-on-tone instead of reading as buildup.
	float waterline_alpha = waterline_crust * mineral_strength * 0.92;
	float mineral = max(grout_alpha, waterline_alpha);
	// RGB now carries the normalized colour and high-frequency detail from each
	// authored source. Alpha alone controls placement, so photographed tile never
	// covers the continuous game tile underneath.
	col = mix(col, grout_layer.rgb, grout_alpha);
	col = mix(col, waterline_layer.rgb, waterline_alpha);

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
	// Crust is matte next to glazed tile, but fully killing its specular in
	// this fog-lit space turned every deposit into a dark stain: most of the
	// tile's apparent brightness here IS its reflection.
	ROUGHNESS = mix(mix(max(orm.g, roughness_floor), 0.30, submerged),
		0.80, mineral);
	SPECULAR = mix(mix(0.45, 0.60, submerged), 0.40, mineral);
	METALLIC = 0.0;
}
