# Isolated Gen V Haze and Clear Smog candidate

Original worktree base: `6dab82f7a33fa8eae4eb3759699ab1032abc5fe2`.
Synchronization: `35802a50e58e76a6fdfcfea4274bd809a44962a5` has the exact
Git tree of B `10cb9572f8db3979fd7d3b1ddf517277008b4eeb` (149 maps).
Root selects only the subsequent logical implementation commit. This is
preparation; C and audio stay inactive. No runtime, device, performance or
adoption claim. No Root/B checkout edits, pushes, delegation or owner locks.

`Pokemon:clearStatStages()` resets the seven existing stage values in place.
It does not invoke switch/fullRestore cleanup, stat-drop prevention, abilities
or RNG. Existing `resetStages()` semantics remain unchanged. The two generated
DSL payloads share `BattleEffects:resetStatStages(scope)`. Haze commits both
living active battlers before narration, leaves reserves untouched and succeeds
at zero stages. Clear Smog's primary effect runs after a successful damaging
hit, including lethal hits, on the current defender only. It is not a secondary:
Shield Dust and Clear Body do not prevent it. The existing action/PP, immunity,
Protect, accuracy and damage owners retain their gates and draw sequence.
Major status, confusion, flinch, conditions (including Focus Energy), weather,
side conditions, typing, identity, moves, IV/EV and HP/PP are not reset by this
stage-only mutation. Ordinary move damage, PP expenditure and action bookkeeping
still occur. No BattleState, Save/schema or RNG changes.

The pinned Showdown `9b136a8c8cdb860a8ab96fa063f906604e352547` base moves
supply both callbacks, unchanged through Gen8, Gen7, Gen6 and Gen5 overrides.
Haze uses `onHitField/getAllActive/clearBoosts` and bypasses Substitute;
Clear Smog uses `onHit/clearBoosts`, accuracy true, and is protectable. Gen5's
Substitute primary-hit callback returns HIT_SUBSTITUTE even when broken; the
shared action owner removes that target before onHit. Clear Smog therefore must
not reset through an absorbed/broken Substitute. Substitute remains unsupported;
no producer or fake substitute state was added. A fail-closed interlock in the
Clear Smog effect refuses execution if Substitute's support gap is removed
without integrating primary-hit routing. That future integration must replace
this interlock with actual body-hit eligibility and add native interaction cases.
The current candidate does not claim executed Substitute coverage or doubles.

[Provenance](provenance.json) records checksum-verified local Showdown/PokeAPI
inputs, exact regeneration, 425 rows, 423 unchanged row bytes, all scalar fields
unchanged, and the original 424-row inverse hash. Producer epoch16 introduces
only these payloads; Chip Away14 and Reflect15 history remain intact. Existing
historical evidence/oracle hashes were not repinned.

[Exposure](exposure.json) preserves the static 44-trainer projection's 11 Haze
and 11 Clear Smog occurrences. This is not SDK constructor proof. The supplied
report contains **26 total gaps**, including these two, hence **24 other projected
gaps**, whereas the brief says 26 other gaps. Every unrelated support entry
remains unchanged; no roster/level/AI/learning adjustment was made.

[Validation](validation.json): SDK3.1.2 production and ordinary harness compile;
a separate private harness also compiles with the new import/registration.
There were 101 targeted existing host tests: 93 pass, seven fail on literal
epoch15 expectations, one errors on the stale Haze-gap expectation, zero skips.
The first 44-pass run is a subset, not additional passes. These suites are not
green. All existing fixtures and assertions remain unchanged. No full host run.
The static qualifier separately passes exact two-row migration, rejection of
current-epoch missing/reversed payloads, unchanged scalars/inverse hashes,
source checksums and exact generation. Existing side, condition and accuracy
SDK suites are retained unchanged and still need Root's native re-execution.

Apply [root-registration.patch](root-registration.patch) only when Root is ready
(the patch applies to the exact B overlay); it is unapplied here. No production
import is needed: the existing DSL/effects/Pokemon imports own the implementation.
The private registered compile is at the evidence directory in validation.json;
it does not establish runtime acceptance. Root owns exact native cases, both
independent review axes and eventual integration.

Native suite `stage-reset`, compiled **not executed**, has these nine cases:

- Haze resets both active seven stages and preserves unrelated state
- Haze with no boosts succeeds through Protect without an accuracy draw
- Stage-reset producers retain sleep flinch and exhausted PP action gates
- Clear Smog body hit resets only defender and retains exact damage RNG
- Clear Smog Protect blocks damage reset and damage RNG but spends PP
- Clear Smog Steel immunity blocks damage reset and RNG but spends PP
- Clear Smog primary reset bypasses Clear Body and Shield Dust
- Enemy Clear Smog resets player only and leaves reserves unchanged
- Clear Smog lethal primary hit resets before ordinary faint handling

Reproduce static qualification using the shared verified input cache:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/qualify_stage_reset.py \
  --showdown-cache "$POKEMON_ENV/preparation/move-failure-phazing/showdown" \
  --report /absolute/new-report.json
python3 -m tools.generate_move_support --check
```

Changed files (logical commit only):

```text
Source/battle/dsl.lua
Source/battle/effects.lua
Source/battle/moveSupport.lua
Source/battle/moves.lua
Source/data/pokemon.lua
Source/dev/stageResetContracts.lua
tools/generate_gen5_data.py
tools/move_producer_contract.py
tools/qualify_stage_reset.py
tools/references/move-producer-migrations.json
tools/references/move-support.json
tools/integration/stage-reset/README.md
tools/integration/stage-reset/exposure.json
tools/integration/stage-reset/provenance.json
tools/integration/stage-reset/root-registration.patch
tools/integration/stage-reset/validation.json
```
