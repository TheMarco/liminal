shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Restored baseline: a shallow curved core with three sparse veils.
// Only the core carries eyes; veils cannot duplicate the face.
uniform sampler2D artwork : source_color, filter_linear, repeat_disable;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float layer = 0.0;
uniform float elapsed = 0.0;
uniform float depth_amount = 1.0;

vec4 frame_sample(vec2 uv) {
    float frame = mod(elapsed * 5.5, 24.0);
    float a = floor(frame), b = mod(a + 1.0, 24.0);
    vec2 cell = vec2(6.0, 4.0);
    uv = clamp(uv, vec2(0.005), vec2(0.995));
    vec2 ua = (vec2(mod(a, 6.0), floor(a / 6.0)) + uv) / cell;
    vec2 ub = (vec2(mod(b, 6.0), floor(b / 6.0)) + uv) / cell;
    return mix(texture(artwork, ua), texture(artwork, ub), fract(frame));
}

void vertex() {
    float across = max(0.0, 1.0 - pow(abs(UV.x - 0.5) * 2.0, 2.0));
    float weight = sin(UV.y * 3.14159);
    VERTEX.z += depth_amount * across * weight * 0.16;
    float loose = smoothstep(0.20, 0.94, UV.y);
    VERTEX.x += sin(elapsed * 0.72 + UV.y * 7.0 + layer * 1.9)
        * loose * 0.016 * depth_amount * (1.0 + layer * 0.5);
}

void fragment() {
    vec2 uv = UV;
    float noise = texture(noise_tex, UV * vec2(2.4, 3.0)
        + vec2(layer * 0.43, -elapsed * 0.025)).r;
    uv.x += (noise - 0.5) * 0.014 * depth_amount * smoothstep(0.2, 0.9, UV.y);
    vec4 art = frame_sample(uv);
    // Remove the source's floor-shadow band at the bottom of each frame.
    float shape = art.a * (1.0 - smoothstep(0.938, 0.95, uv.y));
    float edge = smoothstep(0.025, 0.18, shape) * (1.0 - smoothstep(0.35, 0.92, shape));
    float luma = dot(art.rgb, vec3(0.2126, 0.7152, 0.0722));
    float form = clamp(luma / 0.30, 0.0, 1.0);
    if (layer < 0.5) {
        ALBEDO = vec3(0.009, 0.012, 0.016) + vec3(0.046, 0.05, 0.055) * form;
        float peak = max(art.r, max(art.g, art.b));
        float saturated = peak - min(art.r, min(art.g, art.b));
        float eyes = smoothstep(0.08, 0.22, saturated);
        ALBEDO = mix(ALBEDO, art.rgb / max(peak, 0.001) * 0.65, eyes);
        ALPHA = clamp(smoothstep(0.025, 0.80, shape) * 0.97, 0.0, 1.0);
    } else {
        float fragments = smoothstep(0.35, 0.72, noise);
        ALBEDO = vec3(0.014, 0.019, 0.023);
        ALPHA = edge * fragments * 0.24 * depth_amount;
    }
}
