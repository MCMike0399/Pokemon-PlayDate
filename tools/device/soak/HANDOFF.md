# Soak safety correction against 0607cde0782b1d747641b522d9131cd6fa146d23

Implementation only: no production Source/shared owner edits, Simulator, hardware,
USB operations, push or delegation. The minute schedule and earned save inputs
are unchanged. No packet has been prepared against the unpatched owner. Root
must finish its intended `tools/device_cycle.py` integration FIRST, then prepare
and prove a new packet from the final executing checkout. The adjacent owner
patch remains an unapplied coordination template, not a change to the owner.

`evidence/private-soak-short-proof-20261029-01` remains FAILED and unchanged.
Its completed phases and reported 29 ms / 6.18 MiB do not admit this candidate:
the 8192-byte startup-only console did not match the file markers, and its last
application slice excluded completion work. Earlier stages/proofs are not reused.

## Timing and publication boundary

Sampler schema 3 retains coroutine yield/resume accounting and the original
BootTrace guard on every existing call. The wrapper additionally calls that
original guard after `afterFrame` AND `finish`, while the application segment
clock remains live. Thus completion JSON encoding, open/write/close/print, and
the final game guard are included before `observeSegment` and clock clearing.
Imports before wrapper installation remain covered by since-yield maxima.
There is no subtraction of instrumentation or renaming completion as observer IO.

After this measured application boundary, the producer publishes one `safety`
row carrying its final application counters. This is a measurement observer:
its own encoding/IO cannot be contained in the values being encoded. The
original guard runs again after that row. `soak-publication.json` and matching
`SOAK-PUBLISHED` console receipt carry the measured safety-publication cost,
heap and conservative since-yield maximum up to that receipt's construction.
The receipt does NOT claim to contain its own cost or heap allocations.

After receipt encode/write/close/print, the ORIGINAL guard runs again. Local
assertions require BOTH the entire terminal observer and the combined final
application-plus-observer active segment to remain <=150 ms, with observed heap
<=9 MiB. The receipt tail has a checked upper bound, not an exact reported cost.
A failure appends an error row and enters the existing failure path; strict row
order/count and console checks reject it. No overhead is deducted for admission.
Both short and full validators apply these limits.

Only after these checks does the wrapper stop future game/artifact updates and
print `SOAK-DONE <build>`. This last bounded acknowledgement print and return
bookkeeping are unavoidable, unmeasured measurement-observer publication. They
are explicitly outside the measured/checkable interval; do not claim an exact
whole-process maximum, all-allocation peak or a 150 ms bound on that last print.
The game guard runs after final sampler/receipt work, before this observer-only
acknowledgement. Numeric maxima reported in evidence stop before receipt IO;
the terminal receipt tail is admitted conservatively through local assertions,
witnessed by DONE in the fresh short proof. Hardware additionally requires clean
unchanged crash/error logs and exact rows; a short proof never accepts hardware.

Production automatic GC, normal steps/loading/startup full collection and
collection mode are unchanged. Only private DEVICE_TEST diagnostic full GC is
suppressed. Heap remains observed Lua heap, excluding native allocations.
The minute-cost total/max/last still describes minute snapshots, not all observer
or wrapper cost. Scalar and guard counters retain no history. Default execution
still waits 60 full active minutes at title, performs exactly DS1 press A and
its real Continue/release, then 60 full active minutes at the unchanged earned
position. New terminal safety evidence makes 125 rows, with the same 120 minute
rows. Short mode still waits one full 60000 ms minute per phase: seven rows.

## Owned console capture and cleanup

`simulator.py` now launches the exact SDK child with an owned PTY stdout/stderr
slave, closes the parent's slave, and continuously drains the master to the raw
log. A file `complete` marker alone never triggers termination. Before stopping,
it requires DONE, valid safety/receipt evidence and exact console/file equality
for every SOAK1 row and the publication receipt. The raw log is retained without
rewriting its PTY line endings. After SIGTERM it keeps draining while waiting,
uses SIGKILL only on that owned PID if needed, confirms child reap, and drains to
PTY EOF. Both cleanup confirmations are required for admission. The two existing
locks remain held through archive and verification. Runtime Data is archived;
no broad process termination or deletion of unrelated Data occurs.

