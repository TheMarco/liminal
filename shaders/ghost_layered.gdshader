shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Production version of the approved curved-body / delayed-veil prototype.
// Artwork and timing are supplied per enemy; only the core carries the eyes.
uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float flip_cols = 6.0;
uniform float flip_rows = 4.0;
uniform float flip_count = 24.0;
uniform float base_cut = 0.0;
uniform float keep_colour = 1.0;

instance uniform float layer = 0.0;
instance uniform float elapsed = 0.0;
instance uniform float flip_frame = 0.0;
instance uniform float delayed_frame = 0.0;
instance uniform float flip_blend = 1.0;
instance uniform float flip_loop = 1.0;
instance uniform float fade = 1.0;
instance uniform float flip = 0.0;
instance uniform float dissolve_seed = 0.0;
instance uniform float dissolve_smoke = 0.0;
instance uniform float burn = 0.0;
instance uniform float ignite = 0.0;
instance uniform float sway = 0.0;
instance uniform float torch = 0.0;

vec4 frame_sample(vec2 uv, float frame) {
    float count = max(flip_count, 1.0);
    frame = flip_loop > 0.5 ? mod(frame, count) : clamp(frame, 0.0, count - 1.0);
    float a = floor(frame);
    float b = flip_loop > 0.5 ? mod(a + 1.0, count) : min(a + 1.0, count - 1.0);
    vec2 cells = vec2(flip_cols, flip_rows);
    vec2 pad = max(vec2(0.005), cells * 0.5 / vec2(textureSize(tex, 0)));
    uv = clamp(uv, pad, vec2(1.0) - pad);
    vec2 ua = (vec2(mod(a, flip_cols), floor(a / flip_cols)) + uv) / cells;
    vec2 ub = (vec2(mod(b, flip_cols), floor(b / flip_cols)) + uv) / cells;
    return mix(texture(tex, ua), texture(tex, ub), fract(frame) * flip_blend);
}

float veil_alpha(vec2 uv) {
    vec2 px = vec2(flip_cols, flip_rows) / vec2(textureSize(tex, 0));
    px *= 1.5 + layer * 0.50;
    float alpha = frame_sample(uv, delayed_frame).a * 0.40;
    alpha += frame_sample(uv + vec2(px.x, 0.0), delayed_frame).a * 0.15;
    alpha += frame_sample(uv - vec2(px.x, 0.0), delayed_frame).a * 0.15;
    alpha += frame_sample(uv + vec2(0.0, px.y), delayed_frame).a * 0.15;
    alpha += frame_sample(uv - vec2(0.0, px.y), delayed_frame).a * 0.15;
    return alpha;
}

float floor_mask(float y, bool veil) {
    if (base_cut <= 0.0) { return 1.0; }
    // The source shadow is BELOW the feet. Never trim the hood at UV.y == 0.
    float edge = 1.0 - base_cut;
    return 1.0 - smoothstep(edge - (veil ? 0.034 : 0.006), edge + 0.006, y);
}

void vertex() {
    float across = max(0.0, 1.0 - pow(abs(UV.x - 0.5) * 2.0, 2.0));
    VERTEX.z += across * sin(UV.y * 3.14159) * 0.16;
    float loose = smoothstep(0.20, 0.94, UV.y);
    float bend = sin(elapsed * 0.72 + UV.y * 7.0) * 0.016;
    if (layer > 0.5) {
        bend = sin((elapsed - layer * 0.19) * 0.72 + UV.y * 7.0)
            * (0.016 + layer * 0.015);
    }
    // The mesh is normalized; owners scale it to the artwork's body size.
    VERTEX.x += bend * loose / 1.39;
    float foot = 1.0 - UV.y;
    VERTEX.x += sway * 0.035 * foot * foot;
    if (ignite > 0.5) {
        VERTEX.y -= (1.0 - clamp(fade, 0.0, 1.0)) * foot * 0.16;
    }
}

