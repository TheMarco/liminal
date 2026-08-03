from __future__ import annotations

from typing import Any

import cv2
import numpy as np
from skimage.filters import rank
from skimage.morphology import disk

from .base import EffectExtractor
from ..processing.image_ops import normalize_u8, odd_kernel, remove_small, to_gray


class DirtExtractor(EffectExtractor):
    effect_id = "dirt"

    def extract(self, rgb: np.ndarray, parameters: dict[str, Any]) -> dict[str, np.ndarray]:
        gray = to_gray(rgb)
        scale = float(parameters.get("scale", 1.0))
        denoised = cv2.bilateralFilter(gray, odd_kernel(9 * scale), 35, 35)
        radius = max(3, round(min(gray.shape) * 0.035 * scale))
        local_background = rank.median(denoised, footprint=disk(radius))
        dark_residual = cv2.subtract(local_background, denoised)
        dirt = normalize_u8(cv2.GaussianBlur(dark_residual, (odd_kernel(5 * scale),) * 2, 0), 55, 99.5)
        dirt[dirt < int(parameters.get("threshold", 42))] = 0
        dirt = remove_small(dirt, max(6, gray.size // 8000))

        broad = cv2.GaussianBlur(gray, (odd_kernel(min(gray.shape) * 0.16 * scale),) * 2, 0)
        grime_response = cv2.subtract(broad, cv2.GaussianBlur(gray, (odd_kernel(13 * scale),) * 2, 0))
        grime = normalize_u8(grime_response, 55, 99.5)
        grime[grime < int(parameters.get("grime_threshold", 32))] = 0
        return {"dirt_mask": dirt, "grime_mask": grime}
