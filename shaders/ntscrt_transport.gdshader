shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform vec2 atlas_pixel_size=vec2(0.00078125,0.001388889);
uniform sampler2D screen_texture: hint_screen_texture,filter_linear;
uniform sampler2D receiver_rows: filter_nearest,repeat_disable;
uniform vec2 buffer_size=vec2(720,480);
uniform float field_index=0.0;
uniform float wear=1.0;
uniform float dropouts=0.08;
uniform bool dropout_compensation=true;
uniform float ghost=0.04;
uniform float ghost_delay=2.0;
uniform float chroma_noise=0.12;
uniform float rf_noise=0.02;
uniform float black_level=0.0;
uniform bool caption_data=true;
uniform float stress=0.0;
uniform vec2 entity_pos=vec2(0.5);
uniform float entity_radius=0.0;
uniform float entity_amount=0.0;
uniform bool signal_enabled=true;
uniform bool reduced=false;

float hash(vec2 p) {vec3 p3=fract(vec3(p.xyx)*0.1031);p3+=dot(p3,p3.yzx+33.33);return fract((p3.x+p3.y)*p3.z);}
vec3 yiq(vec3 c){return vec3(dot(c,vec3(0.299,0.587,0.114)),dot(c,vec3(0.596,-0.274,-0.322)),dot(c,vec3(0.211,-0.523,0.312)));}
vec3 rgb(vec3 c){return vec3(c.x+0.956*c.y+0.621*c.z,c.x-0.273*c.y-0.647*c.z,c.x-1.106*c.y+1.703*c.z);}
vec3 picture(vec2 p){return textureLod(screen_texture,(clamp(p,vec2(0.5),buffer_size-vec2(0.5)))*atlas_pixel_size,0.0).rgb;}
// Reconstruct blanking/sync and decorative line-21 data only when the
// receiver slips outside active picture. Caption payload is not game text.
float blanking(float u,float source_y){
	float vbi=max(12.0,floor(buffer_size.y*20.0/242.5));
	float row=source_y+vbi;
	float raster_scale=vbi/20.0;
	float half_line=mod(u,63.556*0.5);
	bool sync=u<4.7;
	if(source_y<0.0 && row<9.0*raster_scale){
		sync=half_line<((row>=3.0*raster_scale && row<6.0*raster_scale)?27.1:2.35);
	}
	float ire=sync?-40.0:0.0;
	if(caption_data && source_y>=-1.0 && source_y<0.0 && u>=10.5){
		float t=(u-10.5)/1.986;
		if(t<7.0)ire=25.0-25.0*cos(t*TAU);
		else if(t<26.0)ire=50.0*step(0.5,hash(vec2(floor(t-7.0),floor(field_index*0.5))));
	}
	return (ire-7.5)/92.5;
}
vec2 dropout(float row) {
	float block=floor(row/3.0);
	float gate=hash(vec2(block,field_index+711.0));
	float threshold=1.0-clamp(dropouts*wear+stress*0.12,0.0,1.0)*0.035;
	return gate>threshold ? vec2(hash(vec2(block+41.0,field_index)),0.012+hash(vec2(block,field_index+73.0))*0.13) : vec2(-1.0,0.0);
}
void fragment(){
	vec2 p=UV*buffer_size;
	if(!signal_enabled){COLOR=vec4(picture(p),1);}
	else {
		float row=floor(p.y);
		vec4 timing=textureLod(receiver_rows,vec2(1.0/6.0,(row+0.5)/buffer_size.y),0.0);
		vec4 color_ref=textureLod(receiver_rows,vec2(0.5,(row+0.5)/buffer_size.y),0.0);
		vec4 levels=textureLod(receiver_rows,vec2(5.0/6.0,(row+0.5)/buffer_size.y),0.0);
		float u=9.4+UV.x*52.656+timing.x;
		float line_cross=floor(u/63.556);
		u=mod(u,63.556);
		float source_y=timing.y*buffer_size.y+line_cross;
		vec2 sample_pos=vec2((u-9.4)/52.656*buffer_size.x,source_y);
		float halo=(1.0-smoothstep(entity_radius*0.3,max(entity_radius,0.001),length((UV-entity_pos)*vec2(1.5,1))))*entity_amount*(reduced?0.0:wear);
		sample_pos.x+=(hash(vec2(row,field_index))-0.5)*halo*5.0;
		bool active=u>=9.4 && u<62.056 && source_y>=0.0 && source_y<buffer_size.y;
		vec3 c=yiq(picture(sample_pos));
		float tick=0.0;
		if(!reduced) {
			vec2 d=dropout(floor(source_y));
			float dx=sample_pos.x/buffer_size.x-d.x;
			if(d.x>=0.0 && dx>=0.0 && dx<d.y) {
				if(dropout_compensation && dx*52.656>0.7) {
					float previous=floor(source_y)-1.0;
					for(int j=0;j<6;j++) {
						vec2 prior=dropout(previous);
						float tdx=sample_pos.x/buffer_size.x-prior.x;
						if(prior.x<0.0 || tdx<0.0 || tdx>=prior.y) break;
						previous-=1.0;
					}
					c=yiq(picture(vec2(sample_pos.x,previous+0.5)));
				} else tick=0.6;
			} else if(!dropout_compensation && d.x>=0.0 && dx>=d.y && dx<d.y+0.025) tick=-0.2*(1.0-(dx-d.y)/0.025);
		}
		if(abs(ghost)>0.001 && wear>0.0) {
			vec3 echo=yiq(picture(sample_pos-vec2(ghost_delay/52.656*buffer_size.x,0.0)));
			float angle=-TAU*3.579545*ghost_delay;
			echo.yz=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*echo.yz;
			c+=(echo-c)*ghost*wear*0.35;
		}
		c.yz=mat2(vec2(color_ref.x,color_ref.y),vec2(-color_ref.y,color_ref.x))*c.yz*color_ref.z;
		float n=hash(vec2(floor(p.x),row)+vec2(field_index*31.0,field_index*7.0))-0.5;
		float n2=hash(vec2(floor(p.x*0.35),row)+vec2(field_index*17.0,13.0))-0.5;
		float sigma=timing.z+rf_noise*wear*(reduced?0.12:0.4);
		c.x=c.x*levels.y*(1.0-timing.w)+levels.x+tick+n*sigma*1.4;
		c.yz*=1.0-timing.w;
		c.yz+=vec2(n2,n)*chroma_noise*wear*(reduced?0.006:0.035)*color_ref.z;
		if(!active) c=vec3(blanking(u,source_y)+n*sigma*0.15,0,0);
		c.x+=black_level*0.55;
		COLOR=vec4(clamp(rgb(c),vec3(0.0),vec3(1.0)),1.0);
	}
}
