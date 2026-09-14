# Original mall storefront signs

Nine original sign textures generated for Marco's game with the built-in OpenAI
image-generation tool. Each sign was generated independently from a written
brief, without any reference image, downloaded logo or pixels from the previous
Katydid atlas. The briefs retain the existing shop names for continuity.

These project-generated images do not inherit the retired source's CC BY-NC
license or its third-party attribution requirement. They may replace that
noncommercial dependency in the game's commercial export.

| Runtime file | Shop |
| --- | --- |
| `sign_key_of_beauty.webp` | Key of Beauty |
| `sign_purple_side.webp` | Purple Side |
| `sign_natural_shop.webp` | Natural Shop |
| `sign_since_1977.webp` | Since 1977 |
| `sign_blue_marine.webp` | Blue Marine |
| `sign_royal_grill.webp` | Royal Grill |
| `sign_boutique_marguerite.webp` | Boutique Marguerite |
| `sign_cafe_paradise_noon.webp` | Cafe Paradise Noon |
| `sign_sunshine_princess.webp` | Sunshine Princess |

## Preparation and placement

Generated PNG masters and complete prompts are kept in `art/mall_signs/`, outside
the Godot resource tree. `bash tools/build_mall_signs.sh` crops the intended sign
band and resizes it to a 1536 × 256 WebP image at quality 92. No lettering is
painted over or copied from the retired assets. The Royal Grill crop is shifted
slightly upward to preserve its crown.

Every image has a 6:1 aspect ratio. The existing mall placement fits each face
within 4.25 × 0.46 m without stretching and retains its normal material,
deterministic distribution and generated-lettering fallback.

The former NC files have been removed from the repository. The Windows and
macOS export presets retain explicit NC exclusions as a safeguard.
