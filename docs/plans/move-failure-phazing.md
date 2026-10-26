# Milestone 5.2 step 1 preparation

Branch: `wip/move-failure-phazing`, based on `895a874` (descendant of `e61adc7`).
This is an implementation candidate, not milestone acceptance. No Simulator was
launched, no push was made, and no ledger, protected art or baseline was changed.
Root must keep the 5.1 campaign Source frozen until acceptance.

## Implementation

The existing engine remains authoritative. Narrow patches from the frozen
Whirlwind packet add one shared active-member commit, actual actor identities
on queued turns, per-opponent participation retention, and terminal `run`
propagation from the DSL. Existing Party, conditions, effects, rewards, learning
and session owners still perform their transactions. Incoming members enter
through existing hazard/ability/seen boundaries; displaced actors cannot act.

Both Whirlwind and Roar now generate `ForceSwitchEffect(DEFENDER)`. They retain
Gen V accuracy 100, PP 20, priority -6 and target ID 10. Roar additionally checks
the target's actual Soundproof ability before accuracy. Trainer battles sample
usable nonactive reserves through RulesRNG; wild battles end as `run`, without
victory rewards. Missing reserves and higher-level wild targets fail normally.

A reviewed inventory explicitly distinguishes 286 supported dispatches from
139 incomplete moves. The generated runtime table fails closed for unknown IDs.
Unsupported attempts consume their normal PP after existing status gates, show
`But it failed!`, print `[move-gap] <key>: <reason>` to the dev log, and retain
at most 12 detached diagnostic receipts. They cannot deal placeholder damage,
apply partial status/stat effects, charge, or sample move accuracy/damage RNG.
The status guard also catches supported rows whose payload becomes nil/NoEffect.

The supported exceptions include Bide, fixed damage/OHKO, Solar Beam, Skull Bash,
Petal Dance, Rollout, Electro Ball, Endeavor, Sucker Punch, Feint, weather,
trapping, hazards, Roost, Worry Seed and deliberate singles failures. Splash
remains intentionally ineffective, now with `But nothing happened!` narration.
Damaging gaps include charge/recharge, Focus Punch, unimplemented rampages,
variable power, Pay Day rewards, item interactions and damaging phazing. Partial
status rows such as Stockpile, Swallow, Memento, Flatter and Heal Pulse also fail.

Only Whirlwind and Roar payloads, plus the producer epoch, change in moves.lua.
The exact migration contract still reverses to the original immutable 424-row
oracle hash. Existing host producer tests advance their expected epoch to 13;
the Poison Fang historical fixture additionally removes the two later phazing
payloads before testing genuine epoch-11 history. No historical hash is updated.

Ten existing synthetic SDK fixture files add `actor = battle[side]` (or the
corresponding actual object) to manually constructed turns/pending actions:
abilityCompatibility, ability, bide, brockMechanics, brockMoveBatch, combat,
earlyCombat, ownTempo, sexAbility and worrySeed contracts. They previously relied
on rebinding a side at execution time. No existing assertion, PP expectation or
RNG expectation is weakened. New real SDK suites contain 27 Whirlwind groups
from the packet and six additional failure/Roar groups. One new group attempts
every unsupported move on both sides, checking failure, HP/status/stages, PP,
move RNG and diagnostic identity.

## Root integration

`Source/main.lua` is byte-identical to the parent. The production-dev-gate owner
must compose [these four registration lines](move-failure-phazing-registration.lua)
into the harness-only overlay after production modules and `dev/contracts` load.
The diagnostic additions expose `battle.force_switch` and `battle.move_gaps`;
these are read-only snapshots, not new model owners or save fields.

