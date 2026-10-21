# B2W2 early-route combat corrections

The candidate from `/private/tmp/pokemon-early-combat` is now integrated in live Source; root owns Simulator acceptance. Compile-only proof passed at `pokemon-early-combat-build-04`. Root actual SDK proof `pokemon-early-combat-sdk-01` passed all23 new groups; aggregate333 passed and2 failed because older tests expected badPoison rejection and423 moves. Those two expectations are now repaired in separate narrow contract patches; root integrated aggregate now passes335/335 and all6 jobs; see accepted-early-combat/acceptance.json. Source SHA for the earlier build03 runtime overlay (before the two contract-only repairs) is `819149a93897b4f9d91ebf1734836bcfd4afd83752924c6674d963e76d3416ef`. Four host checks pass. The new SDK module supplies23 groups, without a replacement SDK. The campaign remains unfinished.

The initiating inventory was `/private/tmp/pokemon-pewter-slice/move-gaps-01.json`: source Brock's Geodude12 exposes Mud Sport, Onix14 exposes Curse/Rage; the gym trainer's Sandshrew11 exposes Rollout/Rapid Spin; forest Weedle/Caterpie expose String Shot. The corrections change those fights materially: Onix can now raise Attack/Defense, Rage can build Attack, and Sandshrew can lock into increasingly powerful Rollout. This is intentional B2W2 mechanics rather than GenI trainer balancing. Native trainer/blackout balance still needs root qualification.

## Concrete rules and sources

`tools/references/early-combat.json` pins immutable Showdown revision `9b136a8c8cdb860a8ab96fa063f906604e352547`, raw file URLs/SHA-256 values, generated row hashes and exact preexisting scalar projections. The implementation was written independently in Lua after reading the primary implementation. It does not import or transpile Showdown at runtime. Relevant inheritance files are base moves/conditions, Gen8/Gen7/Gen6 move overrides, Gen6 conditions and Gen5 moves/conditions. Gen7/Gen8 conditions files do not exist at that immutable revision; this absence is recorded, rather than substituting current master.

| Move | Corrected behavior |
|---|---|
| String Shot | Speed decreases1 stage, not the modern2. |
| Mud Sport | A user volatile weakens Electric base power globally while its holder remains active. GenV Q12 factor1352/4096; no five-turn modern field timer. |
| Curse | Non-Ghost: user Speed-1, Attack+1, Defense+1. Ghost: curse opposing target, pay half maximum HP, quarter-max residual; duplicate curse fails before HP cost. |
| Rage | Successful use arms Rage. Each subsequent opposing damaging hit boosts Attack, capped6; the volatile ends before the user's next attempted move, including status-blocked attempts. |
| Rollout | Five successive forced attempts with successful hit powers30/60/120/240/480; Defense Curl doubles these. Only the first attempt deducts PP. Miss/no target/status interruption releases the lock. |
| Rapid Spin | Successful damage removes the user's Leech Seed, binding and own side hazards. No later-generation Speed boost. Miss/Normal immunity preserves obstacles. |

String Shot and Mud Sport use [Gen5 moves](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/mods/gen5/moves.ts); Rapid Spin inherits its removal handler but drops the modern secondary through [Gen7 moves](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/mods/gen7/moves.ts). Curse, Rage, Rollout and Defense Curl are grounded in [base moves](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/moves.ts), with the old Curse target inherited through Gen8/Gen7 overrides. The pinned [battle action owner](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/sim/battle-actions.ts) runs BeforeMove before PP deduction, skips deduction when a move is locked, and dispatches Hit inside the multi-hit loop. Those ordering details drive the continuation/interruption and per-hit Rage tests.

`BattleConditions` is the battle-owned transient owner. It keys member state by actual Pokémon identity and keeps hazards by player/enemy side. No durable Pokémon field or constructor is changed, so the pending/integrated `PokemonNames` default import is preserved. Scene rendering is unchanged apart from a root-owned PSN label recipe. `calcDamage` retains its existing three-argument API and accepts an optional effective-power fourth argument; only the actual powered-move path passes the mechanic-adjusted power.

Mud Sport modifies base power before damage, with half-down Q12 power rounding; multiple active holders chain the pinned factor. The independent vector uses Electric power95→31 and level100 offensive/defensive stats100, RNG seed2: no critical, variance86, damage24. Rollout's independent seeded powered-hit vectors are23/45/88/176/352 with the same controlled100/100 stats, neutral types, level100 and per-attempt seed2 (accuracy14, critical roll2, variance87). The tests heal the real target between isolated hits so overkill cannot hide power escalation.

