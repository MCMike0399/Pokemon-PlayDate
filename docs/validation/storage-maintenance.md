# Automatic storage maintenance

The 2026-10-29 evening storage direction supersedes the earlier cleanup pause.
`tools/harness/maintain_storage.py` uses only the Python standard library and
existing cleanup inventory helpers. It never launches the Simulator, contacts a
device, changes a service, or cleans worktrees or branches.

The default is a read-only JSON report. Reclamation starts only below 50 GiB
available to this user. An executing invocation stops at 70 GiB, or when its
safe candidates run out. An invocation starting at 50 GiB or higher does no
scan or deletion. This hysteresis avoids repeated cleanup near the minimum.
An already healthy reserve leaves all files untouched.

After deleting eligible archives, execution can share byte-identical `trace.jsonl`
copies inside confirmed exited harness runs using independent APFS clones.
Only retained archives outside the age grace qualify. Cloning refreshes their
change times, so the next invocations leave them alone until the grace expires;
they can then be deleted first if protection has ended. Sharing cannot renew
the grace on every invocation. The same ownership locks and required protection inputs apply. Live runs,
game saves, Source, PDX bundles and frames are excluded. Every source,
destination and temporary clone is checked by SHA256; changed files or a
failed clone leave the destination intact. Nested mounts and device boundaries
are rejected. Different ownership, flags, ACLs or extended attributes refuse a
pair; matching metadata is verified again before publication. Paths, bytes,
mode, access time and modification time remain unchanged; inodes and change
times change. These are not hard links, so later writes
remain independent. Each completed sharing operation has a durable audit line.
Referenced evidence retains all of its bytes. Dry runs never clone files.
Unsupported clone operations refuse maintenance rather than silently making
ordinary copies. Reported logical bytes are not a claim of physical space freed;
the free-space measurements remain authoritative.

If deletions and sharing still leave less than the target, the same executing
invocation calls `compress_archives.py` while all four global locks remain held.
This is the native APFS fallback proven by root on 2026-10-30. Root's separate
pass recovered an observed 14.308 GiB from 178 terminal traces; all 35.424 GB of
logical content passed full post-write SHA256 verification. Those historical
results are not a gain claimed for a future invocation. Its audit and script
remain outside Git in `storage-maintenance-logs/native-trace-compression-20261030-01.json`,
`native-trace-compression-postverify-20261030-01.json`,
`native-compression-pilot-20261030-01/report.json`, and
`compress-closed-traces-20261030-01.py` under the environment directory.

The fallback uses only confirmed terminal `trace.jsonl` files of at least 10 MiB
inside the old retained archive set already selected for sharing. It requires
Darwin and an APFS filesystem verified by `diskutil`; other platforms report
`compression.status: unavailable` without copying or claiming space savings.
It uses `/usr/bin/ditto --rsrc --extattr --acl --hfsCompression` into a unique
sibling temporary file. Compression flag 32 is intentional. An ordinary copy,
no allocation reduction, any other source flag, a hardlink, symlink, nested
mount or cross-device path never qualifies for publication. Chain saves,
packages, Source and references are excluded. Published paths and readable
bytes remain unchanged, with independent future writes.

Before each file, the helper freshly parses and hashes `run.json` and the
containing archive's completed `suite.json` or terminal `outcome.json`. Every
recorded process must have exited with a return code. It also takes the archived
runtime owner lock; this is additional to, and never a substitute for, the four
global locks. Source inode, length, modification/change times, flags, SHA256,
owner, group, mode, ACLs and public extended attributes must remain stable.
The temporary file must have matching bytes and public metadata before atomic
replacement. Access and modification times are restored and the temporary is
fsynced. Terminal proof identities and hashes are checked again. Immediately
before publication, current command/open paths are checked again; only this
process's exact archived-lock entry is exempt. An archive becoming open is
skipped with a refusal, retaining prior successes and audit events. No active
run names are hardcoded, no lock is taken over or expired, and compression
cannot run alongside a live owner of any global lock.

The fallback lowers its own priority to nice 10 if needed, stops at the target,
and has an 1800-second publication budget. Each native copy has a timeout of at
most 180 seconds and no more than the remaining budget. Budget and target checks
run before each file, after copying and immediately before publication. A copy,
verification, source race or open-path refusal leaves the original untouched
and cleans the sibling temporary. Filesystem operations already in progress
can outlast a budget check; no replacement is authorized after the budget expires.

