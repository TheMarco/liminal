from __future__ import annotations

from typing import Any

import cv2
import numpy as np

from .base import EffectExtractor
from ..processing.image_ops import normalize_u8, odd_kernel, remove_small, to_gray


class MoistureExtractor(EffectExtractor):
    effect_id = "moisture"

    def extract(self, rgb: np.ndarray, parameters: dict[str, Any]) -> dict[str, np.ndarray]:
        gray = to_gray(rgb)
        scale = float(parameters.get("scale", 1.0))
        # Moisture on porous architectural materials is a low-frequency color shift.
        # Work on a strongly smoothed LAB image so pores, fibers, and printed grain do
        # not become the mask while broad ochre/gray damp regions remain intact.
        low_pass = odd_kernel(round(min(gray.shape) * 0.018 * scale), 11)
        lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)
        smooth_l = cv2.GaussianBlur(lab[:, :, 0], (low_pass, low_pass), 0).astype(np.float32)
        smooth_b = cv2.GaussianBlur(lab[:, :, 2], (low_pass, low_pass), 0).astype(np.float32)
        neutral_b = float(np.percentile(smooth_b, 18))
        clean_l = float(np.percentile(smooth_l, 88))
        yellowing = np.maximum(smooth_b - neutral_b, 0.0)
        darkness = np.maximum(clean_l - smooth_l, 0.0)
        response = yellowing * float(parameters.get("color_weight", 1.0)) + darkness * float(parameters.get("dark_weight", 0.38))
        moisture = normalize_u8(response, 20, 99.5)
        threshold = int(parameters.get("threshold", 28))
        moisture[moisture < threshold] = 0
        close_size = odd_kernel(round(min(gray.shape) * 0.012 * scale), 7)
        moisture = cv2.morphologyEx(moisture, cv2.MORPH_CLOSE, np.ones((close_size, close_size), np.uint8))
        moisture = remove_small(moisture, max(32, rgb.shape[0] * rgb.shape[1] // 2500))

        fine_darkness = cv2.subtract(cv2.GaussianBlur(gray, (odd_kernel(41 * scale),) * 2, 0), gray)
        vertical = cv2.getStructuringElement(cv2.MORPH_RECT, (3, odd_kernel(31 * scale)))
        runoff_seed = cv2.morphologyEx(fine_darkness, cv2.MORPH_OPEN, vertical)
        runoff = normalize_u8(runoff_seed, 65, 99.7)
        runoff = cv2.bitwise_and(runoff, moisture)
        return {"moisture_mask": moisture, "runoff_mask": runoff}
