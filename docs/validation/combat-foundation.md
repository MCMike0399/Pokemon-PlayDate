# Combat command, PP and terminal foundation

This slice makes the public battle command boundary authoritative, implements exhaustion through Struggle, preserves major status across ordinary return, and separates terminal outcome from campaign blackout. It does not certify every move or implement a complete competitive GenV simulator. Existing unsupported move/ability/item behavior remains in the content audit queue.

## Public commands and PP

`Battle:selectMove(index)` returns `true` on acceptance or `false, reason` on rejection. Reasons are `wrong-phase`, `fainted`, `invalid-index`, `unknown-move`, `no-pp` or `moves-available`. Index0 is reserved for `selectStruggle()`, and is accepted only when no owned move has PP. Invalid indices include nonintegers, nonnumbers, NaN and infinities. Every rejection precedes all rules RNG draws, PP changes, messages, run counters and phase changes.

`availableMoves(pokemon)` returns a detached list of usable owned `{index,key,move}` choices; `needsStruggle([pokemon])` checks exhaustion. Enemy selection samples only usable moves, falling back to generated Struggle when none remain. The public RUN command validates phase/liveness before narration or RNG. Trainer refusal consumes neither PP nor a battle turn. The existing wild escape probability formula is retained; this slice does not claim an independent audit of that formula.

Both sides spend PP in `resolveTurn` after supported BeforeMove gates and before accuracy/type/effect resolution. A battler fainted before its scheduled turn, sleeping, frozen, flinching, fully paralyzed, or hurting itself through confusion spends no PP. A move that actually attempts but misses or meets immunity spends PP. Gates follow the supported GenV priority order: sleep/freeze, flinch, confusion, paralysis. Sleep/confusion duration boundaries now permit their full configured number of affected attempts. Exceptions such as Snore/Sleep Talk and other missing special behavior are not claimed implemented.

Sleep `statusTurns` means remaining blocked attempts. Applying sleep samples1–3; every positive-count attempt decrements and blocks, including the attempt reaching0. A later attempt at0 wakes and can act. Durable sleep0–3 is valid; every nonsleep major status has counter0. The save codec must preserve this boundary. GenV resetting the original sleep duration on switching remains pending party-battle integration; no new sleep-start field or ability policy was silently added.

Equal-priority/effective-speed turns use the rules RNG for the tie instead of a fixed player advantage. Poison/burn residual events use their supported priority, effective speed and a random tie, checking a terminal faint after each event. Battle ends before applying a later residual when the preceding event leaves one side with no battler.

## Struggle and generated semantics

The move library grows from422 to423 by adding generated `struggle`: Normal scalar type, physical power50, always-hit accuracy0, nominal PP1, with `typeless`, `noPP`, and `struggleRecoil` flags. It is an unlearned runtime fallback and does not enter a Pokémon's owned PP map. Save/learning validation must not treat its presence in the library as permission to learn it.

Typeless damage skips STAB, effectiveness and type immunity. Struggle can hit Ghost and does not gain Normal STAB; it still uses supported physical damage/critical/variance rules. Recoil is nearest-integer maximumHP/4 with minimum1, rather than a fraction of damage dealt. A blocked attempt causes no recoil. FIGHT routes full PP exhaustion directly to Struggle; a partially exhausted set keeps the normal move list, with rejected0-PP selections retaining menu ownership and PP.

All new fields and the new row are emitted by `tools/generate_gen5_data.py`; no generated rows were hand edited. Regenerate into a separate directory and compare:

```sh
python3 tools/generate_gen5_data.py --input-root . \
  --output-root /private/tmp/pokemon-combat-regenerate-unique --moves-only \
  --pinned-cache /private/tmp/pokemon-verifier-fresh-cache --extra-move struggle
```

Worker verified byte-identical output for the entire generated move file. Existing422 move payloads remain unchanged. Scalar inputs use the immutable raw PokeAPI sources already pinned by the verifier; Struggle semantic flags have the primary implementation references below.

