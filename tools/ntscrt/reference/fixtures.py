#!/usr/bin/env python3
"""Generate deterministic tiny CPU goldens and check harness/default semantics."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "build/ntscrt-reference"
BIN = OUT / "target/release/ntscrt-reference"
OUT.mkdir(parents=True, exist_ok=True)
subprocess.run([str(BIN), "metadata", str(OUT / "descriptors.json"), str(OUT / "defaults.json")], check=True)
(OUT / "empty.json").write_text("{}\n")
(OUT / "both.json").write_text('{"use_field":3}\n')
manifest = []
for width, height in [(1, 1), (16, 12), (17, 13)]:
    stem = f"ramp-{width}x{height}"
    src = bytes(c for y in range(height) for x in range(width)
                for c in ((x * 17 + y * 3) % 256, (y * 23 + x * 5) % 256, (x * 13 + y * 11) % 256, 255))
    input_path = OUT / f"{stem}.rgba"
    input_path.write_bytes(src)
    for mode, settings, frame, label in [("roundtrip", "both", 0, "identity"),
                                         ("process", "empty", 0, "default-f0"),
                                         ("process", "empty", 1, "default-f1"),
                                         ("process", "defaults", 0, "explicit-default-f0")]:
        dest = OUT / f"{stem}-{label}.rgba"
        yiq = OUT / f"{stem}-{label}.yiq.f32"
        cmd = [str(BIN), mode, str(width), str(height), str(frame), str(OUT / f"{settings}.json"),
               str(input_path), str(dest), str(yiq)]
        subprocess.run(cmd, check=True)
        first = dest.read_bytes()
        first_yiq = yiq.read_bytes()
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
        assert first == dest.read_bytes() and first_yiq == yiq.read_bytes(), "nondeterminism"
        assert len(first) == len(src)
        if label == "identity":
            max_error = max(abs(a - b) for a, b in zip(first, src))
            assert max_error <= 1, f"RGB/YIQ roundtrip error {max_error}"
        if label == "explicit-default-f0":
            assert first == (OUT / f"{stem}-default-f0.rgba").read_bytes(), "legacy defaults leaked"
            assert first_yiq == (OUT / f"{stem}-default-f0.yiq.f32").read_bytes()
        manifest.append({"case": f"{stem}-{label}", "rgbaSha256": hashlib.sha256(first).hexdigest(),
                         "yiqSha256": hashlib.sha256(first_yiq).hexdigest(), "rgbaBytes": len(first),
                         "yiqBytes": len(first_yiq)})
(OUT / "fixtures.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"PASS: {len(manifest)} cases, deterministic RGBA/YIQ, current-default merge, identity error <=1")
