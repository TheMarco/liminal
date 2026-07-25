#!/usr/bin/env python3
"""Turn a white-background looping video into a ghost sprite-sheet with alpha.

Godot's only video codec is Theora, which carries no alpha channel, so a video
cannot be a silhouette. A flipbook can: one texture, frames cycled by offsetting
UVs in the shader that already draws the ghosts.

Usage: build_flipbook.py SRC.mp4 OUT.png [--frames 24] [--height 288]
"""
import argparse, os, subprocess, sys, tempfile
from PIL import Image
import numpy as np


def extract(src, tmp, want):
    """Evenly spaced frames across the whole loop."""
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-count_frames",
         "-show_entries", "stream=nb_read_frames",
         "-of", "default=nokey=1:noprint_wrappers=1", src],
        capture_output=True, text=True).stdout.strip()
    total = int(probe)
    picks = [round(i * total / want) for i in range(want)]
    # a select expression is one decode pass rather than `want` seeks
    expr = "+".join("eq(n\\,%d)" % n for n in picks)
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", src,
         "-vf", "select='%s'" % expr, "-vsync", "0",
         os.path.join(tmp, "f%03d.png")], check=True)
    return sorted(os.listdir(tmp)), total


def to_alpha(img, white, floor):
    """Background out, alpha in, colour kept.

    Alpha comes from how far a pixel is from the backdrop rather than from
    luminance, so the red eyes stay fully opaque instead of reading as mid-grey
    haze and being half-erased. The backdrop is not pure white — this source
    sits around 227-241 — so the white point has to be measured, not assumed,
    or every frame keeps a full-bleed grey wash and nothing ever crops.
    """
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    alpha = (white - a.min(axis=2)) / white
    alpha = np.clip(alpha, 0.0, 1.0)
    alpha[alpha < floor] = 0.0           # kill the residual wash
    # lift the faint smoke a little; it is what sells the shape
    alpha = np.clip(alpha ** 0.88 * 1.08, 0.0, 1.0)
    rgb = np.clip(a / 255.0, 0.0, 1.0)
    out = np.dstack([rgb, alpha[..., None]])
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def white_point(img):
    """Darkest the backdrop gets, from the frame border."""
    a = np.asarray(img.convert("RGB")).astype(np.float32).min(axis=2)
    edge = np.concatenate([a[:6].ravel(), a[-6:].ravel(),
                           a[:, :6].ravel(), a[:, -6:].ravel()])
    return float(np.percentile(edge, 2.0))


def detect_shadow(frames):
    """How much of the bottom is the source's composited ground contact.

    Width is the discriminator, not opacity: a smoke tail tapers to a fifth of
    the body's width, while a cast shadow or fog pool stays as wide as the
    figure or wider. Judging by alpha instead lets a bright pool pass as body
    and amputates the tails on the ones that hover.
    """
    a = np.mean([np.asarray(f)[..., 3].astype(np.float32) for f in frames],
                axis=0) / 255.0
    h, w = a.shape
    spans = np.zeros(h)
    for y in range(h):
        lit = np.flatnonzero(a[y] > 0.05)
        spans[y] = (lit[-1] - lit[0] + 1) if len(lit) else 0.0
    body = float(np.median(spans[int(h * 0.25):int(h * 0.75)]))
    if body <= 0.0:
        return 0.0
    limit = int(h * 0.22)
    cut = 0
    for y in range(h - 1, h - 1 - limit, -1):
        wide = spans[y] > body * 0.45
        faint = a[y].max() < 0.55
        if spans[y] == 0.0 or (wide and faint):
            cut = h - y
        else:
            break
    return min(cut / float(h), 0.22)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--frames", type=int, default=24)
    ap.add_argument("--height", type=int, default=288)
    ap.add_argument("--cols", type=int, default=6)
    ap.add_argument("--floor", type=float, default=0.06,
                    help="alpha below this is treated as backdrop")
    ap.add_argument("--ground", type=float, default=-1.0,
                    help="fade out the bottom fraction; -1 detects the cast "
                         "shadow instead of assuming a fixed band")
    args = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        names, total = extract(args.src, tmp, args.frames)
        raws = [Image.open(os.path.join(tmp, n)).copy() for n in names]
    white = min(white_point(r) for r in raws)
    print("extracted %d of %d source frames; backdrop white point %.0f"
          % (len(raws), total, white))
    frames = [to_alpha(r, white, args.floor) for r in raws]

    # One bounding box for the whole loop. Cropping each frame to its own
    # content would make the figure jitter and change size as it plays.
    box = None
    for f in frames:
        a = np.asarray(f)[..., 3]
        ys, xs = np.nonzero(a > 6)
        if len(xs) == 0:
            continue
        b = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]),
                                     max(box[2], b[2]), max(box[3], b[3]))
    frames = [f.crop(box) for f in frames]
    print("common content box %s -> %dx%d" % (box, frames[0].width,
                                              frames[0].height))

    # The source composites a soft cast-shadow ellipse under the figure. On a
    # transparent billboard that becomes a grey oval hanging at its feet, so
    # the bottom band is faded out — over a ramp, not a hard line, or the smoke
    # tendrils end in a visible cut.
    ground = args.ground
    if ground < 0.0:
        ground = detect_shadow(frames)
        print("detected cast shadow over the bottom %.0f%%" % (ground * 100))
    if ground > 0.0:
        h = frames[0].height
        band = max(1, int(h * ground))
        ramp = np.ones(h, dtype=np.float32)
        ramp[h - band:] = np.linspace(1.0, 0.0, band)
        out = []
        for f in frames:
            a = np.asarray(f).astype(np.float32)
            a[..., 3] *= ramp[:, None]
            out.append(Image.fromarray(a.astype(np.uint8), "RGBA"))
        frames = out
        print("faded the bottom %.0f%% to drop the cast shadow"
              % (ground * 100))

    fh = args.height
    fw = max(1, round(frames[0].width * fh / frames[0].height))
    frames = [f.resize((fw, fh), Image.LANCZOS) for f in frames]

    cols = args.cols
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % cols) * fw, (i // cols) * fh))
    sheet.save(args.dst)
    print("%s  %dx%d  %d frames  %d cols x %d rows  frame %dx%d  %.0f KB" % (
        args.dst, sheet.width, sheet.height, len(frames), cols, rows, fw, fh,
        os.path.getsize(args.dst) / 1024))
    print()
    print("shader constants:  cols=%d rows=%d frames=%d  aspect=%.4f" % (
        cols, rows, len(frames), fw / float(fh)))


if __name__ == "__main__":
    main()
