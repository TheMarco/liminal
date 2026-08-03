from pathlib import Path

import numpy as np
from PIL import Image

from liminal_lab.cli.main import main
from liminal_lab.pipeline import process_batch, process_image


EXPECTED_OUTPUTS = {
    "original_scan.png",
    "moisture_mask.png", "runoff_mask.png", "moisture_decal.png", "dirt_mask.png",
    "grime_mask.png", "carpet_stain_mask.png", "carpet_wear_mask.png",
    "packed_effects.png", "contact_sheet.png",
    "crack_mask.png", "rust_mask.png", "peeling_paint_mask.png",
    "mineral_deposit_mask.png",
    "height_map.png", "normal_map.png", "roughness_map.png",
}


def test_process_image_writes_phase_one_contract(tmp_path: Path, synthetic_surface):
    source = tmp_path / "source.png"
    output = tmp_path / "out"
    Image.fromarray(synthetic_surface).save(source)
    result = process_image(source, output, "vegas_hotel")
    assert set(path.name for path in output.glob("*.png")) == EXPECTED_OUTPUTS
    assert (output / "godot_import_manifest.json").exists()
    assert "organic_growth_mask" not in result.outputs  # disabled by this profile
    assert set(result.outputs) == {path.stem for path in output.glob("*.png")}


def test_batch_and_cli(tmp_path: Path, synthetic_surface, capsys):
    inputs = tmp_path / "inputs"
    inputs.mkdir()
    Image.fromarray(synthetic_surface).save(inputs / "one.png")
    Image.fromarray(synthetic_surface).save(inputs / "two.jpg")
    results = process_batch(inputs, tmp_path / "batch", "office")
    assert len(results) == 2
    assert main(["list-profiles"]) == 0
    assert "office" in capsys.readouterr().out


def test_ceiling_moisture_mode_exports_qc_and_no_irrelevant_masks(tmp_path: Path, synthetic_surface):
    source = tmp_path / "ceiling.png"
    output = tmp_path / "ceiling-out"
    Image.fromarray(synthetic_surface).save(source)
    result = process_image(source, output, "annex", "moisture_ceiling", "moisture", "horizontal")
    assert (output / "quality_report.json").exists()
    assert (output / "quality_preview.png").exists()
    assert not np.asarray(Image.open(output / "runoff_mask.png")).any()
    assert "dirt_mask" not in result.outputs
    assert "carpet_stain_mask" not in result.outputs
