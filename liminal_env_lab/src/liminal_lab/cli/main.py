from __future__ import annotations

import argparse
from pathlib import Path

from ..config import bundled_presets_dir, bundled_profiles_dir, list_json_ids, load_profile
from ..pipeline import EXTRACTORS, process_batch, process_image


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="liminal-lab", description="Create reusable environmental augmentation assets.")
    subcommands = parser.add_subparsers(dest="command", required=True)
    process = subcommands.add_parser("process", help="Process one source image")
    process.add_argument("source", type=Path)
    process.add_argument("output", type=Path)
    process.add_argument("--profile", default="vegas_hotel")
    process.add_argument("--preset", default="balanced")
    process.add_argument("--effect", choices=tuple(EXTRACTORS))
    process.add_argument("--orientation", choices=("vertical", "horizontal"), default="vertical")
    batch = subcommands.add_parser("batch", help="Process an image directory")
    batch.add_argument("input", type=Path)
    batch.add_argument("output", type=Path)
    batch.add_argument("--profile", default="vegas_hotel")
    batch.add_argument("--preset", default="balanced")
    batch.add_argument("--recursive", action="store_true")
    batch.add_argument("--effect", choices=tuple(EXTRACTORS))
    batch.add_argument("--orientation", choices=("vertical", "horizontal"), default="vertical")
    subcommands.add_parser("list-profiles", help="List bundled environment profiles")
    subcommands.add_parser("list-presets", help="List bundled extraction presets")
    show = subcommands.add_parser("show-profile", help="Show a profile summary")
    show.add_argument("profile")
    subcommands.add_parser("gui", help="Launch the interactive Phase 2 preview")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "list-profiles":
        print("\n".join(list_json_ids(bundled_profiles_dir())))
    elif args.command == "list-presets":
        print("\n".join(list_json_ids(bundled_presets_dir())))
    elif args.command == "show-profile":
        profile = load_profile(args.profile)
        print(f"{profile.id}: {profile.display_name}")
        for effect_id, config in profile.effects.items():
            print(f"  {effect_id}: {'enabled' if config.enabled else 'disabled'}")
    elif args.command == "gui":
        from ..gui import launch
        launch()
    elif args.command == "process":
        result = process_image(args.source, args.output, args.profile, args.preset, args.effect, args.orientation)
        print(f"Wrote {len(result.outputs)} assets to {args.output}")
    elif args.command == "batch":
        results = process_batch(args.input, args.output, args.profile, args.preset, args.recursive, args.effect, args.orientation)
        print(f"Processed {len(results)} image(s) into {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
