from __future__ import annotations

from collections import OrderedDict
import json
from pathlib import Path

import numpy as np

from .config import load_preset, load_profile
from .export import build_contact_sheet, pack_rgba, write_godot_manifest
from .extractors import (
    CarpetExtractor, CrackExtractor, DirtExtractor, MineralDepositExtractor,
    MoistureExtractor, OrganicGrowthExtractor, PeelingPaintExtractor, RustExtractor,
)
from .generators import make_transparent_decal
from .models import ExtractionResult
from .processing.image_ops import read_rgb, save_png
from .processing.material_maps import combine_height_masks, damage_to_roughness, height_to_normal
from .processing.quality import assess_ceiling_moisture, build_quality_preview


EXTRACTORS = {
    "moisture": MoistureExtractor(),
    "dirt": DirtExtractor(),
    "carpet_stains": CarpetExtractor(),
    "cracks": CrackExtractor(),
    "rust": RustExtractor(),
    "peeling_paint": PeelingPaintExtractor(),
    "mineral_deposits": MineralDepositExtractor(),
    "organic_growth": OrganicGrowthExtractor(),
}


def _parameters(profile, preset, effect_id: str) -> dict:
    merged = dict(preset.parameters.get(effect_id, {}))
    if effect_id in profile.effects:
        merged.update(profile.effects[effect_id].parameters)
    return merged


def process_image(source: Path, output_dir: Path, profile_name: str, preset_name: str = "balanced", effect: str | None = None, orientation: str = "vertical") -> ExtractionResult:
    rgb = read_rgb(source)
    profile = load_profile(profile_name)
    preset = load_preset(preset_name)
    outputs: dict[str, np.ndarray] = {"original_scan": rgb}

    if effect is None:
        selected = {
            effect_id: extractor for effect_id, extractor in EXTRACTORS.items()
            if profile.effects.get(effect_id) is None or profile.effects[effect_id].enabled
        }
    else:
        selected = {effect: EXTRACTORS[effect]}
    for effect_id, extractor in selected.items():
        outputs.update(extractor.extract(rgb, _parameters(profile, preset, effect_id)))

    if "moisture_mask" in outputs:
        if orientation == "horizontal":
            outputs["runoff_mask"] = np.zeros_like(outputs["moisture_mask"])
        outputs["moisture_decal"] = make_transparent_decal(rgb, outputs["moisture_mask"])
    zeros = np.zeros(rgb.shape[:2], dtype=np.uint8)
    structural = np.maximum(
        outputs.get("crack_mask", zeros), outputs.get("peeling_paint_mask", zeros))
    organic = outputs.get("organic_growth_mask", zeros)
    outputs["packed_effects"] = pack_rgba(
        outputs.get("moisture_mask", zeros), outputs.get("dirt_mask", zeros),
        structural, organic)
    if np.any(structural) or np.any(organic):
        outputs["height_map"] = combine_height_masks(structural, organic)
        outputs["normal_map"] = height_to_normal(outputs["height_map"])
        material_damage = np.maximum.reduce([
            structural, organic, outputs.get("rust_mask", zeros),
            outputs.get("mineral_deposit_mask", zeros),
        ])
        outputs["roughness_map"] = damage_to_roughness(material_damage)
    if effect == "moisture" and orientation == "horizontal":
        quality = assess_ceiling_moisture(outputs["moisture_mask"], outputs["runoff_mask"])
        outputs["quality_preview"] = build_quality_preview(rgb, outputs["moisture_mask"], outputs["moisture_decal"], quality)
        output_dir.mkdir(parents=True, exist_ok=True)
        with (output_dir / "quality_report.json").open("w", encoding="utf-8") as handle:
            json.dump(quality.to_dict(), handle, indent=2)
        previews = OrderedDict([
            ("Original", rgb), ("Moisture", outputs["moisture_mask"]),
            ("RGBA channels (R/G/B)", outputs["packed_effects"][..., :3]),
            ("Decal preview", outputs["moisture_decal"]),
        ])
        outputs["contact_sheet"] = build_contact_sheet(previews, columns=2)
        for name, array in outputs.items():
            save_png(output_dir / f"{name}.png", array)
        write_godot_manifest(output_dir, source, list(outputs))
        return ExtractionResult(source=source, outputs=outputs)

    labels = {
        "moisture_mask": "Moisture", "runoff_mask": "Runoff", "dirt_mask": "Dirt",
        "grime_mask": "Grime", "carpet_stain_mask": "Carpet stain",
        "carpet_wear_mask": "Carpet wear", "crack_mask": "Cracks", "rust_mask": "Rust",
        "peeling_paint_mask": "Peeling paint", "mineral_deposit_mask": "Minerals",
        "organic_growth_mask": "Organic growth", "height_map": "Height",
        "normal_map": "OpenGL normal", "roughness_map": "Roughness",
    }
    previews = OrderedDict([("Original", rgb)])
    for name, label in labels.items():
        if name in outputs:
            previews[label] = outputs[name]
    previews["Packed RGBA"] = outputs["packed_effects"]
    if "moisture_decal" in outputs:
        previews["Decal preview"] = outputs["moisture_decal"]
    outputs["contact_sheet"] = build_contact_sheet(previews)

    output_dir.mkdir(parents=True, exist_ok=True)
    for name, array in outputs.items():
        save_png(output_dir / f"{name}.png", array)
    write_godot_manifest(output_dir, source, list(outputs))
    return ExtractionResult(source=source, outputs=outputs)


def process_batch(input_dir: Path, output_dir: Path, profile_name: str, preset_name: str = "balanced", recursive: bool = False, effect: str | None = None, orientation: str = "vertical") -> list[ExtractionResult]:
    extensions = {".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff"}
    iterator = input_dir.rglob("*") if recursive else input_dir.glob("*")
    sources = sorted(path for path in iterator if path.is_file() and path.suffix.lower() in extensions)
    results = []
    for source in sources:
        relative = source.relative_to(input_dir).with_suffix("")
        results.append(process_image(source, output_dir / relative, profile_name, preset_name, effect, orientation))
    return results
