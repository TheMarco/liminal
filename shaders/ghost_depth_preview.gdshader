shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// A shallow curved core with three sparse veils. Disable both options below
// to recover the original layered prototype exactly.
// Only the core carries eyes; veils cannot duplicate the face.
uniform sampler2D artwork : source_color, filter_linear, repeat_disable;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float layer = 0.0;
uniform float elapsed = 0.0;
uniform float depth_amount = 1.0;
uniform bool cohesive_body = true;
uniform bool lag_wisps = true;

vec4 frame_sample(vec2 uv, float sample_time) {
    float frame = mod(sample_time * 5.5, 24.0);
    float a = floor(frame), b = mod(a + 1.0, 24.0);
    vec2 cell = vec2(6.0, 4.0);
    uv = clamp(uv, vec2(0.005), vec2(0.995));
    vec2 ua = (vec2(mod(a, 6.0), floor(a / 6.0)) + uv) / cell;
    vec2 ub = (vec2(mod(b, 6.0), floor(b / 6.0)) + uv) / cell;
    return mix(texture(artwork, ua), texture(artwork, ub), fract(frame));
}

// Blur only the delayed veils, in source-frame pixels. The face stays sharp
// on the core; every tap stays inside its own sprite-sheet cell.
float veil_alpha(vec2 uv, float sample_time) {
    vec2 px = vec2(6.0, 4.0) / vec2(textureSize(artwork, 0));
    px *= 1.5 + layer * 0.50;
    float alpha = frame_sample(uv, sample_time).a * 0.40;
    alpha += frame_sample(uv + vec2(px.x, 0.0), sample_time).a * 0.15;
    alpha += frame_sample(uv - vec2(px.x, 0.0), sample_time).a * 0.15;
    alpha += frame_sample(uv + vec2(0.0, px.y), sample_time).a * 0.15;
    alpha += frame_sample(uv - vec2(0.0, px.y), sample_time).a * 0.15;
    return alpha;
}

void vertex() {
    float across = max(0.0, 1.0 - pow(abs(UV.x - 0.5) * 2.0, 2.0));
    float weight = sin(UV.y * 3.14159);
    VERTEX.z += depth_amount * across * weight * 0.16;
    float loose = smoothstep(0.20, 0.94, UV.y);
    float bend = sin(elapsed * 0.72 + UV.y * 7.0 + layer * 1.9)
        * 0.016 * (1.0 + layer * 0.5);
    if (lag_wisps && layer > 0.5) {
        // Follow the core's bend at an earlier time, with a little more travel
        // at the loose hem. Delayed poses provide the rest of the movement.
        float late = elapsed - layer * 0.19;
        bend = sin(late * 0.72 + UV.y * 7.0)
            * (0.016 + layer * 0.015);
    }
    VERTEX.x += bend * loose * depth_amount;
}

void fragment() {
    vec2 uv = UV;
    float noise = texture(noise_tex, UV * vec2(2.4, 3.0)
        + vec2(layer * 0.43, -elapsed * 0.025)).r;
    uv.x += (noise - 0.5) * 0.014 * depth_amount * smoothstep(0.2, 0.9, UV.y);
    vec4 art = frame_sample(uv, elapsed);
    // Remove the source's floor-shadow band at the bottom of each frame.
    float shape = art.a * (1.0 - smoothstep(0.938, 0.95, uv.y));
    float edge = smoothstep(0.025, 0.18, shape) * (1.0 - smoothstep(0.35, 0.92, shape));
    float luma = dot(art.rgb, vec3(0.2126, 0.7152, 0.0722));
    float form = clamp(luma / 0.30, 0.0, 1.0);
    if (layer < 0.5) {
        ALBEDO = vec3(0.009, 0.012, 0.016) + vec3(0.046, 0.05, 0.055) * form;
        ALPHA = clamp(smoothstep(0.025, 0.80, shape) * 0.97, 0.0, 1.0);
        if (cohesive_body) {
            // Keep the existing soft boundary, but close down the interior so
            // bright wall details do not split the hood and chest into patches.
            float body = 1.0 - smoothstep(0.72, 0.92, uv.y);
            float solid = smoothstep(0.12, 0.56, shape) * 0.995;
            ALPHA = mix(ALPHA, max(ALPHA, solid), body);
            ALBEDO = vec3(0.0055, 0.007, 0.009) + vec3(0.023, 0.024, 0.026) * form;
        }
        float peak = max(art.r, max(art.g, art.b));
        float saturated = peak - min(art.r, min(art.g, art.b));
        float eyes = smoothstep(0.08, 0.22, saturated);
        ALBEDO = mix(ALBEDO, art.rgb / max(peak, 0.001) * 0.65, eyes);
    } else {
        float fragments = smoothstep(0.35, 0.72, noise);
        ALBEDO = vec3(0.014, 0.019, 0.023);
        ALPHA = edge * fragments * 0.24 * depth_amount;
        if (lag_wisps) {
            float late = elapsed - layer * 0.19;
            float delayed = veil_alpha(uv, late)
                * (1.0 - smoothstep(0.91, 0.95, uv.y));
            float soft_edge = smoothstep(0.015, 0.15, delayed)
                * (1.0 - smoothstep(0.30, 0.85, delayed));
            // A few soft remnants near the sleeves and hem, never a second
            // head or a complete second silhouette. Keep the body unobscured.
            float loose = smoothstep(0.24, 0.48, uv.y);
            float outside = 1.0 - smoothstep(0.12, 0.72, shape);
            ALPHA = soft_edge * fragments * loose * outside
                * (0.53 - layer * 0.035) * depth_amount;
        }
        if (cohesive_body) {
            ALBEDO = vec3(0.007, 0.009, 0.011);
            if (!lag_wisps) {
                ALPHA *= 1.0 - smoothstep(0.18, 0.75, shape);
            }
        }
    }
}
