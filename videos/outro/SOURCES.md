# Ending source

- `outside.ogv`: the ending "OUTSIDE", 94.7s, 1920x1080, 24 fps, Theora +
  Vorbis 48 kHz, ~41 MB. Built 2026-10-17 from an engine render plus
  Seedance 2.5 clips generated on hedra.com, assembled with game sounds by
  `tools/ending_outside_assemble.py`. Full production record:
  `docs/ENDING_CUTSCENE_SCRIPT.md`; every source and prompt:
  `art/ending_outside/v2/`.

  Encode (from `deliverables/ending-outside/outside.mp4`, the assembly
  script's output):

  ```
  ffmpeg2theora deliverables/ending-outside/outside.mp4 --videoquality 8 \
      --audioquality 6 -o videos/outro/outside.ogv
  godot --headless --path . --import
  ```

  Played by `main._play_descent_outro()` when a run is won, before the
  summary. Covered by `tools/audit_descent_outro.gd`.
