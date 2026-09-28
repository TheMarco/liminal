shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D stripe_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 light_color : source_color = vec4(0.72, 0.87, 0.80, 1.0);
uniform vec4 dark_color : source_color = vec4(0.08, 0.30, 0.25, 1.0);

void fragment() {
	// The supplied vinyl map has pale mint and deep green panels. Use its
	// authored boundaries while replacing both colors as a coordinated pair.
	float mint = texture(stripe_tex, UV).g;
	float light_panel = smoothstep(0.10, 0.30, mint);
	ALBEDO = mix(dark_color.rgb, light_color.rgb, light_panel);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.1;
	vec3 orm = texture(orm_tex, UV).rgb;
	AO = orm.r;
	ROUGHNESS = orm.g;
	METALLIC = 0.0;
}
