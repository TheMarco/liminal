shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
varying float brightness;

void vertex() {
	// Camera-facing glints, not flat decals on the wall.
	VERTEX.xy *= INSTANCE_CUSTOM.xy;
	brightness = INSTANCE_CUSTOM.z;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV*2.0-1.0;
	float core = exp(-dot(p,p)*16.0);
	float vertical = exp(-abs(p.x)*35.0-abs(p.y)*4.0);
	float horizontal = exp(-abs(p.y)*38.0-abs(p.x)*7.0);
	// Values above one feed the existing HDR bloom, not a white sprite texture.
	ALBEDO = COLOR.rgb*brightness;
	ALPHA = COLOR.a*(core+vertical*0.18+horizontal*0.08);
}
