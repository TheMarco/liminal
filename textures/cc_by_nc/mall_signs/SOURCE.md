# Mall storefront signs — noncommercial

- **Title:** `Abandoned shopping mall`
- **Creator:** [Katydid](https://sketchfab.com/Katydid.)
- **Source:** <https://sketchfab.com/3d-models/abandoned-shopping-mall-e23793e82dec4d779268229d4a0429a9>
- **License:** [Creative Commons Attribution-NonCommercial 4.0 International](https://creativecommons.org/licenses/by-nc/4.0/)
- **Commercial-use status:** **Not permitted.** Builds containing these textures
  are noncommercial and must not be sold or monetized.

## Modifications

The source is a three-storey octagonal atrium whose geometry is not used: its
5.47 m storeys and 12 m-plus bay spacing do not fit this project's 12 m grid and
4.00 m mall gallery, and every surface is batched by material across the whole
ring, so individual shopfronts cannot be separated without leaving cut edges.

Only the painted fascia signs are used. Nine were cropped from the source's
512 px storefront atlas and saved as individual WebP textures:

`key_of_beauty`, `purple_side`, `natural_shop`, `since_1977`, `blue_marine`,
`royal_grill`, `boutique_marguerite`, `cafe_paradise_noon`, `sunshine_princess`.

Each is cropped only — no recolouring, retouching or resampling. They are mounted
on the project's own generated storefront fascias at the artwork's authored
aspect ratio.

Every use goes through one function in `scripts/chunk.gd`, so this dependency can
be removed in a single edit; the generated `MALL_NAMES` lettering it replaces
remains in place as the fallback.
