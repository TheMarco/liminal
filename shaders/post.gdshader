/*
Shader from Godot Shaders - the free shader library.

This shader is under CC0 license. Feel free to use, improve and
change this shader according to your needs and consider sharing
the modified result to godotshaders.com.

Optimised and packed by @c64cosmin
If you do use this please share it with me
Would love to see what you're making with it <3

It's a combination of these two shaders
~godotshaders.com/shader/VHS-and-CRT-monitor-effect
godotshaders.com/shader/crt-shader-with-realistic-blurring/

CRT grille and rolling lines made by @c64cosmin
Vignette and warping effect was made by pend00
Scanlines are from "TimothyLottes" FROM SHADERTOY
Then ported by AHOPNESS (@ahopness)
https://www.shadertoy.com/view/MsjXzh

Liminal adaptations (2026-08-16): emulated grid defaults to the owner's
720x320 signal; the authored noise dial is `noise_level` while
`noise_amount` is the controller's runtime multiplier (baseline 1.0,
pulsed on events); `bright_boost` honours PostProcessController's setup.
One shader serves both recording modes — the controller builds a clean CRT
material and a gritty RECOVERED TAPE material from it. The `entity_*`
uniforms are the figure-interference halo; only the tape material is ever
fed a non-zero amount.
*/

shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;

uniform vec2 resolution = vec2(720.0, 320.0);

uniform float scan_line_amount :hint_range(0.0, 1.0) = 1.0;
uniform float warp_amount :hint_range(0.0, 5.0) = 0.1;
uniform float noise_level :hint_range(0.0, 0.3) = 0.03;
uniform float noise_amount :hint_range(0.0, 3.0) = 1.0;
uniform float bright_boost :hint_range(0.5, 2.5) = 1.0;
uniform float interference_amount :hint_range(0.0, 1.0) = 0.2;
uniform float grille_amount :hint_range(0.0, 1.0) = 0.1;
uniform float grille_size :hint_range(1.0, 5.0) = 1.0;
uniform float vignette_amount :hint_range(0.0, 2.0) = 0.6;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
// Softens the warped raster boundary into the surrounding black glass. Zero
// preserves the clean CRT edge; recovered footage uses a restrained feather.
uniform float tube_edge_feather : hint_range(0.0, 0.08) = 0.0;
uniform float aberation_amount :hint_range(0.0, 1.0) = 0.5;
uniform float roll_line_amount :hint_range(0.0, 1.0) = 0.12;
uniform float roll_speed :hint_range(-8.0, 8.0) = 1.0;
uniform float scan_line_strength :hint_range(-12.0, -1.0) = -8.0;
uniform float pixel_strength :hint_range(-4.0, 0.0) = -2.0;
// The recording cannot hold a figure: screen-space centre/radius of the
// nearest visible apparition. Inside the halo the rows jitter harder, the
// chroma splits wider and static lifts. Zero amount costs nothing.
uniform vec2 entity_pos = vec2(0.5, 0.5);
uniform float entity_radius = 0.25;
uniform float entity_amt :hint_range(0.0, 1.0) = 0.0;

