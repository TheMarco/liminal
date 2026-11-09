shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform vec2 atlas_pixel_size=vec2(0.00078125,0.001388889);
uniform sampler2D screen_texture:hint_screen_texture,filter_linear;
uniform vec2 buffer_size=vec2(720,480);
uniform vec2 bloom_origin=vec2(180,480);
uniform vec2 bloom_size=vec2(180,120);
uniform bool crt_enabled=true;
uniform bool curvature_enabled=false;
uniform bool linear_output=true;
uniform bool interlaced=true;
uniform bool reduced=false;
uniform int quality=1;
uniform int mask_type=1;
uniform float mask_strength=0.35;
uniform float scanline_strength=0.55;
uniform float bloom=0.18;
uniform float diffusion=0.08;
uniform float convergence=0.2;
uniform float vignette=0.18;
uniform float field_index=0.0;

vec3 signal(vec2 p){return textureLod(screen_texture,clamp(p,vec2(0.5),buffer_size-vec2(0.5))*atlas_pixel_size,0.0).rgb;}
vec3 beam_sample(vec2 p){return pow(max(signal(p),vec3(0)),vec3(2.4));}
vec3 converged(vec2 p,vec2 uv){
	float c=convergence*(0.35+dot(uv-0.5,uv-0.5)*2.0);
	if(quality==0 || c<0.001)return beam_sample(p);
	return vec3(beam_sample(p-vec2(c,0)).r,beam_sample(p).g,beam_sample(p+vec2(c,0)).b);
}
void fragment(){
	vec2 uv=UV;
	if(crt_enabled && curvature_enabled){vec2 p=(uv-0.5)*2.0; p*=1.0+p.yx*p.yx*vec2(0.055,0.08);uv=p*0.5+0.5;}
	vec2 p=uv*buffer_size;
	vec3 output_color=signal(p);
	if(crt_enabled){
		float row=floor(p.y-0.5);
		float footprint=max(fwidth(p.y),0.001);
		vec3 beam=vec3(0);
		for(int j=-1;j<=1;j++){
			float scan=row+float(j)+0.5;
			vec3 c=converged(vec2(p.x,scan),uv);
			vec3 sigma=mix(vec3(0.20),vec3(0.43),pow(clamp(c,vec3(0),vec3(1)),vec3(0.33)));
			sigma=sqrt(sigma*sigma+footprint*footprint/12.0);
			float d=p.y-scan;
			beam+=c*exp(-0.5*d*d/(sigma*sigma))/(2.506628*sigma);
		}
		beam=mix(beam_sample(p),beam,scanline_strength);
		vec2 screen=UV/atlas_pixel_size;
		float pitch=3.0*max(1.0,1.0/atlas_pixel_size.y/1080.0);
		vec2 mask_pos=screen/pitch;
		float width=max(fwidth(mask_pos.x),0.001);
		float aa=max(sin(PI*width)/(PI*width),0.0);
		float phase=mask_pos.x*TAU;
		if(mask_type==2)phase+=mod(floor(mask_pos.y),2.0)*PI;
		vec3 mask=vec3(1.0)+0.85*aa*cos(vec3(phase,phase-TAU/3.0,phase+TAU/3.0));
		if(mask_type>0){float seam=pow(0.5+0.5*cos((mask_pos.y*0.5+floor(mask_pos.x)*0.5)*TAU),10.0);mask*=1.0-0.20*seam*(1.0-smoothstep(0.3,0.65,fwidth(mask_pos.y*0.5)));}
		mask=mix(vec3(1.0),mask,mask_strength*smoothstep(400.0,900.0,1.0/atlas_pixel_size.y));
		vec3 glow=textureLod(screen_texture,(bloom_origin+clamp(uv*bloom_size,vec2(0.5),bloom_size-vec2(0.5)))*atlas_pixel_size,0.0).rgb;
		beam=mix(beam*mask,glow,diffusion*0.4);
		beam+=glow*bloom*0.25;
		if(interlaced && !reduced)beam*=1.0+cos(p.y*PI+mod(field_index,2.0)*PI)*0.015*(1.0-smoothstep(0.8,1.5,footprint));
		beam*=1.0-vignette*dot((uv-0.5)*2.0,(uv-0.5)*2.0)*0.5;
		vec3 over=max(beam-vec3(0.75),vec3(0));
		beam=min(beam,vec3(0.75))+0.25*(1.0-exp(-over/0.25));
		output_color=pow(max(beam,vec3(0)),vec3(1.0/2.2));
		float edge=min(min(uv.x,1.0-uv.x),min(uv.y,1.0-uv.y));
		output_color*=smoothstep(0.0,0.009,edge);
	}
	if(linear_output)output_color=pow(max(output_color,vec3(0)),vec3(2.2));
	COLOR=vec4(clamp(output_color,vec3(0),vec3(1)),1.0);
}
