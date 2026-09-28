"""Build the fixed, soft-edged Annex damage masks used at runtime."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1] / "textures" / "annex"
SIZE = 1024
Y, X = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
X /= SIZE - 1
Y /= SIZE - 1


def noise(rng: np.random.Generator, scale: int) -> np.ndarray:
    samples = rng.random((scale, scale), dtype=np.float32)
    source = Image.fromarray(np.uint8(samples * 255), "L")
    return np.asarray(source.resize((SIZE, SIZE), Image.Resampling.BICUBIC), dtype=np.float32) / 255


def save(name: str, field: np.ndarray) -> None:
    feather = np.minimum.reduce((X, 1 - X, Y, 1 - Y))
    field *= np.clip(feather / 0.065, 0, 1)
    image = Image.fromarray(np.uint8(np.clip(field, 0, 1) * 255), "L")
    image = image.filter(ImageFilter.GaussianBlur(1.1))
    image.save(ROOT / name, optimize=True)


for variant in range(2):
    rng = np.random.default_rng(4501 + variant)
    broad = noise(rng, 12) - 0.5
    fine = noise(rng, 54) - 0.5
    cx, cy = (0.47, 0.52) if variant == 0 else (0.55, 0.45)
    dx = (X - cx) / (0.35 if variant == 0 else 0.32)
    dy = (Y - cy) / (0.30 if variant == 0 else 0.37)
    radius = np.sqrt(dx * dx + dy * dy) + broad * 0.20 + fine * 0.055
    ring = np.exp(-((radius - 0.70) / 0.105) ** 2) * 0.80
    old_halo = np.exp(-((radius - 0.61) / 0.34) ** 2) * 0.19
    satellite = np.exp(-(((X - cx - 0.12) / 0.075) ** 2
                         + ((Y - cy + 0.15) / 0.06) ** 2)) * 0.24
    save(f"ceiling_ring_{variant + 1:02d}.png", ring + old_halo + satellite)

    rng = np.random.default_rng(5501 + variant)
    broad = noise(rng, 11) - 0.5
    fine = noise(rng, 66) - 0.5
    dx = (X - (0.46 if variant == 0 else 0.53)) / 0.39
    dy = (Y - (0.54 if variant == 0 else 0.46)) / 0.33
    radius = np.sqrt(dx * dx + dy * dy) + broad * 0.30 + fine * 0.08
    body = np.clip((0.93 - radius) / 0.28, 0, 1) * (0.32 + noise(rng, 27) * 0.34)
    rim = np.exp(-((radius - 0.78) / 0.11) ** 2) * 0.36
    save(f"carpet_bloom_{variant + 1:02d}.png", body + rim)

    rng = np.random.default_rng(6501 + variant)
    broad = noise(rng, 15) - 0.5
    fine = noise(rng, 76) - 0.5
    seep = np.zeros((SIZE, SIZE), np.float32)
    for drip in range(7):
        center = 0.25 + drip * 0.08 + rng.uniform(-0.025, 0.025)
        length = rng.uniform(0.43, 0.95)
        width = rng.uniform(0.010, 0.035)
        bend = np.sin(Y * (6.0 + drip * 0.31) + drip * 2.4) * 0.014
        track = X - center - bend - broad * 0.028
        strand = np.exp(-(track / width) ** 2)
        fade = np.clip((length - Y) / 0.16, 0, 1)
        seep = np.maximum(seep, strand * fade * (0.32 + fine * 0.18))
    reservoir = np.exp(-(((X - 0.50) / 0.33) ** 2
                         + ((Y - 0.10) / 0.24) ** 2)) * (0.55 + broad * 0.21)
    save(f"wall_seep_{variant + 1:02d}.png", seep + reservoir)

    rng = np.random.default_rng(7501 + variant)
    broad = noise(rng, 15) - 0.5
    fine = noise(rng, 71) - 0.5
    line_y = (0.50 if variant == 0 else 0.44) + broad * 0.10
    line = np.exp(-((Y - line_y) / 0.025) ** 2) * (0.67 + fine * 0.22)
    under = np.clip((Y - line_y) / 0.15, 0, 1) * np.clip((0.95 - Y) / 0.43, 0, 1)
    under *= 0.27 + noise(rng, 29) * 0.21
    save(f"wall_tide_{variant + 1:02d}.png", line + under)
