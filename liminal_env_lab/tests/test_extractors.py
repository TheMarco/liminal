import numpy as np

from liminal_lab.extractors import CarpetExtractor, DirtExtractor, MoistureExtractor


def test_extractors_are_deterministic_and_shape_safe(synthetic_surface):
    for extractor in (MoistureExtractor(), DirtExtractor(), CarpetExtractor()):
        first = extractor.extract(synthetic_surface, {})
        second = extractor.extract(synthetic_surface, {})
        assert first.keys() == second.keys()
        for name in first:
            assert first[name].shape == synthetic_surface.shape[:2]
            assert first[name].dtype == np.uint8
            np.testing.assert_array_equal(first[name], second[name])


def test_moisture_favors_large_stain_over_texture(synthetic_surface):
    mask = MoistureExtractor().extract(synthetic_surface, {})["moisture_mask"]
    assert mask[45:75, 55:95].mean() > mask[:20, :40].mean()

def test_carpet_suppresses_weave_and_preserves_stain(synthetic_surface):
    mask = CarpetExtractor().extract(synthetic_surface, {})["carpet_stain_mask"]
    assert mask[45:75, 55:95].mean() > mask[:20, :40].mean()
