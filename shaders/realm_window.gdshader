shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D realm_view : source_color, filter_linear;
void fragment() {
	ALBEDO = texture(realm_view, SCREEN_UV).rgb;
}
