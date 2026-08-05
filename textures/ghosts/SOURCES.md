# Ghost sheets — sources

Black RGBA figures on cylindrical billboards with noise-eroded edges
(`shaders/ghost.gdshader`). Hostile figures and distant crossing shadows are
animated; the five corner apparitions are deliberately motionless for their
two-second sighting.

Every persistent figure in the game is animated. A corner apparition is the
exception by design: it is a brief impossible shape, never a creature that
walks, chases, or shares the room long enough to read as a decal.

## User-supplied stationary corner apparitions (2026-08-04)

The white-backed PNGs were converted to 512px transparent black cutouts with
`tools/mask_silhouette.py --floor 0.04 --crop 0.035`. They are used only by
`scripts/corner_apparitions.gd`.

| Cutout | Supplied source |
|---|---|
| `corner_hooded_robe.png` | `magnific_silhouette-of-a-hooded-ma_6ARftqYiJO.png` |
| `corner_girl_ragged.png` | `magnific_silhouette-of-a-little-gi_aFEN7ZefSh.png` |
| `corner_girl_lace.png` | `magnific_silhouette-of-a-little-gi_N23aeSX6D9.png` |
| `corner_hooded_man.png` | `magnific_silhouette-of-a-man-weari_8amyNlxIrU.png` |
| `corner_woman_gown.png` | `magnific_silhouette-of-a-woman-whi_MBeLkHCDCm.png` |

## Generated for this project (Magnific)

Seven looping videos of dark hooded figures on white, 720×1280, 24 fps, ~4s.
The white is paper, not background: coverage becomes alpha directly, so smoke,
tendrils and blurred hands survive as partial alpha instead of being chopped
into an outline.

| Sheet | Source loop | Notes |
|---|---|---|
| wraith_anim.webp | `magnific_ghost-looping-animation-s_1sk7R5lr4r.mp4` | red eyes, ragged robe |
| wraith2.webp | `ghost2.mp4` | red eyes, stands in ground fog |
| wraith3.webp | `ghost3.mp4` | no lit eyes — the only blind one |
| wraith4.webp | `ghost4.mp4` | pale green eyes, hangs, trails into smoke |
| wraith5.webp | `ghost5.mp4` | red eyes, broad shoulders |
| wraith6.webp | `ghost6.mp4` | red eyes, one arm reaching |
| wraith7.webp | `ghost7.mp4` | red eyes, hangs, long smoke tail |

## Conversion

Built by `tools/build_flipbook.py`, which prints the shader constants and the
`BODY` row for each sheet:

    python3 tools/build_flipbook.py SRC.mp4 textures/ghosts/NAME.png \
        --frames 24 --height 288 --cols 6

Godot 4 ships one video codec, Theora, and it carries no alpha channel — a
video silhouette would be a black rectangle. So each loop becomes a 6×4 sprite
sheet of 24 frames, and the ghost shader cycles them by offsetting UVs. That
costs nothing over a static cutout and composes with the erosion, the stare
dissolve and the flashlight burn already in the shader.

Three things the conversion has to get right, all learned from these sources:

- **The backdrop is not white.** These sit at 214–249, not 255. Assuming pure
  white leaves a full-bleed wash on every frame and nothing ever crops, so the
  white point is measured from the frame border.
- **Alpha comes from distance to the backdrop, not luminance.** Luminance reads
  the lit eyes as mid-grey haze and half-erases them.
- **The cast shadow has to go.** Several loops composite a soft ellipse under
  the figure, which on a transparent billboard becomes a grey oval hanging at
  its feet. Width is the discriminator, not opacity: a smoke tail tapers to a
  fifth of the body's width while a shadow stays as wide as the figure.

Sheets are WebP — a 24-frame grid is an order of magnitude larger than a single
cutout, and PNG is the wrong trade at that size. Roughly 600 KB each.

The shader normalises a lit pixel to full brightness in its own hue rather than
using the painted value: several sheets paint their eyes a dark red around 0.3,
which came through barely above the black body and read as no eyes at all. Hue
is the artwork's business; how brightly a lit eye burns is the shader's.

## Variant mapping (scripts/shadow_figure.gd)

REVENANT, DROWNED, PILGRIM, TRAILING, GAOLER, REACHER, DRIFTER take one sheet
each, weighted close to evenly — none is a fallback for the others, so there is
no reason to favour one. TRAILING and DRIFTER are the two that hang rather than
walk and trail into nothing where legs should be; `UNDERNEATH_THEMES` keeps
them to the sewers and the asylum, the floors where something could have got in
from below.

The complete project attribution record is `THIRD_PARTY_ASSETS.md`.
