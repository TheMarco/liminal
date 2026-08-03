# Liminal Environment Lab

A deterministic, CPU-only asset-authoring pipeline for reusable Godot 4 environmental augmentation. Phase 2 adds structural and biological damage extraction, derived material maps, a visual desktop preview, and a Godot import handoff. It extracts effects already visible in source imagery; it is not an image generator.

## Install

Python 3.12 or newer is required.

```bash
cd liminal_env_lab
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e '.[dev]'
pytest
```

The runtime uses Pillow, OpenCV (headless), NumPy, and scikit-image. It has no GPU/CUDA dependency.

## CLI

```bash
liminal-lab list-profiles
liminal-lab list-presets
liminal-lab show-profile vegas_hotel
liminal-lab process photo.jpg build/photo --profile vegas_hotel --preset balanced
liminal-lab batch source_photos build/batch --profile annex --preset subtle --recursive
liminal-lab batch ceiling_scans build/ceiling-moisture --profile annex \
  --preset moisture_ceiling --effect moisture --orientation horizontal
liminal-lab process wall.jpg build/wall --profile annex --effect cracks
liminal-lab gui
```

Every processed source produces:

- `original_scan.png`, preserving the exact RGB source pixels in a consistent PNG artifact
- `moisture_mask.png`, `runoff_mask.png`, and `moisture_decal.png`
- `dirt_mask.png` and `grime_mask.png`
- `carpet_stain_mask.png` and `carpet_wear_mask.png`
- crack, rust, peeling-paint, mineral-deposit, and organic-growth masks when enabled by the profile
- `packed_effects.png` with moisture in R, dirt in G, structural damage in B, and organic growth in A
- `height_map.png`, OpenGL/Y-up `normal_map.png`, and `roughness_map.png` when structural or organic damage is present
- `godot_import_manifest.json`, identifying color, data, normal, and channel-packed assets for import tooling
- `contact_sheet.png` with the original, extracted effects, packed channels, and decal preview

Batch exports preserve the input directory hierarchy and place each image's assets in a directory named after the source.

The effect-specific horizontal moisture workflow skips unrelated dirt/carpet extraction, forces runoff to zero, and adds `quality_preview.png` plus a machine-readable `quality_report.json`. QC rejects masks with implausibly low/high coverage, excessive texture leakage, or ceiling runoff.

## Design

```text
liminal_env_lab/
├── presets/                 extraction parameter JSON
├── profiles/                environment composition JSON
├── src/liminal_lab/
│   ├── cli/                 command dispatch
│   ├── export/              channel packing and contact sheets
│   ├── extractors/          independently testable effect modules
│   ├── generators/          transparent decal construction
│   ├── processing/          shared image operations
│   ├── config.py            validated profile/preset loading
│   ├── models.py            stable data contracts
│   └── pipeline.py          single-image and batch orchestration
└── tests/                   unit, integration, and CLI tests
```

Profiles describe level intent; the default run processes implemented effects enabled by the chosen profile. `--effect` isolates one channel even when that profile disables it. Extractors do not contain environment-specific branches, and presets tune extraction independently from environment composition.

## Current Phase 2 boundary

Implemented now: cracks, rust, peeling paint, mineral deposits, organic growth, height/normal/roughness derivation, a non-destructive Tk preview, and a portable Godot manifest.

The next hardening pass is labeled-image calibration, richer per-effect diagnostics and cleanup controls, profile schema migration, and a Godot editor importer that consumes the manifest automatically.
