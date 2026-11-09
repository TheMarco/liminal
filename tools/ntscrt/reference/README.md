# Pinned ntsc-rs CPU reference

This standalone harness executes `ntsc-rs` revision
`add90f5bf1bf7e3c573e4e945a16f44a82941b51` without modifying its sources.
The extracted upstream checkout must already exist at
`build/ntscrt-upstream/ntsc-rs-add90f5bf1bf7e3c573e4e945a16f44a82941b51`.
The relative Cargo path explicitly names that revision. Do not replace its
contents with another revision. Upstream retains its MIT/ISC/Apache-2.0 notices.

Run from the repository root:

```sh
cargo build --locked --release --manifest-path tools/ntscrt/reference/Cargo.toml --target-dir build/ntscrt-reference/target
python3 tools/ntscrt/reference/fixtures.py
python3 tools/ntscrt/verify_ntsc_schema.py
```

`Cargo.lock` was derived from the pinned upstream lock, retaining every used
transitive version, including rand 0.9.2, rand_core 0.9.5, rand_xoshiro 0.7.0,
fearless_simd 0.4.0 and siphasher 1.0.2. Upstream's optional Rayon feature is
turned off; the mathematical pipeline is unchanged and runs serially.
Build products and generated metadata/fixtures live in ignored
`build/ntscrt-reference/`.

## CLI

```sh
build/ntscrt-reference/target/release/ntscrt-reference metadata build/ntscrt-reference/descriptors.json build/ntscrt-reference/defaults.json
build/ntscrt-reference/target/release/ntscrt-reference process 16 12 0 build/ntscrt-reference/empty.json build/ntscrt-reference/ramp-16x12.rgba build/ntscrt-reference/output.rgba build/ntscrt-reference/output.yiq.f32
```

`process WIDTH HEIGHT FRAME SETTINGS INPUT OUTPUT [YIQ_OUTPUT]` accepts
positive dimensions, a nonnegative frame number, flat canonical JSON settings,
and tightly packed RGBA8. Input must contain exactly `width * height * 4` bytes.
It uses the upstream field conversion, scale `[1,1]`, effect pipeline, and Bob
output conversion, matching the sibling C ABI's RGBA path. Optional YIQ output
contains little-endian f32 planes Y, I, Q in upstream YiqView storage order,
excluding scratch. Each plane contains `width * field_rows` floats; stdout
reports the field enum and `field_rows`. Interleaved fields retain upstream
field storage ordering. RGBA output covers the original full image dimensions.

Settings overrides are merged onto **current** `NtscEffectFullSettings::default()`
(which derives from `NtscEffect::default()`) before the upstream preset parser.
This fills every setting so the parser's legacy defaults cannot leak into the
result. Version defaults to 1. Unknown keys are rejected, invalid types/enums
use upstream errors, and out-of-range values use upstream clamping.

`roundtrip` takes the same arguments and bypasses only `apply_effect_to_yiq`;
it measures RGB/YIQ conversion and field reconstruction as an identity baseline.
It is not an effect preset.

## Evidence and limits

The fixture script generates 12 cases across 1x1, 16x12, and odd-sized 17x13
images, including frames 0 and 1, a conversion-only baseline, and explicit
versus implicit current defaults. It verifies repeat execution byte-for-byte
for both RGBA and YIQ, output size, defaults equivalence, and conversion-only
error at most one channel value. `fixtures.json` records SHA-256 hashes.
These tiny cases verify the harness; they do not establish GPU parity.
Floating-point CPU SIMD behavior may vary across target architectures.

Schema verification compares all 62 numeric IDs, names, types, ranges,
logarithmic flags, options and defaults. Percentage ranges are implicitly [0,1]
in the inventory. A mismatch returns nonzero and writes `schema-report.json`.
At initial verification, only the `use_field` options display order differs:
inventory `[0,4,5,1,2,3]`, upstream `[0,1,2,4,5,3]`. Enum values and defaults
match; the inventory is intentionally not rewritten by this tool.
