# Hound

- **Title:** `Monster 6 (dog)`
- **Creator:** Supplied directly by the project owner on 2026-09-18 (source
  file `monster6-dog.glb`).
- **License:** Project-owned asset supplied for use as embedded game content.
- **Authored specification:** A quadruped on a 27-bone rig, roughly 0.75 m
  tall and 1.4 m long, with a single 1.0 s animation layer, at 31,356
  triangles. No foot-named bones, so stride calibration cannot measure it.
- **Modifications:** The supplied animated GLB is retained unchanged. Runtime
  applies a 100x prescale to counter its centimetre-scale Armature node,
  then scales it to a 1.55 m target height (between authored size and the
  2.08 m roster standard), and reuses the default walk speed until it is
  measured.
