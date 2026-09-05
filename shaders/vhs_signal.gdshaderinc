// Recovered tape: bandwidth-limited Y/C signal and playback faults.
// crt_display.gdshader receives this flat signal in a separate display pass.
// Visual references: AV Artifact Atlas (time-base error, Y/C delay, dropout,
// head switching) and Tektronix's NTSC Video Measurements guide.
// No frame history is available in this pass: the field treatment approximates
// interlaced playback; it deliberately does not invent motion-combing trails.
uniform bool tape_signal = false;
uniform float tracking_error : hint_range(0.0, 1.0) = 0.0;
uniform float tracking_y : hint_range(0.0, 1.0) = 0.6;
uniform float chroma_loss : hint_range(0.0, 1.0) = 0.0;
uniform float vertical_slip : hint_range(-1.0, 1.0) = 0.0;
// Live-feed wear is opt-in. The in-world tape preset keeps these at zero.
uniform float rf_noise : hint_range(0.0, 1.0) = 0.0;
uniform float sync_error : hint_range(0.0, 1.0) = 0.0;
uniform float tape_speckle : hint_range(0.0, 1.0) = 0.0;
// Opposing colour-channel delay within the horizontal chroma filter.
// Zero keeps the base recording preset; the live camera opts into extra wear.
uniform float chroma_misalignment : hint_range(0.0, 1.0) = 0.0;
// Visible camera-channel registration error, in emulated signal pixels.
// This also fringes neutral edges, where shifting I/Q alone has little effect.
uniform float rgb_split_px : hint_range(0.0, 5.0) = 0.0;
// Deterministic visual QA; negative values use the live signal clock.
uniform float tape_time = -1.0;

// Every fragment used the same nine source samples for exposure. Evaluate
// them at the quad vertices instead; flat interpolation preserves that one
// value across the whole image, using this pass's current screen copy.
varying flat float tape_exposure_gain;

float tape_hash(vec2 p) {
    // Multiplication hash avoids large sin() seeds losing precision over time.
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float tape_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(tape_hash(cell), tape_hash(cell + vec2(1, 0)), f.x),
        mix(tape_hash(cell + vec2(0, 1)), tape_hash(cell + vec2(1, 1)), f.x), f.y);
}

vec3 tape_sample(vec2 p) {
    return textureLod(SCREEN_TEXTURE, clamp(p, vec2(0.001), vec2(0.999)), 0.0).rgb;
}

vec3 tape_yiq(vec3 c) {
    return vec3(dot(c, vec3(0.299, 0.587, 0.114)),
        dot(c, vec3(0.596, -0.274, -0.322)),
        dot(c, vec3(0.211, -0.523, 0.312)));
}

float tape_exposure() {
    float gain = 1.0;
    if (auto_exposure > 0.0) {
        float avg = 0.0;
        for (int ax = 0; ax < 3; ax++) {
            for (int ay = 0; ay < 3; ay++) {
                avg += tape_yiq(tape_sample(vec2(0.2 + float(ax) * 0.3,
                    0.2 + float(ay) * 0.3))).x;
            }
        }
        gain = mix(1.0, clamp(ae_target / max(avg / 9.0, 0.02), 0.6, 1.6), auto_exposure);
    }
    return gain;
}

vec3 tape_rgb(vec3 c) {
    return vec3(c.x + 0.956 * c.y + 0.621 * c.z,
        c.x - 0.272 * c.y - 0.647 * c.z,
        c.x - 1.106 * c.y + 1.703 * c.z);
}