Compression appends prepared, completed and refused JSON events to the existing
CLI stderr stream. The wrapper's regular log file is flushed and fsynced for
each event. No prior audit file is opened or truncated. A prepared event makes
an interruption between atomic replacement and completion logging diagnosable
from the path and checksum. If the audit stream fails before publication, the
original remains. A later audit failure stops compression and returns all
completed file records with `compression.status: audit unavailable`. The final
CLI report contains `compression.files`, `refusals` and status. Actual reserve
measurements remain in the enclosing report. This adds no scheduler option,
LaunchAgent change or new standalone compressor command.

Root should first integrate the implementation commit into the checkout used
for maintenance. This is the exact root review command:

```sh
/usr/bin/python3 /Users/burbujamc/Developer/Pokemon-PlayDate/tools/harness/maintain_storage.py \
  --project /Users/burbujamc/Developer/Pokemon-PlayDate \
  --env /Users/burbujamc/Developer/Pokemon-PlayDate-env \
  --checkpoint-ref t3/midgame-55b-driver \
  --minimum-free-gib 50 --target-free-gib 70
```

The exact root execution command, after review, is:

```sh
/usr/bin/python3 /Users/burbujamc/Developer/Pokemon-PlayDate/tools/harness/maintain_storage.py \
  --project /Users/burbujamc/Developer/Pokemon-PlayDate \
  --env /Users/burbujamc/Developer/Pokemon-PlayDate-env \
  --checkpoint-ref t3/midgame-55b-driver \
  --minimum-free-gib 50 --target-free-gib 70 --execute
```

Update `--checkpoint-ref` when the active checkpoint changes. A missing branch,
missing committed progress/save index, malformed protection JSON, inaccessible
process inventory or unsafe tree refuses maintenance. No fallback drops a
required protection source. `--min-age-hours` defaults to 24 and cannot be less
than one hour. An execute refusal returns 1. Exhausted candidates below the
minimum return 2. Dry runs and successful reserve checks return 0.

## Retention and deletion boundaries

Only whole directories immediately inside the environment's `evidence` directory
can be removed. Loose files, `chain`, `player-packages`, acceptance-named archives,
acceptance manifests, and top-level `Source`, `references`, `Data` and `runtime-data` stay. Checkout
Source, the environment's reference cache, live SDK Data and everything outside
`evidence` remain outside the deletion boundary. Closed private build snapshots
inside eligible evidence archives may be removed with their containing archive;
this does not edit the checkout's Source. Existing `data_dir` declarations that
still exist retain their owning archive. Individual frames are never pruned by
this command; checkpoint and failed evidence retain their original frame paths.

Protection reads every committed `docs/validation/*.json` recursively and
`docs/validation/progress.md` from `main`, the selected checkpoint branch and
`HEAD`. It also reads current checkout validation JSON and progress. Directory
names, historical evidence paths, escaped JSON paths, templates such as
`<starter>`, globs and resolved aliases all protect the containing whole archive.
Dependencies in every retained archive's host JSON are followed to closure,
including earned chain and partial-save ancestry. Source, PDX contents, frame
payloads and runtime-data are excluded from host dependency parsing. Retained
symlink targets are protected, but encountering an unsafe tree prevents the
whole operation because its ancestry cannot be established safely.

Latest passing runs are retained, including timestamp ties. Suite result names
identify journeys; standalone runs use their ordered journey configurations.
Every device `build_id` gets its latest passing `outcome.json` plus
`device-smoke.json` archive. Unknown device formats remain unclassified and stay.
A suite may be removed only when complete, with no unrun cases, every result is
a journey and every result has a strictly newer passing replacement. Standalone
journey retries have the same replacement requirement. Unknown, incomplete and
unreplaced runs stay. Failed retries can be removed only after a newer pass.

An unreferenced compile stage must explicitly declare `simulator_executed: false`
and a compile-only mode/status, contain a compiled `*.pdx/main.pdz`, have no runtime
artifacts and pass the age and ownership checks. This also covers rejected
compile-only stages. A name containing “rejected”, absence of `run.json`, or a
failed runtime alone never authorizes removal. Other rejected-stage formats stay
for manual review. No saved cleanup plan can be executed.

Execution takes nonblocking maintenance, suite, Simulator and device locks using
the existing per-user lock paths, without truncating their owner records. Before
every removal it recomputes branch references, ancestry, latest passes, current
process paths and eligibility. Current `ps` commands and `lsof` open files and
working directories protect live archives. Recorded PIDs are ignored because
an unrelated process may have reused them. Inventory refuses symlinks, mounts,
hardlinks and special files. A tree fingerprint includes paths, inodes, sizes,
modification times and change times, and is compared again immediately before
removal. The age grace uses both modification and change times, so copying an
old archive does not immediately make the copy eligible. Writers must honor the ownership locks; the grace period and live-path
checks also protect ordinary compiler workers. Arbitrary writers that ignore
locks must not be scheduled against the same archives during maintenance.

