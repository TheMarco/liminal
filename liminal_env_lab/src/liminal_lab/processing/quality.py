from __future__ import annotations

from dataclasses import asdict, dataclass

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont


@dataclass(frozen=True)
class MaskQuality:
    status: str
    score: int
    coverage: float
    texture_leakage: float
    runoff_coverage: float
    reasons: list[str]

    def to_dict(self) -> dict:
        return asdict(self)


def assess_ceiling_moisture(mask: np.ndarray, runoff: np.ndarray) -> MaskQuality:
    active = mask > 0
    coverage = float(active.mean())
    runoff_coverage = float((runoff > 0).mean())
    texture_leakage = float(cv2.Laplacian(mask, cv2.CV_32F).std())
    reasons: list[str] = []
    if coverage < 0.03:
        reasons.append("too little moisture was isolated")
    if coverage > 0.55:
        reasons.append("mask covers too much of the source")
    if texture_leakage > 14.0:
        reasons.append("high-frequency surface texture leaked into the mask")
    if runoff_coverage > 0.01:
        reasons.append("vertical runoff was detected on a horizontal ceiling scan")
    penalties = min(45, len(reasons) * 22)
    score = max(0, round(100 - penalties - max(0.0, coverage - 0.45) * 100))
    return MaskQuality("PASS" if not reasons else "REJECT", score, coverage, texture_leakage, runoff_coverage, reasons)


def build_quality_preview(original: np.ndarray, mask: np.ndarray, decal: np.ndarray, quality: MaskQuality) -> np.ndarray:
    cell_w, cell_h, header_h = 360, 360, 64
    canvas = Image.new("RGB", (cell_w * 3, cell_h + header_h), (20, 21, 23))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    color = (74, 210, 126) if quality.status == "PASS" else (245, 92, 92)
    reason = "Ready for library use" if not quality.reasons else "; ".join(quality.reasons)
    draw.text((14, 12), f"{quality.status}  |  QC score {quality.score}/100", fill=color, font=font)
    draw.text((14, 34), reason[:150], fill=(225, 225, 225), font=font)
    for index, (label, array) in enumerate((("Original", original), ("Moisture mask", mask), ("Decal on neutral surface", decal))):
        image = Image.fromarray(array)
        if image.mode == "RGBA":
            background = Image.new("RGB", image.size, (184, 184, 180))
            background.paste(image, mask=image.getchannel("A"))
            image = background
        else:
            image = image.convert("RGB")
        image.thumbnail((cell_w - 20, cell_h - 36), Image.Resampling.LANCZOS)
        x = index * cell_w + (cell_w - image.width) // 2
        y = header_h + 28 + (cell_h - 28 - image.height) // 2
        canvas.paste(image, (x, y))
        draw.text((index * cell_w + 10, header_h + 8), label, fill=(235, 235, 235), font=font)
    return np.asarray(canvas)