// Recovered-tape grit (2026-08-18). All default to "off" so the clean CRT
// material is unchanged; the tape material dials them in and the controller
// pushes them further with corruption and glitches. Adapted from an
// owner-supplied found-footage shader (hash-driven handheld jitter, sparse
// per-line wobble, tracking tears, ghosting, exposure flicker, colour
// character, head-switching noise) plus VHS dropout streaks.
uniform float jitter_amount :hint_range(0.0, 1.0) = 0.0;   // handheld micro shake
uniform float jitter_speed :hint_range(0.0, 30.0) = 9.0;
uniform float wobble_amount :hint_range(0.0, 1.0) = 0.0;   // sparse line displacement
uniform float tear_amount :hint_range(0.0, 1.0) = 0.0;     // occasional tracking tear
uniform float ghost_amount :hint_range(0.0, 1.0) = 0.0;    // luminance ghost to the right
uniform float flicker_amount :hint_range(0.0, 3.0) = 0.0;  // exposure instability; >1 pulses
uniform float saturation :hint_range(0.0, 2.0) = 1.0;
uniform float contrast :hint_range(0.5, 1.5) = 1.0;
uniform float black_crush :hint_range(0.0, 0.1) = 0.0;
uniform float head_switch_amount :hint_range(0.0, 1.0) = 0.0; // edge sync noise
uniform float dropout_amount :hint_range(0.0, 1.0) = 0.0;  // white streak dropouts
uniform float signal_loss :hint_range(0.0, 1.0) = 0.0;     // bands of lost sync
// DV softness: consumer digital-tape optics and 4:1:1 chroma. Detail is
// low-passed a little sideways; colour is smeared several emulated pixels
// wide, so edges stay roughly where they are but hues bleed past them.
uniform float dv_blur :hint_range(0.0, 1.0) = 0.0;          // luma softness
uniform float dv_chroma_blur :hint_range(0.0, 1.0) = 0.0;   // chroma smear width
uniform float chroma_delay :hint_range(-3.0, 3.0) = 0.0;     // chroma lags luma, source px
// Signal model (2026-08-19). signal_fps quantizes every tape-side random
// process to video frames (0 = continuous); the CRT's own behaviour keeps
// running on TIME. overscan zooms the picture past the tube edge; black_lift
// keeps recorded black off true black inside the tube; field_amount is the
// faint half-line parity shimmer of 480i, never dark lines; line_noise and
// chroma_noise are tape noise correlated along rows; bloom_amount smears
// luminance above bloom_threshold sideways before it clips.
uniform float signal_fps :hint_range(0.0, 60.0) = 0.0;
uniform float overscan :hint_range(0.0, 0.1) = 0.0;
uniform float black_lift :hint_range(0.0, 0.05) = 0.0;
uniform float field_amount :hint_range(0.0, 1.0) = 0.0;
uniform float line_noise :hint_range(0.0, 0.1) = 0.0;
uniform float chroma_noise :hint_range(0.0, 1.0) = 0.0;
uniform float bloom_amount :hint_range(0.0, 1.0) = 0.0;
uniform float bloom_threshold :hint_range(0.0, 1.0) = 0.7;
uniform vec3 color_balance = vec3(1.0, 1.0, 1.0);
// Highlight shoulder: bright interiors (white tile, water glare) washed the
// tape out under bright_boost. Above the knee, excess luminance compresses
// Reinhard-style; 0 disables (the clean tube keeps its linear response).
uniform float highlight_rolloff :hint_range(0.0, 2.0) = 0.0;
uniform float highlight_knee :hint_range(0.2, 1.0) = 0.72;
// Auto-iris: expose by the scene's average luminance (deep mip of the
// screen), the way a consumer camcorder hunts. 0 disables; the clean tube
// keeps its fixed gain. Bright tile rooms pull the gain down instead of
// washing out; dark corridors get a little help.
uniform float auto_exposure :hint_range(0.0, 1.0) = 0.0;
uniform float ae_target :hint_range(0.1, 0.6) = 0.30;

float random(vec2 uv){
    return fract(cos(uv.x * 83.4827 + uv.y * 92.2842) * 43758.5453123);
}

// Tape-side clock: steps once per video frame when signal_fps is set, so
// noise, jitter and dropouts change at 29.97 Hz instead of every display
// frame. CRT-side effects use TIME directly.
float sig_time(){
    return signal_fps > 0.0 ? floor(TIME * signal_fps) / signal_fps : TIME;
}

vec3 fetch_pixel(vec2 uv, vec2 off){
    vec2 pos = floor(uv * resolution + off) / resolution + vec2(0.5) / resolution;

    float noise = 0.0;
    if(noise_level > 0.0){
        noise = random(pos + fract(sig_time())) * noise_level * noise_amount;
    }

    if(max(abs(pos.x - 0.5), abs(pos.y - 0.5)) > 0.5){
        return vec3(0.0, 0.0, 0.0);
    }

    vec3 clr = texture(SCREEN_TEXTURE , pos, -16.0).rgb;
    // Grain rides the picture, not the black: weighted by luminance so a
    // dark figure or an unlit doorway stays dark instead of lifting to grey.
    float lum = dot(clr, vec3(0.299, 0.587, 0.114));
    clr += noise * (0.15 + 0.85 * smoothstep(0.0, 0.22, lum));
    return clr;
}

// Distance in emulated pixels to nearest texel.
vec2 Dist(vec2 pos){
    pos = pos * resolution;
    return - ((pos - floor(pos)) - vec2(0.5));
}

// 1D Gaussian.
float Gaus(float pos, float scale){ return exp2(scale * pos * pos); }

