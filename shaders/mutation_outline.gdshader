shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;

uniform vec4 outline_color : source_color = vec4(0.58, 1.0, 1.0, 1.0);
uniform float strength : hint_range(0.0, 10.0) = 6.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.8;
uniform float grow : hint_range(0.0, 0.12) = 0.045;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb * strength;
	ALPHA = opacity;
}
