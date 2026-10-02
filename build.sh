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
RELEASE_VERSION="${RELEASE_VERSION:-0.5.4}"
if [[ ! "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "Release version must be major.minor.patch (found $RELEASE_VERSION)." >&2
	exit 1
fi
for field in application/product_version application/short_version application/version; do
	if ! grep -Fq "${field}=\"${RELEASE_VERSION}\"" export_presets.cfg; then
		echo "Export preset $field must match release $RELEASE_VERSION." >&2
		exit 1
	fi
done
WINDOWS_EXE="build/windows/${PRODUCT_NAME}.exe"
WINDOWS_ZIP="build/windows/${PRODUCT_NAME}-Windows-${RELEASE_VERSION}.zip"
LINUX_EXE="build/linux/${PRODUCT_NAME}.x86_64"
LINUX_ZIP="build/linux/${PRODUCT_NAME}-Linux-${RELEASE_VERSION}.zip"
APP="build/macos/${PRODUCT_NAME}.app"
MACOS_ZIP="build/macos/${PRODUCT_NAME}-MacOS-${RELEASE_VERSION}.zip"

# Never export directly over a shipped artifact. A missing keychain identity or
# a failed notarization must leave the last known-good release intact.
STAGE_ROOT="$(mktemp -d /tmp/liminal-build.XXXXXX)"
trap 'rm -rf "$STAGE_ROOT"' EXIT
STAGE_WINDOWS_EXE="$STAGE_ROOT/windows/${PRODUCT_NAME}.exe"
STAGE_WINDOWS_ZIP="$STAGE_ROOT/${PRODUCT_NAME}-Windows-${RELEASE_VERSION}.zip"
STAGE_LINUX_EXE="$STAGE_ROOT/linux/${PRODUCT_NAME}.x86_64"
STAGE_LINUX_ZIP="$STAGE_ROOT/linux/${PRODUCT_NAME}-Linux-${RELEASE_VERSION}.zip"
STAGE_APP="$STAGE_ROOT/macos/${PRODUCT_NAME}.app"
STAGE_MACOS_ZIP="$STAGE_ROOT/macos/${PRODUCT_NAME}-MacOS-${RELEASE_VERSION}.zip"
mkdir -p "$STAGE_ROOT/windows" "$STAGE_ROOT/linux" "$STAGE_ROOT/macos"
BUILD_LOG_DIR="${BUILD_LOG_DIR:-$(mktemp -d /tmp/liminal-release-checks.XXXXXX)}"
mkdir -p "$BUILD_LOG_DIR"
echo "validation logs: $BUILD_LOG_DIR"

godot --headless --path . --import

echo "==> audits"
tools/run_audits.sh --no-import --log-dir "$BUILD_LOG_DIR"

# Packed resources are verified against the staged exports before any
# packaging, signing, or publishing. Each check runs from outside the source
# tree with an absolute script path so source assets cannot mask a missing
# resource. An exit code of 0 is not sufficient: script errors, engine
# errors, and leaked objects fail the build, as in tools/run_audits.sh.
verify_pack() {
	local label="$1" pack="$2"
	local log="$BUILD_LOG_DIR/verify-${label}.log"
	echo "==> verifying staged $label resources"
	bash tools/verify_release_pack.sh "$pack" "$log"
}

echo "==> Windows"
mkdir -p build/windows
godot --headless --path . --export-release "Windows Desktop" "$STAGE_WINDOWS_EXE" >/dev/null
verify_pack "windows" "$STAGE_WINDOWS_EXE"
# Keep the exporter's runtime DLLs/architecture directories and console
# wrapper. An embedded resource pack does not embed native dependencies.
( cd "$STAGE_ROOT/windows" && zip -q -r "$STAGE_WINDOWS_ZIP" . )

echo "==> Linux"
mkdir -p build/linux
godot --headless --path . --export-release "Linux" "$STAGE_LINUX_EXE" >/dev/null
chmod +x "$STAGE_LINUX_EXE"
verify_pack "linux" "$STAGE_LINUX_EXE"
zip -q -j "$STAGE_LINUX_ZIP" "$STAGE_LINUX_EXE"

echo "==> macOS"
mkdir -p build/macos
# Export into a clean staging path. The existing app is not touched until the
# selected signing and validation steps pass.
godot --headless --path . --export-release "macOS" "$STAGE_APP" >/dev/null
STAGE_MACOS_PCK="$STAGE_APP/Contents/Resources/${PRODUCT_NAME}.pck"
if [ ! -f "$STAGE_MACOS_PCK" ]; then
	echo "expected staged macOS pack at $STAGE_MACOS_PCK" >&2
	exit 1
fi
verify_pack "macos" "$STAGE_MACOS_PCK"

if [ "$NOTARIZE" = "0" ]; then
	# Offline local builds must not contact Apple's timestamp or notary service.
	echo "   local ad-hoc macOS signing (no notarization or network upload)"
	codesign --force --deep --sign - "$STAGE_APP"
	codesign --verify --deep --strict "$STAGE_APP"
else
	IDENTITY="$(security find-identity -v -p codesigning \
		| awk -F'"' '/Developer ID Application/{print $2; exit}')"
	if [ -z "$IDENTITY" ]; then
		echo "   no Developer ID cert available; refusing to replace the last notarized release" >&2
		exit 1
	fi
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
		echo "   Developer ID signature is invalid; refusing to notarize a broken bundle" >&2
		exit 1
	fi

	echo "==> notarizing (a few minutes)"
	rm -f build/macos/notarize-submit.zip
	ditto -c -k --keepParent "$STAGE_APP" build/macos/notarize-submit.zip
	xcrun notarytool submit build/macos/notarize-submit.zip \
		--keychain-profile "$NOTARY_PROFILE" --wait
	xcrun stapler staple "$STAGE_APP"
	rm -f build/macos/notarize-submit.zip
	spctl -a -vvv -t exec "$STAGE_APP"
fi

# Commit only validated staged artifacts. In notarized builds, macOS is zipped
# after stapling so the shipped archive carries the notarization ticket.
rm -rf "$APP"
ditto "$STAGE_APP" "$APP"
cp -R "$STAGE_ROOT/windows/." build/windows/
cp -f "$STAGE_WINDOWS_ZIP" "$WINDOWS_ZIP"
cp -f "$STAGE_LINUX_EXE" "$LINUX_EXE"
cp -f "$STAGE_LINUX_ZIP" "$LINUX_ZIP"
rm -f "$MACOS_ZIP"
ditto -c -k --keepParent "$STAGE_APP" "$MACOS_ZIP"

echo
echo "built:"
ls -lh "$MACOS_ZIP" "$WINDOWS_ZIP" "$LINUX_ZIP"
