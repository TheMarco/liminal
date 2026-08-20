#!/bin/bash
# One command to run the whole verification suite. Every refactor phase must
# leave this green.
#
#   tools/run_audits.sh              # editor import pass, then every audit
#   tools/run_audits.sh -j 4         # limit concurrency (default: cores - 2)
#   tools/run_audits.sh -f corridor  # only audits whose name matches a filter
#   tools/run_audits.sh --no-import  # skip the import pass
#
# Audits are independent processes, so they run in parallel. Each writes its
# output to a log; failures are replayed at the end.
#
# The Godot import pass has to run first whenever a class_name was added or an
# asset changed, otherwise headless runs fail spuriously. It is cheap when the
# cache is warm, so it is on by default.
#
# --- generation fingerprint ---------------------------------------------------
# audit_world_hash.gd is the refactor gate: it fingerprints the generated scene
# graph so a behaviour-preserving change can be proven byte-identical. Around a
# risky edit:
#
#   godot --headless --path . --script tools/audit_world_hash.gd -- \
#       --out=tools/golden/world_hash.txt --dump=/tmp/before.txt
#   ...edit...
#   godot --headless --path . --script tools/audit_world_hash.gd -- \
#       --check=tools/golden/world_hash.txt --dump=/tmp/after.txt
#   diff /tmp/before.txt /tmp/after.txt      # pinpoints the node that moved
#
# The digest records geometry to 5 decimals and is only comparable between runs
# of the SAME Godot build, so it is a local gate rather than a CI assertion.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

CPU_COUNT=$(sysctl -n hw.ncpu 2>/dev/null \
	|| getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)
JOBS=$(( CPU_COUNT - 2 ))
[ "$JOBS" -lt 1 ] && JOBS=1
FILTER=""
DO_IMPORT=1
TIMEOUT=${TIMEOUT:-300}
BASELINE=""
SAVE_BASELINE=""
while [ $# -gt 0 ]; do
	case "$1" in
		-j) JOBS="$2"; shift 2 ;;
		-f) FILTER="$2"; shift 2 ;;
		-t) TIMEOUT="$2"; shift 2 ;;
		--baseline) BASELINE="$2"; shift 2 ;;
		--save-baseline) SAVE_BASELINE="$2"; shift 2 ;;
		--no-import) DO_IMPORT=0; shift ;;
		-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done

GODOT=${GODOT:-godot}
LOGDIR=$(mktemp -d /tmp/liminal-audits.XXXXXX)

# name|script|extra args
# Kept in the order the CI workflow runs them, with the audits that CI does not
# yet run appended.
AUDITS=(
	"corridors|tools/audit_corridors.gd|"
	"annex|tools/audit_annex.gd|"
	"wall_utilities|tools/audit_wall_utilities.gd|"
	"zones|tools/audit_zones.gd|"
	"doorways|tools/audit_doorways.gd|"
	"airport_luggage|tools/audit_airport_luggage.gd|"
	"mall_shopping_carts|tools/audit_mall_shopping_carts.gd|"
	"mall_directory|tools/audit_mall_directory.gd|"
	"chemistry_props|tools/audit_chemistry_props.gd|"
	"slots|tools/audit_slots.gd|"
	"new_levels|tools/audit_new_levels.gd|"
	"brutalist|tools/audit_brutalist.gd|"
	"bloom|tools/audit_bloom.gd|"
	"survivability|tools/audit_survivability.gd|"
	"prop_overlap|tools/audit_prop_overlap.gd|"
	"airport_colliders|tools/audit_airport_colliders.gd|"
	"wall_art|tools/audit_wall_art.gd|"
	"interactions|tools/audit_interactions.gd|"
	"arrivals|tools/audit_arrivals.gd|"
	"level_switches|tools/audit_level_switches.gd|--nologo"
	# Eight deterministic seeds cover 88 floor routes. Route planning now uses
	# compact wall caches and normally completes in a fraction of a second.
	"descent_routes|tools/audit_descent_routes.gd|8"
	# Two route builds per theme-seed; six seeds cover 132 doorway cases while
	# keeping the complete suite quick enough for routine local use.
	"blackout_shortcuts|tools/audit_blackout_shortcuts.gd|6"
	"descent_mutation_graph|tools/audit_descent_mutation_graph.gd|"
	"world_mutation_contract|tools/audit_world_mutation_contract.gd|"
	"descent_runtime|tools/audit_descent_runtime.gd|--mode=descent --nologo"
	"airport_runtime|tools/audit_airport_runtime.gd|--mode=descent --descent-floor=4 --nologo"
	"descent_progress|tools/audit_descent_progress.gd|"
	"intro_playback|tools/audit_intro_playback.gd|"
	"cross_video_review|tools/audit_cross_video_review.gd|"
	"descent_ritual|tools/audit_descent_ritual.gd|"
	"optional_vhs|tools/audit_optional_vhs.gd|"
	"ghost_room_contract|tools/audit_ghost_room_contract.gd|"
	"horror_director|tools/audit_horror_director.gd|"
	"corner_apparitions|tools/audit_corner_apparitions.gd|"
	"photo_anomalies|tools/audit_photo_anomalies.gd|"
	"photo_runtime|tools/audit_photo_runtime.gd|--mode=descent --nologo"
	"photo_coverage|tools/audit_photo_coverage.gd|--mode=descent --nologo"
	"title_screen|tools/audit_title_screen.gd|"
	"font_check|tools/font_check.gd|"
	"ceiling_seams|tools/audit_ceiling_seams.gd|"
	"chunk_smoke|tools/audit_chunk_smoke.gd|"
	"pool_corners|tools/audit_pool_corners.gd|"
	"pool_scale|tools/audit_pool_scale.gd|"
	"pool_crossings|tools/audit_pool_crossings.gd|"
	"pool_environment|tools/audit_pool_environment.gd|"
	"pool_heights|tools/audit_pool_heights.gd|"
	"pool_jacuzzi|tools/audit_pool_jacuzzi.gd|"
	"pool_minerals|tools/audit_pool_minerals.gd|"
	"pool_openings|tools/audit_pool_openings.gd|"
	"flashlight_charging|tools/audit_flashlight_charging.gd|"
	"blackout_lighting|tools/audit_blackout_lighting.gd|"
	"mutation_reveal|tools/audit_mutation_reveal.gd|"
	"wander_mode|tools/audit_wander_mode.gd|--nologo"
	# Not just a generation fingerprint: it builds 423 chunks across every theme
	# and style, so a method reached through the wrong level builder shows up here
	# as a SCRIPT ERROR, which run_one treats as a failure.
	"world_hash|tools/audit_world_hash.gd|--check=tools/golden/world_hash.txt"
	"pool_basins|tools/audit_pool_basins.gd|"
	"pool_lighting|tools/audit_pool_lighting.gd|"
)

