#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
LIMINAL_GODOT_BIN="${LIMINAL_GODOT:-godot}"
exec "$LIMINAL_GODOT_BIN" --path . tools/cross_video_review.tscn
