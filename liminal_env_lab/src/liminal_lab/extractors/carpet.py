from __future__ import annotations

from typing import Any

import cv2
import numpy as np

from .base import EffectExtractor
from ..processing.image_ops import normalize_u8, odd_kernel, remove_small, to_gray


class CarpetExtractor(EffectExtractor):
    effect_id = "carpet_stains"

    def extract(self, rgb: np.ndarray, parameters: dict[str, Any]) -> dict[str, np.ndarray]:
        gray = to_gray(rgb)
        scale = float(parameters.get("scale", 1.0))
        weave = odd_kernel(parameters.get("weave_kernel", 9) * scale)
        suppressed = cv2.medianBlur(gray, weave)
        broad_size = odd_kernel(min(gray.shape) * 0.14 * scale, 15)
        baseline = cv2.GaussianBlur(suppressed, (broad_size, broad_size), 0)
        stain_response = cv2.subtract(baseline, suppressed)
        stain = normalize_u8(cv2.GaussianBlur(stain_response, (odd_kernel(9 * scale),) * 2, 0), 50, 99.5)
        stain[stain < int(parameters.get("threshold", 38))] = 0
        stain = remove_small(stain, max(12, gray.size // 3000))

        gradient = cv2.morphologyEx(suppressed, cv2.MORPH_GRADIENT, np.ones((5, 5), np.uint8))
        texture_loss = cv2.subtract(cv2.GaussianBlur(gradient, (broad_size, broad_size), 0), gradient)
        wear = normalize_u8(texture_loss, 60, 99)
        wear = cv2.GaussianBlur(wear, (odd_kernel(11 * scale),) * 2, 0)
        wear[wear < int(parameters.get("wear_threshold", 35))] = 0
        return {"carpet_stain_mask": stain, "carpet_wear_mask": wear}
