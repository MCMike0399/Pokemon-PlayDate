# Staged B2W2 learnset foundation

This slice is staged at `/private/tmp/pokemon-learnsets-foundation/Source`; it has not changed live production Source or passed gameplay acceptance. Its reviewable patch is `/private/tmp/pokemon-learnsets-foundation/production.patch`, with hashes/preservation checks in `foundation-manifest.json`. Apply only the six files listed there to a newly qualified base. Do not copy the entire staged Source: its unowned harness files predate later root-owned qualification fixes.

The staged slice adds2184 complete B2W2 learning events for151 species, initializes moves at the actual level, removes the intro's first-two override, queues explicit level-up choices, and implements the three extra move definitions required by the complete learnsets. Species IDs, names, base stats, GenV types and assets remain unchanged. All419 existing move payload rows are byte-preserved. No images, maps or battle art changed.

## Reproduce and check generation

`tools/generate_learnsets.py` reads immutable raw CSVs directly through the checksum-enforcing source loader. It does not call the verifier comparator/oracle or the move generator. Metadata includes each event's move key, level, nullable source order and canonical numeric ID. Ordering is level ascending, explicit source order ascending before missing order, then numeric move ID. Repeated learning events are retained. The full legacy `pokemonData.moves` array is a generated projection of those events; it is not a second editable definition.

First add the three required move payloads to an isolated staged copy using the narrow moves-only mode. This mode uses immutable PokeAPI scalar history, skips Showdown/species writes, and refuses any unexpected change to an existing move row:

```sh
python3 tools/generate_gen5_data.py --input-root . \
  --output-root /private/tmp/pokemon-learnsets-foundation --moves-only \
  --pinned-cache /private/tmp/pokemon-verifier-fresh-cache \
  --extra-move charm --extra-move psywave --extra-move stormThrow
```

The staged runtime DSL/battle patch must accompany these payloads; Psywave is an actual effect class and Storm Throw uses an actual forced-critical path. Scalar additions alone are insufficient. Full species generation remains uninvoked and retains the old mutable Showdown fetch paths; pinning those paths is a separate task. The generator now requires an explicit output root, so the old bare command must be updated.

Generate metadata into the explicit staged output, preserving its other fields and runtime methods:

```sh
python3 tools/generate_learnsets.py \
  --pokemon /private/tmp/pokemon-learnsets-foundation/Source/data/pokemon.lua \
  --moves /private/tmp/pokemon-learnsets-foundation/Source/battle/moves.lua \
  --cache /private/tmp/pokemon-verifier-fresh-cache \
  --output /private/tmp/pokemon-learnsets-foundation/Source/data/pokemon.lua
```

Add `--check` to compare without writing and fail on drift. With live419-move input this command fails before writing, listing `charm, psywave, stormThrow`. Unknown source IDs, duplicate events, absent species, malformed levels/order, checksum failures and missing move definitions cannot silently drop learning events. The independent verifier can inspect the staged files:

```sh
python3 tools/verify_moves/main.py \
  --pokemon /private/tmp/pokemon-learnsets-foundation/Source/data/pokemon.lua \
  --moves /private/tmp/pokemon-learnsets-foundation/Source/battle/moves.lua \
  --cache /private/tmp/pokemon-verifier-fresh-cache \
  --output /private/tmp/pokemon-learnset-content-unique.json
python3 -m unittest tools.tests.test_learnset_generator tools.tests.test_move_verifier -v
```

The staged verifier reports zero learnset and scalar discrepancies. Its overall exit1 still reflects unresolved mechanics elsewhere in the library; the static inventory also needs capability reconciliation after the new Storm Throw contract is accepted. Do not waive those failures or interpret the data checks as completed gameplay.

## Runtime interface and player choices

