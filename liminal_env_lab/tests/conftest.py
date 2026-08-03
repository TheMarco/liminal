from __future__ import annotations

import numpy as np
import pytest


@pytest.fixture
def synthetic_surface() -> np.ndarray:
    height, width = 128, 160
    y, x = np.mgrid[:height, :width]
    base = 190 + 6 * np.sin(x * 0.8) + 4 * np.cos(y * 0.65)
    rgb = np.dstack((base, base + 2, base - 3))
    stain = ((x - 76) / 36) ** 2 + ((y - 58) / 25) ** 2 < 1
    rgb[stain] -= np.array([65, 48, 25])
    rgb[28:105, 116:121] -= np.array([55, 42, 28])
    return np.clip(rgb, 0, 255).astype(np.uint8)
