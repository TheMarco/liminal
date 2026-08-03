from __future__ import annotations

import cv2
import numpy as np


def make_transparent_decal(rgb: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Create a neutral-color RGBA decal; source wall color is intentionally discarded."""
    alpha = cv2.GaussianBlur(mask, (3, 3), 0)
    tint = np.empty_like(rgb)
    tint[:, :] = (76, 68, 52)
    strength = alpha.astype(np.float32)[..., None] / 255.0
    tinted = np.clip(tint * (0.72 + 0.28 * strength), 0, 255).astype(np.uint8)
    return np.dstack((tinted, alpha))
