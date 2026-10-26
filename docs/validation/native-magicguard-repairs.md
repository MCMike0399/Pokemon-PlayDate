# Native Magic Guard witness lifetime repair

Base: `4a69432f72b23f383ea984c06e54dd523448b30d`.
Branch: `wip/native-magicguard-repairs`.

The root Native2 report at
`~/Developer/Pokemon-PlayDate-env/evidence/m53-private-sdk-20261026-02/00001-result.json`
contains three contact failures with `expected true, got false`. At the exact
base, their first matching assertions are `contactAbilityContracts.lua:303`
(Toxic after Worry Seed), `:345` (Double Edge target damage), and `:359`
(confusion self-hit damage). Plain HP assertions have a different error shape.
The later Scratch ledger assertion in the recoil case is unreachable after
`:345` fails; neither its outcome nor the intervening Struggle outcome can be
inferred from that report. The confusion RNG assertion likewise follows its
failing ledger assertion.

`attempt` and `residual` call `settle`, which resumes the real script until it
leaves the script phase. `BattleScriptPhase:exit` calls `effects:endRound`,
setting `round=nil`. Consequently `damagedThisRound` must return false after
these helpers return, regardless of whether the preceding real HP loss was
properly recorded. The negative ledger assertions at the same boundary were
also vacuous. This is a contract observation-lifetime defect; no production
change is justified by these failures.

The optional observer now starts a round inside the actual script, runs the
unchanged production producer, verifies that the same live round remains, then
checks HP/ledger/status/counters/PP/RNG before returning from the coroutine.
All Magic Guard ledger checks use this boundary. Every original true/false
expectation is retained; extra assertions cover Struggle target damage, actual
Scratch HP loss, the replaced effective ability, Toxic counter3, and cleanup
of the round after script exit. Other contact cases retain their original
helper behavior. No production hook, actor validation, hit-token ownership,
lethal handling, confusion/Struggle provenance, move data or RNG is changed.

Verification: sourced `~/Developer/Pokemon-PlayDate-env/env.sh`;
`python3 -m tools.check_contact_ability_sources` passed all17 pinned primary
files at Showdown `9b136a8c8cdb860a8ab96fa063f906604e352547`.
The19 tests in `test_contact_ability_sources`, `test_cerulean_abilities`, and
`test_ability_metadata` passed with zero skips. `git diff --check` passed.

Real SDK3.1.2 compile-only staging passed with:

```sh
python3 tools/harness/run.py --build-only contracts --output "$POKEMON_ENV/evidence/native-magicguard-repairs-compile-20261026-01"
```

That directory retains staged Source, per-file hashes, build log and build.json.
Compiled source SHA256:
`2b4223562b6fd05331974850d03fcec104d9bb4cdba64a70c55a1ef2c35430e1`.
The compilation identifies the base revision plus dirty contract source; the
staged contract bytes are the repaired candidate. Documentation was added after
this compile and does not affect Source.

**Actual Native acceptance remains pending.** No Simulator, substitute Lua/SDK,
push, or delegation was used. Root must cherry-pick this repair and rerun the
real contracts through its runtime owner. The existing imported registration
is sufficient. Compilation and host source checks do not establish that the
three cases pass, that their previously unreachable assertions pass, or that
the full1588-case suite is green. If another guard fails, its precise label
now identifies the observed live producer and endpoint.
