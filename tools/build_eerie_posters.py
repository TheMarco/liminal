#!/usr/bin/env python3
"""Build exact-text, logo-bearing poster textures from generated art plates."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "paintings" / "posters"
RUNTIME_DIR = ROOT / "paintings" / "runtime" / "posters"
GENERATED_DIR = ROOT / "paintings" / "generated"
LOGO_PATH = SOURCE_DIR / "liminal-logo.png"
WIDTH = 768
HEIGHT = 1024
ART_BOTTOM = 842

FONT_BOLD = Path("/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf")
FONT_REGULAR = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")


@dataclass(frozen=True)
class ThemeSpec:
    name: str
    plate: str
    crop: tuple[int, int, int, int]
    focus_y: float
    header: str
    accent: tuple[int, int, int]
    slogans: tuple[str, ...]


THEMES = (
    ThemeSpec(
        "office",
        "poster-bg-office-annex.png",
        (13, 14, 501, 1524),
        0.39,
        "EMPLOYEE GUIDANCE",
        (77, 104, 91),
        (
            "YOUR DESK REMEMBERS YOUR SHAPE",
            "PRODUCTIVITY CONTINUES AFTER YOU LEAVE",
            "ATTENDANCE IS A FORM OF GRATITUDE",
            "THE MEETING HAS ALREADY STARTED",
            "PLEASE KEEP YOUR THOUGHTS WITHIN THE CUBICLE",
            "YOUR REPLACEMENT IS ONBOARDING NOW",
            "CLOCK OUT ONLY WHEN THE CLOCK AGREES",
            "HUMAN RESOURCES KNOWS WHERE YOU ARE",
            "A CLEAN DESK LEAVES NO EVIDENCE",
        ),
    ),
    ThemeSpec(
        "annex",
        "poster-bg-office-annex.png",
        (523, 14, 1012, 1524),
        0.42,
        "GUEST SERVICES",
        (166, 111, 25),
        (
            "WELCOME BACK. YOU NEVER CHECKED OUT.",
            "EVERY KEY OPENS THE SAME ROOM",
            "PLEASE ENJOY YOUR EXTENDED STAY",
            "HOUSEKEEPING WILL ENTER WHETHER YOU ARE READY",
            "YOUR RESERVATION HAS NO DEPARTURE DATE",
            "QUIET GUESTS RECEIVE COMPLIMENTARY NIGHTS",
            "THE LOBBY IS CLOSER THAN IT APPEARS",
            "PLEASE LEAVE YOUR NAME AT THE DESK",
            "SOMEONE ELSE IS USING YOUR ROOM",
        ),
    ),
    ThemeSpec(
        "airport",
        "poster-bg-airport-mall.png",
        (9, 8, 534, 1438),
        0.36,
        "PASSENGER NOTICE",
        (46, 103, 130),
        (
            "YOUR GATE HAS ALWAYS BEEN OPEN",
            "FINAL BOARDING BEGAN YESTERDAY",
            "THANK YOU FOR WAITING. WE NOTICED.",
            "YOUR FLIGHT IS ON TIME. YOU ARE LATE.",
            "UNATTENDED PASSENGERS WILL BE REMOVED",
            "ALL DESTINATIONS SHARE THIS TERMINAL",
            "YOUR BAGGAGE ARRIVED WITHOUT YOU",
            "PLEASE REMAIN SEATED DURING THE DELAY",
            "LAST CALL FOR A NAME YOU RECOGNIZE",
        ),
    ),
    ThemeSpec(
        "mall",
        "poster-bg-airport-mall.png",
        (552, 8, 1077, 1438),
        0.39,
        "CUSTOMER CARE",
        (130, 54, 49),
        (
            "EVERYTHING MUST GO. PLEASE REMAIN.",
            "THE STORES ARE CLOSED. THE MALL IS OPEN.",
            "YOUR PURCHASE HAS BEEN REMEMBERED",
            "YOUR RECEIPT IS PROOF YOU WERE HERE",
            "THE FOOD COURT WILL SERVE YOU SHORTLY",
            "PLEASE RETURN TO THE STORE THAT CHOSE YOU",
            "TODAY'S SALE ENDS WHEN THE LIGHTS RETURN",
            "MANNEQUINS ARE FOR DISPLAY ONLY. SO ARE YOU.",
            "CUSTOMER SERVICE IS DIRECTLY BEHIND YOU",
        ),
    ),
    ThemeSpec(
        "school",
        "poster-bg-school-asylum.png",
        (0, 0, 531, 1448),
        0.38,
        "STUDENT SUCCESS",
        (91, 51, 60),
        (
            "PERFECT ATTENDANCE IS FOREVER",
            "THE BELL RINGS WHEN YOU ARE READY",
            "TODAY'S LESSON HAS NO END",
            "YOUR SEAT HAS BEEN KEPT WARM",
            "HALL PASSES DO NOT WORK AFTER DARK",
            "THE SUBSTITUTE KNOWS YOUR NAME",
            "PLEASE FACE THE FRONT UNTIL DISMISSED",
            "THERE WILL BE A TEST ON WHAT YOU FORGOT",
            "GRADUATION HAS BEEN POSTPONED INDEFINITELY",
        ),
    ),
    ThemeSpec(
        "asylum",
        "poster-bg-school-asylum.png",
        (555, 0, 1086, 1448),
        0.40,
        "PATIENT PROGRESS",
        (85, 112, 94),
        (
            "YOUR IMPROVEMENT HAS BEEN OBSERVED",
            "COMPLIANCE IS A FORM OF WELLNESS",
            "YOU MAY LEAVE WHEN YOU ARRIVE",
            "YOUR FILE IS THICKER THAN YOU REMEMBER",
            "GROUP THERAPY BEGINS WHEN YOU ARE ALONE",
            "THE DOCTOR WILL SEE THROUGH YOU NOW",
            "RESTRAINT IS A FORM OF REASSURANCE",
            "PLEASE REPORT ANY UNFAMILIAR MEMORIES",
            "RECOVERY LOOKS DIFFERENT FROM INSIDE",
        ),
    ),
    ThemeSpec(
        "prison",
        "poster-bg-prison-generic.png",
        (16, 99, 501, 1435),
        0.44,
        "CONDUCT STANDARD",
        (158, 73, 36),
        (
            "GOOD BEHAVIOR IS ALWAYS WATCHED",
            "VISITING HOURS HAVE BEEN EXTENDED INDEFINITELY",
            "YOUR CELL KNOWS WHEN YOU ARE EMPTY",
            "COUNT YOURSELF BEFORE LIGHTS OUT",
            "FREEDOM IS A SCHEDULED ACTIVITY",
            "THE YARD IS OPEN. THE SKY IS NOT.",
            "YOUR SENTENCE KNOWS WHERE YOU SLEEP",
            "SILENCE WILL BE RECORDED AS CONSENT",
            "RELEASE PAPERWORK IS CURRENTLY MISSING",
        ),
    ),
)


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    if not path.exists():
        raise FileNotFoundError(f"Required poster font is missing: {path}")
    return ImageFont.truetype(str(path), size)


def wrap_words(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont,
               max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        if draw.textbbox((0, 0), candidate, font=face)[2] <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def fitted_copy(draw: ImageDraw.ImageDraw, text: str, max_width: int,
                max_height: int) -> tuple[ImageFont.FreeTypeFont, list[str], int]:
    for size in range(82, 29, -2):
        face = font(FONT_BOLD, size)
        lines = wrap_words(draw, text, face, max_width)
        spacing = max(8, size // 7)
        box = draw.multiline_textbbox(
            (0, 0), "\n".join(lines), font=face, spacing=spacing)
        if box[2] <= max_width and box[3] <= max_height and len(lines) <= 5:
            return face, lines, spacing
    face = font(FONT_BOLD, 30)
    return face, wrap_words(draw, text, face, max_width), 8


def logo_layer() -> Image.Image:
    logo = Image.open(LOGO_PATH).convert("RGBA")
    if logo.getchannel("A").getbbox() is None:
        raise ValueError("The supplied Liminal logo has no visible pixels")
    # Preserve the complete supplied lockup, including its authored black
    # field. Cropping to visible marks made the earlier version look like a
    # loose icon instead of the Liminal Inc. corporate signature.
    return logo


def poster_background(spec: ThemeSpec, variant: int) -> Image.Image:
    plate = Image.open(GENERATED_DIR / spec.plate).convert("RGB")
    panel = plate.crop(spec.crop)
    style = variant % 3
    series = variant // 3
    focus_y = min(0.62, max(
        0.28,
        spec.focus_y + (style - 1) * 0.035 + (series - 1) * 0.012,
    ))
    art = ImageOps.fit(
        panel,
        (WIDTH, ART_BOTTOM),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, focus_y),
    )
    art = ImageEnhance.Contrast(art).enhance((0.94, 1.02, 0.98)[style])
    art = ImageEnhance.Color(art).enhance((0.82, 0.94, 0.74)[style])
    # The corporate footer is part of the layout, not an overlay. Compose the
    # full environment plate entirely above it so the logo can never amputate
    # a fountain, desk, doorway, or other focal object at the bottom edge.
    bg = Image.new("RGB", (WIDTH, HEIGHT), (3, 5, 5))
    bg.paste(art, (0, 0))
    return bg.convert("RGBA")


def add_vignette(image: Image.Image) -> None:
    shade = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shade)
    for inset in range(0, 52, 4):
        alpha = max(0, 34 - inset // 2)
        draw.rounded_rectangle(
            (inset, inset, WIDTH - 1 - inset, HEIGHT - 1 - inset),
            radius=10,
            outline=(7, 10, 9, alpha),
            width=5,
        )
    image.alpha_composite(shade)


def build_poster(spec: ThemeSpec, variant: int, slogan: str,
                 logo: Image.Image) -> Image.Image:
    image = poster_background(spec, variant)
    add_vignette(image)
    draw = ImageDraw.Draw(image, "RGBA")
    cream = (239, 234, 210, 255)
    ink = (21, 24, 22, 255)
    accent = (*spec.accent, 255)

    draw.rectangle((28, 28, WIDTH - 29, HEIGHT - 29), outline=(238, 233, 211, 210), width=5)

    header_face = font(FONT_REGULAR, 22)
    header_text = f"{spec.header}  /  {variant + 1:02d}"
    header_width = draw.textbbox((0, 0), header_text, font=header_face)[2]

    style = variant % 3
    if style == 0:
        panel_fill = (235, 230, 207, 232)
        text_fill = ink
        header_fill = (*spec.accent, 255)
        panel_top = 58
    elif style == 1:
        panel_fill = (15, 19, 18, 220)
        text_fill = cream
        header_fill = (226, 220, 195, 255)
        panel_top = 74
    else:
        panel_fill = (*spec.accent, 222)
        text_fill = cream
        header_fill = (246, 240, 216, 255)
        panel_top = 48

    copy_face, lines, spacing = fitted_copy(draw, slogan, WIDTH - 128, 350)
    copy = "\n".join(lines)
    copy_box = draw.multiline_textbbox((0, 0), copy, font=copy_face, spacing=spacing)
    copy_height = copy_box[3] - copy_box[1]
    panel_bottom = panel_top + 58 + copy_height + 68
    draw.rounded_rectangle(
        (42, panel_top, WIDTH - 43, panel_bottom),
        radius=7,
        fill=panel_fill,
    )
    draw.rectangle((42, panel_top, 57, panel_bottom), fill=accent)
    draw.text((76, panel_top + 23), header_text, font=header_face, fill=header_fill)
    draw.rectangle(
        (76, panel_top + 51, min(WIDTH - 78, 76 + header_width), panel_top + 55),
        fill=accent if style < 2 else cream,
    )
    draw.multiline_text(
        (76, panel_top + 72),
        copy,
        font=copy_face,
        fill=text_fill,
        spacing=spacing,
    )

    # The white/gray lockup is only approved over a dark field. Give every
    # design the same black corporate footer so light artwork can never wash
    # out the wordmark or leave it floating without contrast.
    plaque = (42, ART_BOTTOM + 8, WIDTH - 43, HEIGHT - 42)
    draw.rounded_rectangle(
        plaque,
        radius=5,
        fill=(3, 5, 5, 248),
        outline=(*spec.accent, 255),
        width=3,
    )
    fitted_logo = ImageOps.contain(logo, (620, 104), Image.Resampling.LANCZOS)
    logo_x = (WIDTH - fitted_logo.width) // 2
    logo_y = HEIGHT - 160 + (104 - fitted_logo.height) // 2
    image.alpha_composite(fitted_logo, (logo_x, logo_y))
    return image.convert("RGB")


def save_all(specs: Iterable[ThemeSpec]) -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    logo = logo_layer()
    for spec in specs:
        for variant, slogan in enumerate(spec.slogans):
            poster = build_poster(spec, variant, slogan, logo)
            stem = f"poster-{spec.name}-{variant + 1:02d}"
            poster.save(SOURCE_DIR / f"{stem}.png", optimize=True)
            poster.save(
                RUNTIME_DIR / f"{stem}.webp",
                "WEBP",
                quality=88,
                method=6,
            )
            print(f"built {stem}: {slogan}")


if __name__ == "__main__":
    save_all(THEMES)
