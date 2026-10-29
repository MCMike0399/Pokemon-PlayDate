# Checkpoint evidence cleanup

Run from the checkout whose acceptance records should be preserved. The command
uses only the Python standard library and never starts the Simulator.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/harness/cleanup_evidence.py > "$POKEMON_ENV/cleanup-review.json"
```

The default is a read-only JSON report. Review `entries`, `reclaimable_bytes`,
`exclusions` and `warnings`. Bytes count logical regular-file content, so actual
disk space recovered can differ with compression or shared APFS clones. Loose
files directly under `evidence` are never deleted. Keep the report outside
`evidence`, where it will not itself become a protection reference.

After review, the runtime owner can run the same command with `--execute`.
This recomputes the plan; it does not consume an old report. It acquires the
existing suite and Simulator locks without changing their owner records and
checks eligibility again before each removal. Stop other evidence writers,
including compile-only workers, before execution. A refused run exits nonzero;
if execution stops midway, earlier removals remain removed. Capture stdout and
stderr for the operator's record. `--project PATH` chooses another checkout;
`--env PATH` overrides `POKEMON_ENV`. The evidence root must be a real directory
immediately inside that environment. Nothing outside it is removed.

Only explicitly labelled compile-only bundles without runtime artifacts, and
completed runs with an identical scenario and a newer successful replacement,
qualify. A build without a runtime record alone is uncertain and stays. Runs
without a terminal outcome stay. The newest failure for each recognized
checkpoint stays by outcome-file modification time, including ties; failures with
unknown checkpoints stay.
Checkpoint names `m50` through `m59` optionally include `a`, `b` or `c`; older
Brock, Cerulean and Vermilion scenarios provide fallback checkpoint labels.

Protection covers all tracked repository JSON (a superset of acceptance JSON),
untracked acceptance JSON, `chain-saves.json` and `progress.md`. Exact directory
names, relative and historical absolute evidence paths, and `<starter>` or glob
references protect the entire containing top-level directory. Dependencies in
retained host evidence JSON are followed until no additional directories are
retained. Actual path aliases are resolved against the file, checkout and environment.
Game Source, compiled bundles, frames, numbered mailbox request/result payloads
and archived SDK runtime-data are excluded from dependency scanning. These contain
game data, including intentionally corrupt save fixtures, rather than host ancestry.
The whole `chain` tree, save/provenance exports, live process references, live
recorded PIDs, existing private runtime data, links and their targets, mounts,
hard links, special files, unreadable trees and uncertain classifications stay.
Malformed protection JSON aborts the scan. Entries changed within one hour stay;
`--min-age-hours N` can increase that grace period. PID reuse may deliberately
retain an extra directory. Protection favors keeping evidence over recovering
space; a report can therefore contain no candidates.
