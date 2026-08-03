import json
from pathlib import Path

import numpy as np

from liminal_lab.export.manifest import write_godot_manifest
from liminal_lab.processing.material_maps import combine_height_masks, damage_to_roughness, height_to_normal


def test_material_maps_are_godot_ready():
    mask = np.zeros((24, 24), dtype=np.uint8)
    mask[7:17, 10:14] = 255
    height = combine_height_masks(mask, np.rot90(mask))
    normal = height_to_normal(height)
    roughness = damage_to_roughness(height)
    assert height.shape == roughness.shape == (24, 24)
    assert normal.shape == (24, 24, 3)
    assert all(array.dtype == np.uint8 for array in (height, normal, roughness))
    assert normal[..., 2].mean() > normal[..., 0].mean()
    assert roughness[10, 11] > roughness[0, 0]


def test_manifest_marks_normal_and_data_textures(tmp_path: Path):
    path = write_godot_manifest(tmp_path, Path("wall.jpg"), [
        "original_scan", "crack_mask", "normal_map", "moisture_decal"])
    data = json.loads(path.read_text())
    by_id = {entry["id"]: entry for entry in data["assets"]}
    assert "original_scan" not in by_id
    assert by_id["crack_mask"]["usage"] == "data"
    assert by_id["normal_map"]["usage"] == "normal"
    assert by_id["moisture_decal"]["usage"] == "texture"