// 3-tap Gaussian filter along horz line.
vec3 Horz3(vec2 pos, float off){
    vec3 b = fetch_pixel(pos, vec2(-1.0, off));
    vec3 c = fetch_pixel(pos, vec2( 0.0, off));
    vec3 d = fetch_pixel(pos, vec2( 1.0, off));
    float dst = Dist(pos).x;

    // Convert distance to weight.
    float scale = pixel_strength;
    float wb = Gaus(dst - 1.0, scale);
    float wc = Gaus(dst + 0.0, scale);
    float wd = Gaus(dst + 1.0, scale);

    // Return filtered sample.
    return (b * wb + c * wc + d * wd) / (wb + wc + wd);
}

// Return scanline weight.
float Scan(vec2 pos, float off){
    float dst = Dist(pos).y;

    return Gaus(dst + off, scan_line_strength);
}

// Allow nearest three lines to effect pixel.
vec3 Tri(vec2 pos){
    vec3 clr = fetch_pixel(pos, vec2(0.0));
    if(scan_line_amount > 0.0){
        vec3 a = Horz3(pos,-1.0);
        vec3 b = Horz3(pos, 0.0);
        vec3 c = Horz3(pos, 1.0);

        float wa = Scan(pos,-1.0);
        float wb = Scan(pos, 0.0);
        float wc = Scan(pos, 1.0);

        vec3 scanlines = a * wa + b * wb + c * wc;
        clr = mix(clr, scanlines, scan_line_amount);
    }
    return clr;
}

// Takes in the UV and warps the edges, creating the spherized effect
// Aspect-aware: curvature is computed in physical (square) units so a 16:9
// tube bows the same amount per centimetre in both axes.
vec2 warp(vec2 uv, float aspect){
    vec2 delta = uv - 0.5;
    delta.x *= aspect;
    float delta2 = dot(delta.xy, delta.xy);
    float delta4 = delta2 * delta2;
    float delta_offset = delta4 * warp_amount;
    delta.x /= aspect;

    vec2 warped = uv + delta * delta_offset;
    return (warped - 0.5) / mix(1.0,1.2,warp_amount/5.0) + 0.5;
}

float vignette(vec2 uv){
    uv *= 1.0 - uv.xy;
    float vignette = uv.x * uv.y * 15.0;
    return pow(vignette, vignette_intensity * vignette_amount);
}

float floating_mod(float a, float b){
    return a - b * floor(a/b);
}

vec3 grille(vec2 uv){
    float unit = PI / 3.0;
    float scale = 2.0*unit/grille_size;
    float r = smoothstep(0.5, 0.8, cos(uv.x*scale - unit));
    float g = smoothstep(0.5, 0.8, cos(uv.x*scale + unit));
    float b = smoothstep(0.5, 0.8, cos(uv.x*scale + 3.0*unit));
    return mix(vec3(1.0), vec3(r,g,b), grille_amount);
}

float hash1(float n){
    return fract(sin(n * 91.3458) * 47453.5453);
}