## Damage, faint order and exit ownership

Powered hits accumulate actual HP removed, including the last hit of a multi-hit move. Drain and damage-based recoil use that actual total with GenV nearest-integer rounding, avoiding overkill healing/recoil. Fixed-damage DSL attacks respect type immunity while ignoring resistance/STAB/critical scaling, and report actual HP removed. This does not repair every OHKO, variable-power or secondary-effect rule in the broad library.

Terminal kind is explicit: `battle.outcome` is nil until terminal resolution, then `victory`, `defeat` or `run`. `emitEnd()` emits `battleEnd(won, kind)` once, preserving the legacy boolean first argument. Normal listeners run in registration order even when the first owner changes the root state; listener cleanup happens after emission. Forced exit cancels stale callbacks. If an observer throws, emission bookkeeping/listener ownership is still cleared and the error propagates using existing Signal error semantics.

For the supported GenV simultaneous damage/recoil case, target damage precedes user recoil and the last-fainted side wins. Thus the attacking player can have a terminal victory while both HP values are0. No competitive Self-KO clause was added. A fainted player receives no XP, so level-up stat growth cannot revive it. The local campaign controller separately treats the supported active player's0 HP as blackout, fully restores it and uses the existing zone-respawn behavior. A win can mark a trainer/progression flag while also requiring this local blackout. This is a bounded single-active-battler policy; party switching/replacement and authentic Pokémon Center blackout placement are separate work.

Before restoration/exit, `BattleState:finish` records `game.lastBattleOutcome = {kind,won,blackout,player_hp,enemy_hp}`. This preserves preheal evidence after a run or blackout. Ordinary victory/run return preserves major status and its durable counter. Every return or forced exit clears stages, confusion, flinch and disposable battle listeners. Blackout performs the existing full restore of the currently supported player. The root's `game:offerLearning(pokemon)` hook remains after world return.

## Primary references

