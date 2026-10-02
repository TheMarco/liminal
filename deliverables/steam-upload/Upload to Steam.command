#!/bin/bash
set -euo pipefail

upload_dir="$(cd "$(dirname "$0")" && pwd)"
project_dir="$(cd "$upload_dir/../.." && pwd)"
steamcmd_path="$project_dir/build/steam-tools/steamcmd.sh"
steam_user="${1:-marcovhv}"

fail() {
    printf '\n%s\n' "$1"
    read -r -p 'Press Return to close.'
    exit 1
}

[[ -x "$steamcmd_path" ]] || fail "SteamCMD is missing: $steamcmd_path"
for game_file in \
    'windows/It wants you to stay.exe' \
    'linux/It wants you to stay.x86_64' \
    'macos/It wants you to stay.app/Contents/MacOS/It wants you to stay'; do
    [[ -s "$project_dir/build/$game_file" ]] || fail "Missing game file: $game_file"
done

printf '\nChecking the Mac distribution signature and notarization...\n'
if ! bash "$project_dir/tools/verify_macos_distribution.sh" "$project_dir/build/macos/It wants you to stay.app"; then
    fail 'Mac release verification failed. Upload cancelled before Steam login.'
fi

mkdir -p "$project_dir/build/steam-upload-output"
cd "$upload_dir"

printf '\nIt Wants You To Stay — Steam upload\n'
printf 'Account: %s\n' "$steam_user"
printf 'App: 4336360 | Build: 0.5.3 | Windows, Linux and macOS\n\n'
printf 'Enter your Steam password and Steam Guard code here if requested.\n'
printf 'This uploads the existing builds; it does not release the game.\n\n'

# Steam stops on a failed command. Preview validates file mappings before upload.
set +e
bash "$steamcmd_path" \
    +@ShutdownOnFailedCommand 1 \
    +login "$steam_user" \
    +run_app_build "$upload_dir/app_preview_4336360.vdf" \
    +run_app_build "$upload_dir/app_build_4336360.vdf" \
    +quit
upload_result=$?
set -e

printf '\nSteamCMD finished (exit code %s).\n' "$upload_result"
printf 'A successful upload reports a BuildID; verify it on the Steamworks Builds page.\n'
printf 'Logs: %s\n' "$project_dir/build/steam-upload-output"
read -r -p 'Press Return to close.'
exit "$upload_result"
