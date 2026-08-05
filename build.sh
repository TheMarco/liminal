#!/usr/bin/env bash
# Build It wants you to stay for macOS (universal, signed + notarized) and Windows.
# Needs Godot 4.6 on PATH with export templates installed.
#
# macOS notarization uses a stored notarytool profile (default AC_PASSWORD).
# One-time setup, if it is ever missing:
#   xcrun notarytool store-credentials "AC_PASSWORD" \
#       --apple-id "<apple-id-email>" --team-id 3ML6V62AF5 \
#       --password "<app-specific-password>"
# Skip notarization (fast local build) with:  NOTARIZE=0 ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

NOTARY_PROFILE="${NOTARY_PROFILE:-AC_PASSWORD}"
NOTARIZE="${NOTARIZE:-1}"
PRODUCT_NAME="It wants you to stay"
WINDOWS_EXE="build/windows/${PRODUCT_NAME}.exe"
WINDOWS_ZIP="build/windows/${PRODUCT_NAME}-Windows.zip"
APP="build/macos/${PRODUCT_NAME}.app"
MACOS_ZIP="build/macos/${PRODUCT_NAME}-macOS.zip"

godot --headless --path . --import

echo "==> Windows"
mkdir -p build/windows
godot --headless --path . --export-release "Windows Desktop" >/dev/null
rm -f "$WINDOWS_ZIP"
zip -q -j "$WINDOWS_ZIP" "$WINDOWS_EXE"

echo "==> macOS"
mkdir -p build/macos
# A previously notarized+stapled .app resists in-place overwrite (macOS App
# Management protection), which surfaces as a bogus "template binary not
# found" export error. Always export into a clean path.
rm -rf "$APP"
godot --headless --path . --export-release "macOS" >/dev/null

IDENTITY="$(security find-identity -v -p codesigning \
	| awk -F'"' '/Developer ID Application/{print $2; exit}')"
if [ -z "$IDENTITY" ]; then
	echo "   no Developer ID cert — ad-hoc signing only (will not pass Gatekeeper elsewhere)"
	codesign --force --deep --sign - "$APP"
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
		--entitlements /tmp/liminal.entitlements --sign "$IDENTITY" "$APP"
	if ! codesign --verify --deep --strict "$APP"; then
		if [ "$NOTARIZE" = "0" ]; then
			echo "   Developer ID signature did not verify — using a valid ad-hoc signature for this local build"
			codesign --force --deep --sign - "$APP"
			codesign --verify --deep --strict "$APP"
		else
			echo "   Developer ID signature is invalid; refusing to notarize a broken bundle" >&2
			exit 1
		fi
	fi

	if [ "$NOTARIZE" = "1" ]; then
		echo "==> notarizing (a few minutes)"
		rm -f build/macos/notarize-submit.zip
		ditto -c -k --keepParent "$APP" build/macos/notarize-submit.zip
		xcrun notarytool submit build/macos/notarize-submit.zip \
			--keychain-profile "$NOTARY_PROFILE" --wait
		xcrun stapler staple "$APP"
		rm -f build/macos/notarize-submit.zip
		spctl -a -vvv -t exec "$APP"
	fi
fi

# zip AFTER stapling, so the shipped archive carries the notarization ticket
rm -f "$MACOS_ZIP"
ditto -c -k --keepParent "$APP" "$MACOS_ZIP"

echo
echo "built:"
ls -lh "$MACOS_ZIP" "$WINDOWS_ZIP"
