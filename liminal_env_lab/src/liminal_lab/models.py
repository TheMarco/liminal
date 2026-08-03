from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import numpy as np


@dataclass(frozen=True)
class EffectConfig:
    enabled: bool
    parameters: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class EnvironmentProfile:
    schema_version: int
    id: str
    display_name: str
    description: str
    effects: dict[str, EffectConfig]


@dataclass(frozen=True)
class PipelinePreset:
    name: str
    parameters: dict[str, dict[str, Any]]


@dataclass
class ExtractionResult:
    source: Path
    outputs: dict[str, np.ndarray]
