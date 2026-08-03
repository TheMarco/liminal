from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def build_contact_sheet(items: Mapping[str, np.ndarray], cell_size: tuple[int, int] = (320, 220), columns: int = 3) -> np.ndarray:
    if not items:
        raise ValueError("Contact sheet requires at least one image")
    cell_w, cell_h = cell_size
    label_h = 28
    rows = (len(items) + columns - 1) // columns
    sheet = Image.new("RGB", (cell_w * columns, cell_h * rows), (24, 24, 26))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (label, array) in enumerate(items.items()):
        row, column = divmod(index, columns)
        image = Image.fromarray(array)
        if image.mode == "RGBA":
            checker = Image.new("RGB", image.size, (174, 174, 174))
            checker.paste(image, mask=image.getchannel("A"))
            image = checker
        else:
            image = image.convert("RGB")
        image.thumbnail((cell_w - 16, cell_h - label_h - 12), Image.Resampling.LANCZOS)
        x = column * cell_w + (cell_w - image.width) // 2
        y = row * cell_h + label_h + (cell_h - label_h - image.height) // 2
        sheet.paste(image, (x, y))
        draw.text((column * cell_w + 9, row * cell_h + 8), label, fill=(235, 235, 235), font=font)
    return np.asarray(sheet)
