# Explicit Pi artifact storage

This is a private local operator workflow. No public push, new daemon, mount,
credential, service change or T3 database relocation is required. The shared
owner qualified `burbuja-cluster/storage/pi_artifacts.py` at SHA256
`29e0e8015e91cfbbbc4fd6bac5a820f00b1278ce66caa8f1a53a279f420046d2`.
Its `qualification.json` records15 real-Pi/failure tests. Playdate does not edit
that helper. Transport slots belong to the shared coordinator. Only the explicitly granted
Playdate canary may run; other Playdate bulk stays held until Blast completes.

`tools/harness/pi_archive.py` delegates only explicit allowlisted directories.
`pi_archive_allowlist.json` pins the nine reviewed closed failed runs and their
terminal proof hashes, plus the qualified helper digest. The default prints a
plan. Transfer execution is enabled only for a coordinator-granted slot, then closed
again. Queue execution is a separate gate and stays off until the real canary.
Missing Pi, pressure, a busy lock, changed proof or a helper error leaves the
operation deferred; the wrapper never substitutes deletion for archival.

Every archive, resume, restore, rehearsal, release and verify invocation holds:

1. `pokemon-playdate-storage-maintenance-501.lock`
2. `pokemon-playdate-suite-501.lock`
3. `pokemon-playdate-simulator-501.lock`
4. `pokemon-playdate-device-501.lock`
5. A stable per-artifact cold-storage lock outside the artifact tree.

These are nonblocking locks in `/private/tmp`, acquired in that order. Their
descriptors are merged with any existing inherited chain, then passed through
`pass_fds` and `PI_ARTIFACT_LOCK_FDS`. Cleanup
closes the parent's descriptors without explicit unlock, so inherited SSH/rsync
children retain exclusion after an interrupted parent. The shared helper also
holds its global archive lock and propagates all descriptors. Busy is defer;
do not run competing retries while another project owns the transport slot.

## First canary, after the explicit slot grant

Candidate: `m55b-earned-eleventh-resumed-20261030-01`, about1.087GiB allocated,
2,297,879,913 logical bytes (2.140067GiB). Rehearsal needs7.140067GiB including
the helper's5GiB margin; recheck actual free space at the slot. All three
journeys failed and the terminal suite is complete; newer passing B chains are
separate. This is not a current runtime input. Preserve all remote bytes and
receipts because older ancestry may still refer to it.

The read-only metadata audit is in environment
`storage-maintenance-logs/pi-first-candidate-metadata-20261101.json`.
No ACLs or special files were found. All38,033 entries
carry `com.apple.provenance`, which Playdate's JSON/image/PDX evidence readers do
not require. Nine JSONL traces carry APFS compressionflag32 with `com.apple.decmpfs` and
compression-backing `com.apple.ResourceFork`; these are not application resource
forks. Logical reads and hashes,
not that physical representation, must survive restore. Any newly found required
nonportable metadata must exclude a candidate until the shared helper supports it.

Enable only the manual execution flag after the slot grant; keep
`queue_enabled=false`. With the existing environment loaded:

```sh
candidate=m55b-earned-eleventh-resumed-20261030-01
python3 tools/harness/pi_archive.py archive "$candidate"           # plan only
python3 tools/harness/pi_archive.py archive "$candidate" --execute
# Read the emitted playdate-<id> receipt; use that exact ID below.
python3 tools/harness/pi_archive.py verify "$candidate" --id "$archive_id" --execute
python3 tools/harness/pi_archive.py rehearse "$candidate" --id "$archive_id" --execute
python3 tools/harness/pi_archive.py release "$candidate" --id "$archive_id" --execute
python3 tools/harness/pi_archive.py restore "$candidate" --id "$archive_id" --execute
python3 tools/harness/pi_archive.py verify "$candidate" --id "$archive_id" --execute
# After exact same-path/proof/full-manifest/trace-byte review, final reviewed release:
python3 tools/harness/pi_archive.py release "$candidate" --id "$archive_id" --execute
```

Rehearsal uses the helper's full `restore --rehearse`: adjacent temporary restore,
hash verification, then removal of only its verified temporary copy. Release
requires that receipt, remote re-verification and unchanged local content.
Restore never overwrites an existing path. Check the live receipt's status after
original-path restore before any later second release. Interrupted copies use
`resume <candidate> --id <id> --execute`; do not create competing duplicate jobs.

## Sustained operation: implemented, gated pending canary

Archive approved cold artifacts below70GiB free; stop normal archive work at
100GiB. The initial approved backlog may still be moved deliberately. Chain
saves, player packages, current/pinned inputs, active runs, Git, SDK, live
worktrees, references, models and T3 SQLite/WAL stay local. No broad recursive
age deletion or automatic eligibility scan is permitted.

