shader_type canvas_item;
render_mode unshaded;

// Original Godot implementation informed by CRT-Royale's documented display
// model: https://docs.libretro.com/shader/crt_royale/
// This is not a port of Royale. The tape signal is rendered first; this pass
// reconstructs light from the beam in linear space, then phosphors and glass.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 signal_resolution = vec2(720.0, 480.0);
uniform float crt_gamma = 2.4;
uniform float display_gamma = 2.2;
uniform float beam_min_sigma = 0.22;
uniform float beam_max_sigma = 0.42;
uniform float mask_strength : hint_range(0.0, 1.0) = 0.48;
uniform float mask_triad_size : hint_range(2.0, 8.0) = 3.0;
uniform bool slot_mask = true;
uniform float convergence : hint_range(0.0, 1.0) = 0.18;
uniform vec2 curvature = vec2(0.055, 0.08);
uniform float overscan = 0.018;
uniform float diffusion_weight = 0.075;
uniform float halation_weight = 0.025;
uniform float bloom_weight = 0.12;
uniform float field_strength = 0.12;
uniform float display_time = -1.0;

vec2 glass_uv(vec2 uv) {
    vec2 p = (uv - 0.5) * 2.0;
    p *= 1.0 + p.yx * p.yx * curvature;
    return p * 0.5 + 0.5;
}

vec3 signal_light(vec2 uv) {
    vec3 signal = textureLod(screen_texture, clamp(uv, vec2(0.001), vec2(0.999)), 0.0).rgb;
    return pow(max(signal, vec3(0.0)), vec3(crt_gamma));
}

vec3 converged_light(vec2 uv) {
    // Beam misconvergence grows toward the tube perimeter, in source pixels.
    float radius = dot(uv - 0.5, uv - 0.5) * 2.0;
    vec2 offset = vec2(convergence * (0.35 + radius), 0.035 * radius) / signal_resolution;
    return vec3(signal_light(uv - offset).r, signal_light(uv).g,
        signal_light(uv + offset).b);
}

vec3 beam_light(vec2 uv) {
    float line_pos = uv.y * signal_resolution.y - 0.5;
    float row = floor(line_pos);
    float footprint = max(fwidth(line_pos), 0.001);
    vec3 light = vec3(0.0);
    for (int i = -1; i <= 2; i++) {
        float scan_row = row + float(i);
        vec3 c = converged_light(vec2(uv.x, (scan_row + 0.5) / signal_resolution.y));
        // More beam current means a broader spot, independently for R/G/B.
        vec3 sigma = mix(vec3(beam_min_sigma), vec3(beam_max_sigma),
            pow(clamp(c, vec3(0), vec3(1)), vec3(0.33)));
        // Approximate pixel-area integration by adding the footprint variance.
        sigma = sqrt(sigma * sigma + footprint * footprint / 12.0);
        float distance_to_line = line_pos - scan_row;
        vec3 profile = exp(-0.5 * distance_to_line * distance_to_line / (sigma * sigma))
            / (2.506628 * sigma);
        light += c * profile;
    }
    return light;
}

vec3 phosphor_mask(vec2 raster, vec2 viewport_size) {
    float pitch = mask_triad_size * max(1.0, viewport_size.y / 1080.0);
    vec2 p = raster * viewport_size / pitch;
    // Integrate the grille carrier over a pixel footprint so curved corners
    // and fractional window scales don't turn fine triads into moving moire.
    float width = max(fwidth(p.x), 0.001);
    float aa = max(sin(PI * width) / (PI * width), 0.0);
    float phase = p.x * TAU;
    vec3 stripes = vec3(1.0) + 0.85 * aa * cos(vec3(phase,
        phase - TAU / 3.0, phase + TAU / 3.0));
    if (slot_mask) {
        // Staggered vertical slots, with narrow separators between groups.
        float slot_y = p.y * 0.5 + floor(p.x) * 0.5;
        float seam = pow(0.5 + 0.5 * cos(slot_y * TAU), 10.0);
        float seam_visibility = 1.0 - smoothstep(0.3, 0.65, fwidth(p.y * 0.5));
        stripes *= 1.0 - 0.22 * seam * seam_visibility;
    }
    float visibility = smoothstep(400.0, 900.0, viewport_size.y);
    return mix(vec3(1.0), stripes, mask_strength * visibility);
}

vec3 glass_diffusion(vec2 uv) {
    // A broad Gaussian approximation. All samples and additions are linear
    // light, so bright phosphors spread naturally without gray edge fringes.
    vec2 spread = vec2(4.5, 2.8) / signal_resolution;
    vec3 blurred = signal_light(uv) * 0.20;
    for (int i = -1; i <= 1; i += 2) {
        blurred += signal_light(uv + vec2(float(i) * spread.x, 0)) * 0.13;
        blurred += signal_light(uv + vec2(0, float(i) * spread.y)) * 0.13;
        for (int j = -1; j <= 1; j += 2) {
            blurred += signal_light(uv + vec2(float(i), float(j)) * spread) * 0.07;
        }
    }
    return blurred;
}

void fragment() {
    vec2 glass = glass_uv(SCREEN_UV);
    vec2 uv = (glass - 0.5) / (1.0 + overscan) + 0.5;
    vec3 beam = beam_light(uv);
    vec3 mask = phosphor_mask(glass, 1.0 / SCREEN_PIXEL_SIZE);
    vec3 diffuse = glass_diffusion(uv);
    vec3 light = mix(beam * mask, diffuse, diffusion_weight);
    float diffuse_luma = dot(diffuse, vec3(0.2126, 0.7152, 0.0722));
    light += vec3(diffuse_luma) * halation_weight;
    // Bloom fills high-current phosphor gaps; dark regions retain the mask.
    light = mix(light, max(light, diffuse),
        smoothstep(0.15, 0.85, diffuse_luma) * bloom_weight);
    float t = display_time >= 0.0 ? display_time : TIME;
    float parity = mod(floor(t * 59.94), 2.0);
    float row = uv.y * signal_resolution.y;
    float field_visibility = 1.0 - smoothstep(0.45, 1.0, fwidth(row) * 0.5);
    light *= 1.0 + cos(row * PI + parity * PI) * field_strength * 0.025 * field_visibility;
    // Glass edges and face falloff are applied after the light has spread.
    vec2 face = (glass - 0.5) * 2.0;
    float falloff = 1.0 - 0.13 * dot(face, face);
    float edge = min(min(glass.x, 1.0 - glass.x), min(glass.y, 1.0 - glass.y));
    float aperture = smoothstep(0.0, 0.013, edge);
    vec3 display = pow(max(light * falloff, vec3(0.0)), vec3(1.0 / display_gamma));
    COLOR = vec4(clamp(display, vec3(0), vec3(1)) * aperture, 1.0);
}
