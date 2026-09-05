shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley;

// Render on the original model's triangles: no floating bounding-box decals.
// Coordinates are relative to the furnishing, so they follow yaw/streaming.
uniform mat4 mesh_to_prop;
uniform vec3 bounds_min;
uniform vec3 bounds_size = vec3(1.0);
uniform int profile = 0;
uniform float strength = 0.6;
uniform float wear_seed = 0.0;
uniform bool casino = false;
uniform bool infected = false;
varying vec3 prop_position;
varying vec3 prop_normal;

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
        mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float band(float p, float lo, float hi, float feather) {
    return smoothstep(lo - feather, lo, p) * (1.0 - smoothstep(hi, hi + feather, p));
}

void vertex() {
    prop_position = (mesh_to_prop * vec4(VERTEX, 1.0)).xyz;
    prop_normal = normalize(transpose(inverse(mat3(mesh_to_prop))) * NORMAL);
}

void fragment() {
    vec3 p = (prop_position - bounds_min) / bounds_size;
    vec3 n = normalize(prop_normal);
    // Authors use both X-forward and Z-forward assets. The shallow horizontal
    // dimension identifies the service face of a rack, locker or glass pane.
    if (bounds_size.x < bounds_size.z) {
        p = p.zyx;
        n = n.zyx;
    }
    vec2 seed = vec2(wear_seed * 0.137, wear_seed * 0.071);
    float broad = noise(p.xz * 9.0 + seed) * 0.6 + noise(p.xy * 17.0 + seed) * 0.4;
    float grain = noise(prop_position.xz * 65.0 + prop_position.xy * 42.0 + seed);
    float top = smoothstep(0.40, 0.85, n.y);
    float front = smoothstep(0.55, 0.88, abs(n.z));
    float side = 1.0 - abs(n.y);
    float low = 1.0 - smoothstep(0.10, 0.30, p.y);
    float edge = smoothstep(0.78, 0.97, max(abs(p.x - 0.5), abs(p.z - 0.5)) * 2.0);
    float mask = 0.0;
    vec3 color = vec3(0.14, 0.105, 0.065);
    float rough = 0.92;

    if (profile == 0 || profile == 4) { // Seating, worktops, rubbed armrests.
        float seat = band(p.y, 0.30, 0.79, 0.10);
        mask = seat * (edge * 0.45 + top * smoothstep(0.49, 0.73, broad) * 0.4);
        vec2 q = p.xz - vec2(0.34 + hash(seed) * 0.25, 0.42);
        float ring = 1.0 - smoothstep(0.012, 0.028, abs(length(q * vec2(1.0, 1.3)) - 0.13));
        if (hash(seed + 3.7) < 0.24) mask += ring * top * 0.42;
        color = mix(vec3(0.10, 0.065, 0.028), vec3(0.37, 0.28, 0.15), edge);
        rough = mix(0.94, 0.44, edge);
        if (casino && hash(seed + 8.3) < 0.12) {
            vec2 metres = bounds_size.x < bounds_size.z ? bounds_size.zx : bounds_size.xz;
            float burn = 1.0 - smoothstep(0.004, 0.008, length((p.xz - vec2(0.43, 0.62)) * metres));
            mask = max(mask, burn * top * seat * 0.95);
            color = mix(color, vec3(0.02, 0.012, 0.005), burn);
        }
    } else if (profile == 1 || profile == 2) { // Metal fittings, lockers, rails.
        float hand = band(p.y, 0.44, 0.67, 0.10) * front;
        float chips = smoothstep(0.59, 0.81, broad) * (low * 0.8 + edge * 0.5);
        mask = chips + hand * smoothstep(0.45, 0.78, broad) * 0.36;
        color = mix(vec3(0.25, 0.115, 0.034), vec3(0.40, 0.39, 0.31), hand);
        rough = mix(0.96, 0.38, hand);
    } else if (profile == 3) { // Fan grilles, rack scrapes, cleaned handles/labels.
        float slats = 1.0 - smoothstep(0.10, 0.28, abs(fract(p.y * 28.0) - 0.5));
        float dust = front * slats * smoothstep(0.35, 0.73, broad);
        float handle = band(p.x, 0.76, 0.84, 0.04) * band(p.y, 0.38, 0.64, 0.07) * front;
        float label = band(p.x, 0.18, 0.46, 0.018) * band(p.y, 0.74, 0.79, 0.012) * front;
        mask = dust * 0.55 + low * side * broad * 0.42 + label * 0.32 + handle * broad * 0.33;
        color = mix(vec3(0.38, 0.36, 0.29), vec3(0.12, 0.12, 0.11), handle);
        rough = mix(0.97, 0.34, handle);
    } else if (profile == 5) { // Broad wiped arcs and faint hand-height smears.
        float wipe = abs(length((p.xy - vec2(0.46, 0.55)) * vec2(0.8, 1.2)) - 0.24);
        float arcs = 1.0 - smoothstep(0.008, 0.045, wipe);
        mask = (arcs * 0.32 + band(p.y, 0.30, 0.65, 0.12) * broad * 0.13) * front;
        color = vec3(0.49, 0.48, 0.39);
        rough = 0.84;
    } else if (profile == 6) { // Mineral crust and old damp around plumbing/pots.
        float tide = 1.0 - smoothstep(0.015, 0.075, abs(p.y - 0.22 - (broad - 0.5) * 0.08));
        mask = (tide * 0.65 + low * smoothstep(0.43, 0.70, broad) * 0.52) * side;
        color = mix(vec3(0.20, 0.17, 0.08), vec3(0.63, 0.59, 0.43), tide);
    } else if (profile == 7) { // Court paint rubbed down to the varnished floor.
        mask = top * smoothstep(0.53, 0.79, broad) * 0.75;
        color = vec3(0.40, 0.28, 0.14);
        rough = 0.74;
    } else if (profile == 8) { // Travelator entrance plates, polished by shoes.
        mask = top * (0.18 + broad * 0.22) * (1.0 - smoothstep(0.25, 0.50, abs(p.x - 0.5)));
        color = vec3(0.35, 0.36, 0.34);
        rough = 0.38;
    }
    if (infected) {
        mask += low * broad * 0.30;
        color *= vec3(0.70, 0.85, 0.61);
    }
    ALBEDO = color;
    ROUGHNESS = rough;
    SPECULAR = 0.28;
    ALPHA = clamp(mask * (0.74 + grain * 0.26) * strength, 0.0, 0.28);
}
