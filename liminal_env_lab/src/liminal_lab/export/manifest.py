from __future__ import annotations

import json
from pathlib import Path


def write_godot_manifest(output_dir: Path, source: Path, output_names: list[str]) -> Path:
    """Write a deterministic import handoff consumed by Godot tooling."""
    entries = []
    for name in sorted(output_names):
        if name in {"original_scan", "contact_sheet", "quality_preview"}:
            continue
        usage = "texture"
        if name.endswith("_mask") or name in {"height_map", "roughness_map", "packed_effects"}:
            usage = "data"
        elif name == "normal_map":
            usage = "normal"
        entries.append({
            "id": name,
            "file": f"{name}.png",
            "usage": usage,
            "godot": {
                "compress/mode": 0 if usage in {"data", "normal"} else 1,
                "mipmaps/generate": True,
                "roughness/mode": 1 if usage == "normal" else 0,
            },
        })
    payload = {"schema_version": 1, "source": source.name, "assets": entries}
    path = output_dir / "godot_import_manifest.json"
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return path
