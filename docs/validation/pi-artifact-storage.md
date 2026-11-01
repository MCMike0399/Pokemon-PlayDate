# Explicit Pi artifact storage

This is a private local operator workflow. No public push, new daemon, mount,
credential, service change or T3 database relocation is required. The shared
owner qualified `burbuja-cluster/storage/pi_artifacts.py` at SHA256
`4e32546b7d22ad209520cb1b5ac3a8534a083cc789574dde3a7ca5af114ce469`.
Its `qualification.json` records14 real-Pi/failure tests. Playdate does not edit
that helper. Blast owns the first bulk slot; **no Playdate transfer yet**.

`tools/harness/pi_archive.py` delegates only explicit allowlisted directories.
`pi_archive_allowlist.json` pins the nine reviewed closed failed runs and their
terminal proof hashes, plus the qualified helper digest. The default prints a
plan. Transfer execution remains disabled until the coordinator grants a slot.
Missing Pi, pressure, a busy lock, changed proof or a helper error leaves the
operation deferred; the wrapper never substitutes deletion for archival.

Every archive, resume, restore, rehearsal, release and verify invocation holds:

1. `pokemon-playdate-storage-maintenance-501.lock`
2. `pokemon-playdate-suite-501.lock`
3. `pokemon-playdate-simulator-501.lock`
4. `pokemon-playdate-device-501.lock`
5. A stable per-artifact cold-storage lock outside the artifact tree.

These are nonblocking locks in `/private/tmp`, acquired in that order. Their
descriptors are passed through `pass_fds` and `PI_ARTIFACT_LOCK_FDS`. Cleanup
closes the parent's descriptors without explicit unlock, so inherited SSH/rsync
children retain exclusion after an interrupted parent. The shared helper also
holds its global archive lock and propagates all descriptors. Busy is defer;
do not run competing retries while another project owns the transport slot.

## First canary, after the explicit slot grant

Candidate: `m55b-earned-eleventh-resumed-20261030-01`, about1.087GiB. All three
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
python3 tools/harness/pi_archive.py rehearse "$candidate" --id "$archive_id" --execute
python3 tools/harness/pi_archive.py release "$candidate" --id "$archive_id" --execute
python3 tools/harness/pi_archive.py restore "$candidate" --id "$archive_id" --execute
python3 tools/harness/pi_archive.py verify "$candidate" --id "$archive_id" --execute
```

Rehearsal uses the helper's full `restore --rehearse`: adjacent temporary restore,
hash verification, then removal of only its verified temporary copy. Release
requires that receipt, remote re-verification and unchanged local content.
Restore never overwrites an existing path. Check the live receipt's status after
original-path restore before any later second release. Interrupted copies use
`resume <candidate> --id <id> --execute`; do not create competing duplicate jobs.

## Sustained operation: prepared, disabled pending canary

Archive approved cold artifacts below70GiB free; stop normal archive work at
100GiB. The initial approved backlog may still be moved deliberately. Chain
saves, player packages, current/pinned inputs, active runs, Git, SDK, live
worktrees, references, models and T3 SQLite/WAL stay local. No broad recursive
age deletion or automatic eligibility scan is permitted.

The existing30-minute `maintain-storage.sh` still calls `maintain_storage.py`.
Its `--execute` entry now reports the explicit disabled Pi queue instead of
running legacy age deletion/compression. No LaunchAgent or shared helper was
changed. The queue has **no enabled transfer processor yet**; first real canary,
slot admission and resume/retry phase handling must close before enabling it.

For a new closed directory, the project owner must first review closure,
supersession and current/pinned dependencies, then add its exact name and terminal
proof hash to the allowlist. Enqueue is explicit, idempotent, fenced by the same
locks, and writes only a local pending job:

```sh
python3 tools/harness/pi_archive.py enqueue "$candidate" \
  --review-note 'Owner reviewed: closed superseded failure, no current/pinned input.' --execute
python3 tools/harness/pi_archive.py maintenance
```

Enqueue never contacts the Pi. Busy/offline/pressure must keep bytes and pending
state; nothing is automatically skipped or released. Future finalize hooks run
only after the producer exits and its terminal proof is published. Implement
processing only through the existing30-minute entry point, not another scheduler.

Restore the original absolute ordinary paths before strict seed/ancestry, Source
or PDX verification. No symlink/mount stubs replace evidence directories. A
`.ARCHIVED.json` receipt is not an input or proof substitute. Do not rewrite
frozen manifests or hashes to Pi paths, and hydrate every referenced dependency.