vec3 recovered_tape(vec2 screen_uv, vec2 screen_pixel_size, vec2 fragcoord) {
    float t = tape_time >= 0.0 ? tape_time : TIME;
    float fps = signal_fps > 0.0 ? signal_fps : 29.97;
    float frame = floor(t * fps);
    float field = floor(t * fps * 2.0);
    vec2 px = 1.0 / resolution;
    float aspect = screen_pixel_size.y / screen_pixel_size.x;
    vec2 pos = screen_uv;
    // A trace of field weave, not a full-picture half-line jump every field.
    pos.y += (mod(field, 2.0) - 0.5) * field_amount * 0.22 * px.y;
    float row = floor(pos.y * resolution.y);
    float halo = 0.0;
    if (entity_amt > 0.001) {
        vec2 rel = (screen_uv - entity_pos) * vec2(aspect, 1.0);
        halo = (1.0 - smoothstep(entity_radius * 0.35,
            max(entity_radius, 0.001), length(rel))) * entity_amt;
    }
    // Time-base error is predominantly horizontal and correlated across rows.
    // Slow transport wander + line flutter; no persistent leftward hash bias.
    float wander = tape_noise(vec2(t * 1.7, 8.2)) - 0.5;
    float flutter = tape_noise(vec2(pos.y * 22.0, t * 11.0)) - 0.5;
    float line_jitter = tape_hash(vec2(row, field)) - 0.5;
    pos.x += (wander * jitter_amount * 3.0
        + flutter * wobble_amount * 5.0
        + line_jitter * (interference_amount + halo * 1.3)) * px.x;

    // One damaged swath moves through the raster and settles, rather than
    // displacing a random selection of rectangular blocks over the whole image.
    float track_width = mix(0.008, 0.075, tracking_error);
    float track = (1.0 - smoothstep(track_width * 0.2, track_width,
        abs(pos.y - tracking_y))) * tracking_error;
    float skew = (tape_noise(vec2(row * 0.12, field)) - 0.5) * 2.0;
    pos.x += (track * (12.0 + skew * 28.0)
        + halo * line_jitter * 5.0) * px.x;
    pos.y += vertical_slip * 5.0 * px.y;
    if (sync_error > 0.0) {
        // A brief loss of horizontal lock hooks the upper picture sideways;
        // the transport's vertical bob is supplied by the event envelope.
        float hook = 1.0 - smoothstep(0.0, 0.22, pos.y);
        float direction = tape_hash(vec2(floor(field / 3.0), 81.0)) - 0.5;
        pos.x += (hook * direction * 42.0 + line_jitter * 3.0)
            * sync_error * px.x;
    }
    // Brief crease flutter also exists on the television's independent feed.
    float cycle = floor(t / 7.0);
    float age = mod(t, 7.0);
    float crease_start = 1.0 + tape_hash(vec2(cycle, 14.0)) * 4.8;
    float crease_p = (age - crease_start) / 0.16;
    float crease_env = smoothstep(0.0, 0.15, crease_p)
        * (1.0 - smoothstep(0.35, 1.0, crease_p));
    float crease_y = tape_hash(vec2(cycle, 26.0));
    float crease = (1.0 - smoothstep(0.002, 0.009,
        abs(pos.y - crease_y))) * crease_env * tear_amount;
    pos.x += crease * skew * 16.0 * px.x;

    // Head switch occurs at the foot of the raster, partially hidden by
    // overscan. Only a few rows are exposed, with stronger noise on a bad lock.
    float switch_line = 0.986 + (tape_hash(vec2(field, 4.0)) - 0.5) * 0.004;
    float head = smoothstep(switch_line, switch_line + 0.007, pos.y)
        * head_switch_amount;
    pos.x += head * (line_jitter * 24.0 + 4.0) * px.x;

    // Luma retains edges; low-bandwidth colour spreads considerably farther.
    // Sampling stays continuous horizontally: VHS has no rectangular pixels.
    float luma_width = mix(0.45, 1.55, dv_blur);
    vec3 source_center = tape_sample(pos);
    vec3 center = tape_yiq(source_center);
    vec3 left = tape_yiq(tape_sample(pos - vec2(px.x * luma_width, 0.0)));
    vec3 right = tape_yiq(tape_sample(pos + vec2(px.x * luma_width, 0.0)));
    float far_left = tape_yiq(tape_sample(pos - vec2(px.x * luma_width * 2.0, 0.0))).x;
    float far_right = tape_yiq(tape_sample(pos + vec2(px.x * luma_width * 2.0, 0.0))).x;
    float y = center.x * 0.40 + (left.x + right.x) * 0.24
        + (far_left + far_right) * 0.06;
    // Restrained edge peaking / a delayed luma echo, not an RGB duplicate.
    y += (center.x - (left.x + right.x) * 0.5) * 0.10;
    float echo = tape_yiq(tape_sample(pos - vec2(5.0 * px.x, 0))).x;
    y = mix(y, echo, ghost_amount * 0.09);
    float chroma_wander = (tape_noise(vec2(t * 0.7, pos.y * 3.0)) - 0.5)
        * (0.45 + aberation_amount * 3.0 + halo * 3.0);
    vec2 cpos = pos - vec2((chroma_delay + chroma_wander) * px.x, 0.0);
    float cwidth = mix(1.0, 6.0, dv_chroma_blur);
    // Unequal I/Q response makes colour edges sit slightly out of register.
    // Bias the existing filter taps in opposite directions: their total
    // weight stays one, so flat colours and the luma silhouette stay stable.
    // Transport wander slowly changes the separation; faults exaggerate it.
    float separation = clamp(chroma_misalignment
        * (0.48 + aberation_amount * 0.28 + chroma_wander * 0.08 + halo * 0.2),
        0.0, 0.75);
    vec2 channel_bias = vec2(separation, -separation);
    vec2 iq = tape_yiq(tape_sample(cpos)).yz * 0.28;
    for (int i = 1; i <= 3; i++) {
        float weight = i == 1 ? 0.22 : (i == 2 ? 0.10 : 0.04);
        vec2 off = vec2(float(i) * cwidth * px.x, 0);
        iq += (tape_yiq(tape_sample(cpos - off)).yz * (vec2(1.0) + channel_bias)
            + tape_yiq(tape_sample(cpos + off)).yz * (vec2(1.0) - channel_bias)) * weight;
    }
    if (rgb_split_px > 0.0) {
        // Offset red and blue around the green/luma anchor. Feed only the
        // resulting colour difference into the decoded signal: edges acquire
        // red/cyan and blue/yellow fringes without doubling the silhouette.
        // Keep this narrower than the broad chroma bleed so muted rooms and
        // white OSD lettering show the registration error clearly.
        float split = rgb_split_px * clamp(1.0 + aberation_amount * 0.6
            + chroma_wander * 0.12 + halo * 0.5, 0.75, 1.8);
        vec2 offset = vec2(split * px.x, 0.0);
        vec3 separated = vec3(tape_sample(pos - offset).r, source_center.g,
            tape_sample(pos + offset).b);
        iq += (tape_yiq(separated).yz - center.yz) * 0.8;
    }
    // Low-level chroma phase drift, with short colour unlocks during faults.
    float phase = (tape_noise(vec2(t * 0.45, pos.y * 2.0)) - 0.5) * 0.025
        + track * skew * 0.32;
    iq = mat2(vec2(cos(phase), sin(phase)), vec2(-sin(phase), cos(phase))) * iq;
    iq *= saturation * (1.0 - chroma_loss) * (1.0 - track * 0.65);

    // Signed noise follows the signal clock; dark picture retains fine luma
    // noise, but colour falls away near black instead of flashing confetti.
    float grain = tape_hash(vec2(floor(pos.x * resolution.x), row) + frame * vec2(17, 31)) - 0.5;
    float shadow_noise = mix(0.72, 1.0, smoothstep(0.03, 0.4, y));
    y += grain * noise_level * noise_amount * shadow_noise;
    y += line_jitter * line_noise;
    vec2 cn = vec2(tape_noise(vec2(pos.x * 75.0, row + frame * 7.0)),
        tape_noise(vec2(pos.x * 63.0 + 52.0, row + frame * 11.0))) - 0.5;
    iq += cn * chroma_noise * 0.022 * smoothstep(0.015, 0.18, y);

    // Dropout compensation borrows a neighbouring line. Small white/dark RF
    // pin streaks ride the damaged section, never a flat full-width white bar.
    float dropout_gate = tape_hash(vec2(row, frame + 93.0));
    if (dropout_gate > 1.0 - dropout_amount * 0.014) {
        float start = tape_hash(vec2(row + 7.0, frame));
        float span = 0.012 + tape_hash(vec2(row + 19.0, frame)) * 0.12;
        float streak = smoothstep(start, start + 0.004, pos.x)
            * (1.0 - smoothstep(start + span - 0.008, start + span, pos.x));
        vec3 previous = tape_yiq(tape_sample(pos - vec2(px.x * 2.0, px.y * 2.0)));
        y = mix(y, previous.x + grain * 0.14, streak * 0.85);
        iq *= 1.0 - streak * 0.7;
    }
    float rf = max(track * 0.7, max(head * 0.55, crease * 0.3));
    // Gameplay signal loss remains legible away from the damaged swath.
    rf = max(rf, signal_loss * (0.12 + 0.65 * track));
    y = mix(y, 0.12 + grain * 0.42, clamp(rf, 0.0, 0.9));
    iq *= 1.0 - rf;

    if (tape_speckle > 0.0) {
        // Dust / damaged oxide: short bright pins and trailing dark streaks.
        // Correlated along a scanline and stepped at the tape frame rate.
        float hit = tape_hash(vec2(row + 149.0, frame));
        if (hit > 1.0 - tape_speckle * 0.028) {
            float x0 = tape_hash(vec2(row, frame + 201.0));
            float length_px = 2.0 + tape_hash(vec2(row, frame + 209.0)) * 14.0;
            float dx = (pos.x - x0) * resolution.x;
            float pin = smoothstep(-1.0, 0.0, dx) * (1.0 - smoothstep(0.5, 2.5, dx));
            float tail = smoothstep(1.0, 3.0, dx) * (1.0 - smoothstep(3.0, length_px + 3.0, dx));
            float polarity = tape_hash(vec2(row, frame + 251.0)) > 0.3 ? 1.0 : -1.0;
            y += (pin * 0.28 - tail * 0.09) * polarity;
            iq *= 1.0 - max(pin, tail) * 0.65;
        }
    }
    if (rf_noise > 0.0) {
        // RF snow arrives in a swath, with a fine residue over the rest of
        // the picture. Its ragged row edges follow the unstable tape signal.
        float distance_to_noise = abs(pos.y - tracking_y + line_jitter * 0.018);
        float swath = 1.0 - smoothstep(0.025, 0.16, distance_to_noise);
        float snow = tape_hash(vec2(floor(pos.x * resolution.x * 1.4), row)
            + frame * vec2(29.0, 13.0));
        float amount = rf_noise * (0.09 + swath * 0.68);
        y = mix(y, snow * 0.65, amount);
        iq *= 1.0 - amount;
    }

    vec3 clr = max(tape_rgb(vec3(y, iq)), vec3(0.0));
    clr *= bright_boost * tape_exposure_gain;
    clr *= 1.0 + (tape_noise(vec2(t * 2.4, 30.0)) - 0.5) * 0.04 * flicker_amount;
    float lum = max(tape_yiq(clr).x, 0.0001);
    float excess = max(lum - highlight_knee, 0.0);
    float shoulder = min(lum, highlight_knee) + excess / (1.0 + excess * highlight_rolloff);
    clr *= shoulder / lum;
    clr = max((clr - 0.5) * contrast + 0.5 - black_crush, vec3(0));
    clr = clr * (1.0 - black_lift) + black_lift;
    clr *= color_balance;

    return clamp(clr, vec3(0), vec3(1));
}
