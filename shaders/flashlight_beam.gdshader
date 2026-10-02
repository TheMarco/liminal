shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never,
    depth_test_disabled, shadows_disabled, fog_disabled;

// A bounded eight-sample shaft, independent of the scene's fog grid. Integrate
// only the air in front of opaque geometry; never paint a cone over a wall.
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 beam_colour : source_color = vec3(0.88, 0.93, 1.0);
uniform float beam_range = 21.0;
uniform float cone_slope = 0.405;
uniform float scattering = 0.010;
instance uniform float beam_energy = 1.0;
varying vec3 origin_view;
varying vec3 axis_view;

void vertex() {
    origin_view = (VIEW_MATRIX * MODEL_MATRIX[3]).xyz;
    axis_view = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    float depth = texture(scene_depth, SCREEN_UV).r;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
    #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
        ndc.z = depth * 2.0 - 1.0;
    #endif
    vec4 scene_h = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    vec3 scene = scene_h.xyz / max(abs(scene_h.w), 0.00001);
    float distance_to_surface = length(scene);
    vec3 ray = scene / max(distance_to_surface, 0.00001);
    float travel = min(distance_to_surface, beam_range);
    float shaft = 0.0;
    // Quadratic spacing resolves the narrow near-source cone without jitter
    // or temporal history. The beam stays steady while walking or turning.
    for (int i = 0; i < 8; i++) {
        float u0 = float(i) / 8.0;
        float u1 = float(i + 1) / 8.0;
        float start = travel * u0 * u0;
        float end = travel * u1 * u1;
        vec3 point = ray * ((start + end) * 0.5) - origin_view;
        float axial = dot(point, axis_view);
        float radius = max(axial * cone_slope, 0.001);
        float radial = max(dot(point, point) - axial * axial, 0.0) / (radius * radius);
        float edge = 1.0 - smoothstep(0.28, 1.0, radial);
        float core = exp(-radial * 5.0);
        float near_fade = smoothstep(0.45, 1.6, axial);
        float far_fade = 1.0 - smoothstep(beam_range * 0.65, beam_range, axial);
        float attenuation = 1.0 / (1.0 + axial * axial * 0.055);
        // Dust scatters mostly along the light's travel direction. From behind
        // a held torch we see weak backscatter, not a bright white fog disc.
        // A Henyey-Greenstein phase with g=0.45 keeps side views shaft-like.
        vec3 light_direction = point / max(length(point), 0.001);
        float cosine = dot(light_direction, -ray);
        float phase_denominator = 1.2025 - 0.9 * cosine;
        float phase = 0.7975 / (phase_denominator * sqrt(phase_denominator));
        shaft += (end - start) * edge * (0.22 + core * 0.78)
            * near_fade * far_fade * attenuation * phase;
    }
    ALBEDO = beam_colour * shaft * scattering;
    ALPHA = beam_energy;
}
