from __future__ import annotations

import cv2
import numpy as np
import pytest

from liminal_lab.extractors import (
    CrackExtractor,
    MineralDepositExtractor,
    OrganicGrowthExtractor,
    PeelingPaintExtractor,
    RustExtractor,
)


@pytest.fixture
def phase2_surface() -> np.ndarray:
    image = np.full((128, 160, 3), (156, 164, 168), dtype=np.uint8)

    # Branching dark crack.
    cv2.line(image, (12, 12), (48, 75), (35, 35, 38), 2)
    cv2.line(image, (35, 53), (62, 42), (35, 35, 38), 2)

    # Corroded orange-brown patch.
    cv2.circle(image, (90, 28), 14, (151, 70, 24), -1)
    cv2.circle(image, (100, 35), 9, (188, 93, 30), -1)

    # Contrasting chips representing exposed undercoat.
    peel = np.array([[70, 62], [102, 57], [111, 76], [96, 91], [65, 82]], np.int32)
    cv2.fillPoly(image, [peel], (220, 213, 185))
    cv2.circle(image, (82, 72), 5, (125, 133, 138), -1)

    # Pale mineral crust and green organic growth.
    cv2.ellipse(image, (28, 105), (19, 9), 12, 0, 360, (238, 239, 226), -1)
    cv2.circle(image, (132, 102), 16, (43, 105, 49), -1)
    cv2.circle(image, (146, 112), 8, (68, 132, 55), -1)
    return image


@pytest.mark.parametrize(
    ("extractor", "mask_name"),
    [
        (CrackExtractor(), "crack_mask"),
        (RustExtractor(), "rust_mask"),
        (PeelingPaintExtractor(), "peeling_paint_mask"),
        (MineralDepositExtractor(), "mineral_deposit_mask"),
        (OrganicGrowthExtractor(), "organic_growth_mask"),
    ],
)
def test_phase2_extractors_are_shape_safe_deterministic_and_nonzero(
    phase2_surface: np.ndarray,
    extractor: object,
    mask_name: str,
) -> None:
    first = extractor.extract(phase2_surface, {})[mask_name]
    second = extractor.extract(phase2_surface.copy(), {})[mask_name]

    assert first.shape == phase2_surface.shape[:2]
    assert first.dtype == np.uint8
    assert np.count_nonzero(first) > 0
    assert np.array_equal(first, second)


def test_phase2_effect_ids_and_exact_mask_names(phase2_surface: np.ndarray) -> None:
    expected = [
        (CrackExtractor(), "cracks", "crack_mask"),
        (RustExtractor(), "rust", "rust_mask"),
        (PeelingPaintExtractor(), "peeling_paint", "peeling_paint_mask"),
        (MineralDepositExtractor(), "mineral_deposits", "mineral_deposit_mask"),
        (OrganicGrowthExtractor(), "organic_growth", "organic_growth_mask"),
    ]
    for extractor, effect_id, mask_name in expected:
        assert extractor.effect_id == effect_id
        assert set(extractor.extract(phase2_surface, {})) == {mask_name}
