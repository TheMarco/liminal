from __future__ import annotations

import json
from importlib.resources import files
from pathlib import Path
from typing import Any

from .models import EffectConfig, EnvironmentProfile, PipelinePreset


def _read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return data


def bundled_profiles_dir() -> Path:
    packaged = Path(str(files("liminal_lab").joinpath("profiles")))
    return packaged if packaged.is_dir() and any(packaged.glob("*.json")) else Path(__file__).resolve().parents[2] / "profiles"


def bundled_presets_dir() -> Path:
    packaged = Path(str(files("liminal_lab").joinpath("presets")))
    return packaged if packaged.is_dir() and any(packaged.glob("*.json")) else Path(__file__).resolve().parents[2] / "presets"


def load_profile(name_or_path: str | Path, search_dir: Path | None = None) -> EnvironmentProfile:
    candidate = Path(name_or_path)
    if not candidate.exists():
        directory = search_dir or bundled_profiles_dir()
        candidate = directory / f"{candidate.stem}.json"
    data = _read_json(candidate)
    required = {"schema_version", "id", "display_name", "description", "effects"}
    missing = required - data.keys()
    if missing:
        raise ValueError(f"Profile {candidate} is missing: {', '.join(sorted(missing))}")
    effects = {
        key: EffectConfig(bool(value.get("enabled", False)), dict(value.get("parameters", {})))
        for key, value in data["effects"].items()
    }
    return EnvironmentProfile(int(data["schema_version"]), str(data["id"]), str(data["display_name"]), str(data["description"]), effects)


def load_preset(name_or_path: str | Path, search_dir: Path | None = None) -> PipelinePreset:
    candidate = Path(name_or_path)
    if not candidate.exists():
        directory = search_dir or bundled_presets_dir()
        candidate = directory / f"{candidate.stem}.json"
    data = _read_json(candidate)
    if "name" not in data or "parameters" not in data:
        raise ValueError(f"Invalid preset: {candidate}")
    return PipelinePreset(str(data["name"]), dict(data["parameters"]))


def list_json_ids(directory: Path) -> list[str]:
    return sorted(path.stem for path in directory.glob("*.json"))
