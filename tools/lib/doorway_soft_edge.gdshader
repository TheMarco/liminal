shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://tools/lib/doorway_magic.gdshaderinc"
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float edge_core = 0.025;
uniform float edge_width = 0.24;
uniform float blur_radius = 7.0;
uniform float edge_opacity = 0.96;

void vertex() {
	magic_local = VERTEX;
}

void fragment() {
	float distance_to_edge = abs(doorway_edge_distance(magic_local));
	float feather = 1.0-smoothstep(edge_core,edge_width,distance_to_edge);
	// Stop above the carpet: this is a soft aperture edge, never a floor strip.
	feather *= smoothstep(0.025,0.15,magic_local.y)*magic_amount;
	if (feather < 0.002) { discard; }
	// The spatial renderer supplies filtered screen mips. Sparse disc taps
	// copied every HDR spark into a visible flower; one continuous footprint
	// softens the boundary without making satellite images of the particles.
	float radius = mix(blur_radius*0.43,blur_radius,feather)*VIEWPORT_SIZE.y/900.0;
	vec3 blurred = textureLod(scene_color,SCREEN_UV,log2(max(1.0,radius))).rgb;
	ALBEDO = blurred;
	ALPHA = feather*edge_opacity;
}
