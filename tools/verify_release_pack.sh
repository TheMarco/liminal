#!/usr/bin/env bash
# Verify a PCK (or an executable containing one) without source-tree fallback.
set -euo pipefail
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	echo "usage: $0 PACK [LOG]" >&2
	exit 2
fi
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PACK=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
CHECK_DIR=$(mktemp -d /tmp/liminal-pack-check.XXXXXX)
LOG=${2:-"$CHECK_DIR/verify.log"}
mkdir -p "$(dirname "$LOG")"
LOG=$(cd "$(dirname "$LOG")" && pwd)/$(basename "$LOG")
GODOT=${GODOT:-godot}
rc=0
( cd "$CHECK_DIR" && exec "$GODOT" --headless --main-pack "$PACK" \
	--log-file "$CHECK_DIR/godot.log" \
	--script "$SCRIPT_DIR/verify_release_pack.gd" >"$LOG" 2>&1 ) &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' INT TERM EXIT
waited=0
while kill -0 "$pid" 2>/dev/null; do
	if [ "$waited" -ge "${VERIFY_PACK_TIMEOUT:-300}" ]; then
		kill -9 "$pid" 2>/dev/null || true
		echo "pack verification timed out after ${waited}s" >>"$LOG"
		rc=99
		break
	fi
	sleep 1
	waited=$((waited + 1))
done
wait "$pid" || rc=$?
trap - INT TERM EXIT
if grep -q 'SCRIPT ERROR' "$LOG"; then rc=90; fi
if grep -qE 'ObjectDB instances leaked|resources still in use at exit' "$LOG"; then rc=91; fi
# macOS's headless certificate enumeration can fail in a sandbox. This exact
# host diagnostic is unrelated to pack contents; all other engine errors fail.
if grep '^ERROR:' "$LOG" | grep -v '^ERROR: Condition "ret != noErr" is true\. Returning: ""$' >"$CHECK_DIR/errors"; then
	rc=92
fi
if ! grep -q '^PACK_VERIFY PASS:' "$LOG"; then rc=93; fi
if [ "$rc" -ne 0 ]; then
	cat "$LOG" >&2
	echo "packed-resource verification failed (exit $rc); log: $LOG" >&2
	exit "$rc"
fi
grep '^PACK_VERIFY PASS:' "$LOG"
