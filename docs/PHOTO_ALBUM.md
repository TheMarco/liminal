# Photo album

In Descent, press **P** during gameplay to open the album. Use the arrow keys,
Previous/Next buttons, or thumbnails to browse. **P / Esc** closes it. The game
pauses while browsing; recordings, photo review and doorway reveals finish
before it can open.

Every new shutter exposure is retained, including ordinary scenery and repeat
photographs. Each entry shows its floor and a short description of the framed
anomaly, or the floor context for ordinary views. Descriptions are frozen when
the photo is taken: the first numbered-door image records the 104/106 mismatch,
while subsequent images describe the changed door. Caption detection includes
previously documented anomalies, independently of evidence credit.

Images remain in the current run's album across death, floor transitions and
Continue. New runs show their own album. Older evidence cannot be reconstructed:
previous versions saved anomaly IDs, not images. CLI/dev runs keep images only
in memory and never write the normal profile's album.

Normal runs store JPEGs (up to 1600 pixels on the longest edge) and an atomic
JSON manifest under `user://photo_albums/<run seed>/`. Images are loaded on demand.
Missing images show an unavailable message; failed saves report an error. Older
runs' directories are retained, but only the current run is shown in the UI.

Checks:

- `tools/audit_photo_album_store.gd`: image roundtrip, descriptions, order, seed
  isolation, missing/corrupt files, failed-save rollback, memory image ownership.
- `tools/audit_photo_album.gd -- --mode=descent --nologo`: capture integration,
  empty/populated browsing, bounds, pause/resume and CLI isolation.
- `tools/capture_photo_album.gd -- --mode=descent --nologo --seed=21`: rendered
  shutter-to-album flow, descriptions before/after documenting, no repeat credit,
  opening gates, P/Escape, and 1280x800 / 960x540 layouts.

Run headless audits with `godot --headless --path . --log-file /tmp/album-engine.log
--script <audit path>`. The capture helper requires a graphical renderer and
writes images to `/tmp/liminal-photo-album`.

The floor photo requirement is a progression minimum, not a capture limit.
New discoveries continue to register and resolve after it is met; the HUD
shows the actual evidence total alongside the minimum. Distinct bleed marks
can also be documented freely after the minimum. Repeated subjects still save
photographs in the album without duplicate evidence credit.