void fragment() {
    vec2 uv = UV;
    uv.x = mix(uv.x, 1.0 - uv.x, flip);
    float remaining = clamp(fade, 0.0, 1.0);
    float dissolve = 1.0 - remaining;
    float seed = dissolve_seed * 17.31;
    float noise = texture(noise_tex, uv * vec2(2.4, 3.0)
        + vec2(layer * 0.43, -elapsed * 0.025)).r;
    uv.x += (noise - 0.5) * 0.014 * smoothstep(0.2, 0.9, uv.y);

    // Preserve the game's flowing, spatially broken dissolve and corner smoke.
    float bend_a = texture(noise_tex,
        uv * vec2(1.7, 1.15) + vec2(seed, -elapsed * 0.055)).r;
    float bend_b = texture(noise_tex,
        uv * vec2(4.8, 2.3) + vec2(-seed * 0.37, -elapsed * 0.11)).r;
    uv.x += ((bend_a - 0.5) * dissolve * 0.075
        + (bend_b - 0.5) * dissolve * 0.022) * (1.0 + dissolve_smoke * 0.85);
    uv.y += dissolve * (1.0 - dissolve_smoke) * (0.018 + bend_a * 0.045);

    vec4 art = frame_sample(uv, flip_frame);
    float shape = art.a * floor_mask(uv.y, false);
    float form = clamp(dot(art.rgb, vec3(0.2126, 0.7152, 0.0722)) / 0.30, 0.0, 1.0);
    vec3 albedo;
    float opacity;
    if (layer < 0.5) {
        albedo = vec3(0.0055, 0.007, 0.009) + vec3(0.023, 0.024, 0.026) * form;
        opacity = smoothstep(0.025, 0.80, shape) * 0.97;
        float body = 1.0 - smoothstep(0.72, 0.92, uv.y);
        opacity = mix(opacity, max(opacity, smoothstep(0.12, 0.56, shape) * 0.995), body);
        if (keep_colour > 0.5) {
            float peak = max(art.r, max(art.g, art.b));
            float saturated = peak - min(art.r, min(art.g, art.b));
            float eyes = smoothstep(0.08, 0.22, saturated);
            albedo = mix(albedo, art.rgb / max(peak, 0.001) * 0.65, eyes);
        }
    } else {
        float delayed = veil_alpha(uv) * floor_mask(uv.y, true);
        float soft_edge = smoothstep(0.015, 0.15, delayed)
            * (1.0 - smoothstep(0.30, 0.85, delayed));
        float fragments = smoothstep(0.35, 0.72, noise);
        float loose = smoothstep(0.24, 0.48, uv.y);
        float outside = 1.0 - smoothstep(0.12, 0.72, shape);
        albedo = vec3(0.007, 0.009, 0.011);
        opacity = soft_edge * fragments * loose * outside * (0.53 - layer * 0.035);
    }

    float n1 = texture(noise_tex, uv * vec2(2.15, 1.15)
        + vec2(seed + elapsed * 0.012, -elapsed * 0.075 * (1.0 - dissolve_smoke))).r;
    float n2 = texture(noise_tex, uv * vec2(6.2, 3.7)
        + vec2(-seed * 0.61 - elapsed * 0.021, -elapsed * 0.13 * (1.0 - dissolve_smoke))).r;
    float smoke_field = n1 * 0.58 + n2 * 0.42
        + (1.0 - uv.y) * 0.16 * (1.0 - dissolve_smoke);
    float threshold = mix(-0.24, 1.08, dissolve);
    float survive = smoothstep(threshold - 0.14, threshold + 0.14, smoke_field);
    opacity *= survive * smoothstep(0.0, 0.10, remaining);

    // Flashlight relief remains restrained and belongs only to the body.
    if (layer < 0.5 && torch > 0.001) {
        vec2 px = vec2(flip_cols, flip_rows) / vec2(textureSize(tex, 0));
        float hx0 = dot(frame_sample(uv - vec2(px.x, 0.0), flip_frame).rgb, vec3(0.333));
        float hx1 = dot(frame_sample(uv + vec2(px.x, 0.0), flip_frame).rgb, vec3(0.333));
        float hy0 = dot(frame_sample(uv - vec2(0.0, px.y), flip_frame).rgb, vec3(0.333));
        float hy1 = dot(frame_sample(uv + vec2(0.0, px.y), flip_frame).rgb, vec3(0.333));
        vec3 normal = normalize(vec3((hx0 - hx1) * 2.4, (hy0 - hy1) * 2.4, 1.0));
        float lit = max(dot(normal, normalize(vec3(-0.34, 0.52, 0.78))), 0.0);
        albedo += vec3(1.0, 0.92, 0.80) * pow(lit, 1.6) * form * torch * 0.16;
    }

    float ember = n1 * 0.55 + n2 * 0.45;
    float emit = 0.0;
    if (burn > 0.0 && layer < 0.5) {
        float heat = burn * burn;
        float catches = ember * (0.55 + form * 0.75);
        float glow = smoothstep(0.62 - heat * 0.50, 0.99 - heat * 0.34, catches) * heat;
        emit = glow * 1.25;
        albedo = mix(albedo, vec3(1.0, 0.80, 0.52), glow);
    }
    if (ignite > 0.5) {
        float front = dissolve * 1.58 - (1.0 - uv.y) * 0.78
            + form * 0.22 - ember * 0.18 - n2 * 0.10;
        float consumed = smoothstep(0.0, 0.13, front);
        if (layer < 0.5) {
            float core = smoothstep(-0.015, 0.005, front)
                * (1.0 - smoothstep(0.005, 0.045, front));
            float flame = smoothstep(-0.055, 0.0, front)
                * (1.0 - smoothstep(0.02, 0.15, front));
            float charred = smoothstep(0.02, 0.11, front)
                * (1.0 - smoothstep(0.15, 0.42, front));
            float spark = smoothstep(0.90, 0.995, ember)
                * smoothstep(0.01, 0.10, front)
                * (1.0 - smoothstep(0.18, 0.60, front));
            opacity *= 1.0 - consumed * 0.97;
            opacity = max(opacity, (flame * 0.80 + spark * 0.85) * shape * survive);
            opacity = max(opacity, charred * 0.55 * shape * survive);
            vec3 hot = mix(vec3(1.0, 0.42, 0.10), vec3(1.0, 0.78, 0.42), clamp(flame * 1.3, 0.0, 1.0));
            hot = mix(hot, vec3(1.0, 0.97, 0.90), clamp(core * 1.5, 0.0, 1.0));
            albedo = mix(albedo, vec3(0.05, 0.03, 0.03), clamp(charred * 0.9, 0.0, 1.0));
            albedo = mix(albedo, hot, clamp(flame * 1.5 + core + spark, 0.0, 1.0));
            emit = flame * (0.26 + ember * 0.34) + core * 0.80 + spark * 1.05;
        } else {
            // Veils vanish with the consuming front, without duplicate flames.
            opacity *= (1.0 - consumed) * remaining;
        }
    }
    ALBEDO = albedo * (1.0 + emit * 4.5);
    ALPHA = clamp(opacity * smoothstep(0.0, 0.10, remaining), 0.0, 1.0);
}
