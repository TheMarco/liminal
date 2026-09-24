// Temporary, local surface treatment. No screen-wide overlay or transparency
// on the wall: fully solid fragments retain depth, shadows and native shading.
uniform float magic_amount = 0.0;
uniform float magic_clock = 0.0;
uniform vec2 magic_half = vec2(1.0);
uniform float magic_phase = 0.0;
uniform float magic_center_y = 1.125;
varying vec3 magic_local;

float magic_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453);
}

float magic_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(magic_hash(i),magic_hash(i+vec2(1,0)),f.x),
		mix(magic_hash(i+vec2(0,1)),magic_hash(i+vec2(1,1)),f.x),f.y);
}

float doorway_edge_distance(vec3 p) {
	vec2 q = p.xy-vec2(0.0,magic_center_y);
	float angle = atan(q.y,q.x);
	vec2 ray = vec2(cos(angle),sin(angle));
	vec2 extent = max(magic_half,vec2(0.00001));
	float ellipse = inversesqrt(dot(ray/extent,ray/extent));
	float rectangle = min(extent.x/max(abs(ray.x),0.000001),extent.y/max(abs(ray.y),0.000001));
	float lobes = 0.13*sin(angle*3.0+magic_phase*1.3)
		+0.065*sin(angle*5.0-magic_phase*1.7)+0.035*cos(angle*7.0+0.8);
	float chips = (abs(sin(angle*13.0+0.8*sin(angle*3.0)))-0.5)*0.14;
	float fissures = pow(max(0.0,sin(angle*17.0+1.7*sin(angle*5.0))),6.0)*0.16;
	float fractured = ellipse*(1.0+lobes)+(chips+fissures)*smoothstep(0.0,0.28,magic_phase);
	float radius = mix(max(0.00001,fractured),rectangle,smoothstep(0.70,1.0,magic_phase));
	// Match the mesh's below-floor contour, not a glowing horizontal threshold.
	float below_floor = min(extent.x/max(abs(ray.x),0.000001),
		(magic_center_y+0.18)/max(-ray.y,0.000001));
	float floor_release = smoothstep(0.40,0.68,magic_phase)*smoothstep(0.0,0.55,-ray.y);
	radius = mix(radius,below_floor,floor_release);
	return length(q)-radius;
}

vec4 doorway_magic(vec3 p) {
	vec2 q = p.xy-vec2(0.0,magic_center_y);
	float angle = atan(q.y,q.x);
	float d = max(0.0,doorway_edge_distance(p));
	float flow = magic_noise(q*4.0+vec2(magic_clock*0.42,-magic_clock*0.8));
	// Native material right at the cut. Only the surrounding pale web emits.
	float outside_rim = smoothstep(0.12,0.30,d);
	float ripple = pow(0.5+0.5*sin(d*38.0-magic_clock*3.4+flow*2.2),10.0)
		*exp(-d*2.7)*smoothstep(0.04,0.12,d);
	float threads = pow(0.5+0.5*sin(angle*23.0+flow*7.0-magic_clock*1.1),14.0)
		*exp(-d*5.0)*smoothstep(0.02,0.09,d);
	vec3 pale = mix(vec3(0.78,0.81,0.76),vec3(0.88,0.85,0.79),flow);
	vec3 light = pale*(ripple*0.65+threads*1.3)*outside_rim;
	float pressure = sin(d*17.0-magic_clock*1.6+flow)*exp(-d*3.2)*0.06*outside_rim;
	// The floor is not part of this shader; no rectangular carpet imprint.
	return vec4(light*magic_amount,pressure*magic_amount);
}
