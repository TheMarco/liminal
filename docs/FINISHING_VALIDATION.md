# Finishing validation (ending excluded)

This pass targets release correctness, retained graphics memory, streaming,
and access to the existing game. It does not add floors or change narrative
structure, quotas, encounter cadence, or first-view skipping rules.

## Release gates

Run `tools/run_audits.sh -j 1` before accepting changes to construction or
transition boundaries. CI uses the same list with two workers. A performance
gate runs alone; an export is then verified from outside the source tree.
`build.sh` runs those gates before packaging/signing/publishing, and validates
each staged platform pack before touching existing releases.
Local build logs survive staging cleanup; `BUILD_LOG_DIR` can select their
destination (the default is a fresh `/tmp/liminal-release-checks.*` directory).

The helper `bash tools/verify_release_pack.sh PACK [LOG]` rejects a missing
success marker, script errors, unexpected engine errors, leaked resources,
nonzero exit, or a hung verifier. Its sole engine-error exception is the exact
macOS sandbox certificate-enumeration diagnostic. The source tree must not
provide missing packaged assets.

## Windows hardware check

The target Windows GPU/RAM has not yet been specified. A Mac render or a pack
check cannot establish D3D12 performance or a minimum specification.

Use the newly exported Windows artifact, record its SHA-256, OS, CPU, RAM,
GPU/VRAM, display resolution, driver and HDR state. Run at 1920×1080 with
default visual effects first. Existing `--perf-log` diagnostics now include
frame p95/p99 as well as average/worst, draw count and graphics allocations.
Flags after `--` select isolated QA play and do not write campaign progress.
Keep the startup renderer/GPU line with the results: confirm whether the run
actually used Direct3D 12 or a fallback. The official 4.7.2 templates omit the
optional Agility SDK DLLs; Godot can fall back to the Windows system runtime.
The ZIP must contain the entire export directory, including any native
dependencies supplied by the installed export template.

Example PowerShell (replace the executable path with the extracted build):

```powershell
Get-FileHash '.\It wants you to stay.exe' -Algorithm SHA256
& '.\It wants you to stay.exe' --resolution 1920x1080 --log-file "$PWD\casino.log" -- --nologo --mode=wander --seed=240721 --level=0 --perf-log
& '.\It wants you to stay.exe' --resolution 1920x1080 --log-file "$PWD\airport.log" -- --nologo --mode=wander --seed=240721 --level=4 --perf-log
& '.\It wants you to stay.exe' --resolution 1920x1080 --log-file "$PWD\data-center.log" -- --nologo --mode=wander --seed=240721 --level=10 --perf-log
```

Keep the window focused; walk and sprint through new rooms, reverse course,
and turn quickly. Record first-use hitches separately from warmed travel.
Visit all eleven floors using the Wander floor keys, then return to Casino
twice. Check that memory returns toward its floor-specific range rather than
retaining the entire tour. Time transitions too: preparation deliberately
moves decoding behind the opaque fade.

Then exercise Descent pursuit, a blackout and restoration, charging, a realm
visit/return, photographic capture, album, tape pause/rewind and a floor
transition. Check the new binding prompts and subtitles at real viewing
distance. Test an ordinary saved run separately, including quit/relaunch and
Continue; QA flags intentionally bypass campaign persistence.

Use sustained 60 fps / roughly 16.7 ms as the initial target at 1080p, report
p95/p99 and visible stalls rather than average FPS alone, and leave a
meaningful VRAM margin. These are evaluation targets, not certified results.
If the chosen minimum PC misses them, identify CPU/GPU/texture pressure before
changing quality settings or declaring a minimum specification.

## Bounded fresh-player session

Use someone who has not seen the implementation. Let them start a new run
without coaching. Watch the opening and first floor; then sample one middle
and one late floor. Ask them to think aloud only when stuck. Do not explain
the camera/elevator relationship before observing whether the game does.

Record only actionable observations:

- Time from taking control to the first deliberate photograph; what prompted it.
- Their explanation of evidence versus onward progress after the tutorial.
- Where they become lost, and whether they can recover without a hint.
- Deaths that feel unavoidable or whose cause they cannot explain.
- Repeated unproductive stretches, and whether quiet stretches let events register.
- Legibility of evidence, prompts and subtitles at 1080p; missed or mistimed dialogue.
- Whether bindings, pause, replay, album and Continue behave as expected.

