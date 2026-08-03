from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any

import numpy as np


class EffectExtractor(ABC):
    effect_id: str

    @abstractmethod
    def extract(self, rgb: np.ndarray, parameters: dict[str, Any]) -> dict[str, np.ndarray]:
        """Return named uint8 masks with the same height and width as rgb."""
