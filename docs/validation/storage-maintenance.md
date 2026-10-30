# Automatic storage maintenance

The 2026-10-29 evening storage direction supersedes the earlier cleanup pause.
`tools/harness/maintain_storage.py` uses only the Python standard library and
existing cleanup inventory helpers. It never launches the Simulator, contacts a
device, changes a service, or cleans worktrees or branches.

The default is a read-only JSON report. Reclamation starts only below 150 GiB
available to this user. An executing invocation stops at 170 GiB, or when its
safe candidates run out. An invocation starting at 150 GiB or higher does no
scan or deletion. This hysteresis avoids repeated cleanup near the minimum.
With the reported 160 GiB reserve, the command should do nothing.

Root should first integrate the implementation commit into the checkout used
for maintenance. This is the exact root review command:

```sh
/usr/bin/python3 /Users/burbujamc/Developer/Pokemon-PlayDate/tools/harness/maintain_storage.py \
  --project /Users/burbujamc/Developer/Pokemon-PlayDate \
  --env /Users/burbujamc/Developer/Pokemon-PlayDate-env \
  --checkpoint-ref wip/checkpoint-a-erika \
  --minimum-free-gib 150 --target-free-gib 170
```

The exact root execution command, after review, is:

```sh
/usr/bin/python3 /Users/burbujamc/Developer/Pokemon-PlayDate/tools/harness/maintain_storage.py \
  --project /Users/burbujamc/Developer/Pokemon-PlayDate \
  --env /Users/burbujamc/Developer/Pokemon-PlayDate-env \
  --checkpoint-ref wip/checkpoint-a-erika \
  --minimum-free-gib 150 --target-free-gib 170 --execute
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
revalidation refuses. No COW deduplication or hardlink creation is included.
The root's earlier SHA256-verified COW archives remain independent files and
retain their paths. Automatic cleanup cannot guarantee a reserve if only
protected evidence remains; root must inspect exit status 2.

## Proposed scheduling, not installed

Root can review a wrapper outside Git at
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
  --minimum-free-gib 150 --target-free-gib 170 --execute \
  > "$maintenance_logs/$maintenance_stamp.json" \
  2> "$maintenance_logs/$maintenance_stamp.log"
```

A proposed per-user LaunchAgent at
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

No wrapper, agent file, installation or scheduling command was executed as part
of this implementation. Root owns installation and log upkeep after review.
The earlier manual audit and scripts remain outside Git at
`~/Developer/Pokemon-PlayDate-env/cleanup-20261029-night`.

Run the focused host checks without the SDK:

```sh
python3 -m unittest tools.tests.test_storage_maintenance -v
```

All deletion tests use temporary directories, temporary Git branches and
temporary lock files. They do not probe actual SDK Data or device paths.
