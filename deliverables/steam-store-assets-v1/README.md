# It wants you to stay - Steam store assets v1

The coordinated key art carries forward the existing trailer's cream condensed title and nested-door emblem. A warm casino opens into a cold fluorescent office corridor. The capsule art is generated marketing imagery based on the game's branding and gameplay references; it is not a gameplay screenshot.

## Upload files

All files below are in `upload/` and in `steam-upload-assets.zip`.

| Steam slot | Filename | Exact dimensions |
| --- | --- | --- |
| Header Capsule | `header-capsule-920x430.png` | 920 x 430 |
| Small Capsule | `small-capsule-462x174.png` | 462 x 174 |
| Main Capsule | `main-capsule-1232x706.png` | 1232 x 706 |
| Vertical Capsule | `vertical-capsule-748x896.png` | 748 x 896 |
| Page Background | `page-background-1438x810.png` | 1438 x 810 |
| Game manual | `it-wants-you-to-stay-player-guide.pdf` | A4, 4 pages |
| Quick reference | `it-wants-you-to-stay-quick-reference.pdf` | A4, 1 page |

Use the player guide for the main manual slot. The one-page quick reference is also supplied if you prefer a compact manual or want an additional downloadable reference. Extract the ZIP and upload individual files to their respective slots.

The capsule images contain the game title and emblem only, with no review quotes, scores, awards, release dates or promotional text. The page background contains no title or emblem and is intentionally subdued; Steam applies its own tint and edge treatment.

## Verification

- All five final images are RGB PNGs at the exact requested pixel dimensions.
- The small capsule was visually checked at 462 x 174, 231 x 87 and 184 x 69.
- All five PDF pages were rendered with Poppler and visually inspected for legibility, wrapping, table alignment and clipping.
- Control descriptions were checked against `scripts/game_input.gd`, `scripts/photo_camera.gd`, `scripts/photo_album.gd`, `scripts/vhs_ritual.gd`, `scripts/player.gd`, `scripts/title.gd` and `scripts/game_settings.gd`.
- Campaign persistence details were checked against `docs/DESCENT.md` and `docs/PHOTO_ALBUM.md`.
- No game code or runtime settings were changed. The package was not uploaded to Steam.

`asset-manifest.json` records file sizes, pixel dimensions, PDF page counts and SHA-256 checksums. `review/` contains local proof images and PDF page renders; these are not upload assets.

## Sources and revisions

- Image creation: built-in `image_gen.imagegen` tool. One separately composed image per requested slot.
- Exact prompt set: `sources/image-prompts.json`.
- Full-resolution generated artwork: `sources/*-master.png`.
- Deterministic export sizing: macOS `sips`, resampling the full image without cropping or repainting.
- Existing branding reference: `deliverables/promo_trailer/v5-metadata/title-review.jpg`.
- Gameplay visual reference: `deliverables/promo_trailer/v5-metadata/shot-contact-sheet.jpg`.
- Original emblem: `icon.png`.
- PDF source: `sources/build_guides.py`, using ReportLab and embedded fonts.

The PDF source is editable. Run it with the bundled Python environment to rebuild both guides; font paths in the script point to this Mac's bundled runtime and existing DIN Condensed font. The guides deliberately avoid untested hardware promises and ending spoilers.
