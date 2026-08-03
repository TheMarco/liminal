from __future__ import annotations

from typing import Any

import cv2
import numpy as np

from .base import EffectExtractor
from ..processing.image_ops import odd_kernel, remove_small, to_gray


def _threshold_response(response: np.ndarray, threshold: int, min_area: int) -> np.ndarray:
    """Convert an already scaled response to a clean, soft uint8 mask."""
    mask = np.clip(response, 0, 255).astype(np.uint8)
    mask[mask < threshold] = 0
    return remove_small(mask, min_area)


class CrackExtractor(EffectExtractor):
    effect_id = "cracks"

    def extract(self, rgb: np.ndarray, parameters: dict[str, Any]) -> dict[str, np.ndarray]:
        gray = to_gray(rgb)
        scale = float(parameters.get("scale", 1.0))
        kernel = odd_kernel(9 * scale, 5)
        # A closing fills narrow dark fissures; subtracting the source retains only
        # the dark, line-like structures rather than ordinary material gradients.
        closed = cv2.morphologyEx(gray, cv2.MORPH_CLOSE, np.ones((kernel, kernel), np.uint8))
        dark_lines = cv2.subtract(closed, gray)
        response = cv2.GaussianBlur(dark_lines, (odd_kernel(3 * scale),) * 2, 0).astype(np.float32) * 4.0
        mask = _threshold_response(
            response,
            int(parameters.get("threshold", 34)),
            max(3, gray.size // 16000),
        )
        return {"crack_mask": mask}


class RustExtractor(EffectExtractor):
    effect_id = "rust"

    def extract(self, rgb: np.ndarray, parameters: dict[str, Any]) -> dict[str, np.ndarray]:
        hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
        hue = hsv[:, :, 0].astype(np.float32)
        saturation = hsv[:, :, 1].astype(np.float32)
        value = hsv[:, :, 2].astype(np.float32)
        # Rust occupies the red-orange-yellow arc. The triangular hue weighting
        # rejects saturated blues/greens while preserving both brown and orange.
        hue_weight = np.clip(1.0 - np.abs(hue - 13.0) / 16.0, 0.0, 1.0)
        response = saturation * hue_weight * np.clip((280.0 - value) / 120.0, 0.45, 1.25)
        mask = _threshold_response(
            response,
            int(parameters.get("threshold", 38)),
            max(4, rgb.shape[0] * rgb.shape[1] // 12000),
        )
        return {"rust_mask": mask}


class PeelingPaintExtractor(EffectExtractor):
    effect_id = "peeling_paint"

    def extract(self, rgb: np.ndarray, parameters: dict[str, Any]) -> dict[str, np.ndarray]:
        scale = float(parameters.get("scale", 1.0))
        lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.float32)
        kernel = odd_kernel(min(rgb.shape[:2]) * 0.09 * scale, 9)
        local = cv2.GaussianBlur(lab, (kernel, kernel), 0)
        color_break = np.linalg.norm(lab - local, axis=2)
        gray = to_gray(rgb)
        edge = cv2.morphologyEx(gray, cv2.MORPH_GRADIENT, np.ones((3, 3), np.uint8)).astype(np.float32)
        response = cv2.GaussianBlur(color_break * 2.3 + edge * 0.7, (3, 3), 0)
        mask = _threshold_response(
            response,
            int(parameters.get("threshold", 36)),
            max(8, gray.size // 5000),
        )
        return {"peeling_paint_mask": mask}


class MineralDepositExtractor(EffectExtractor):
    effect_id = "mineral_deposits"

    def extract(self, rgb: np.ndarray, parameters: dict[str, Any]) -> dict[str, np.ndarray]:
        hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
        saturation = hsv[:, :, 1].astype(np.float32)
        value = hsv[:, :, 2].astype(np.float32)
        gray = to_gray(rgb)
        kernel = odd_kernel(min(gray.shape) * 0.08 * float(parameters.get("scale", 1.0)), 9)
        local = cv2.GaussianBlur(gray, (kernel, kernel), 0).astype(np.float32)
        pale = np.clip(value - 145.0, 0.0, 110.0) * np.clip((105.0 - saturation) / 105.0, 0.0, 1.0)
        raised = np.maximum(gray.astype(np.float32) - local, 0.0) * 2.0
        response = cv2.GaussianBlur(pale + raised, (3, 3), 0)
        mask = _threshold_response(
            response,
            int(parameters.get("threshold", 34)),
            max(5, gray.size // 8000),
        )
        return {"mineral_deposit_mask": mask}


class OrganicGrowthExtractor(EffectExtractor):
    effect_id = "organic_growth"

    def extract(self, rgb: np.ndarray, parameters: dict[str, Any]) -> dict[str, np.ndarray]:
        hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
        hue = hsv[:, :, 0].astype(np.float32)
        saturation = hsv[:, :, 1].astype(np.float32)
        value = hsv[:, :, 2].astype(np.float32)
        # Moss/algae range from yellow-green through blue-green and are typically
        # darker than fresh painted greens.
        hue_weight = np.clip(1.0 - np.abs(hue - 55.0) / 38.0, 0.0, 1.0)
        response = saturation * hue_weight * np.clip((300.0 - value) / 135.0, 0.55, 1.35)
        mask = _threshold_response(
            response,
            int(parameters.get("threshold", 32)),
            max(5, rgb.shape[0] * rgb.shape[1] // 10000),
        )
        return {"organic_growth_mask": mask}
