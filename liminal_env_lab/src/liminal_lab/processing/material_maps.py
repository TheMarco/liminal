from __future__ import annotations

import cv2
import numpy as np


def combine_height_masks(*masks: np.ndarray) -> np.ndarray:
    """Combine damage masks into a stable grayscale displacement map."""
    available = [mask.astype(np.float32) for mask in masks if mask is not None]
    if not available:
        raise ValueError("At least one mask is required")
    height = np.maximum.reduce(available)
    return cv2.GaussianBlur(height, (3, 3), 0).astype(np.uint8)


def height_to_normal(height: np.ndarray, strength: float = 2.0) -> np.ndarray:
    """Create an OpenGL-oriented RGB normal map (+Y/green points up)."""
    source = height.astype(np.float32) / 255.0
    dx = cv2.Sobel(source, cv2.CV_32F, 1, 0, ksize=3) * strength
    dy = cv2.Sobel(source, cv2.CV_32F, 0, 1, ksize=3) * strength
    normal = np.dstack((-dx, -dy, np.ones_like(source)))
    normal /= np.maximum(np.linalg.norm(normal, axis=2, keepdims=True), 1e-6)
    return np.clip((normal * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)


def damage_to_roughness(damage: np.ndarray, base: int = 150, variation: int = 90) -> np.ndarray:
    normalized = damage.astype(np.float32) / 255.0
    return np.clip(base + normalized * variation, 0, 255).astype(np.uint8)
