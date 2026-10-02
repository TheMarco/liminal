#!/bin/bash
# Release gate: require Developer ID signing, a stapled ticket, and Gatekeeper acceptance.
set -euo pipefail

app_path="${1:?Usage: verify_macos_distribution.sh /path/to/Game.app}"
[[ -d "$app_path" ]] || { printf 'Mac app not found: %s\n' "$app_path" >&2; exit 1; }

signature_details="$(codesign -dv --verbose=4 "$app_path" 2>&1)" || {
    printf '%s\n' "$signature_details" >&2
    exit 1
}
case "$signature_details" in
    *'Authority=Developer ID Application:'*) ;;
    *) printf 'Mac release rejected: a Developer ID Application signature is required.\n' >&2; exit 1 ;;
esac

codesign --verify --deep --strict --verbose=2 "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=4 "$app_path"
printf 'Mac distribution checks passed: %s\n' "$app_path"
