#!/usr/bin/env bash
# Build It wants you to stay for macOS (universal, signed + notarized), Windows,
# and Linux x86_64.
# Needs Godot 4.7 or newer on PATH with matching export templates installed.
#
# macOS notarization uses a stored notarytool profile (default AC_PASSWORD).
# One-time setup, if it is ever missing:
#   xcrun notarytool store-credentials "AC_PASSWORD" \
#       --apple-id "<apple-id-email>" --team-id 3ML6V62AF5 \
#       --password "<app-specific-password>"
# Skip notarization (fast local build) with:  NOTARIZE=0 ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

GODOT_VERSION="$(godot --version)"
IFS=. read -r GODOT_MAJOR GODOT_MINOR _ <<< "$GODOT_VERSION"
if (( GODOT_MAJOR < 4 || (GODOT_MAJOR == 4 && GODOT_MINOR < 7) )); then
	echo "Godot 4.7+ is required for HDR display output (found $GODOT_VERSION)." >&2
	exit 1
fi

NOTARY_PROFILE="${NOTARY_PROFILE:-AC_PASSWORD}"
NOTARIZE="${NOTARIZE:-1}"
PRODUCT_NAME="It wants you to stay"
WINDOWS_EXE="build/windows/${PRODUCT_NAME}.exe"
WINDOWS_ZIP="build/windows/${PRODUCT_NAME}-Windows.zip"
LINUX_EXE="build/linux/${PRODUCT_NAME}.x86_64"
LINUX_ZIP="build/linux/${PRODUCT_NAME}-Linux.zip"
APP="build/macos/${PRODUCT_NAME}.app"
MACOS_ZIP="build/macos/${PRODUCT_NAME}-macOS.zip"

# Never export directly over a shipped artifact. A missing keychain identity or
# a failed notarization must leave the last known-good release intact.
STAGE_ROOT="$(mktemp -d /tmp/liminal-build.XXXXXX)"
trap 'rm -rf "$STAGE_ROOT"' EXIT
STAGE_WINDOWS_EXE="$STAGE_ROOT/windows/${PRODUCT_NAME}.exe"
STAGE_WINDOWS_ZIP="$STAGE_ROOT/windows/${PRODUCT_NAME}-Windows.zip"
STAGE_LINUX_EXE="$STAGE_ROOT/linux/${PRODUCT_NAME}.x86_64"
STAGE_LINUX_ZIP="$STAGE_ROOT/linux/${PRODUCT_NAME}-Linux.zip"
STAGE_APP="$STAGE_ROOT/macos/${PRODUCT_NAME}.app"
STAGE_MACOS_ZIP="$STAGE_ROOT/macos/${PRODUCT_NAME}-macOS.zip"
mkdir -p "$STAGE_ROOT/windows" "$STAGE_ROOT/linux" "$STAGE_ROOT/macos"

godot --headless --path . --import

echo "==> Windows"
mkdir -p build/windows
godot --headless --path . --export-release "Windows Desktop" "$STAGE_WINDOWS_EXE" >/dev/null
zip -q -j "$STAGE_WINDOWS_ZIP" "$STAGE_WINDOWS_EXE"

echo "==> Linux"
mkdir -p build/linux
godot --headless --path . --export-release "Linux" "$STAGE_LINUX_EXE" >/dev/null
chmod +x "$STAGE_LINUX_EXE"
zip -q -j "$STAGE_LINUX_ZIP" "$STAGE_LINUX_EXE"

echo "==> macOS"
mkdir -p build/macos
# Export into a clean staging path. The existing notarized app is not touched
# until signing, notarization, stapling, and Gatekeeper validation all pass.
godot --headless --path . --export-release "macOS" "$STAGE_APP" >/dev/null

IDENTITY="$(security find-identity -v -p codesigning \
	| awk -F'"' '/Developer ID Application/{print $2; exit}')"
if [ -z "$IDENTITY" ]; then
	if [ "$NOTARIZE" = "1" ]; then
		echo "   no Developer ID cert available; refusing to replace the last notarized release" >&2
		echo "   use NOTARIZE=0 only for an explicitly local ad-hoc build" >&2
		exit 1
	fi
	echo "   no Developer ID cert — ad-hoc signing requested for this local build"
	codesign --force --deep --sign - "$STAGE_APP"
else
	# hardened runtime is required for notarization; Godot needs library
	# validation relaxed to load its own resources
	cat > /tmp/liminal.entitlements <<-'XML'
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
		<key>com.apple.security.cs.disable-library-validation</key>
		<true/>
	</dict>
	</plist>
	XML
	codesign --force --deep --timestamp --options runtime \
		--entitlements /tmp/liminal.entitlements --sign "$IDENTITY" "$STAGE_APP"
	if ! codesign --verify --deep --strict "$STAGE_APP"; then
		if [ "$NOTARIZE" = "0" ]; then
			echo "   Developer ID signature did not verify — using a valid ad-hoc signature for this local build"
			codesign --force --deep --sign - "$STAGE_APP"
			codesign --verify --deep --strict "$STAGE_APP"
		else
			echo "   Developer ID signature is invalid; refusing to notarize a broken bundle" >&2
			exit 1
		fi
	fi

	if [ "$NOTARIZE" = "1" ]; then
		echo "==> notarizing (a few minutes)"
		rm -f build/macos/notarize-submit.zip
		ditto -c -k --keepParent "$STAGE_APP" build/macos/notarize-submit.zip
		xcrun notarytool submit build/macos/notarize-submit.zip \
			--keychain-profile "$NOTARY_PROFILE" --wait
		xcrun stapler staple "$STAGE_APP"
		rm -f build/macos/notarize-submit.zip
		spctl -a -vvv -t exec "$STAGE_APP"
	fi
fi

# Commit only validated staged artifacts. macOS is zipped AFTER stapling, so
# the shipped archive carries the notarization ticket.
rm -rf "$APP"
ditto "$STAGE_APP" "$APP"
cp -f "$STAGE_WINDOWS_EXE" "$WINDOWS_EXE"
cp -f "$STAGE_WINDOWS_ZIP" "$WINDOWS_ZIP"
cp -f "$STAGE_LINUX_EXE" "$LINUX_EXE"
cp -f "$STAGE_LINUX_ZIP" "$LINUX_ZIP"
rm -f "$MACOS_ZIP"
ditto -c -k --keepParent "$STAGE_APP" "$MACOS_ZIP"

echo
echo "built:"
ls -lh "$MACOS_ZIP" "$WINDOWS_ZIP" "$LINUX_ZIP"
