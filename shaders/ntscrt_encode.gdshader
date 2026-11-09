shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Downsample the finished scene + HUD, then modulate Y'IQ onto a carrier.
// RGB only: opaque window backbuffers do not preserve a payload in alpha.
// R = biased composite (or Y' for separated video), G/B = scaled, biased I/Q.
// The scale also fits saturated primaries in non-HDR, 8-bit backbuffers.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 buffer_size = vec2(720.0,480.0);
uniform float field_index = 0.0;
uniform bool linear_input = true;
uniform bool interlaced = true;
uniform bool signal_enabled = true;
uniform int decoder=1;
uniform float auto_exposure = 0.35;
uniform float brightness = 1.0;
varying flat float exposure;

vec3 encoded(vec3 c) {
	return linear_input ? pow(max(c,vec3(0.0)),vec3(1.0/2.2)) : max(c,vec3(0.0));
}
void vertex() {
	float average = 0.0;
	for(int y=0;y<3;y++) for(int x=0;x<3;x++) {
		vec3 c=encoded(textureLod(screen_texture,vec2(0.2+float(x)*0.3,0.2+float(y)*0.3),0.0).rgb);
		average += dot(c,vec3(0.299,0.587,0.114));
	}
	exposure = signal_enabled ? mix(1.0,clamp(0.38/max(average/9.0,0.02),0.72,1.35),auto_exposure) : 1.0;
}
void fragment() {
	vec2 pos=UV;
	float row=floor(UV.y*buffer_size.y);
	if(interlaced && signal_enabled) {
		float parity=mod(field_index,2.0);
		pos.y=(floor(row*0.5)*2.0+parity+0.5)/buffer_size.y;
	}
	vec3 rgb=encoded(textureLod(screen_texture,clamp(pos,SCREEN_PIXEL_SIZE*0.5,vec2(1.0)-SCREEN_PIXEL_SIZE*0.5),0.0).rgb);
	rgb=clamp(rgb*exposure*brightness,vec3(0.0),vec3(1.0));
	float y=dot(rgb,vec3(0.299,0.587,0.114));
	float i=dot(rgb,vec3(0.596,-0.274,-0.322));
	float q=dot(rgb,vec3(0.211,-0.523,0.312));
	float phase=(floor(UV.x*buffer_size.x)+0.5)*PI*0.5+row*PI+mod(floor(field_index*0.5),2.0)*PI;
	float composite=y+i*cos(phase)+q*sin(phase);
	COLOR=vec4(decoder==2 || !signal_enabled ? y : (composite+0.65)/2.3,i/1.3+0.5,q/1.3+0.5,1.0);
}
