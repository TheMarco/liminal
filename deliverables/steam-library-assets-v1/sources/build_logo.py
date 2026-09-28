"""Rebuild the existing code-native trailer title as outlined SVG.

Uses the same DIN Condensed font and nested doorway construction as
tools/edit_promo.py:title_layer. This does not edit generated bitmap art.
PNG export is performed separately by sharp from these vector outlines.
"""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.transformPen import TransformPen

HERE = Path(__file__).resolve().parent
font = TTFont('/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf')
glyphs = font.getGlyphSet()
cmap = font.getBestCmap()
kern = {}
if 'kern' in font:
    for table in font['kern'].kernTables:
        kern.update(table.kernTable)

def outline(text):
    path = SVGPathPen(glyphs)
    bounds = BoundsPen(glyphs)
    advance = 0
    previous = None
    for char in text:
        name = cmap[ord(char)]
        if previous:
            advance += kern.get((previous, name), 0)
        glyph = glyphs[name]
        matrix = (1, 0, 0, 1, advance, 0)
        glyph.draw(TransformPen(path, matrix))
        glyph.draw(TransformPen(bounds, matrix))
        advance += font['hmtx'][name][0]
        previous = name
    return path.getCommands(), bounds.bounds

first, b1 = outline('IT WANTS')
second, b2 = outline('YOU TO STAY')
scale = 890 / (b2[2] - b2[0])
cap_height = max(b1[3] - b1[1], b2[3] - b2[1]) * scale
gap = 30
height = 2 * cap_height + gap
top = (480 - height) / 2
bottom = top + height
text_x = 326

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1280" height="480" viewBox="0 0 1280 480">
<title>It wants you to stay - library logo</title>
<desc>Original trailer branding reconstructed as clean vector outlines on transparency.</desc>
<defs><g id="logo">
  <g fill="none" stroke="currentColor" stroke-width="9" stroke-linejoin="miter" stroke-linecap="butt">
    <path d="M 64 {bottom:.4f} V {top:.4f} H 261 V {bottom:.4f}"/>
    <path d="M 109 {bottom:.4f} V {top+height*.15:.4f} H 216 V {bottom:.4f}"/>
    <path d="M 145 {bottom:.4f} V {top+height*.29:.4f} H 181 V {bottom:.4f}"/>
  </g>
  <path fill="currentColor" d="{first}" transform="translate({text_x-b1[0]*scale:.4f},{top+b1[3]*scale:.4f}) scale({scale:.8f},{-scale:.8f})"/>
  <path fill="currentColor" d="{second}" transform="translate({text_x-b2[0]*scale:.4f},{top+cap_height+gap+b2[3]*scale:.4f}) scale({scale:.8f},{-scale:.8f})"/>
</g></defs>
<use xlink:href="#logo" color="#551b18" transform="translate(2,2)" opacity="0.86"/>
<use xlink:href="#logo" color="#ede7d5"/>
</svg>'''
assert top > 20 and bottom < 460, (top, bottom)
(HERE / 'library-logo-outlined.svg').write_text(svg)
print(f'Wrote native vector logo: 1280 x 480; title height {height:.1f}px, top {top:.1f}px')