The existing30-minute `maintain-storage.sh` still calls `maintain_storage.py`.
Its `--execute` entry now reports the explicit disabled Pi queue instead of
running legacy age deletion/compression. No LaunchAgent or shared helper was
changed. The bounded processor is implemented. Its automatic queue gate stays off until
the real canary passes; the transport gate opens only for a granted slot. The scheduler calls `maintenance_tick`
**outside** any pre-held producer/maintenance fences. That function acquires the
four fences plus artifact lock once and invokes the owned phase directly; never
call manual `execute` while already holding them.

For a new closed directory, the project owner must first review closure,
supersession and current/pinned dependencies, then add its exact name and terminal
proof hash to the allowlist. New superseded successful runs additionally need
`expected_ok:true`; never classify a current/latest/pinned pass as cold. Enqueue is explicit, idempotent, fenced by the same
locks, and writes only a local pending job:

```sh
python3 tools/harness/pi_archive.py enqueue "$candidate" \
  --review-note 'Owner reviewed: closed superseded failure, no current/pinned input.' --execute
python3 tools/harness/pi_archive.py maintenance
```

Enqueue never contacts the Pi. The processor performs one approved data phase
per tick: archive (or resume an interrupted unchanged copy), then full rehearsal,
then release. Source-bound receipt lookup uses the shared metadata API to recover
an ID lost before the parent journal update; ambiguous receipts stop for owner
review. A successful archived receipt and matching stub are required for done.
Busy/offline/pressure keeps the original and pending job; no phase or proof is
skipped. Explicit manual operations handle the deliberate initial backlog.

The70→100GiB cycle is persisted. The parser cap (8MiB/4096 metadata rows) is
checked **after** subprocess capture; it is not a hard output-memory limit.
Qualified helper output is metadata/statistics, not artifact payload. Metadata
lookup can time out; healthy copy/restore/release writers are never killed on an
observation timer. Inherited fences remain held by children after parent loss.

Future finalize hooks run only after the producer exits and its terminal proof
is published. Use only the existing30-minute entry point, not a new scheduler.


Restore the original absolute ordinary paths before strict seed/ancestry, Source
or PDX verification. No symlink/mount stubs replace evidence directories. A
`.ARCHIVED.json` receipt is not an input or proof substitute. Do not rewrite
frozen manifests or hashes to Pi paths, and hydrate every referenced dependency.

## Deferred partials and project-owner recovery

Before automatic or manual rehearsal, refuse adjacent retained temps for the
exact source and archive ID. The qualified helper uses the double-dot form
`..<source>.rehearsal-<id>.restore-<uuid>`; the single-dot form is also guarded.
Original-path restore has no ID in its temp name, so manual restore conservatively
refuses any `.<source>.restore-*` for that source. No partial is followed or
removed automatically. Pending jobs with partials remain marked for owner
attention and cannot accumulate new copies on unattended retries.

The responsible **project agent** handles recovery, without repeated user
approval: inspect the exact receipt and retained phase logs; confirm the original
and verified remote archive are intact, ownership/open handles are clear and the
partial path is the known source-scoped temp. Dispose or quarantine only that
known partial under the producer fences. Never delete originals or unknown temp
paths. Re-enqueue with the explicit receipt ID and a recovery review note to
clear owner attention; the guard will defer again if the partial still exists.
`release_failed`/`releasing` or conflicting source/stub state likewise requires
owner recovery, never automatic release replay.

After a consumer restores an archived proof, inspect its live receipt (the
qualified helper marks original-path restore verified). Re-enqueue with `--id`
to reuse that exact verified copy rather than creating another archive. After
local release the HDD is one full copy, not a redundant backup; immutable receipt
and exact-path hydration remain required before proof reuse.

Current pin29e adds only the release auxiliary `local_present=false` correction.
The historical data canary used4e (retained by the shared owner); original data
manifests/hashes are unchanged and the data canary is not repeated for this fix.

## Current rollout after real canary

Canary0363a44b completed the full cycle and final reviewed release; full manifest
and nine compressed-trace logical hashes matched at the original path. The
loaded `local.pokemon-playdate.storage-maintenance`1800s agent points to exactly
`/bin/sh .../Pokemon-PlayDate-env/maintain-storage.sh`; those exact arguments
reached the empty queue outside fences. No restart or new service was required.
Queue is enabled/empty, **transport execution remains false** during initial
Blast/Showdown batches. After actual completion/slot release from Showdown thread
`d1e77c2d-8344-46bd-b271-e36db44637ac`, the project agent is authorized to enable
transport without repeated user permission; verify the real handoff first. Keep
queue empty until individually owner-reviewed closed paths are enqueued.