Behavior references are pinned Pokémon Showdown commit [`9b136a8c8cdb860a8ab96fa063f906604e352547`](https://github.com/smogon/pokemon-showdown/tree/9b136a8c8cdb860a8ab96fa063f906604e352547), inspected independently of this repository's generator output:

- [Move attempt before PP deduction](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/sim/battle-actions.ts#L312), and [recoil rounding/Struggle maximumHP recoil](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/sim/battle-actions.ts#L1435). SHA256 `9d477a6296f8916cbbbfc36ae18bb0729dfda0646e4ee1c00ccb4199661c56d4`.
- [Struggle definition and typeless modification](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/moves.ts#L18207). SHA256 `61ab107dae9628d79ac61da16c72e8565f6a1211874298e00c77c5c0ac9755a7`.
- [Status gates and event priorities](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/conditions.ts), with [Gen6 inherited burn/paralysis/confusion behavior](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/mods/gen6/conditions.ts) and [Gen5 sleep switch reset](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/mods/gen5/conditions.ts). SHA256 respectively `d27aa18fade4d85152b4ce8a002b9c6801e5e08f1859db918e14695797875eda`, `9cca533633c20fecc0d5cf4cbd0f318ed9e0e5164c7f9ba2d62b45b9eaaf6850`, `a45e44a9459209e082b2775cc1b4a24fc32ef9067d0909b8f9d75d7137b3a7dc`.
- [Random speed ties](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/sim/battle.ts#L434), [per-event residual faint resolution](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/sim/battle.ts#L489), [drain rounding](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/sim/battle.ts#L2187) and [GenV last-fainted winner](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/sim/battle.ts#L2659). SHA256 `966fe2263d943343bebc7bbf44ba5ec93454448276a6d45b497885d304dfda58`.

This is primary implementation corroboration, not an original cartridge/ROM comparison or complete ability-aware simulator certification.

## Contracts and native scenarios

Root imports `dev/combatContracts` and registers `Contracts.register("combat", CombatContracts.run)`. Its27 SDK cases exercise real production rules/classes, including invalid command side effects, both-side PP timing, sleep0, all supported status gates, misses/immunity, filtered enemy choices, fallback UI, damage vectors, overkill, residual/faint ordering, event observer ownership/error cleanup, persistent status, blackout and progression. The actual BattleState observer regression saves/restores the real SDK sprite list to avoid corrupting the surrounding contract run's world. Root must execute these cases on the integrated identified SDK bundle; compilation is not execution.

Independent expected vectors include a level50/100Atk/100Def typeless Struggle producing20 damage from known seed1,18 maximumHP causing5 recoil,3 HP drained at50% healing2, and6 HP damage at25% causing2 recoil. These expected values are literal vectors, not values obtained by asking the same implementation under test.

Root fixture hooks extend `adjust_battle` with PP maps restricted to known moves and validated major status/counter pairs, validating both battlers before mutation. Diagnostics expose `battle.current_move` from `currentMoveKey`, `needs_struggle`, `available_player_moves`, explicit `outcome`, and `last_battle_outcome`. Fixture reset clears the last-outcome record.

Runtime-owner commands, fresh output directories:

```sh
python3 tools/harness/run.py --scenario tools/harness/scenarios/combat-pp-run-status.json --output /private/tmp/pokemon-combat-pp-run-unique
python3 tools/harness/run.py --scenario tools/harness/scenarios/combat-struggle.json --output /private/tmp/pokemon-combat-struggle-unique
python3 tools/harness/run.py --scenario tools/harness/scenarios/combat-simultaneous-blackout.json --output /private/tmp/pokemon-combat-blackout-unique
```

The three scenarios require12 native captures. They use actual input with bounded awaits, not direct turn-resolution calls. The partial-PP scenario demonstrates the rejected move retaining the move menu/RNG/PP and a safe run preserving poison. The all-exhausted scenario uses seed42/current level5 Charmander–Magikarp stats: enemy Struggle3 damage plus4 recoil, player Struggle5 damage plus5 recoil, leaving player10HP/enemy8HP with every owned PP0 and exactly4 rules draws. These strict values are analytical expectations to be confirmed by the root's actual run, not claimed runtime observations.

The simultaneous scenario uses level7 Charmander against level5 Gastly, all PP0 and both HP1. It captures damage, both HP0, terminal victory without XP gain, then actual blackout restoration. The archived last-outcome record must retain both preheal HP0 and victory/blackout flags, while the returned level7 player has22HP and restored PP. Root must inspect the native frames and rerun original intro, ordinary battle return and blackout/learning regressions before acceptance.

Worker validation before Source freeze: SDK compilation passed at `/private/tmp/pokemon-combat-foundation-compile.pdx`; generated moves reproduced exactly;53 existing verifier/generator host tests passed after the integrator updated obsolete pre-foundation expectations. Scenario JSONs parse and whitespace checks pass. Worker launched no Simulator. Actual integrated SDK counts, native results, visual inspection and any root-found defects belong to the subsequent acceptance record.

First root-owned integrated execution: `/private/tmp/pokemon-combat-save-contracts-01/00001-result.json` reports all27 combat cases passing. The aggregate was93 passed/1 failed, with the sole failure in a persistence sequence-cap test (`dev/saveContracts.lua:251`, nil `data`). The worker inspected the finalized report without accessing the runtime mailbox. This is passing combat contract evidence, not acceptance of the full aggregate or the still-pending native scenarios/visual regressions.

Subsequent root-owned aggregate `/private/tmp/pokemon-persistence-rng-contracts-02/00001-result.json` passed all112 cases, including all27 combat cases, after the independent persistence repair and RNG wire hardening. Root reported all915 protected visual artifacts matching exactly. Native combat scenario execution/inspection is still owned by the root acceptance pass.
