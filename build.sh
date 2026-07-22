#!/usr/bin/env bash
# Build Liminal Vegas for macOS (universal, signed + notarized) and Windows.
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

godot --headless --path . --import

echo "==> Windows"
mkdir -p build/windows
godot --headless --path . --export-release "Windows Desktop" >/dev/null
(cd build/windows && rm -f LiminalVegas-Windows.zip \
	&& zip -q -j LiminalVegas-Windows.zip LiminalVegas.exe)

echo "==> macOS"
mkdir -p build/macos
godot --headless --path . --export-release "macOS" >/dev/null
APP=build/macos/LiminalVegas.app

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
	codesign --force --timestamp --options runtime \
		--entitlements /tmp/liminal.entitlements --sign "$IDENTITY" "$APP"
	codesign --verify --strict "$APP"

	if [ "$NOTARIZE" = "1" ]; then
		echo "==> notarizing (a few minutes)"
		rm -f build/macos/notarize-submit.zip
		ditto -c -k --sequesterRsrc --keepParent "$APP" build/macos/notarize-submit.zip
		xcrun notarytool submit build/macos/notarize-submit.zip \
			--keychain-profile "$NOTARY_PROFILE" --wait
		xcrun stapler staple "$APP"
		rm -f build/macos/notarize-submit.zip
		spctl -a -vvv -t exec "$APP"
	fi
fi

# zip AFTER stapling, so the shipped archive carries the notarization ticket
(cd build/macos && rm -f LiminalVegas-macOS.zip \
	&& ditto -c -k --sequesterRsrc --keepParent LiminalVegas.app LiminalVegas-macOS.zip)

echo
echo "built:"
ls -lh build/macos/LiminalVegas-macOS.zip build/windows/LiminalVegas-Windows.zip