# Every listed audit gates the result. Keep the variable for the result/report
# machinery below, but do not exempt failures from the suite.
NONGATING=""

if [ "$DO_IMPORT" = "1" ]; then
	printf 'import pass ... '
	if $GODOT --headless --log-file "$LOGDIR/import-godot.log" \
			--path . --editor --quit >"$LOGDIR/import.log" 2>&1; then
		echo "ok"
	else
		echo "FAILED"; cat "$LOGDIR/import.log"; exit 1
	fi
fi

# chunk.gd preloads every level builder, so one unparseable builder takes the
# whole Chunk class down and every audit below fails for the same reason. Say so
# once instead of 29 times.
printf 'compile check ... '
$GODOT --headless --log-file "$LOGDIR/compile-godot.log" \
	--path . --script tools/check_compile.gd >"$LOGDIR/compile.log" 2>&1
if grep -qE "Parse Error|Compile Error" "$LOGDIR/compile.log"; then
	echo "FAILED"
	echo
	grep -E "Parse Error|Compile Error|GDScript::reload" "$LOGDIR/compile.log" | head -12
	echo
	echo "Scripts do not compile. Audits would all fail for this reason alone."
	exit 1
fi
echo "ok"

# Timing gates cannot share CPU fairly with the parallel functional suite.
# Run the controlled heavy-builder smoke test alone, after compile/import and
# before launching the worker pool.
if [ -z "$FILTER" ] || [[ "generation_performance" == *"$FILTER"* ]]; then
	printf 'generation performance ... '
	if $GODOT --headless --log-file "$LOGDIR/generation-performance-godot.log" \
			--path . --script tools/audit_generation_performance.gd \
			>"$LOGDIR/generation-performance.log" 2>&1; then
		echo "ok"
	else
		echo "FAILED"
		cat "$LOGDIR/generation-performance.log"
		exit 1
	fi
	if [ "$FILTER" = "generation_performance" ]; then
		echo "logs: $LOGDIR"
		exit 0
	fi
fi

run_one() {
	local name="$1" script="$2" extra="$3" log="$LOGDIR/$1.log"
	if [ ! -f "$script" ]; then
		echo "SKIP" >"$LOGDIR/$name.status"; return
	fi
	# An `extends SceneTree` audit that hits an error mid-run never reaches its
	# quit(), so it idles forever instead of failing. Cap every audit.
	if [ -n "$extra" ]; then
		# shellcheck disable=SC2086
		$GODOT --headless --log-file "$LOGDIR/$name-godot.log" \
			--path . --script "$script" -- $extra >"$log" 2>&1 &
	else
		$GODOT --headless --log-file "$LOGDIR/$name-godot.log" \
			--path . --script "$script" >"$log" 2>&1 &
	fi
	local pid=$!
	local waited=0
	while kill -0 "$pid" 2>/dev/null; do
		if [ "$waited" -ge "$TIMEOUT" ]; then
			kill -9 "$pid" 2>/dev/null
			echo "--- killed after ${TIMEOUT}s (hung)" >>"$log"
			echo "99" >"$LOGDIR/$name.status"
			return
		fi
		sleep 1
		waited=$((waited + 1))
	done
	wait "$pid"
	local rc=$?
	# A Godot script can print an error and still exit 0, so treat a hard
	# script error, resource leak, or non-allowlisted engine error as a failure.
	if [ $rc -eq 0 ] && grep -q "SCRIPT ERROR" "$log"; then rc=90; fi
	if [ $rc -eq 0 ] && grep -qE \
		"ObjectDB instances leaked|resources still in use at exit" "$log"; then
		rc=91
	fi
	if [ $rc -eq 0 ]; then
		grep '^ERROR:' "$log" | grep -Ev \
			'^ERROR: (Parameter "(material|t)" is null\.|Condition "ret != noErr" is true\. Returning: ""|Error saving editor settings to |Cannot save file .*/editor_settings-4\.6\.tres)' \
			>"$LOGDIR/$name.unexpected-errors" || true
		if [ -s "$LOGDIR/$name.unexpected-errors" ]; then rc=92; fi
	fi
	echo "$rc" >"$LOGDIR/$name.status"
}

