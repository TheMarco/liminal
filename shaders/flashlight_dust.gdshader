shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never,
    skip_vertex_transform, shadows_disabled, fog_disabled;

uniform float cell_size = 1.0;
uniform float mote_size = 0.014;
uniform float density = 0.35;
uniform float motion_time = 0.0;
uniform vec3 observer_position;
uniform vec3 light_position;
uniform vec3 light_direction = vec3(0.0, 0.0, -1.0);
uniform vec3 light_colour : source_color = vec3(0.88, 0.93, 1.0);
uniform vec3 dust_colour : source_color = vec3(0.86, 0.81, 0.70);
uniform float light_energy = 1.0;
uniform float cone_slope = 0.405;
uniform float water_height = -1e9;
varying float illumination;

vec3 hash_cell(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

void vertex() {
    vec3 cell = floor(MODEL_MATRIX[3].xyz / cell_size + 0.5);
    vec3 random = hash_cell(cell + vec3(17.0, 59.0, 113.0));
    vec3 centre = cell * cell_size + (random - 0.5) * cell_size * 0.72;
    float phase = random.x * 6.283185;
    centre += vec3(sin(motion_time*0.27 + phase),
        sin(motion_time*0.18 + phase*1.7),
        cos(motion_time*0.23 + phase*2.3)) * vec3(0.16, 0.10, 0.13);
    vec3 from_light = centre - light_position;
    float axial = dot(from_light, light_direction);
    float radius = max(axial * cone_slope, 0.001);
    float radial = max(dot(from_light, from_light) - axial*axial, 0.0)/(radius*radius);
    float beam = (1.0-smoothstep(0.28, 1.0, radial))*smoothstep(0.5, 1.2, axial);
    vec3 field_distance = abs(centre-observer_position)/vec3(7.0, 3.5, 7.0);
    float boundary = max(max(field_distance.x,field_distance.y),field_distance.z);
    float edge = 1.0-smoothstep(0.72, 0.94, boundary);
    float near_fade = smoothstep(0.65, 1.5, distance(centre, observer_position));
    float selected = 1.0-smoothstep(density, min(density+0.05,1.0), random.z);
    illumination = selected * beam * edge * near_fade * step(water_height+0.03,centre.y)
        * light_energy * (0.5+random.y*0.5)/(1.0+axial*axial*0.035);
    // Camera-facing micro-quads, but their centres and slow drift are world
    // anchored. Normal depth testing hides them behind walls and furniture.
    vec3 view_centre = (VIEW_MATRIX * vec4(centre,1.0)).xyz;
    float size = mote_size * mix(0.55, 1.5, random.y);
    VERTEX = view_centre + vec3(VERTEX.xy*size, 0.0);
}

void fragment() {
    float radius2 = dot(UV*2.0-1.0, UV*2.0-1.0);
    float grain = exp(-radius2*4.5)*(1.0-smoothstep(0.65,1.0,radius2));
    ALBEDO = light_colour*dust_colour*2.2;
    ALPHA = grain*illumination*0.75;
}
