shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley;

// Physical surface marks. UVs belong to a bounded, metre-sized patch attached
// to its supporting face. No screen-space noise or clock: wear stays put.
uniform int motif = 0;
uniform bool damp_spread = false;
uniform sampler2D stain_mask : source_color, filter_linear_mipmap_anisotropic;
instance uniform float wear_seed = 0.0;
instance uniform float strength = 0.5;
instance uniform vec2 patch_size = vec2(1.0);
instance uniform vec4 ink : source_color = vec4(0.12, 0.09, 0.06, 1.0);
instance uniform float surface_roughness = 0.92;
instance uniform float tile_pitch = 0.0;
varying vec3 world_position;
varying vec3 world_normal;
varying flat vec3 patch_origin;
varying flat vec3 patch_axis_u;
varying flat vec3 patch_axis_v;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    patch_origin = MODEL_MATRIX[3].xyz;
    patch_axis_u = normalize(MODEL_MATRIX[0].xyz);
    patch_axis_v = normalize(MODEL_MATRIX[1].xyz);
}

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

float fbm(vec2 p) {
    return noise(p) * 0.57 + noise(p * 2.13 + 7.1) * 0.28
        + noise(p * 4.39 + 19.3) * 0.15;
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 ba = b - a;
    return length(p - a - ba * clamp(dot(p - a, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0));
}

float box_distance(vec2 p, vec2 size) {
    vec2 d = abs(p) - size;
    return length(max(d, vec2(0))) + min(max(d.x, d.y), 0.0);
}

void fragment() {
    vec2 uv = UV;
    vec2 p = uv - 0.5;
    vec2 seed = vec2(wear_seed * 0.137, wear_seed * 0.071);
    float broad = fbm(uv * 5.2 + seed);
    float fine = noise(uv * patch_size * 45.0 + seed);
    float aa = max(fwidth(uv.x) + fwidth(uv.y), 0.0015);
    float border = smoothstep(0.0, 0.075, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
    float mask = 0.0;
    vec3 color = ink.rgb;
    float radius = length(p * vec2(1.0, 1.15)) + (broad - 0.5) * 0.17;
    vec3 an = abs(world_normal);
    vec2 tile_metres = an.y > an.x && an.y > an.z ? world_position.xz
        : (an.x > an.z ? world_position.zy : world_position.xy);
    vec2 tile_grid = tile_metres / max(tile_pitch, 0.10);
    vec2 origin_metres = an.y > an.x && an.y > an.z ? patch_origin.xz
        : (an.x > an.z ? patch_origin.zy : patch_origin.xy);
    vec3 span = abs(patch_axis_u) * patch_size.x + abs(patch_axis_v) * patch_size.y;
    vec2 extent = an.y > an.x && an.y > an.z ? span.xz
        : (an.x > an.z ? span.zy : span.xy);
    vec2 tile_center = ((floor(tile_grid) + 0.5) * max(tile_pitch, 0.10) - origin_metres) / max(extent, vec2(0.01));
    float whole_tile = step(max(abs(tile_center.x) + tile_pitch / max(extent.x, 0.01) * 0.5,
        abs(tile_center.y) + tile_pitch / max(extent.y, 0.01) * 0.5), 0.47);

    if (motif == 0) { // Spill: several dried tide rings with a lighter centre.
        float body = 1.0 - smoothstep(0.32, 0.43, radius);
        float rim = 1.0 - smoothstep(0.012, 0.035, abs(radius - 0.345));
        mask = body * (0.18 + broad * 0.20) + rim * 0.36;
        if (damp_spread) {
            // Reuse the project's authored water masks for building leaks.
            // A metre-wide ceiling leak must not resemble a coffee-cup ring.
            float stain = texture(stain_mask, uv).r;
            mask = smoothstep(0.045, 0.74, stain) * (0.70 + fine * 0.20);
        }
    } else if (motif == 1 || motif == 9) { // Leak / rust descending from a fixing.
        float width = mix(0.37, 0.19, uv.y);
        float centre = (noise(vec2(uv.y * 4.0, wear_seed)) - 0.5) * 0.11;
        float spread = abs(p.x - centre) + (broad - 0.5) * 0.16;
        float trunk = 1.0 - smoothstep(width * 0.35, width, spread);
        float tide = 1.0 - smoothstep(0.008, 0.055, abs(spread - width * 0.72));
        vec2 run_uv = vec2(uv.x * 43.0 + noise(uv * 6.0 + seed) * 1.8, uv.y * 8.0);
        float strands = smoothstep(0.49, 0.78, noise(run_uv + seed));
        float fade = 1.0 - smoothstep(0.57 + broad * 0.20, 0.99, uv.y);
        mask = (trunk * (0.20 + broad * 0.18 + strands * 0.18) + tide * 0.13) * fade;
        if (motif == 9) mask *= 1.3;
        color *= mix(0.85, 1.18, broad);
    } else if (motif == 2) { // Mold follows a damp boundary, with small colonies.
        float colony = smoothstep(0.41, 0.69, broad);
        float flecks = smoothstep(0.34, 0.72, fine);
        mask = colony * (0.32 + flecks * 0.68) * (1.0 - smoothstep(0.25, 0.51, radius));
        color = mix(ink.rgb * 0.55, ink.rgb * vec3(0.88, 1.12, 0.72), broad);
    } else if (motif == 3 || motif == 13) { // Segmented, branching structural cracks.
        float distance_to_crack = 10.0;
        vec2 previous = vec2(0.48, 0.06);
        for (int i = 1; i <= 11; i++) {
            float h = hash(vec2(float(i), wear_seed));
            vec2 next = vec2(0.5 + (h - 0.5) * 0.12, 0.06 + float(i) * 0.08);
            distance_to_crack = min(distance_to_crack,
                segment(uv * patch_size, previous * patch_size, next * patch_size));
            if (i == 4 || i == 8) {
                vec2 middle = next + vec2(i == 4 ? -0.08 : 0.08, 0.025);
                vec2 end = next + vec2(i == 4 ? -0.19 : 0.17, 0.11);
                distance_to_crack = min(distance_to_crack,
                    segment(uv * patch_size, next * patch_size, middle * patch_size));
                distance_to_crack = min(distance_to_crack,
                    segment(uv * patch_size, middle * patch_size, end * patch_size));
            }
            previous = next;
        }
        float crack_aa = max(fwidth(distance_to_crack), 0.00025);
        float crack_width = (motif == 13 ? 0.003 : 0.0018) * (0.55 + broad * 0.65);
        mask = 1.0 - smoothstep(max(0.0, crack_width - crack_aa),
            crack_width + crack_aa, distance_to_crack);
        mask += (1.0 - smoothstep(0.004, 0.011, distance_to_crack)) * 0.10;
        if (motif == 13) {
            mask = max(mask, (1.0 - smoothstep(0.16, 0.42, radius)) * (0.15 + broad * 0.52));
        }
    } else if (motif == 4) { // Wheels, shoes and chair legs leave broken arcs.
        for (int i = 0; i < 5; i++) {
            vec2 shift = vec2(hash(vec2(float(i), wear_seed + 1.0)), hash(vec2(float(i), wear_seed + 2.0))) - 0.5;
            vec2 q = p + shift * 0.4;
            float arc = abs(length(q * vec2(0.9, 1.6)) - (0.20 + float(i) * 0.025));
            mask = max(mask, (1.0 - smoothstep(0.006 + aa, 0.021 + aa, arc))
                * smoothstep(0.35, 0.7, noise(uv * 18.0 + seed + float(i))));
        }
        mask += (1.0 - smoothstep(0.17, 0.48, radius)) * 0.13;
    } else if (motif == 5 || motif == 14) { // Repaint / a clean footprint left behind.
        float d = box_distance(p, vec2(0.39, 0.39));
        mask = 1.0 - smoothstep(-0.025, 0.015, d + (fine - 0.5) * 0.015);
        if (tile_pitch > 0.0) {
            vec2 joint = abs(fract(tile_grid) - 0.5);
            mask = whole_tile * step(0.50, hash(floor(tile_grid) + seed))
                * (1.0 - smoothstep(0.43, 0.49, max(joint.x, joint.y)));
        }
        if (motif == 14) {
            mask *= 0.3;
            mask += (1.0 - smoothstep(0.003, 0.014, abs(d))) * 0.35;
            for (int i = 0; i < 4; i++) {
                vec2 screw = vec2(i < 2 ? -0.34 : 0.34, (i == 0 || i == 2) ? -0.34 : 0.34);
                mask += (1.0 - smoothstep(0.009, 0.016, length(p - screw))) * 0.7;
            }
        }
    } else if (motif == 6) { // Removed tape and notices: adhesive edge, torn scraps.
        float d = box_distance(p, vec2(0.35, 0.37));
        mask = (1.0 - smoothstep(0.012, 0.045, abs(d))) * (0.3 + broad * 0.7);
        mask += (1.0 - smoothstep(-0.02, 0.0, d)) * smoothstep(0.62, 0.78, broad) * 0.5;
        for (int i = 0; i < 4; i++) {
            vec2 pin = vec2(i < 2 ? -0.32 : 0.32, (i == 0 || i == 2) ? -0.34 : 0.34);
            mask += (1.0 - smoothstep(0.0018, 0.004, length((p - pin) * patch_size))) * 0.7;
        }
    } else if (motif == 7 || motif == 17) { // A scorch / scattered cigarette burns.
        float burn = radius;
        if (motif == 17) {
            burn = 1.0;
            for (int i = 0; i < 4; i++) {
                vec2 q = vec2(hash(vec2(float(i), wear_seed)), hash(vec2(float(i) + 8.0, wear_seed))) * 0.65 + 0.175;
                burn = min(burn, length((uv - q) * patch_size) * 14.0);
            }
        }
        mask = (1.0 - smoothstep(0.16, 0.38, burn)) * (0.75 + fine * 0.25);
        color *= mix(0.35, 1.15, smoothstep(0.06, 0.35, burn));
    } else if (motif == 8 || motif == 15) { // Dry dust / clogged intake slats.
        mask = smoothstep(0.32, 0.72, broad) * (0.6 + fine * 0.4);
        if (motif == 15) {
            float slat = 1.0 - smoothstep(0.09, 0.21, abs(fract(uv.y * 15.0) - 0.5));
            mask *= slat;
        }
        mask *= 1.0 - smoothstep(0.30, 0.61, radius);
    } else if (motif == 10 || motif == 16) { // Chalky mineral crust / a historic waterline.
        float line = abs(p.y + (noise(vec2(uv.x * 5.0, wear_seed)) - 0.5) * 0.10);
        float ring = abs(radius - 0.31);
        float d = motif == 16 ? line : ring;
        mask = (1.0 - smoothstep(0.018, 0.12, d)) * (0.25 + broad * 0.75);
        mask *= 0.62 + fine * 0.38;
    } else if (motif == 11) { // Missing mosaic cluster, snapped to its own tile grid.
        vec2 grid = tile_pitch > 0.0 ? tile_grid : uv * patch_size / 0.10;
        vec2 tile = floor(grid);
        float picked = hash(tile + seed);
        vec2 cell = abs(fract(grid) - 0.5);
        float edge = max(cell.x, cell.y);
        if (tile_pitch > 0.0) {
            // Always remove the tile containing this rare patch's centre.
            // Random selection alone could leave a recorded patch invisible.
            vec2 centre_tile = floor(origin_metres / tile_pitch);
            mask = (all(equal(tile, centre_tile)) ? 1.0 : 0.0) * whole_tile;
        } else {
            // The fallback still removes whole tiles from a compact group.
            vec2 local_center = (tile + 0.5) * 0.10 / patch_size - 0.5;
            vec2 centre_tile = floor(patch_size * 0.5 / 0.10);
            mask = all(equal(tile, centre_tile)) ? 1.0 : 0.0;
        }
        mask *= 0.85 + fine * 0.15;
        color *= mix(1.12, 0.70, smoothstep(0.40, 0.49, edge)) * (0.88 + fine * 0.22);
    } else if (motif == 12) { // Dirt packed at a base, fixing or floor joint.
        mask = (1.0 - smoothstep(0.18, 0.50, abs(p.y))) * smoothstep(0.30, 0.72, broad);
        mask *= 0.65 + fine * 0.35;
    } else if (motif == 18) { // Dry crumbling plaster around a rupture.
        mask = smoothstep(0.48, 0.74, broad) * (1.0 - smoothstep(0.12, 0.48, radius));
    } else if (motif == 19) { // Flattened carpet / a softened path in floor polish.
        float path = 1.0 - smoothstep(0.09, 0.42, abs(p.x + (broad - 0.5) * 0.12));
        float ends = 1.0 - smoothstep(0.22, 0.49, abs(p.y));
        mask = path * ends * (0.13 + broad * 0.16);
    } else if (motif == 20) { // Low, broken luggage and furniture rubs along a wall.
        float height = abs(p.y + (noise(vec2(uv.x * 3.0, wear_seed)) - 0.5) * 0.12);
        float line = 1.0 - smoothstep(0.015, 0.085, height);
        mask = line * smoothstep(0.30, 0.72, noise(uv * vec2(14.0, 3.0) + seed)) * 0.6;
        mask += (1.0 - smoothstep(0.02, 0.22, height)) * broad * 0.10;
    } else if (motif == 21) { // Faded adhesive left by a removed row of letters.
        vec2 letter = vec2(fract(uv.x * 7.0), uv.y);
        float choice = hash(vec2(floor(uv.x * 7.0), wear_seed));
        float stem = 1.0 - smoothstep(0.018, 0.075, abs(letter.x - 0.22));
        float top_bar = 1.0 - smoothstep(0.025, 0.08, abs(letter.y - 0.25));
        float mid_bar = 1.0 - smoothstep(0.025, 0.08, abs(letter.y - 0.5));
        float low_bar = 1.0 - smoothstep(0.025, 0.08, abs(letter.y - 0.75));
        float across = step(0.22, letter.x) * (1.0 - smoothstep(0.64, 0.76, letter.x));
        mask = max(stem * step(0.25, letter.y) * step(letter.y, 0.75),
            across * max(top_bar, max(mid_bar * step(0.3, choice), low_bar * step(0.6, choice))));
        mask *= smoothstep(0.36, 0.72, broad) * 0.5;
    }

    ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
    ROUGHNESS = surface_roughness;
    METALLIC = 0.0;
    SPECULAR = 0.22;
    ALPHA = clamp(mask * border * strength * ink.a, 0.0, 0.36);
    // Mortar replaces the missing tile's face rather than tinting the glazed
    // tile underneath. Its density varies spatially; exposed areas are opaque.
    if (motif == 11) ALPHA = clamp(mask * border * 1.55, 0.0, 1.0);
}