echo "running ${#AUDITS[@]} audits, $JOBS at a time"
active=0
for entry in "${AUDITS[@]}"; do
	IFS='|' read -r name script extra <<<"$entry"
	[ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]] && continue
	run_one "$name" "$script" "$extra" &
	active=$((active + 1))
	if [ "$active" -ge "$JOBS" ]; then wait -n 2>/dev/null || wait; active=$((active - 1)); fi
done
wait

fails=0
softfails=0
for entry in "${AUDITS[@]}"; do
	IFS='|' read -r name script extra <<<"$entry"
	[ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]] && continue
	status=$(cat "$LOGDIR/$name.status" 2>/dev/null || echo "?")
	if [ "$status" = "0" ]; then
		printf '  %-24s PASS\n' "$name"
	elif [ "$status" = "SKIP" ]; then
		printf '  %-24s skip (missing)\n' "$name"
	elif [[ " $NONGATING " == *" $name "* ]]; then
		printf '  %-24s fail (%s) — not gating\n' "$name" "$status"
		softfails=$((softfails + 1))
	else
		printf '  %-24s FAIL (%s)\n' "$name" "$status"
		fails=$((fails + 1))
	fi
done

if [ "$fails" -gt 0 ]; then
	echo
	echo "=== failing audit output ==="
	for entry in "${AUDITS[@]}"; do
		IFS='|' read -r name script extra <<<"$entry"
		[ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]] && continue
		status=$(cat "$LOGDIR/$name.status" 2>/dev/null || echo "?")
		[ "$status" = "0" ] && continue
		[ "$status" = "SKIP" ] && continue
		[[ " $NONGATING " == *" $name "* ]] && continue
		echo "--- $name (exit $status)"
		tail -25 "$LOGDIR/$name.log"
	done
fi

if [ -n "$SAVE_BASELINE" ]; then
	: >"$SAVE_BASELINE"
	for entry in "${AUDITS[@]}"; do
		IFS='|' read -r name script extra <<<"$entry"
		echo "$name=$(cat "$LOGDIR/$name.status" 2>/dev/null || echo '?')" >>"$SAVE_BASELINE"
	done
	echo
	echo "baseline saved to $SAVE_BASELINE"
fi

echo
echo "logs: $LOGDIR"

# Comparing against a recorded baseline answers the only question a refactor
# actually needs -- "did I break something that was working" -- without hiding
# failures that were already there.
if [ -n "$BASELINE" ] && [ -f "$BASELINE" ]; then
	newfail=0
	fixed=0
	known=0
	for entry in "${AUDITS[@]}"; do
		IFS='|' read -r name script extra <<<"$entry"
		[ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]] && continue
		now=$(cat "$LOGDIR/$name.status" 2>/dev/null || echo "?")
		was=$(grep "^$name=" "$BASELINE" 2>/dev/null | cut -d= -f2)
		[ -z "$was" ] && was="?"
		if [ "$now" != "0" ] && [ "$was" = "0" ]; then
			echo "  NEW FAILURE: $name (was passing)"
			newfail=$((newfail + 1))
		elif [ "$now" = "0" ] && [ "$was" != "0" ] && [ "$was" != "?" ]; then
			echo "  fixed: $name (was $was)"
			fixed=$((fixed + 1))
		elif [ "$now" != "0" ]; then
			known=$((known + 1))
		fi
	done
	echo
	if [ "$newfail" -gt 0 ]; then
		echo "RESULT: $newfail NEW failure(s) vs baseline, $known known, $fixed fixed"
		exit 1
	fi
	echo "RESULT: no new failures ($known known, $fixed fixed)"
	exit 0
fi

if [ "$fails" -gt 0 ]; then
	echo "RESULT: $fails gating failure(s)"
	exit 1
fi
[ "$softfails" -gt 0 ] && echo "RESULT: all gating audits pass ($softfails non-gating failure(s))"
[ "$softfails" -eq 0 ] && echo "RESULT: all audits pass"
exit 0
