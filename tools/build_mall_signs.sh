#!/bin/bash
# Prepare the original generated sign artwork for Godot. Requires ImageMagick.
# Run from any directory: bash tools/build_mall_signs.sh
set -euo pipefail
cd "$(dirname "$0")/.."

sign_source="art/mall_signs/masters"
sign_output="textures/authored/mall_signs"
mkdir -p "$sign_output"

for sign_name in key_of_beauty purple_side natural_shop since_1977 blue_marine \
    royal_grill boutique_marguerite cafe_paradise_noon sunshine_princess; do
    sign_input="$sign_source/sign_$sign_name.png"
    read -r sign_width sign_height <<< "$(magick identify -format '%w %h' "$sign_input")"
    sign_crop_height=$((sign_width / 6))
    sign_crop_y=$(((sign_height - sign_crop_height) / 2))
    # The restaurant's crown sits a little higher than the other wordmarks.
    if [ "$sign_name" = royal_grill ]; then
        sign_crop_y=$((sign_height / 5))
    fi
    magick "$sign_input" -crop "${sign_width}x${sign_crop_height}+0+${sign_crop_y}" \
        +repage -resize 1536x256 -strip -quality 92 \
        "$sign_output/sign_$sign_name.webp"
done
