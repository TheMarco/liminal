shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform vec2 atlas_pixel_size=vec2(0.00078125,0.001388889);
uniform sampler2D screen_texture:hint_screen_texture,filter_linear;
uniform vec2 source_origin=vec2(0);
uniform vec2 source_size=vec2(720,480);
uniform vec2 direction=vec2(1,0);
uniform bool first_pass=true;
vec3 sample_at(vec2 p){return textureLod(screen_texture,(source_origin+clamp(p,vec2(0.5),source_size-vec2(0.5)))*atlas_pixel_size,0.0).rgb;}
void fragment(){
	vec2 p=UV*source_size;
	vec3 c=vec3(0.0);
	for(int i=-4;i<=4;i++){
		vec3 s=sample_at(p+direction*float(i)*2.0);
		if(first_pass) s=pow(max(s,vec3(0)),vec3(2.4));
		c+=s*exp(-float(i*i)/8.0);
	}
	COLOR=vec4(c/4.89803,1);
}