float hash2(vec2 p){
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float roll_line(vec2 uv){
    float x = uv.y * 3.0 - TIME * roll_speed;
    float f = cos(x) * cos(x * 2.35 + 1.1) * cos(x * 4.45 + 2.3);
    float roll_line = smoothstep(0.5, 0.9, f);
    return roll_line * roll_line_amount;
}

void fragment(){
    vec2 pix = FRAGCOORD.xy;
    float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    vec2 pos = warp(SCREEN_UV, aspect);
    float st = sig_time();
    // Overscan: the tube shows slightly less than the recorded raster.
    if(overscan > 0.0){
        pos = (pos - 0.5) / (1.0 + overscan) + 0.5;
    }
    // 480i field parity: odd fields sit half a line lower, faintly.
    float field = 0.0;
    if(field_amount > 0.0){
        field = mod(floor(TIME * 59.94), 2.0);
        pos.y += field * 0.5 * field_amount / resolution.y;
    }

    float line = 0.0;
    if(roll_line_amount > 0.0){
        line = roll_line(pos);
    }

    float halo = 0.0;
    if(entity_amt > 0.001){
        vec2 rel = SCREEN_UV - entity_pos;
        rel.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
        halo = (1.0 - smoothstep(entity_radius * 0.35, entity_radius,
            length(rel))) * entity_amt;
    }

    // Handheld micro-shake: the whole frame steps a few emulated pixels at a
    // camcorder's frame cadence.
    if(jitter_amount > 0.0){
        float frame = floor(st * jitter_speed);
        pos += vec2(hash1(frame) - 0.5, hash1(frame + 12.73) - 0.5)
            * vec2(4.0, 2.0) * jitter_amount / resolution;
    }
    // Sparse per-line wobble: most lines hold, a few jump.
    if(wobble_amount > 0.0){
        float ln = floor(pos.y * resolution.y);
        float w = pow(hash2(vec2(ln, floor(st * 18.0))), 14.0);
        pos.x += (w - 0.5) * 12.0 * wobble_amount / resolution.x;
    }
    // Occasional tracking tear: a band shears sideways for a beat.
    if(tear_amount > 0.0){
        float cycle = floor(st * 0.65);
        float tear_y = hash1(cycle + 43.1);
        float tear_w = 0.008 + hash1(cycle + 11.4) * 0.025;
        float tear = smoothstep(tear_w, 0.0, abs(pos.y - tear_y))
            * step(0.7, hash1(cycle + 91.0));
        pos.x += tear * (hash1(cycle + 13.2) - 0.5) * 40.0 * tear_amount
            / resolution.x;
    }

    vec2 sq_pix = floor(pos * resolution) / resolution + vec2(0.5) / resolution;
    if(interference_amount + roll_line_amount + halo > 0.0){
        float interference = random(sq_pix.yy + fract(st));
        pos.x += (interference * (interference_amount + line * 6.0
            + halo * 9.0)) / resolution.x;
    }

    vec3 clr = Tri(pos);
    if(aberation_amount + halo > 0.0){
        float chromatic = aberation_amount + line * 2.0 + halo * 2.5;
        vec2 chromatic_x = vec2(chromatic,0.0) / resolution.x;
        vec2 chromatic_y = vec2(0.0, chromatic/2.0) / resolution.y;
        float r = Tri(pos - chromatic_x).r;
        float g = Tri(pos + chromatic_y).g;
        float b = Tri(pos + chromatic_x).b;
        clr = vec3(r,g,b);
    }

    // The halo disturbs the signal AROUND the figure (displacement and
    // chroma above) but only lightly dusts the body itself — static over a
    // dark figure only hides it.
    if(halo > 0.001){
        clr = mix(clr, vec3(random(sq_pix + fract(TIME * 1.3))),
            0.07 * min(halo, 1.0));
    }
    // DV softness, applied in a luma/chroma split so the two can blur by
    // different widths like the codec did.
    if(dv_blur + dv_chroma_blur > 0.0){
        vec2 px = vec2(1.0, 0.0) / resolution;
        vec3 lw = vec3(0.299, 0.587, 0.114);
        float y = dot(clr, lw);
        if(dv_blur > 0.0){
            float y1 = dot(fetch_pixel(pos - px, vec2(0.0)), lw)
                + dot(fetch_pixel(pos + px, vec2(0.0)), lw);
            float y2 = dot(fetch_pixel(pos - px * 2.0, vec2(0.0)), lw)
                + dot(fetch_pixel(pos + px * 2.0, vec2(0.0)), lw);
            float soft = (y * 0.4 + y1 * 0.2 + y2 * 0.1);
            y = mix(y, soft, dv_blur);
        }
        // Shadows stay achromatic: residual chroma in the dark floors
        // sparkled once lifted by the iris.
        // Chroma is read a little late (chroma_delay) and smeared wide.
        vec2 cpos = pos + px * chroma_delay;
        vec3 cc = chroma_delay != 0.0 ? fetch_pixel(cpos, vec2(0.0)) : clr;
        vec3 chroma = cc - vec3(dot(cc, lw));
        if(dv_chroma_blur > 0.0){
            float w = 1.0 + 5.0 * dv_chroma_blur;
            vec3 acc = chroma;
            for(int i = 1; i <= 3; i++){
                vec3 a = fetch_pixel(cpos - px * w * float(i), vec2(0.0));
                vec3 b = fetch_pixel(cpos + px * w * float(i), vec2(0.0));
                acc += (a - vec3(dot(a, lw))) + (b - vec3(dot(b, lw)));
            }
            chroma = mix(chroma, acc / 7.0, dv_chroma_blur);
        }
        // Tape noise correlated along the row: a luma offset per line and
        // a low-frequency colour tint that smears sideways.
        if(line_noise > 0.0 || chroma_noise > 0.0){
            float row = floor(pos.y * resolution.y);
            y += (hash2(vec2(row, fract(st) * 7.0)) - 0.5) * line_noise
                * (0.2 + 0.8 * smoothstep(0.0, 0.22, y));
            if(chroma_noise > 0.0){
                // Smoothed along x — hard per-column tints striped flat
                // walls into visible bands (owner report 2026-08-19).
                float cx = pos.x * resolution.x / 24.0;
                float c0 = floor(cx);
                float f = smoothstep(0.0, 1.0, fract(cx));
                vec2 k0 = vec2(row * 0.37 + c0, fract(st) * 11.0);
                vec2 k1 = vec2(row * 0.37 + c0 + 1.0, fract(st) * 11.0);
                vec3 n0 = vec3(hash2(k0), hash2(k0 + 1.7), hash2(k0 + 3.1));
                vec3 n1 = vec3(hash2(k1), hash2(k1 + 1.7), hash2(k1 + 3.1));
                // Luminance-weighted like the grain: unweighted chroma
                // noise on near-black reads as flashing confetti once the
                // iris lifts a dark floor (Monolith report, 2026-08-20).
                chroma += (mix(n0, n1, f) - 0.5) * 0.035 * chroma_noise
                    * smoothstep(0.02, 0.20, y);
            }
        }
        clr = vec3(y) + chroma * (0.25 + 0.75 * smoothstep(0.02, 0.16, y));
    }
    // Bloom: luminance past the knee smears sideways before it clips.
    if(bloom_amount > 0.0){
        vec2 px = vec2(1.0, 0.0) / resolution;
        vec3 lw = vec3(0.299, 0.587, 0.114);
        vec3 glow = vec3(0.0);
        float wsum = 0.0;
        for(int i = -3; i <= 3; i++){
            if(i == 0) continue;
            float w = 1.0 / (1.0 + abs(float(i)));
            vec3 c = fetch_pixel(pos + px * float(i) * 3.0, vec2(0.0));
            glow += max(c - vec3(bloom_threshold), vec3(0.0)) * w;
            wsum += w;
        }
        glow /= wsum;
        clr += glow * 1.6 * bloom_amount;
    }
    // Signal loss: whole bands of lines lose sync — smeared sideways, then
    // swallowed by static as the loss deepens. Band count and width grow
    // with the amount; at 1.0 most of the raster is gone for a frame.
    if(signal_loss > 0.0){
        float band = floor(pos.y * 18.0);
        float seed = floor(st * 20.0);
        float g = hash2(vec2(band, seed));
        if(g < signal_loss * 0.55){
            float shear = (hash2(vec2(band + 3.0, seed)) - 0.5) * 0.12
                * signal_loss;
            vec3 smear = fetch_pixel(pos + vec2(shear, 0.0), vec2(0.0));
            float stat = random(sq_pix * 3.0 + fract(st * 2.1));
            float swallow = smoothstep(0.25, 1.0, signal_loss)
                * hash2(vec2(band + 9.0, seed));
            clr = mix(smear, vec3(stat) * 0.8, swallow);
        }
    }
    // Luminance ghost: a faint delayed copy trailing to the right, the way a
    // worn head smears bright edges.
    if(ghost_amount > 0.0){
        vec3 ghost = fetch_pixel(pos - vec2(6.0 * ghost_amount, 0.0)
            / resolution, vec2(0.0));
        clr = mix(clr, ghost, 0.12 * ghost_amount);
    }
    // Dropouts: where oxide has flaked the deck's compensator repeats the
    // line above, so the streak is a smeared, slightly lifted copy of the
    // neighbouring picture with soft ends — never a white bar.
    if(dropout_amount > 0.0){
        float ln = floor(pos.y * resolution.y);
        float seed = floor(st * 24.0);
        float gate = hash2(vec2(ln, seed));
        if(gate > 1.0 - 0.009 * dropout_amount){
            float x0 = hash2(vec2(ln * 3.1, seed + 7.0));
            float len = 0.02 + hash2(vec2(ln * 1.7, seed + 3.0)) * 0.10;
            float edge = len * 0.25;
            float in_streak = smoothstep(x0, x0 + edge, pos.x)
                * (1.0 - smoothstep(x0 + len - edge, x0 + len, pos.x));
            vec3 above = fetch_pixel(pos - vec2(0.0, 2.0) / resolution,
                vec2(0.0));
            vec3 smear = (above + fetch_pixel(pos - vec2(3.0, 2.0)
                / resolution, vec2(0.0))) * 0.5;
            float lum = dot(smear, vec3(0.299, 0.587, 0.114));
            vec3 fill = mix(smear, vec3(lum), 0.6) * 1.18 + vec3(0.015);
            clr = mix(clr, fill, in_streak * 0.7);
        }
    }

    if(grille_amount > 0.0)clr *= grille(pix);
    clr *= 1.0 + scan_line_amount * 0.6 + line * 3.0 + grille_amount * 2.0;
    if(vignette_amount > 0.0)clr *= vignette(pos);
    clr *= bright_boost;
    if(auto_exposure > 0.0){
        // Nine fixed taps stand in for a scene average — hint_screen_texture
        // provides no usable mip chain here, and a deep textureLod read
        // returned black, slamming the iris to max gain (2026-08-20).
        float avg = 0.0;
        for(int ax = 0; ax < 3; ax++){
            for(int ay = 0; ay < 3; ay++){
                vec2 at = vec2(0.2 + 0.3 * float(ax), 0.2 + 0.3 * float(ay));
                avg += dot(texture(SCREEN_TEXTURE, at).rgb,
                    vec3(0.299, 0.587, 0.114));
            }
        }
        avg /= 9.0;
        float gain = clamp(ae_target / max(avg, 0.02), 0.42, 1.7);
        clr *= mix(1.0, gain, auto_exposure);
    }
    if(highlight_rolloff > 0.0){
        // Only luminance ABOVE the knee compresses. The base term must be
        // min(l, knee): with a bare knee, every pixel below it was pulled
        // UP to knee level, which pinned the whole frame to a flat beige
        // and silently neutralised boost and iris (found 2026-08-20).
        float l = dot(clr, vec3(0.299, 0.587, 0.114));
        float excess = max(l - highlight_knee, 0.0);
        float target = min(l, highlight_knee)
            + excess / (1.0 + excess * highlight_rolloff);
        clr *= target / max(l, 1e-4);
    }
    // Exposure instability: an auto-iris hunting.
    if(flicker_amount > 0.0){
        float fl = sin(st * 17.0) * 0.35 + sin(st * 7.31) * 0.25
            + (hash1(floor(st * 24.0)) - 0.5) * 0.4;
        clr *= 1.0 + fl * 0.06 * flicker_amount;
    }
    // Colour character: tape washes colour out and lifts contrast, then
    // loses the deepest blacks.
    if(saturation != 1.0 || contrast != 1.0 || black_crush > 0.0){
        float lum = dot(clr, vec3(0.299, 0.587, 0.114));
        clr = mix(vec3(lum), clr, saturation);
        clr = (clr - 0.5) * contrast + 0.5;
        clr = max(clr - vec3(black_crush), vec3(0.0));
    }
    // Head-switching noise: the sync bands at the top and bottom of the
    // raster tear into static, strongest at the very edge.
    if(head_switch_amount > 0.0){
        float fr = floor(st * 30.0);
        float top = smoothstep(0.03, 0.0, SCREEN_UV.y);
        // The switch point wanders a little frame to frame and across x.
        float edge = 0.045 + (hash1(fr + 5.0) - 0.5) * 0.012
            + sin(SCREEN_UV.x * 9.0 + fr) * 0.004;
        float bottom = smoothstep(edge, 0.0, 1.0 - SCREEN_UV.y);
        float n = hash2(vec2(SCREEN_UV.x * 200.0, fr)) - 0.5;
        clr += (top * 0.6 + bottom * 1.6) * n * 0.35 * head_switch_amount;
        // Bottom band also shears sideways, the classic VHS head switch.
        clr = mix(clr, fetch_pixel(pos + vec2(hash1(fr) * 0.02, 0.0),
            vec2(0.0)), bottom * 0.7 * head_switch_amount);
    }

    // Inside the tube recorded black floats above true black; outside the
    // raster stays dark glass. Field parity adds a hair of luminance shimmer.
    bool in_tube = max(abs(pos.x - 0.5), abs(pos.y - 0.5)) <= 0.5;
    if(in_tube){
        if(black_lift > 0.0){
            clr = clr * (1.0 - black_lift) + vec3(black_lift);
        }
        if(field_amount > 0.0){
            clr *= 1.0 - field * 0.02 * field_amount;
        }
    }
    clr *= color_balance;

    if(tube_edge_feather > 0.0){
        float edge_distance = min(min(pos.x, 1.0 - pos.x),
            min(pos.y, 1.0 - pos.y));
        float tube_edge = smoothstep(-tube_edge_feather,
            tube_edge_feather, edge_distance);
        clr *= tube_edge;
    }

    COLOR.rgb = clr;
    COLOR.a = 1.0;
}
