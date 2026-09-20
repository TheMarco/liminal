# Baseline audit cleanup — September 20, 2026

Base revision: `7f42f81`. Work was applied alongside the engineer's uncommitted
Package 3 implementation; the seam-walk test remains owned by that engineer.
Engine: Godot `4.7.2.stable.official.ed1daf0bf`.

## Repairs

- Route planning: replace recursive district retries with the same ordered,
  bounded search; cache canonical edges, room identities and scan adjacency;
  index obstruction approach positions once per path. Cache immutable photo
  placement facts separately from changing target/room reservations. Live
  topology still resolves changed edges and scan changes invalidate cached
  adjacency.
- Realm previews: owner-local frame signals wake suspended preparation jobs
  during teardown, while the owner is still alive. Cancellation propagates
  through the asynchronous bounty-placement search.
- Annex: free the unparented carpet-overlay mesh when every placement candidate
  blocks a doorway. This was the shared real node/resource leak behind the
  realm-generation and test-mode shutdown reports. An explicit rejection
  regression checks orphan-node counts.
- Data Center: reserve a wider transverse service gap in water-court rack rows
  to clear the cooling units, using the network rack's rotated width.
- Office: curated poster positions must respect already placed fixtures,
  including coffee machines. Wall-mount clearance ignores complete decorative
  wear subtrees, including their millimetre-scale peeling finish.
- Giant photo props: measure imported visual height as well as collider height
  and reserve room for the visible light mote below the ceiling.
- Pool equipment: retain the preferred five placement samples, then search
  finer/wider shoreline offsets. Doorway, access, water and headroom clearance
  remain unchanged. Availability improves from 7 to 11 spiral slides across
  the existing 12-seed corpus (board/straight/spiral: 59/52/11).
- Web export: include the attribution record and exclude the same restricted
  assets and development content as the native exports.
- Placement bounds: calculate box-collider bounds directly from their dimensions
  instead of creating renderer debug meshes during threaded resource loading.
  The full run exposed this engine-error race in realm-campaign and objective-
  prompt checks; both pass after the repair, as does charging-station placement.

## Audit corrections

- Reality approach checks the current contract: figures move through the
  warning; explicit movement holds still work. Removed the nonexistent
  `_reveal` fixture field and isolated unrelated sighting audio.
- Spawn loading primes both walk and run resources for Pool Girl.
- Survivability supplies a real floor for the movement projection checks.
- First doorway streams the normal approach and waits for the actual lazy
  realm preview, with a bounded deadline, before freezing the fixture.
- School integrity accepts either two supplied, book-filled shelf models or
  the complete procedural shelf with its separate encyclopedia set. Aggregate
  coverage checks both forms; the fallback cart reads its active material.
- Realm generation uses shared resource cleanup after freeing its chunks.
- Photo-album failure tests retain their assertions. The suite recognizes only
  the two exact, deliberately induced fixture error messages, only for this
  audit; all other engine errors remain failures.
- Schedule the two exhaustive route audits without other suite workers. The
  blackout corpus passes in isolation but exceeded the wall-clock limit under
  eight-way load. Corpus sizes, assertions and the 300-second timeout are
  unchanged; other audits still use the requested parallelism.

## Fingerprint review

Two fresh processes produced byte-identical fingerprints for all 522 chunks.
Compared with the pre-cleanup current-tree fingerprint, only four sampled
chunks changed: three Office cases lose conflicting posters and one Poolrooms
case gains safe equipment geometry. The much larger difference from the old
checked-in golden predates this cleanup. The golden was refreshed only after
this comparison, not used to suppress geometry or safety assertions.

## Verification

The route-equivalence probe compared clean `7f42f81` with the optimized tree
for seed `1725793455`: Casino (floor 0), Office (2), Airport (3), Poolrooms (7).
Origins, target walls, full paths and introductory/obstruction/realm hints
matched exactly. Logs: `/tmp/route-proof-head.out` and
`/tmp/route-proof-final.out`.

The refreshed golden passes its final check (`/tmp/cleanup-final-hash.out`).
All 162 audit entries now pass, with no waived or skipped failures. The broad
run was resumed after its slow batch scheduler was stopped; it was not a
single uninterrupted invocation. Its three remaining failures were rerun
serially after the renderer repair: blackout shortcuts, realm campaign and
objective prompts. All three passed. The blackout audit checked 66/66 useful
ordinary doors and 88 geometry cases under the unchanged timeout.

Consolidated per-audit logs: `/tmp/liminal-audits.rtH8Bo`.
Final result listing: `/tmp/baseline-final-reruns.out`.
The regular runner now schedules route searches exclusively; reproduce with
`tools/run_audits.sh --no-import -j 4` (omit `--no-import` after asset/class changes).
`git diff --check` and `bash -n tools/run_audits.sh` also pass.

Historical baseline records in `SPATIAL_MUTATIONS_BASELINE.md` remain historical;
they are not blanket exceptions for any future failures.
