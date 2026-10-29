# Zone construction allocation candidate

Starts at exact main `309194ee0b35f329426d21f8c19b9c0442780d11`, prepared
with GPT-6.1 Sol / medium in its isolated worktree. Only `zone.lua`,
`tileRegistry.lua` and this handoff change. No push or delegation.

`fromMapDefinition` grants its fresh cell arrays ownership through a private,
one-use weak-key config lookup. `Zone:init` still performs every existing tile,
collision and terrain validation. Public numeric configs still copy their input;
no caller-supplied flag grants ownership. Public tiles/collision remain separate
from reset baselines. Private terrain current/baseline rows initially share;
`_commitTiles` detaches an affected row before replacing any cell, including undo.
Compact palettes and noncompact cell records preserve their previous semantics.

`prepareBatch` privately retains normalized copies behind an opaque,
registry-specific handle. `preparedTerrain` returns defensive copies.
`registerPreparedBatch` rechecks every current registry conflict before publishing
anything, with no yield during check/publication. It recomputes IDs on each use,
so handles also work after `checkpointRuntime` rollback. Caller entry/handle
mutations cannot change the private snapshot. Public `validateBatch` still
returns defensive normalized entries; `registerBatch` still validates untrusted
entries and returns IDs. Constructor errors after publication restore the
registry checkpoint, including image references. Existing append-only checkpoint
ownership applies: the runtime owner must serialize registry transactions.

SDK 3.1.2 production and full harness **compilation only** passed, along with
`git diff --check`. Artifacts:
`/private/tmp/zone-allocations-final-production-stage-20261029/build.json` and
`/private/tmp/zone-allocations-final-harness-20261029/build.json`.
No Simulator, hardware, USB, host game-Lua execution or new fixture contracts.
Runtime compatibility, heap, latency and hardware acceptance remain unverified;
no measured performance gain is claimed.

Root must run the existing `SourceMapContracts`, `SourceMapActivationContracts`,
`WorldContracts`, `WorldViewRollbackContracts`, `PewterProviderContracts` and
`PewterInstallContracts` in separate production-based SDK batches in the unchanged
16 MB pool. Reuse root's small-batch staging; the monolithic development suite
previously exhausted that pool. Check prepared-batch caller mutation, conflict
after preparation, wrong/forged handles, checkpoint rollback/reuse, constructor
failure, public config/getter isolation, terrain reset and partial mutation undo.
Those edge cases have been reviewed statically here, not executed.

Exact root compile and smoke replay commands, from the integrated checkout:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/build.py --sdk "$PLAYDATE_SDK_PATH" --output /private/tmp/zone-root-compile/Pokemon.pdx --stage /private/tmp/zone-root-compile-stage
python3 tools/harness/run.py --build-only --output /private/tmp/zone-root-harness snapshot
export ZONE_EVIDENCE="$HOME/Developer/Pokemon-PlayDate-env/evidence"
python3 - <<'PY'
import json, os
from pathlib import Path
root = Path(os.environ['ZONE_EVIDENCE'])
prior = json.loads((root / 'p0-exact-game-smoke-20261029-01/run.json').read_text())
target = root / 'zone-smoke-buttons-20261029.json'
with target.open('x') as stream:
    json.dump(prior['commands'], stream)
PY
python3 tools/device/build_smoke.py --output "$ZONE_EVIDENCE/zone-exact-smoke-build-20261029-01"
python3 tools/device/simulator_smoke.py --build-stage "$ZONE_EVIDENCE/zone-exact-smoke-build-20261029-01"
python3 tools/device/simulator_smoke.py --build-stage "$ZONE_EVIDENCE/zone-exact-smoke-build-20261029-01" --output "$ZONE_EVIDENCE/zone-exact-smoke-20261029-01" --earned-save "$ZONE_EVIDENCE/p0-exact-game-smoke-20261029-01/earned-save.json" --commands "$ZONE_EVIDENCE/zone-smoke-buttons-20261029.json" --timing-factor 35.1118487293 --execute
```

Use fresh output names on repeats. The factor is the prior provisional calibration,
not a newly measured game factor. Root must retain its provenance and compare the
same workload against exact parent `309194ee` before claiming improvement.
Require SDK pool `16645684`, post-GC title/Continue <=6 MiB, observed Lua peak
<=9 MiB, map/battle wall time and estimated device phase <=500 ms, ordinary
active frame <=33/factor ms (0.939854 ms), and slice <=1000/factor ms
(28.480414 ms). Estimate phase = wall + active*(factor-1) + endpoint allowance;
do not multiply coroutine/display suspension by the CPU factor. Lua heap omits
native allocations. Last exact evidence `p0-exact-game-smoke-20261029-01` still
fails timing (map estimate about 5259 ms). P0 remains frozen, and the game is
not yet playable on Playdate hardware. Root alone owns any later hardware cycle.
