"""Original low-resolution staff display; no reference-photo pixels."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/airport_gate_desk"
OUT.mkdir(parents=True, exist_ok=True)
(OUT / ".gdignore").write_text("")
im = Image.new("RGB", (768, 448), "#08191b")
d = ImageDraw.Draw(im)
font = "/System/Library/Fonts/Menlo.ttc"
def text(x, y, value, size=20, color="#719693"):
    d.text((x, y), value, font=ImageFont.truetype(font, size), fill=color)
d.rectangle((0, 0, 768, 58), fill="#163e42")
text(24, 14, "TERMINAL / GATE CONTROL", 24, "#b9cdbe")
text(28, 85, "FLIGHT CLOSED", 38, "#c5b57b")
text(28, 146, "BOARDING DISABLED  |  AGENT 02", 19)
for i, (key, value) in enumerate([
    ("SERVICE", "LAST DEPARTURE"), ("PASSENGERS", "000 / 000"),
    ("DOOR STATUS", "SEALED"), ("NEXT FLIGHT", "AWAITING UPDATE"),
]):
    y = 207 + i * 43
    d.line((28, y - 10, 735, y - 10), fill="#214045", width=1)
    text(28, y, key, 18)
    text(330, y, value, 18, "#a1b8ad")
text(28, 409, "F1 HELP   F2 MANIFEST   F3 CLOSE", 16)
im.save(OUT / "gate_screen.png")
