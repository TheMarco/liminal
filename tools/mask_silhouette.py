#!/usr/bin/env python3
"""Turn a dark figure photographed/painted on white into a soft black cutout.

The generated art comes as ink-on-white: every pixel is white paper showing
through some amount of figure. So coverage is simply how far the pixel fell
from the paper, and that coverage IS the alpha — no thresholding. Smoke,
loose hair and blurred hands survive as partial alpha instead of being
chopped into a hard outline, which is the whole point for these.

    observed = paper * (1 - a)   (the ink is black)  =>  a = 1 - observed/paper

Writes a black RGBA PNG, autocropped and scaled to 512px tall, ready for
textures/ghosts/ and shaders/ghost.gdshader.

    python3 tools/mask_silhouette.py in.png out.png [--gain 1.2] [--floor 0.05]
    python3 tools/mask_silhouette.py out.png --measure   # numbers for BODY
"""

import argparse
import sys

import numpy as np
from PIL import Image

HEIGHT = 512
PAD = 5  # px of breathing room at output scale; the shader eats edges


def coverage(
    path: str, floor: float, gain: float, gamma: float, ground: float,
    band: float, trim: float
) -> np.ndarray:
    im = Image.open(path).convert("L")
    lum = np.asarray(im, dtype=np.float32) / 255.0
    # the paper, not the brightest speck of it
    paper = float(np.percentile(lum, 95.0))
    a = np.clip((paper - lum) / max(paper, 1e-4), 0.0, 1.0)
    # sensor grain and compression fuzz read as a faint everywhere-haze
    cut = np.full_like(a, floor)
    if ground > 0.0:
        # Several were rendered standing on a floor, and brought the cast
        # shadow with them. On a billboard that becomes a black puddle hanging
        # in the air. The shadow is faint where the feet are solid, so a
        # harder cut ramped into the bottom of the frame takes the one and
        # leaves the other.
        y = np.linspace(0.0, 1.0, a.shape[0], dtype=np.float32)[:, None]
        ramp = np.clip((y - (1.0 - band)) / max(band, 1e-4), 0.0, 1.0)
        cut = np.maximum(cut, floor + ground * ramp)
    a = np.clip((a - cut) / np.maximum(1.0 - cut, 1e-4), 0.0, 1.0)
    if trim > 0.0:
        # A pooled cast shadow can be as dark as the feet standing in it, so
        # no threshold will separate them. Cut it off instead: the figure ends
        # at the floor line, which is where a billboard meets the floor anyway.
        a = a[: int(a.shape[0] * (1.0 - trim))]
    if gamma != 1.0:
        a = np.power(a, gamma)
    if gain != 1.0:
        a = np.clip(a * gain, 0.0, 1.0)
    return a


def crop_box(a: np.ndarray, thresh: float) -> tuple[int, int, int, int]:
    rows = np.where(a.max(axis=1) > thresh)[0]
    cols = np.where(a.max(axis=0) > thresh)[0]
    if rows.size == 0 or cols.size == 0:
        sys.exit("nothing found above the paper — bad floor/threshold?")
    return int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1


def measure(path: str) -> None:
    """Report a finished cutout as shadow_figure.gd's BODY wants it.

    Haze, smoke and blur run past the body at both ends of the file, so a
    quad sized to the file stands the figure short with its feet off the
    floor. These are where the body itself starts and stops.
    """
    a = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32)[..., 3]
    rows = np.where(a.max(axis=1) >= 0.45 * 255.0)[0]
    if rows.size == 0:
        sys.exit(f"{path}: no solid body found")
    h = a.shape[0]
    name = path.split("/")[-1].removesuffix(".png")
    print(
        f'\t"{name}":{" " * max(1, 12 - len(name))}[{a.shape[1] / h:.3f}, '
        f"{1.0 - (rows[-1] + 1) / h:.3f}, {1.0 - rows[0] / h:.3f}],"
    )


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("dst", nargs="?")
    p.add_argument("--floor", type=float, default=0.05, help="grain cut, 0-1")
    p.add_argument("--gain", type=float, default=1.0, help="opacity multiplier")
    p.add_argument("--gamma", type=float, default=1.0, help="<1 lifts the haze")
    p.add_argument("--ground", type=float, default=0.0, help="cast-shadow cut")
    p.add_argument("--band", type=float, default=0.22, help="ground cut height")
    p.add_argument("--trim", type=float, default=0.0, help="drop the bottom")
    p.add_argument("--melt", type=float, default=0.0, help="dissolve the base")
    p.add_argument("--crop", type=float, default=0.04, help="autocrop threshold")
    p.add_argument("--height", type=int, default=HEIGHT)
    p.add_argument("--measure", action="store_true",
                   help="report a finished cutout for BODY, do not convert")
    args = p.parse_args()

    if args.measure:
        measure(args.src)
        return
    if args.dst is None:
        sys.exit("need an output path")

    a = coverage(args.src, args.floor, args.gain, args.gamma, args.ground, args.band,
                 args.trim)
    x0, y0, x1, y1 = crop_box(a, args.crop)
    a = a[y0:y1, x0:x1]

    if args.melt > 0.0:
        # and the last of it dissolves before it reaches the ground
        y = np.linspace(0.0, 1.0, a.shape[0], dtype=np.float32)[:, None]
        a = a * np.clip((1.0 - y) / max(args.melt, 1e-4), 0.0, 1.0)

    h = args.height - PAD * 2
    w = max(1, round(a.shape[1] * h / a.shape[0]))
    alpha = Image.fromarray((a * 255.0 + 0.5).astype(np.uint8)).resize(
        (w, h), Image.LANCZOS
    )

    out = Image.new("RGBA", (w + PAD * 2, args.height), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (w, h), (0, 0, 0, 255)), (PAD, PAD), alpha)
    out.save(args.dst)
    solid = float((np.asarray(alpha, dtype=np.float32) / 255.0 > 0.9).mean())
    print(
        f"{args.dst}  {out.width}x{out.height}  aspect {out.width / out.height:.3f}"
        f"  solid {solid * 100:.0f}%"
    )


if __name__ == "__main__":
    main()
