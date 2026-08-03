from __future__ import annotations

import numpy as np


def pack_rgba(
    moisture: np.ndarray,
    dirt: np.ndarray,
    structural_damage: np.ndarray | None = None,
    organic_growth: np.ndarray | None = None,
) -> np.ndarray:
    shape = moisture.shape
    if dirt.shape != shape:
        raise ValueError("All packed masks must have identical dimensions")
    zeros = np.zeros(shape, dtype=np.uint8)
    structural = zeros if structural_damage is None else structural_damage
    organic = zeros if organic_growth is None else organic_growth
    if structural.shape != shape or organic.shape != shape:
        raise ValueError("All packed masks must have identical dimensions")
    return np.dstack((moisture, dirt, structural, organic)).astype(np.uint8)
