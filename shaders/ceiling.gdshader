shader_type spatial;
// 600 mm mineral-fibre panels, painted T-bars and occasional water damage.
// Real, mipmapped pore detail avoids the former centimetre-deep worm ridges.
uniform vec3 col : source_color = vec3(0.90, 0.89, 0.86);
uniform vec3 stain : source_color = vec3(0.43, 0.32, 0.20);
uniform vec3 col_rail : source_color = vec3(0.73, 0.72, 0.68);
uniform float tile = 0.6;
uniform float bump_strength = 1.0;
uniform float stain_amount = 0.28;
uniform float missing_amount = 0.6;
uniform sampler2D tile_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wpos;

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hashf(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
vec2 panel_uv(vec2 p) {
	vec2 id = floor(p/tile);
	vec2 f = fract(p/tile);
	float seed = hashf(id);
	if (seed>0.5) f = f.yx;
	if (hashf(id+4.7)>0.5) f.x = 1.0-f.x;
	// Four interiors from the existing credited tile sheet, excluding its rails.
	vec2 quadrant = floor(vec2(hashf(id+7.1),hashf(id+3.9))*2.0)*0.5;
	return quadrant+vec2(0.025)+f*0.425;
}
float edge_distance(vec2 p) {
	vec2 f = fract(p/tile);
	return min(min(f.x,1.0-f.x),min(f.y,1.0-f.y))*tile;
}
float height_at(vec2 p) {
	float edge = edge_distance(p);
	float crown = 1.0-smoothstep(0.009,0.015,edge);
	float pore = texture(tile_tex,panel_uv(p)).r;
	return crown*0.0025 + pore*0.00035*(1.0-crown);
}
void fragment() {
	vec2 p = wpos.xz;
	vec2 id = floor(p/tile);
	float edge = edge_distance(p);
	float aa = max(fwidth(edge),0.0004);
	float rail = 1.0-smoothstep(0.012-aa,0.012+aa,edge);
	float seam = (1.0-smoothstep(0.017-aa,0.017+aa,edge))*(1.0-rail);
	vec3 grain = texture(tile_tex,panel_uv(p)).rgb;
	vec3 c = col*mix(vec3(1.0),grain,0.55)*(0.97+0.06*hashf(id+8.9));
	// Sparse stains vary over several panels instead of stamping every tile.
	float wet = texture(detail_tex,p*0.14+vec2(0.13,0.31)).r;
	float stain_mask = smoothstep(0.56,0.76,wet);
	float tide = smoothstep(0.54,0.58,wet)*(1.0-smoothstep(0.58,0.64,wet));
	c = mix(c,stain,(stain_mask*0.35+tide*0.16)*stain_amount);
	c *= 1.0-seam*0.22;
	c = mix(c,col_rail,rail);
	float missing = step(1.0-0.018*missing_amount,hashf(id+19.7))*(1.0-rail);
	c = mix(c,vec3(0.015,0.014,0.012),missing);
	vec3 gn = normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
	vec3 axis = abs(gn.y)>0.9 ? vec3(1.0,0.0,0.0) : vec3(0.0,1.0,0.0);
	vec3 t1 = normalize(cross(axis,gn));
	vec3 t2 = cross(gn,t1);
	float e = 0.003;
	float h = height_at(p);
	vec3 slope = t1*(height_at(p+t1.xz*e)-h)/e+t2*(height_at(p+t2.xz*e)-h)/e;
	NORMAL = normalize(mat3(VIEW_MATRIX)*normalize(gn-slope*bump_strength*(1.0-missing)));
	ALBEDO = c;
	ROUGHNESS = mix(0.94,0.68,rail);
	METALLIC = 0.0;
	SPECULAR = mix(0.16,0.28,rail);
}