The existing real pool/USB preflight still runs. Immediately before launch the
actual Simulator preferences bytes are retained in `malloc-preflight.ini` and
parsed; the measured MallocPoolSize must be 16645684 (SDK's 16 MB setting).
`run.json` and proof retain its digest and actual parsed value. Admission checks
those bytes again, rather than trusting a driver-assigned constant.

## Dependency freeze and root sequence

The retained `soak-tools/` now uses repository-relative paths and pins the exact
six packet files PLUS the executing `tools/device_cycle.py`, `tools/harness/run.py`,
`tools/harness/protocol.py`, `tools/harness/build.py`, `tools/harness/__init__.py`,
`tools/harness/dev_imports.lua`, `tools/build.py`, and
`tools/device/build_smoke.py`. These cover the static project import closure for
preparation, ownership, staging, verification and locks. Dynamic visual/scenario
helpers are not used in this execution. Dependency snapshots bracket preparation;
retained bytes and the complete fixed path set are checked at every verification.
Source's DS1 seam is separately pinned as before. Changing ANY pinned helper,
including root's owner patch, requires preparing and proving a new packet.

1. Integrate/review root's intended owner patch in the executing checkout. Keep
   production Source byte-identical to the chosen production input from 0607cde's
   retained stage (its `production_source_manifest` is the authority); do not
   substitute the newer HEAD merely because it is available. The soak source
   overlay remains only private main/pdxinfo and the two private modules.
2. Run the existing host checks and compile, then `prepare.py --project <exact
   intended production checkout> --sdk <SDK> --earned-save <unchanged earned
   manifest> --output <fresh stage>`. Verify against the original production
   inventory and confirm final executing shared-owner bytes are pinned. No final
   packet should be built before the owner change and dependency freeze.
3. ROOT ONLY: `simulator.py --build-stage <fresh stage> --sdk <SDK> --output
   <fresh proof> --execute-root`. No old proof or edited build JSON is admissible.
4. Inspect the fresh seven rows, complete then safety, exact SOAK1 console/file
   equality, matching publication receipt, DONE, DS1 ready/accepted/done and real
   Continue, unchanged earned bytes, raw <=150 ms / <=9 MiB evidence and checked
   terminal bounds, actual retained 16 MB preflight, exact dependency/PDX hashes,
   no runtime errors, confirmed owned-child reap and PTY EOF. Re-run `admission`
   against the retained proof. Root review closure is required BEFORE hardware.
5. Only then use the reviewed owner launch/collect hooks. Full hardware still
   needs 60+60 active minutes, all 125 rows and existing installed identity,
   earned bytes, error/crash log and reservation checks. No acceptance claimed.

Existing checks: four soak host tests (fixture updated for schema 3; no test-count
increase), 25 device-cycle host tests, Python syntax and unapplied owner patch
apply check pass. SDK 3.1.2 compile of a COPY of retained stage 05 with only the
new sampler succeeds at `/var/folders/w6/k16ngbtn5_qgp2ph4h65y7p80000gn/T/soak-safety-compile-auqtdkvo`.
This copy is compile evidence only, not a prepared/admitted packet. No runtime
behavior, PTY witness or new resource maxima were measured by this worker.

Root closure: a build-identified `soak-done.txt` is written only after final
application/observer guards and assertions. Hardware collection requires it;
a receipt prefix alone cannot pass or clear the reservation. Witness IO and
DONE print are explicitly unmeasured observer acknowledgements. The short
Simulator still enforces 150 ms / 9 MiB. Hardware retains the existing 5-second crash
ceiling, not the Simulator CPU-time ceiling; latency acceptance is separate.
