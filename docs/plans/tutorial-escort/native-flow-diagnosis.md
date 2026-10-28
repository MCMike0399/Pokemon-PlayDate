# Native escort flow diagnostic handoff

Base: `4a69432f72b23f383ea984c06e54dd523448b30d`.
Branch: `wip/native-escort-flow`.

The root-owned run `m53-private-sdk-20261026-02` reports the same wrapper error
for all five exact escort route/reset cases: expected dialog, got tutorial-escort.
Its result does not retain the inner controller pose. The arrival loop allows
2001 controller updates including the initial reservation update. The later
departure/reset loop allows 100. The failure alone cannot distinguish failed
movement, blocked occupancy, guard invalidation or insufficient timing.

The contract now identifies initial invitation, arrival and departure/reset
assertions separately. A mismatch includes `escort-context=` JSON captured before
fixture teardown: phase/waiting, retry phase, blocked ticks, root/top/valid guards,
both poses, player interpolation/origin, controller movement flags, route indices,
and each next cell's collision and occupant source ID. Production flow, route
data, update bounds, endpoint/dialog assertions and full durable-session equality
are unchanged. No native runtime was launched by this worker.

Root should cherry-pick this diagnostic commit into its current repaired candidate
(including the separate actor/STAY and both arrival-transit repairs), then run:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/harness/run.py --recent-interval 60 --scenario tools/harness/scenarios/tutorial-escort.json --output "$POKEMON_ENV/evidence/native-escort-flow-diagnostic-20261026-01"
```

The scenario runs the registered SDK contracts; the current harness does not
offer an individual-suite filter. Use a fresh output suffix if that path exists.
Return the five `tutorial-escort: exact leased escort route and reset` errors
from `requests/00001-result.json` (or locate the numbered result in that run).
The error now contains the stopping context even though fixture cleanup restores
the original world before the outer harness snapshot.

Ranked probes once native context is available:

1. A blocked next-cell occupant in the final aisle predicts `phase=blocked` with
   both movers false and indices before the final right steps. Inspect that
   reservation and the yielding condition before changing either route.
2. A rejected ordinary player step predicts `phase=failed` and a rejection in
   `waiting`; inspect Player traversal at the reported target.
3. An ownership guard predicts `valid=false` or `top=false` and no progress;
   inspect the fixture/scene attachment rather than increasing tick limits.
4. A timing-only issue predicts a still-moving legal route, valid guards and no
   blocked state at the limit. Require measured native timing before altering it.

Verification performed: all seven `tools.tests.test_tutorial_escort` host checks
passed; real SDK compile-only staging passed in
`~/Developer/Pokemon-PlayDate-env/evidence/native-escort-diagnostic-build-20261026-01`.
This establishes compilation and unchanged pinned data, not native execution or
a causal repair. Controller changes and native acceptance remain pending root's
diagnostic run.
