# Original mall sign artwork

Nine independent images created with the built-in image-generation tool from
the complete written briefs in `prompts.json`. No old texture or logo was used
as an image reference. `masters/` retains the selected original PNG outputs.

Run `bash tools/build_mall_signs.sh` from the project to prepare the cropped
1536 × 256 runtime WebP faces in `textures/authored/mall_signs/`.

This folder is ignored by Godot and excluded from exports. Only the runtime
faces are imported into the game; the generation masters are kept for editing.
