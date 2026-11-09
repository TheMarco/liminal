shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform vec2 atlas_pixel_size=vec2(0.00078125,0.001388889);
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec2 buffer_size=vec2(720.0,480.0);
uniform float field_index=0.0;
uniform int decoder=1;
uniform int tape_speed=0;
uniform int quality=1;
uniform float chroma_bleed=0.5;
uniform float chroma_delay=1.3;
uniform float saturation=0.9;
uniform float sharpness=0.25;
uniform bool signal_enabled=true;

vec4 sample_at(vec2 pixel) {
	return textureLod(screen_texture,(clamp(floor(pixel),vec2(0.0),buffer_size-vec2(1.0))+0.5)*atlas_pixel_size,0.0);
}
float composite(vec2 pixel) { return sample_at(pixel).r*2.3-0.65; }
float luma(vec2 pixel) {
	if(decoder==2 || !signal_enabled) return sample_at(pixel).r;
	if(decoder==1) return composite(pixel)*0.5+(composite(pixel-vec2(0,1))+composite(pixel+vec2(0,1)))*0.25;
	return composite(pixel)*0.5+(composite(pixel-vec2(2,0))+composite(pixel+vec2(2,0)))*0.25;
}
vec2 chroma(vec2 pixel) {
	if(decoder==2 || !signal_enabled) return (sample_at(pixel).gb-0.5)*1.3;
	float row=floor(pixel.y);
	float phase=(floor(pixel.x)+0.5)*PI*0.5+row*PI+mod(floor(field_index*0.5),2.0)*PI;
	float c=composite(pixel)-luma(pixel);
	return 2.0*c*vec2(cos(phase),sin(phase));
}
void fragment() {
	vec2 p=floor(UV*buffer_size);
	float y=luma(p);
	float softness=signal_enabled ? 0.18+float(tape_speed)*0.14 : 0.0;
	float neighbours=(luma(p-vec2(1,0))+luma(p+vec2(1,0)))*0.5;
	y=mix(y,neighbours,softness)+(y-neighbours)*sharpness*(signal_enabled?0.5:0.0);
	vec2 iq=vec2(0.0);
	float total=0.0;
	int radius=!signal_enabled ? 0 : (quality==0 ? 4 : 8);
	float spread=signal_enabled ? 1.0+chroma_bleed*1.6+float(tape_speed)*0.7 : 1.0;
	for(int tap=-8;tap<=8;tap++) {
		if(abs(tap)>radius) continue;
		float weight=exp(-float(tap*tap)/(quality==0?7.0:22.0));
		// Demodulate at consecutive carrier samples before widening the Y/C filter.
		vec2 at=p-vec2(signal_enabled?chroma_delay:0.0,0)+vec2(float(tap),0);
		vec2 c=chroma(at);
		if(decoder==2 && signal_enabled) c=chroma(p+vec2(float(tap)*spread-chroma_delay,0));
		iq+=c*weight;
		total+=weight;
	}
	iq/=max(total,0.001);
	if(signal_enabled) {
		// Additional broad colour response and vertical colour-under averaging.
		vec2 wide=((sample_at(p-vec2(4.0*spread+chroma_delay,0)).gb+sample_at(p+vec2(4.0*spread-chroma_delay,0)).gb)*0.5-0.5)*1.3;
		iq=mix(iq,wide,chroma_bleed*0.35);
		iq=mix(iq,(sample_at(p-vec2(chroma_delay,1)).gb-0.5)*1.3,float(tape_speed)*0.07);
		iq*=saturation;
	}
	vec3 rgb=vec3(y+0.956*iq.x+0.621*iq.y,y-0.273*iq.x-0.647*iq.y,y-1.106*iq.x+1.703*iq.y);
	COLOR=vec4(clamp(rgb,vec3(0.0),vec3(1.0)),1.0);
}
