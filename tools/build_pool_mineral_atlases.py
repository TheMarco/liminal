#!/usr/bin/env python3
"""Build tile-aware Poolrooms mineral masks from authored reference scans.

The authored scans photograph bright calcite crust growing on clean white
tile.  This tool keeps only that crust.  The response keys on the deposit
being brighter and rougher than the tile face it grows on; the photographed
grout grid is dark, narrow and straight, so it is detected on darkness and
deleted outright (crust covering grout is bright, so the deletion cannot eat
the effect being kept).  Isolated dust is dropped while crystalline spray
near the main deposit survives, and every cell ends in a guaranteed
transparent falloff before packing into two deterministic 4x2 atlases.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def _smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    t = np.clip((value - edge0) / max(edge1 - edge0, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _edge_fade(height: int, width: int, fraction: float) -> np.ndarray:
    yy, xx = np.mgrid[0:height, 0:width]
    distance = np.minimum.reduce((xx, width - 1 - xx, yy, height - 1 - yy))
    return _smoothstep(0.0, max(2.0, min(height, width) * fraction), distance)


def _crust_response(rgb: np.ndarray) -> np.ndarray:
    """Score how strongly each pixel reads as deposit rather than tile.

    The crust is brighter than a broad local exposure model and carries far
    more high-frequency relief than the smooth tile face, so brightness
    excess and texture energy vote together.
    """
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.float32)
    base = cv2.GaussianBlur(gray, (0, 0), max(24.0, min(gray.shape) / 22.0))
    brightness = np.clip(gray - base, 0.0, None)
    fine = gray - cv2.GaussianBlur(gray, (0, 0), 2.0)
    energy = cv2.GaussianBlur(np.abs(fine), (0, 0), 4.0)
    response = brightness * 3.0 + energy * 7.0
    return cv2.GaussianBlur(response, (0, 0), 2.0)


def _ellipse(size: int) -> np.ndarray:
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (size, size))


def _deposit_mask(response: np.ndarray) -> np.ndarray:
    """Keep the deposit and its nearby spray; delete the photographed grid.

    Grout lines and the deposit differ in scale and shape, not polarity: the
    crust body survives an opening that erases every thin line, and straight
    line runs are deleted only outside the thick core so they can never cut
    a slot through the deposit itself.
    """
    height, width = response.shape
    span = min(height, width)
    binary = (response > 34.0).astype(np.uint8)
    # The opening disk must be wider than a photographed grout course or bare
    # grout survives as part of the core and its protection zone.
    core = cv2.morphologyEx(binary, cv2.MORPH_OPEN,
        _ellipse(max(25, (span // 36) | 1)))
    if not core.any():
        return np.zeros_like(response)
    # Grid intersections carry just enough buildup to seed a small core each,
    # which would protect the whole photographed grid. Only components in the
    # same class as the largest deposit count.
    count, labels, stats, _ = cv2.connectedComponentsWithStats(core, 8)
    areas = stats[1:, cv2.CC_STAT_AREA]
    keep_ids = 1 + np.flatnonzero(areas >= areas.max() * 0.12)
    core = np.isin(labels, keep_ids).astype(np.uint8)
    zone = cv2.dilate(core, _ellipse(max(41, (span // 20) | 1)))
    run = max(61, span // 30)
    lines = binary * 0
    for kernel_size in ((run, 3), (3, run), (run * 2, 1), (1, run * 2)):
        lines = np.maximum(lines, cv2.morphologyEx(binary, cv2.MORPH_OPEN,
            cv2.getStructuringElement(cv2.MORPH_RECT, kernel_size)))
    near_core = cv2.dilate(core, _ellipse(13))
    keep = binary & zone & ~(lines & ~near_core)
    return cv2.GaussianBlur(keep.astype(np.float32), (5, 5), 0)


def _mineral_colour(rgb: np.ndarray) -> np.ndarray:
    """Preserve the crust's layered colour, lifted toward dry chalk.

    The game's tile albedo is bright and the Poolrooms are lit by soft
    omnidirectional fog light, so anything darker than the tile reads as
    grime rather than mineral. Raising the pivot keeps the crust's relative
    layering while landing it slightly brighter than the tile it sits on.
    """
    source = rgb.astype(np.float32) / 255.0
    colour = (source - 0.5) * 1.32 + 0.56
    colour *= np.array([1.0, 0.99, 0.94], dtype=np.float32)
    return np.clip(colour * 255.0, 32.0, 250.0).astype(np.uint8)


def _grout_cross_centre(gray: np.ndarray) -> tuple[int, int]:
    """Locate the photographed grout crossing near the image centre.

    The scans do not place their cross exactly at the centre, and the runtime
    shader anchors cell centres on the game's grout intersections — an
    uncorrected offset paints every deposit beside its crossing.
    """
    closed = cv2.morphologyEx(gray, cv2.MORPH_CLOSE, _ellipse(51))
    darkness = np.clip(closed - gray, 0.0, None)

    def peak(profile: np.ndarray) -> int:
        smooth = cv2.GaussianBlur(profile.reshape(1, -1), (0, 0), 9.0).ravel()
        lo = smooth.size // 3
        return lo + int(np.argmax(smooth[lo:smooth.size * 2 // 3]))

    return peak(darkness.mean(axis=0)), peak(darkness.mean(axis=1))


def _raw_mask(rgb: np.ndarray) -> np.ndarray:
    response = _crust_response(rgb)
    return np.clip((response - 26.0) * 1.8, 0.0, 255.0) * _deposit_mask(response)


def _arm_offset(mask: np.ndarray) -> tuple[int, int]:
    """Measure where the extracted crusted arms actually sit in the crop.

    The darkness-based cross detection is biased wherever crust covers part
    of a grout course, so the crop is refined against the arms the extraction
    itself produced: the columns and rows with the longest strong-alpha runs.
    """
    strong = (mask > 128.0).astype(np.float32)
    col = cv2.GaussianBlur(strong.sum(axis=0).reshape(1, -1), (0, 0), 2.0).ravel()
    row = cv2.GaussianBlur(strong.sum(axis=1).reshape(1, -1), (0, 0), 2.0).ravel()

    def near_centre_peak(profile: np.ndarray) -> int:
        # The darkness estimate is already close; a peak far from centre is a
        # dense crust column, not the arm.
        centre = profile.size // 2
        window = profile.size // 6
        return centre - window + int(np.argmax(profile[centre - window:centre + window]))

    return (near_centre_peak(col) - mask.shape[1] // 2,
        near_centre_peak(row) - mask.shape[0] // 2)


def _centred_grout_crop(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.float32)
    cx, cy = _grout_cross_centre(gray)
    height, width = gray.shape
    for _ in range(3):
        half = min(cx, width - 1 - cx, cy, height - 1 - cy)
        crop = rgb[cy - half:cy + half, cx - half:cx + half]
        mask = _raw_mask(crop)
        dx, dy = _arm_offset(mask)
        limit = half // 8
        if abs(dx) <= 3 and abs(dy) <= 3:
            break
        cx += int(np.clip(dx, -limit, limit))
        cy += int(np.clip(dy, -limit, limit))
    return crop, mask


def _suppress_grid(rgb: np.ndarray) -> np.ndarray:
    """Inpaint the photographed tile grid out of a waterline scan.

    Bare grid courses read as thin straight runs of edge energy; the crust
    band is excluded because its rough mass survives a disk opening. Without
    this, the photograph's grid survives inside the deposit's colour at a
    spacing that cannot match the game's own tiles.
    """
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.float32)
    fine = np.abs(gray - cv2.GaussianBlur(gray, (0, 0), 2.0))
    edge = (cv2.GaussianBlur(fine, (0, 0), 3.0) > 4.5).astype(np.uint8)
    span = min(gray.shape)
    run = max(61, span // 30)
    lines = edge * 0
    for kernel_size in ((run, 3), (3, run), (run * 2, 1), (1, run * 2)):
        lines = np.maximum(lines, cv2.morphologyEx(edge, cv2.MORPH_OPEN,
            cv2.getStructuringElement(cv2.MORPH_RECT, kernel_size)))
    thick = cv2.morphologyEx(edge, cv2.MORPH_OPEN,
        _ellipse(max(21, (span // 80) | 1)))
    lines &= ~cv2.dilate(thick, _ellipse(15))
    inpaint = cv2.dilate(lines, _ellipse(9)) * 255
    if not inpaint.any():
        return rgb
    return cv2.inpaint(rgb, inpaint, 7.0, cv2.INPAINT_TELEA)


def _prepare(path: Path, kind: str, cell_size: tuple[int, int]) -> Image.Image:
    rgb = np.asarray(Image.open(path).convert("RGB"))
    if kind == "grout":
        rgb, mask = _centred_grout_crop(rgb)
    else:
        rgb = _suppress_grid(rgb)
        mask = _raw_mask(rgb)
    height, width = mask.shape
    yy, xx = np.mgrid[0:height, 0:width]
    nx = (xx + 0.5) / width
    ny = (yy + 0.5) / height

    if kind == "grout":
        # Fade the deposit down over most of its outer half. The broad ramp is
        # what keeps a dense scan from ending in a visible circular arc: by the
        # time the guarantee reaches zero, the crust has already thinned away
        # through its own holes.
        radius = np.sqrt(((nx - 0.5) / 0.5) ** 2 + ((ny - 0.5) / 0.5) ** 2)
        envelope = 1.0 - _smoothstep(0.52, 0.98, radius)
    else:
        # Waterline scans are intentionally panoramic.  Preserve the full
        # mineral band, but force both ends and the clean top/bottom to zero so
        # adjacent shader segments feather invisibly.
        x_fade = _smoothstep(0.0, 0.09, nx) * (1.0 - _smoothstep(0.91, 1.0, nx))
        y_fade = 1.0 - _smoothstep(0.30, 0.46, np.abs(ny - 0.5))
        envelope = x_fade * y_fade

    mask *= envelope * _edge_fade(height, width, 0.025)
    alpha = np.clip(mask, 0, 255).astype(np.uint8)
    rgba = np.dstack((_mineral_colour(rgb), alpha))
    image = Image.fromarray(rgba, mode="RGBA")
    target_w, target_h = cell_size
    image.thumbnail((target_w, target_h), Image.Resampling.LANCZOS)
    cell = Image.new("RGBA", cell_size, (0, 0, 0, 0))
    cell.paste(image, ((target_w - image.width) // 2, (target_h - image.height) // 2))
    return cell


def _atlas(source_dir: Path, output: Path, prefix: str, cell_size: tuple[int, int]) -> None:
    cells = [_prepare(source_dir / f"{prefix}{index}.png", prefix, cell_size) for index in range(1, 9)]
    atlas = Image.new("RGBA", (cell_size[0] * 4, cell_size[1] * 2), (0, 0, 0, 0))
    for index, cell in enumerate(cells):
        atlas.paste(cell, ((index % 4) * cell_size[0], (index // 4) * cell_size[1]))
    output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output, optimize=True)
    print(f"wrote {output} ({atlas.width}x{atlas.height})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    _atlas(args.source, args.output / "grout_mineral_atlas.png", "grout", (512, 512))
    _atlas(args.source, args.output / "waterline_mineral_atlas.png", "waterline", (1024, 512))


if __name__ == "__main__":
    main()
