import numpy as np
import pytest

from liminal_lab.export import build_contact_sheet, pack_rgba
from liminal_lab.generators import make_transparent_decal


def test_rgba_channel_contract():
    moisture = np.full((8, 9), 11, np.uint8)
    dirt = np.full((8, 9), 22, np.uint8)
    packed = pack_rgba(moisture, dirt)
    assert packed.shape == (8, 9, 4)
    assert np.all(packed[..., 0] == 11)
    assert np.all(packed[..., 1] == 22)
    assert np.all(packed[..., 2:] == 0)


def test_rgba_rejects_mismatched_sizes():
    with pytest.raises(ValueError):
        pack_rgba(np.zeros((2, 2), np.uint8), np.zeros((3, 2), np.uint8))


def test_decal_uses_mask_as_alpha(synthetic_surface):
    mask = np.zeros(synthetic_surface.shape[:2], np.uint8)
    mask[20:40, 20:40] = 255
    decal = make_transparent_decal(synthetic_surface, mask)
    assert decal.shape == (*mask.shape, 4)
    assert decal[..., 3].max() == 255
    assert decal[0, 0, 3] == 0


def test_contact_sheet_is_rgb():
    sheet = build_contact_sheet({"A": np.zeros((20, 30), np.uint8), "B": np.zeros((20, 30, 4), np.uint8)})
    assert sheet.ndim == 3 and sheet.shape[2] == 3
