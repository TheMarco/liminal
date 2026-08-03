from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def read_rgb(path: Path) -> np.ndarray:
    with Image.open(path) as image:
        return np.asarray(image.convert("RGB"), dtype=np.uint8)


def to_gray(rgb: np.ndarray) -> np.ndarray:
    return cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)


def normalize_u8(values: np.ndarray, low: float = 1.0, high: float = 99.0) -> np.ndarray:
    array = values.astype(np.float32)
    lo, hi = np.percentile(array, (low, high))
    if hi <= lo + 1e-6:
        return np.zeros(array.shape, dtype=np.uint8)
    return np.clip((array - lo) * (255.0 / (hi - lo)), 0, 255).astype(np.uint8)


def odd_kernel(value: int, minimum: int = 3) -> int:
    value = max(minimum, int(value))
    return value if value % 2 else value + 1


def remove_small(mask: np.ndarray, min_area: int) -> np.ndarray:
    binary = mask > 0
    count, labels, stats, _ = cv2.connectedComponentsWithStats(binary.astype(np.uint8), 8)
    kept = np.zeros(mask.shape, dtype=np.uint8)
    for index in range(1, count):
        if stats[index, cv2.CC_STAT_AREA] >= min_area:
            kept[labels == index] = mask[labels == index]
    return kept


def save_png(path: Path, array: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = "RGBA" if array.ndim == 3 and array.shape[2] == 4 else None
    Image.fromarray(array, mode=mode).save(path, format="PNG", optimize=True)
