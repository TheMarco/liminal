# Ghost silhouettes — sources

Black RGBA cutouts on cylindrical billboards with noise-eroded edges
(`shaders/ghost.gdshader`), spawned by `scripts/shadow_figure.gd`.

## Traced (Wikimedia Commons)

Photo-traced human silhouettes, thresholded and cropped to 512px. Hard,
binary edges — the shader carves their outline out of drifting noise so they
do not look stamped.

| File | Source (Wikimedia Commons) | License | Author |
|---|---|---|---|
| man_bald.png | File:Silhouette of a standing man.svg | CC0 | Mette Aumala |
| man_shirt.png | File:Silhouette of man standing and facing forward.svg | CC0 | Madeleine Price Ball |
| woman_walk.png | File:1Silhouette Female.jpg | CC BY 2.0 | Phil Bronnery (Moscow, Russia) |
| girl.png | File:Girl silhouette black.svg | CC0 | OpenClipart-Vectors |

## Painted (generated for this project, Magnific)

Dark figures on white, masked off the white by `tools/mask_silhouette.py`.
The white is paper, not background: coverage becomes alpha directly, so
smoke, loose hair and blurred hands survive as partial alpha instead of being
chopped into an outline. These arrive soft-edged and the shader eases off
(`SOFT` in shadow_figure.gd: erode 0.14, edge window opened right up).

The exact runs, from `~/Downloads/magnific_creepy-silouette-*`:

    coat.png    …like-img_8vXnGMoIrU  --ground 0.25 --melt 0.02
    gown.png    …in-style_iA9sls73uK  --floor 0.08 --ground 0.20 --melt 0.03
    husk.png    …in-style_gJLQF1RSXO  --floor 0.22 --gain 1.4 --ground 0.30 --band 0.30 --melt 0.04
    knife.png   …in-style_TeWNRhpVNR  --floor 0.10 --gain 1.3 --ground 0.30 --melt 0.03
    axeman.png  …in-style_SOsFbI4Ub8  --floor 0.14 --gain 1.35 --ground 0.35 --band 0.30 --melt 0.04
    horned.png  …in-style_74SbkFHJAL  --floor 0.08 --trim 0.145 --melt 0.03
    smoke.png   …in-style_ONwK182ynm  --floor 0.07 --melt 0.03

`--floor` cuts the paper grain, `--ground` the faint cast shadow at the feet,
`--trim` a pooled one too dark to threshold away (horned stood in its own
shadow), `--melt` dissolves the base so nothing ends on a cut line.

## Variant mapping (scripts/shadow_figure.gd)

GAUNT/TALL use man_bald (TALL stretched to 2.35m), CRAWLER man_shirt,
WRAITH/WATCHER woman_walk (WATCHER mirrored), CHILD girl. COAT, GOWN, HUSK,
KNIFE, AXEMAN take one painted cutout each; HORNED and SMOKE are the two that
are not pretending to be people, and `UNDERNEATH_THEMES` keeps them to the
sewers and the asylum.