The final JSON records before/after available bytes and their observed delta.
Entry `bytes` is logical file size, not a promise of reclaimed APFS allocation.
Concurrent disk activity can affect the free-space delta. Each actual removal
also emits a JSON audit line to stderr, preserving partial progress if a later
revalidation refuses. Copy-on-write sharing also emits an audit line; hard links
are never created. The earlier SHA256-verified COW archives remain independent files and
retain their paths. Automatic cleanup cannot guarantee a reserve if only
protected evidence remains; root must inspect exit status 2.

## Existing scheduling and historical installation recipe

The existing root-owned wrapper is outside Git at
`/Users/burbujamc/Developer/Pokemon-PlayDate-env/maintain-storage.sh`:

```sh
#!/bin/sh
set -eu
maintenance_logs=/Users/burbujamc/Developer/Pokemon-PlayDate-env/storage-maintenance-logs
mkdir -p "$maintenance_logs"
maintenance_stamp=$(/bin/date -u +%Y%m%dT%H%M%SZ)-$$
exec /usr/bin/python3 /Users/burbujamc/Developer/Pokemon-PlayDate/tools/harness/maintain_storage.py \
  --project /Users/burbujamc/Developer/Pokemon-PlayDate \
  --env /Users/burbujamc/Developer/Pokemon-PlayDate-env \
  --checkpoint-ref wip/checkpoint-a-erika \
  --minimum-free-gib 50 --target-free-gib 70 --execute \
  > "$maintenance_logs/$maintenance_stamp.json" \
  2> "$maintenance_logs/$maintenance_stamp.log"
```

The root-installed per-user LaunchAgent is at
`~/Library/LaunchAgents/local.pokemon-playdate.storage-maintenance.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.pokemon-playdate.storage-maintenance</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>/Users/burbujamc/Developer/Pokemon-PlayDate-env/maintain-storage.sh</string>
  </array>
  <key>StartInterval</key><integer>1800</integer>
  <key>ProcessType</key><string>Background</string>
  <key>LowPriorityIO</key><true/>
  <key>Nice</key><integer>10</integer>
</dict>
</plist>
```

No wrapper, agent file or scheduling configuration was changed by this compression
implementation. Root verified the existing 30-minute wrapper separately. The
XML and shell above are the historical installation recipe, not a command run by
this packet; its old checkpoint selector must not replace the current wrapper.
The earlier manual audit and scripts remain outside Git at
`~/Developer/Pokemon-PlayDate-env/cleanup-20261029-night`.

Run the focused host checks without the SDK:

```sh
/usr/bin/python3 -m unittest tools.tests.test_storage_maintenance tools.tests.test_archive_sharing tools.tests.test_archive_compression -v
```

Use the actual `/usr/bin/python3` (3.9.6) for these checks. All 29 existing
storage/sharing tests remain, including the hardlink refusal case expressed
with Python 3.9's `os.link`. Compression tests cover a disposable native
roundtrip on supported hosts and explicit unavailability elsewhere, plus
filesystem/fault adapters for bytes, metadata, open paths, terminal proofs,
source races, copy failure, temporary cleanup, budgets and audit failures.
Integration tests check deletion → sharing → compression order and that all
four global locks are held when the helper runs. No test mutates a real archive,
SDK Data, Source, device or scheduler. No real archive pass was run for this
implementation.

Root can verify the CLI without executing maintenance:

```sh
/usr/bin/python3 tools/harness/maintain_storage.py --help
```

The review command above remains a dry run. Root owns any subsequent real
archive execution through the existing wrapper; its configuration is unchanged.

Root recovery after worker usage limit: all 49 focused tests pass under the actual
`/usr/bin/python3` 3.9.6, including the native disposable APFS case. Root subsequently integrated the helper after direct safety inspection, the prior
reviewed manual algorithm and 49 merged checks. No fresh independent agent review
was available after the worker usage limit. No new real archive pass or scheduler
configuration change was performed by this integration. The failed worker
was not restarted or switched to another provider.

Native-compressed traces are excluded from the sharing pass. Their logical size
can be much larger than their physical allocation; repeatedly expanding and
hashing them delays the compression fallback without useful reserve recovery.
This changes eligibility only. Ordinary clone verification, metadata checks and
all ownership locks remain in force.