After composing that overlay, the root runtime commands are:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/harness/run.py contracts --output "$POKEMON_ENV/evidence/m52-move-failure-sdk-01"
python tools/harness/run.py --scenario tools/harness/scenarios/move-failure-phazing/whirlwind-trainer.json --output "$POKEMON_ENV/evidence/m52-whirlwind-trainer-01"
python tools/harness/run.py --scenario tools/harness/scenarios/move-failure-phazing/whirlwind-wild-success.json --output "$POKEMON_ENV/evidence/m52-whirlwind-wild-01"
python tools/harness/run.py --scenario tools/harness/scenarios/move-failure-phazing/whirlwind-wild-higher-fail.json --output "$POKEMON_ENV/evidence/m52-whirlwind-higher-01"
python tools/harness/run.py --scenario tools/harness/scenarios/move-failure-phazing/roar-wild-success.json --output "$POKEMON_ENV/evidence/m52-roar-wild-01"
python tools/harness/run.py --scenario tools/harness/scenarios/move-failure-phazing/unsupported-teleport.json --output "$POKEMON_ENV/evidence/m52-unsupported-teleport-01"
```

Each output directory must be new. Scenarios use native menu input after explicit
fixtures; they are mechanics witnesses, not natural campaign acceptance. Root
should inspect dragged-out/new opponent, wild escape/world return and failed
Teleport screenshots, and run the required merged protected-art comparison.
The two new native scenarios are unexecuted; root must diagnose any failed
message/timing vector before treating them as acceptance.

## Checks completed without Simulator

All host commands ran after sourcing the environment above:

```sh
python -m tools.generate_move_support --check
python -m unittest tools.tests.test_move_failure_phazing tools.tests.test_move_producer_contract tools.tests.test_early_combat_generator tools.tests.test_ability_metadata tools.tests.test_move_verifier
python -m unittest discover -s tools/tests -p '*generation.py'
git diff --check
```

Results: 63 targeted/verifier tests and 44 generation tests passed, zero skips.
The move generator was run moves-only against SHA-verified immutable CSVs.
A private Source copy with the four overlay registrations compiled with SDK
3.1.2 `pdc`; no fake SDK or Lua runtime was used. The final compile-only evidence
is `~/Developer/Pokemon-PlayDate-env/evidence/m52-move-failure-phazing-compile-02/`.
It includes the staged Source, compile log and per-file hashes. Its temporary
main registrations exist only inside that private copy. Host logs and pinned
source caches are under `~/Developer/Pokemon-PlayDate-env/preparation/move-failure-phazing/`.
Compilation establishes neither SDK assertion results nor native behavior.

## Pins and limitations

- Frozen packet SHA256 verified against `implementation-handoffs/manifest.json`:
  `7e82e300fda92fa1435e4cec6a00b795e5d90bb8464b4b5732fb0929c03f3d79`.
  Only its narrow production diffs, actor fixture migrations, SDK suite and three
  scenario files were used. The engine was never replaced wholesale.
- Default oracle: Showdown `9b136a8c8cdb860a8ab96fa063f906604e352547`, base moves
  through gen8/gen7/gen6/gen5 mods. The five exact SHA256 pins are recorded in
  `tools/references/move-support.json` and match the existing metadata generator.
- PokeAPI `2bf639e5572812a67d2b94903fdcb9d095f5aeb2` and pre-SV scalar snapshot
  `c9cb78bd0a36b33210e697e6cb1b5065bd9fb24a`, through the existing verified CSV
  manifest. No species or learnset change was made.
- Wild level/escape policy retains the packet's strict target-level <= source-level
  rule from native reconstruction `b279bbefa99bb2f6fbabcc95e4b6d3e939290353`.
  Showdown has no wild encounter/reward oracle. No new native reference research
  or cartridge RNG equivalence is claimed.
- Support means core singles dispatch, not complete mechanics acceptance. Sun and
  Hail have no producer; Growth's Sun doubling and Blizzard's Hail accuracy remain
  pending with those producers. Flame Burst's adjacent-ally behavior is doubles
  only. Other abilities and rare interactions remain the existing release backlog.
- Substitute, Ingrain and reflection have no supported producers. No fabricated
  marker is used to claim their phazing interactions. Soundproof coverage added
  here is specifically Roar; this does not implement every sound move interaction.
- Historical runtime evidence may correctly become stale when owner bytes change.
  Do not rewrite those accepted evidence hashes to claim this candidate ran.
  Root owns SDK/native execution, full merged checks and acceptance.
