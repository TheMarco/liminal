#!/usr/bin/env python3
"""Render trailer shots sequentially using the real Godot project."""
import argparse
import json
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "build/promo-trailer-v6"
SHOTS = {
    "casino_traverse": (1, 135), "office_traverse": (3, 135),
    "annex_traverse": (9, 120), "school_traverse": (5, 120), "server_traverse": (10, 120),
    "pool_grand": (8, 135), "pool_floaties": (8, 120), "pool_girl": (8, 135),
    "casino": (1, 90), "office": (3, 75), "annex": (9, 75),
    "pool": (8, 90), "school": (5, 75), "server": (10, 90),
    "casino_kill": (1, 135), "office_kill": (3, 135),
    "annex_kill": (9, 135), "school_kill": (5, 135), "server_kill": (10, 135),
    "wave": (3, 180), "breath": (9, 150), "doors": (3, 120),
    "annex_flood": (9, 135), "portal": (2, 240), "death": (9, 75),
    "cross_warning": (1, 125), "cross_stay": (1, 180),
    "annex_run": (9, 90), "school_run": (5, 90), "pool_hero": (8, 90),
}

def main():
    p = argparse.ArgumentParser()
    p.add_argument("shots", nargs="*", choices=list(SHOTS))
    p.add_argument("--probe", action="store_true")
    args = p.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for name in args.shots or list(SHOTS):
        floor, count = SHOTS[name]
        if args.probe:
            count = 2
        cmd = ["godot", "--path", str(ROOT), "--minimized", "--audio-driver", "Dummy",
               "--fixed-fps", "30", "--disable-render-loop", "--script", "tools/trailer_capture.gd",
               "--log-file", str(OUT / (name + ".godot.log")), "--", "--nologo", "--test-mode",
               "--seed=240721" if name == "pool_floaties" else "--seed=21", f"--descent-floor={floor}", f"--shot={name}", f"--frames={count}",
               "--vhs", "--no-crt"]
        if args.probe:
            cmd += ["--small", "--out=" + str(OUT / "probe")]
        start = time.time()
        print("RENDER_START", name, count, flush=True)
        with (OUT / (name + ".process.log")).open("w") as log:
            proc = subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=420)
        text = (OUT / (name + ".process.log")).read_text()
        ok = proc.returncode == 0 and f"TRAILER_DONE {name} frames={count}" in text and 'SCRIPT ERROR' not in text
        print("RENDER_END", name, "OK" if ok else "FAILED", round(time.time()-start, 1), flush=True)
        records.append({"shot": name, "floor": floor, "frames":count,"ok":ok})
        if not ok:
            print(text[-4500:], flush=True)
            raise SystemExit(1)
    (OUT / "last-render.json").write_text(json.dumps(records, indent=2))

if __name__ == "__main__":
    main()
