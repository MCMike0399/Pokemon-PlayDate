# Paused implementation handoffs

These archives preserve unfinished worker candidates at the user-requested pause.
They are **not integrated production code** and do not establish full-game completion.
See [the execution ledger](../../validation/progress.md) for each proof and limitation.

Verify archive SHA-256 values in `manifest.json`, then extract the needed packages
under `/private/tmp` to restore their original directory names. Several followups
refer to their base package, so restore both. Reference caches and original-base
snapshots are excluded; pinned source URLs/checksums and reproduction tools remain
in the packets or repository. Re-fetch/check primary inputs when a tool needs them.

Review manifests and narrow patches before merging. Shared context, battle,
session, codec and UI files have overlapping changes across candidates. Run one
identified Simulator session at a time and preserve existing real saves.