`Pokemon.initialMovesFor(species, level)` is for a newly created encounter/gift. It walks eligible events forward into a four-slot FIFO. A currently known duplicate does not reorder slots; a previously forgotten move can reappear at a later event. Level0 evolution/relearn-only records do not enter encounter moves. The returned move list is detached. This behavior follows the primary [PKHeX Learnset implementation](https://github.com/kwsch/PKHeX/blob/d2fea14b563f4b16fef7788b9699b20d5b3f410f/PKHeX.Core/Legality/Learnset/Learnset.cs), specifically `SetEncounterMoves`/`AddMoveShiftLater`. This is implementation evidence, not an original GenV ROM comparison. The same source exposes a different backwards helper, so “last four distinct names” alone would underspecify duplicate behavior.

At level5, normal initialization produces Bulbasaur Tackle/Growl, Charmander Scratch/Growl and Squirtle Tackle/Tail Whip. Ember, Bubble and Leech Seed arrive at level7. Abra knows Teleport; Magikarp knows Splash until Tackle at15 and Flail at30. Source order preserves Bulbasaur's Poison Powder then Sleep Powder at13. The old B/W level-up-only Psychic on Exeggcute and Bite on Vaporeon disappear from the B2W2 level-up projection; both moves remain in the battle library, and future machine/tutor availability is separate.

`gainXP(amount)` preserves the existing boolean first return. Its second result contains `{fromLevel, toLevel, levels, moveChoices}`. It recalculates stats and appends detached learning events without changing chosen moves or PP. Choices carry stable per-instance IDs plus canonical source move IDs/order. Already-known and already-pending duplicates are suppressed. `getPendingMoveChoices()` returns a defensive copy; unresolved choices remain owned by the Pokémon across battle return.

`resolveMoveChoice(id, "learn", slot)` explicitly learns, requiring a slot1–4 replacement when full. `resolveMoveChoice(id, "decline")` consumes a declined offer. Invalid choices do not consume the pending offer. New moves start at full PP; forgotten PP is removed, unrelated PP is preserved, and an already-known resolution does not refill PP. No move-learning menu is wired yet: a battle/session UI owner must consume these choices before this becomes a complete playable learning feature.

`Pokemon.learnsetEntriesFor(species, minimum, maximum)` provides detached source records. `getRelearnableMoves()` is a nonmutating query for eligible unknown moves; it does not enqueue events or implement a relearner. Evolution must preserve the existing Pokémon/move choices and explicitly ask for new-species learning options, rather than reconstruct through `Pokemon(...)`. Evolution/relearning policy, prompts and persistence are not implemented in this slice. Save codecs must preserve `moves`, `pp`, `pendingMoveChoices` and `nextMoveChoiceId`; decoding must not silently replace selected moves with constructor defaults.

## Three required move additions

| Move | GenV scalar payload | Implemented staged behavior |
| --- | --- | --- |
| Charm | Normal/status, power0, accuracy100, PP20 | Defender Attack falls two stages with existing clamp/narration DSL |
| Psywave | Psychic/special, power0, accuracy80, PP15 | Uniform integer50–150 percent of level, floored/minimum1; fixed damage ignores resistance/STAB/crit, respects immunity, records actual HP removed |
| Storm Throw | Fighting/physical, power40, accuracy100, PP10 | Explicit `willCrit` field takes the critical path, including GenV stage handling; variance remains random |

Scalar values come from pinned PokeAPI historical resolution. Behavior is corroborated by [Pokémon Showdown's base moves](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/moves.ts) and its [Gen5 overrides](https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/mods/gen5/moves.ts): Psywave's damage callback plus80 accuracy, Storm Throw forced critical plus40 power, and Charm's Attack reduction plusNormal typing. No existing419 move payload changed to implement these additions. The existing broader fixed-damage/drain/PP/status defects remain outside scope.

Pinned source references/checksums:

- PokeAPI `2bf639e5572812a67d2b94903fdcb9d095f5aeb2`: `moves.csv`, `pokemon_moves.csv`, `version_groups.csv` SHA256s are recorded in [sources.json](../../tools/verify_moves/sources.json) and generator output. Archived scalar history uses `c9cb78bd0a36b33210e697e6cb1b5065bd9fb24a`, as documented in the verifier.
- PKHeX `d2fea14b563f4b16fef7788b9699b20d5b3f410f`: `Learnset.cs` SHA256 `5200eafc0c0065572546bf95a8eed07e9482e2b706c834b514f1b4c3fc3a454d`; B2W2 source class SHA256 `7e2a2f1b3906aea13050e33b7888ce23f20e5befcad74e8daa39f3148f6e5869`.
- Showdown `9b136a8c8cdb860a8ab96fa063f906604e352547`: base `moves.ts` SHA256 `61ab107dae9628d79ac61da16c72e8565f6a1211874298e00c77c5c0ac9755a7`; Gen5 `moves.ts` SHA256 `b7f2146ad3b81a5f17a05fdb87bc3fb9b19e891ac2a44ec8f7b4ca94252e8010`.

## Acceptance status and root handoff

Nineteen offline generator/preservation/failure tests pass, alongside34 verifier tests. SDK compile-only passed at `/private/tmp/pokemon-learnsets-foundation/CompileOnly.pdx`. Metadata regeneration with `--check` passed, the independent staged verifier reports zero data discrepancies, and `git apply --check /private/tmp/pokemon-learnsets-foundation/production.patch` passed. No Simulator was launched by the worker.

The staged `dev/learnsetContracts.lua` exposes `LearnsetContracts.run()`, returning the same `{ok,passed,failed,tests}` structure as the existing contracts. Root must import it into a private identified build after production modules and execute it with the actual SDK. Fourteen cases cover protected starter pairs, Abra/Magikarp, level boundaries, duplicates/same-level order, all151 species at four levels, explicit learning/decline/replacement, PP cleanup, detached choices, multi-level gains/cap, relearning queries, Charm, Psywave variance/immunity/miss/actual damage/player and enemy faint outcomes, and Storm Throw forced critical/stage behavior. Root must rerun the existing contracts and original three-starter intro/rival regressions on the integrated revision. Compilation is not execution evidence. Pending learning UI and save/evolution ownership remain required work.
