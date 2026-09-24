shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform bool membrane = false;
uniform float strength = 0.0;
uniform float clock = 0.0;
varying vec3 local_point;
varying float mist_seed;

float hash_mist(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

float noise_mist(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash_mist(i),hash_mist(i+vec2(1,0)),f.x),
		mix(hash_mist(i+vec2(0,1)),hash_mist(i+vec2(1,1)),f.x),f.y);
}

float cloud(vec2 p) {
	return noise_mist(p)*0.57+noise_mist(p*2.03+vec2(9.1))*0.28
		+noise_mist(p*4.07-vec2(3.7))*0.15;
}

void vertex() {
	local_point = VERTEX;
	mist_seed = INSTANCE_CUSTOM.z;
	if (!membrane) {
		VERTEX.xy *= INSTANCE_CUSTOM.xy;
		MODELVIEW_MATRIX = VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 p = membrane ? local_point.xy*1.8 : UV*3.5+vec2(mist_seed*17.0);
	vec2 drift = vec2(clock*0.14,-clock*0.20);
	vec2 curl = vec2(cloud(p+drift),cloud(p+vec2(7.4,2.8)-drift));
	float body = cloud(p*1.5+curl*3.5+drift);
	float filaments = pow(1.0-abs(cloud(p*2.2+curl*5.0-drift)*2.0-1.0),7.0);
	float density = smoothstep(0.30,0.78,body);
	float falloff = membrane ? 1.0 : pow(max(0.0,1.0-length(UV*2.0-1.0)),1.7);
	float depth = texture(scene_depth,SCREEN_UV).r;
	vec4 scene = INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,depth,1.0);
	float behind = -scene.z/max(abs(scene.w),0.000001);
	float soft_contact = clamp((behind+VERTEX.z)/0.25,0.0,1.0);
	ALBEDO = mix(vec3(0.17,0.18,0.165),vec3(0.55,0.58,0.54),density);
	EMISSION = vec3(0.14,0.15,0.13)*filaments*0.45;
	// Enrich edge billows, not the central veil: the destination stays legible.
	float opacity = membrane ? (0.035+density*0.22+filaments*0.06) : density*0.60;
	ALPHA = opacity*falloff*strength*soft_contact*(membrane ? 1.0 : COLOR.a);
}