## Required dependencies

Leech Seed, partial trapping, Defense Curl, Spikes, Stealth Rock, Toxic Spikes and Toxic now have actual production effects. These are the dependencies needed for honest removal/escalation behavior, rather than synthetic obstacle flags.

Leech Seed rejects Grass and duplicate targets, drains1/8 maximum HP, and heals only actual HP removed into the current source-side active receiver. Binding moves (`bind`, `wrap`, `clamp`, `fireSpin`, `whirlpool`, `sandTomb`) establish a4/5-residual trap, block voluntary switch/run, deal GenV1/16 residual, and release when their source leaves/faints. The duration comes from the inherited condition's5/6 pre-decrement clock; [Gen5 conditions](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/mods/gen5/conditions.ts) overrides the later1/8 divisor. No Binding Band/Grip Claw/Shed Shell behavior is claimed.

Spikes stack to3 (1/8,1/6,1/4 entry damage), Stealth Rock scales1/8 by Rock effectiveness, and Toxic Spikes stack to2. Grounded Poison absorbs Toxic Spikes; Flying avoids ground hazards, Steel avoids poison, and two layers inflict bad poison. Entry processing preserves side-condition insertion order. Hazards run on actual party/trainer replacement and can cause another forced replacement or final defeat/victory; they never revive. The primary hazard/seed producers and handlers are in the pinned base moves file. Only typing determines grounding because abilities/items are not implemented.

Bad poison is durable major status `badPoison`; the escalating counter is battle-owned, starts0, increments before residual, caps15 and resets on switch/new battle/exit. The inherited [toxic condition](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/conditions.ts) resets stage on switch, uses residual order9 and multiplies the floored minimum1 `maxHP/16` unit by its stage. The literal31-HP vector loses1,2,3. Toxic is now a generated move row with GenV Poison/status/90accuracy/10PP; it obeys Poison/Steel immunity and fails visibly when already afflicted. Antidote, full-status medicines and full restore recognize bad poison. Capture treats it like ordinary poison's GenV1.5 multiplier; no capture algorithm changes were made.

Residual order is Seed8, poison/toxic9, burn10, Curse12, binding13, then speed ordering within each order and one rules tie draw for matching active speeds. Damage is checked for faint/terminal outcome before later residuals proceed. Major status persists at ordinary exit; all battle-owned fields clear. The existing separate burn GenV1/8 behavior comes from [Gen6 conditions inherited by Gen5](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/mods/gen6/conditions.ts).

Codec version remains3: this is an additive allowed-status enum, with exactly the existing record shape and nonsleep counters0. All old codec3 records retain their meaning and remain supported; no nickname, XP or sleep migration is guessed. Earlier unsupported codec1/2 behavior is unchanged. A saved `badPoison` record contains no escalation counter; decoding into a new battle starts that counter0 as required. Older unreleased builds will reject the new status enum, rather than reinterpret it. Generic save/session envelope versions remain unchanged.

## Reviewable integration

`foundation-manifest.json` lists base/current hashes for every owned runtime file and generator; `patches/` contains narrow diffs against those live bases. The fixture hunk was rebased onto the current live Pokédex seen fixture and adds only `badPoison` status support. The owner also supplies portable tools/reference/tests under staged `tools/` for repository installation. Existing CSV caches/reports are untouched.

Root integration recipes, inserted only into the validator's private current-tree copy:

- BattleState forced exit calls `battle:clearVolatiles()` before releasing the reference, except while `battle.emittingEnd`; normal `emitEnd` clears after all terminal listeners and also cleans up if a listener throws.
- Diagnostics exposes `battle.conditions = battle:getConditionsSnapshot()`.
- Native BattleScene/PartyState PSN label maps recognize `badPoison`.
- The harness `adjust_battle` status enum recognizes `badPoison`; its existing nonsleep counter preflight remains authoritative.
- Dev main imports `earlyCombatContracts` and registers `early-combat`. Battle itself imports `battle/conditions`; no production main import is required for that owner.

`getConditionsSnapshot()` returns fresh primitive player/enemy states (`mud_sport`, `cursed`, `rage`, `defense_curl`, `rollout_hits`, `seeded`, `trapped`, `trap_turns`, `toxic_counter`) and each side's hazard layers. Cured status reports toxic counter0 immediately. It does not expose identity references or mutate the maps. Locked Rollout is advanced automatically by `Battle:update()` from a command phase; user commands cannot replace it with another move, bag action, run or voluntary switch. Enemy move selection likewise retains Rollout with no choice RNG while locked. Forced replacement remains available after faint cleanup.