Finish with their three most confusing moments and three strongest moments.
Retune only a recurring observed problem. Keep the authored opening, scare
cadence and quotas unchanged until this session supplies evidence. Complete
one exported campaign playthrough before release; the ending remains the
owner's separate follow-up.

Stop adding work when the gates pass, the chosen minimum PC meets the agreed
budget, access settings work, and playtesting exposes no recurring clarity,
fairness or stability issue. Additional content needs a demonstrated reason.

## Local measurements — 2026-09-26

Godot 4.7.2, Apple M3 Max, Metal Forward+, seed 240721, a 1280×720 rendered
subviewport with 4× MSAA, TAA and the default effects. The same eleven-floor
tour was sampled before and after this pass. These are Godot's reported
graphics allocations at settled floor samples, not total process RAM or
transient transition peaks.

| Measurement | Before | After |
| --- | ---: | ---: |
| Initial Casino | 2,278 MiB | 1,894 MiB |
| Highest sampled floor allocation | 8,237 MiB | 2,611 MiB |
| Casino after touring all floors | 8,237 MiB | 2,346 MiB |
| Retained prop-scene entries on return | 91 | 8 |
| Retained material entries on return | 278 | 49 |

The return allocation fell by 71.5%. Floor transitions in the after-tour took
1.07–3.07 seconds including the existing fade; decoding is deliberately paid
behind that fade. This does not certify Windows performance. Frame timings
from these rendered tours are not a controlled before/after FPS comparison.

The separate, uncontended headless generation gate passed. Casino streaming
updates measured p95 3.68 ms / maximum 5.59 ms; Airport measured p95 3.23 ms /
maximum 5.39 ms on its 1,200-step out-and-back route. The older standalone
streaming probe did not prepare the floor's resource manifest, so its 58–69 ms
Airport samples must not be presented as equivalent production measurements.

All eleven floor captures were inspected, with a separate before/after check
of the first compressed 4K prop. Source textures and resolutions are unchanged;
95 large opaque maps now use high-quality GPU compression. Controls, subtitle
playback and the backup notice were also rendered and inspected. The synthetic
tour still emits the same seven Texture RID teardown warnings seen before
this pass; these are not a clean native shutdown certification.
The exported Windows pack also passed isolated resource verification and a
Casino rendering smoke check using the Mac engine, with all 49 streamed
chunks resident. The render harness has the same seven Texture RID warnings;
the headless pack verifier exits cleanly apart from the documented macOS
certificate diagnostic. This does not execute the Windows binary itself.

The September 21 world fingerprint was stale against the existing Office,
Prison, Annex and surface-wear work. Its current corpus contains 525 chunks
(previously 522), including the flooded Annex hall. The reference has been
refreshed under Godot 4.7.2 for this current game; the suite must independently
match it. This establishes a new reference for future changes, rather than
claiming the previous unverified edits were structurally identical.

## Completed automated verification

The sequential authoritative run completed all 157 functional audits. Seven
initial failures were corrected and passed focused reruns: visible light
sources, reported placement, new-level furnishings, prop overlap, Airport
ceiling fixtures, enemy streaming and jacuzzi movement. The other results
remain valid; the final keyboard-label change also passed its focused audit
and a native controls/instructions capture. Related pool fixtures now set the
actual Poolrooms theme and passed their subsequent full-run checks.

Compilation, the uncontended generation/streaming timing gate, the independent
525-case world-fingerprint comparison and final isolated pack verification
passed. Shell syntax and whitespace checks passed. Verifier failure-path
fixtures reject script errors, unexpected engine errors, resource leaks,
missing success markers and timeouts; the audit runner also rejects an empty
filter match and terminates a script-error hang promptly. CI has been updated
to invoke these shared gates; a remote CI run was not performed here.

The local evidence is retained in `/tmp/liminal-finishing-20260926`, including
the original failures, focused reruns, before/after measurements and captures.
The Windows candidate, checksums and portable instructions are in
`build/validation-20260926`. Native Windows/minimum-hardware validation and the
fresh-player session remain outstanding. No claim of release certification
or playtest-driven pacing changes is made before those checks.
