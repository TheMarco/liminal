# Fonts

Downloaded from the Google Fonts repo (`github.com/google/fonts`) with
`python3 urllib` — `curl` is permission-denied in this environment.

| File | Family | Licence | Used for |
|---|---|---|---|
| `RockSalt-Regular.ttf` | Rock Salt | Apache-2.0 | Asylum wall scrawl — shaky block capitals, reads as marker/scratched plaster |
| `Caveat-Regular.ttf` | Caveat | OFL-1.1 | Asylum wall scrawl variant — fast, fluid, desperate cursive |
| `VT323-Regular.ttf` | VT323 | OFL-1.1 | Office CRT records — square, low-resolution terminal glyphs with nearest filtering |
| `RazorKeen-Regular.otf` | Razor Keen | CC0 (declared in the font's own name table: "Released in 2022 under CC0 license. No rights reserved.") | Photo-only hidden writing (`PhotoAnomaly.WRITING_FONT`) |

Both are picked per-cell in `Chunk._asy_scrawl` so a corridor mixes hands, as
if written by different people over years.

Caveat ships as a variable font (`Caveat[wght].ttf` upstream, saved here under
the static name); Godot loads it at its default weight, which is what we want.

Re-download:

    https://github.com/google/fonts/raw/main/apache/rocksalt/RockSalt-Regular.ttf
    https://github.com/google/fonts/raw/main/ofl/caveat/Caveat%5Bwght%5D.ttf
    https://github.com/google/fonts/raw/main/ofl/vt323/VT323-Regular.ttf