```sh
# After installing the staged tools/reference/test files into the repo:
python3 -m unittest tools.tests.test_early_combat_generator -v
python3 tools/verify_early_combat.py --source-cache /private/tmp/early-combat-primary --fetch
python3 tools/generate_gen5_data.py --input-root "$PWD" --output-root /private/tmp/early-combat-regenerated --moves-only --pinned-cache /private/tmp/pokemon-verifier-source --extra-move toxic
cmp Source/battle/moves.lua /private/tmp/early-combat-regenerated/Source/battle/moves.lua
# Root Simulator owner only; private overlay preserves current unowned Source:
python3 /private/tmp/pokemon-early-combat/validate_staged.py --project "$PWD" --output /private/tmp/pokemon-early-combat-sdk-01 --execute
```

For pre-integration replay, run the staged verifier against its staged Source and use `PYTHONPATH="$PWD" python3 /private/tmp/pokemon-early-combat/tools/generate_gen5_data.py --input-root "$PWD" --output-root /private/tmp/early-combat-regenerated --moves-only --pinned-cache /private/tmp/pokemon-verifier-source --extra-move toxic`. The live input needs no modification. Scalar CSV pins remain in `tools/verify_moves/sources.json`; `--fetch` on the generator fetches only those immutable inputs. The legacy full species/Showdown path remains outside this invoked mode.

Generated preservation checks prove all423 preexisting scalar rows remain exact. Only17 declared existing effects/flags change: binding6, Leech Seed, String Shot, Rage, Defense Curl, Curse, Spikes, Rollout, Rapid Spin, Mud Sport, Toxic Spikes, Stealth Rock. Toxic is the sole new row, for424 total. The verifier rejects corrupted source pins, undeclared effects, scalar changes and roster drift with nonzero exit. No move data was hand-edited.

## SDK and native qualification

Twenty-three SDK groups exercise all six corrections and real producers, literal power/damage/HP vectors, duplicate/capped effects, Ghost self-KO, Rage multi-hit/fixed/status/residual distinctions, all five Rollout PP stages, automatic forced continuation, rejected commands without RNG, miss/no-target/status interruption, actual party withdrawal/entry, seed actual-HP healing, trap restrictions/release, spin miss/immunity/removal/no Speed boost, hazard layers/grounding, Toxic progression/switch/faint/save/cure/reapply/capture bonus, ordered residual narration and once-only terminal cleanup. These execute real production Lua classes and RulesRNG under the SDK. Root reports all23 passed in the actual SDK run; the repaired existing groups pass in the root335-contract integrated run.

Five native recipes live under `tools/harness/scenarios/`, run with validator `--scenario PATH --execute` by root:

- `early-combat-mud-sport.json`: Geodude12 uses its actual slot2; shows weakening message and one PP spent.
- `early-combat-curse.json`: Onix14 actual slot1; captures Defense rise after Speed/Attack messages.
- `early-combat-rage.json`: Onix14 actual slot3 receives a real Rattata hit and displays Rage building.
- `early-combat-rollout.json`: Sandshrew11 actual slot2 starts with1PP against Splash-only Magikarp100; all five seeded hit receipts/captures assert the same0PP and20 total rules draws.
- `early-combat-rapid-spin.json`: Sandshrew11 is seeded by a real Bulbasaur7, then uses its actual slot3 to clear it visibly.

These are supplementary, explicit fixture journeys; they do not substitute for natural forest/gym trainer progression, balance or blackout review. Their text/frame/HP expectations remain strict until actual root execution. No art/layout/player sprite is changed.

## Remaining gaps

This slice does not make the full424-move library complete. Abilities, held items, weather, Substitute, Protect, reflection/Snatch/Baton Pass interactions, doubles, phazing and all other unsupported mechanics remain unsupported campaign work. In particular grounding is type-based without Levitate; trapping ignores unimplemented escape items; seed ignores unimplemented Liquid Ooze/Magic Guard; Rage does not claim Substitute/ability interactions; Rollout does not implement modern Disguise/Ice Face or called-move quirks. No such policy is silently applied as a completed feature.

The existing general damage/stat model and multi-hit distribution are preserved outside the declared corrections; IV/EV/nature, exact broader damage rounding, accuracy/OHKO and battle medicine UI need their separate scopes. Full bad poison outside-battle walking damage is not implemented (GenV has no field poison damage), and no GenI field poison tick was added. Physical-device performance is unvalidated.
