# Original151 evolution foundation

Current integrated status: PC/evolution shipped in checkpoint `6b37c78`, with
381 SDK contracts and seven runtime jobs ([evidence](accepted-pc-evolution/acceptance.json)).
The current continuation also resolves old-species learning **during** battle
before the next opponent; the earlier deferral note below is historical.
Four repaired integrated recipes pass, including the actual battle→learning→
evolution flow and120-frame recording, with complete result text inspected.
Specimen Codec5 now preserves nature/ability-slot/held data through evolution;
ability/item effects and the creator-ownership followup remain unfinished.
See [current execution ledger](progress.md) and
[observed evidence](observed-pewter-foundation/evidence.json).

The following records the frozen evolution packet's original design and tests;
its candidate/pending wording describes that historical handoff.

Candidate only: `/private/tmp/pokemon-evolution`. No live Source or Simulator was changed by this worker. Compile03 and the two-file follow-up compile passed; six host tests and full pinned generation checks pass. Original actual SDK evidence `/private/tmp/pokemon-evolution-sdk-01/00001-result.json` reports364 passed/0 failed, including26 evolution groups. The separate follow-up adds one callback regression for27 evolution groups; its SDK/native acceptance remains pending root. Five native recipes are supplied. This foundation does not complete the campaign or establish natural availability of all151 species.

## Primary data and sequencing

`tools/references/evolution.json` pins PKHeX revision `d2fea14b563f4b16fef7788b9699b20d5b3f410f`, its actual Gen5 `evos_g5.pkl` resource, the binary unpacker/method enum, immutable PokeAPI item IDs and behavior files from pokebw2 revision `b279bbefa99bb2f6fbabcc95e4b6d3e939290353`. Every input has a SHA-256 checksum and immutable URL. The generator independently unpacks the16-bit container/8-byte records and filters both source and target to1..151. It produces72 edges:52 level,16 stone and4 trade. It rejects unexpected methods/forms/item IDs/counts instead of silently guessing.

The graph uses the [Gen5 evolution resource](https://github.com/kwsch/PKHeX/blob/d2fea14b563f4b16fef7788b9699b20d5b3f410f/PKHeX.Core/Resources/byte/evolve/evos_g5.pkl), interpreted through [EvolutionSet](https://github.com/kwsch/PKHeX/blob/d2fea14b563f4b16fef7788b9699b20d5b3f410f/PKHeX.Core/Legality/Evolutions/EvolutionSet.cs), BinLinkerAccessor16 and EvolutionType. Original stones map Gen5 item IDs81..85 to stable gameplay `moonStone`, `fireStone`, `thunderStone`, `waterStone`, `leafStone`, independently checked against the pinned item CSV. All existing species/stat/learnset/art IDs remain unchanged. Crobat, Steelix, Espeon/Umbreon and other later species are excluded; no newer CSV-only Linking Cord or regional form rule is imported.

Source behavior is pinned to actual Gen5 code:

- [BattleClient_LearnMoveSeq](https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/ov167/btl_client.c) resolves current-level old-species moves during experience processing.
- [EventBattleReturn_CheckLevelUps](https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/ov166/event_battle_return.c) records actual level increases and iterates each party slot once after battle. Results1/3/5 qualify. [BtlMain_DetermineResult](https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/ov167/btl_main.c) identifies capture5; [BtlClientIDList_GetEscapeResult](https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/ov167/btl_calc.c) identifies player escape3 for this singles scope. Our terminal kinds therefore preserve pending events for victory/run/caught and discard them on defeat.
- [ShinkaDemo](https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/ov284/shinka_demo.c) updates species/dex at completion, then resets its learning index and offers the evolved species' current-level moves. [PokeParty_LearnNextLevelMove](https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/system/poke_tool.c) matches exactly the current level and skips already-known moves; it does not backfill level1/evolution-only moves introduced in later generations.

A correction to the initial design: fainting alone does **not** discard the event in this implementation. The pinned [CheckEvolveSpecies](https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/system/shinka_check.c) has no HP gate for level/item checks. `setChangedPkmSpecies` calls stat recalculation, whose HP0 branch preserves fainting. The original recalled faint restriction was replaced after reading these functions. A qualifying evolution may remain at0HP. Existing local campaign victory+blackout healing is a separate BattleState policy: it heals before progression, which evolution preserves; it is not an evolution revive.

HP increases add the maximum-HP difference. For a maximum decrease the source clamps current HP to the new maximum instead of subtracting the difference; zero stays zero. The species setter preserves XP, moves, PP and status; changes the default name unless nicknamed; and recalculates stats. We follow the existing project stat model (current IV/EV/nature policy), not invented random traits.

## One interface and one owner

`Evolution.candidates(session,mon,trigger)` validates actual owned party membership and returns the eligible target for `{kind="level"}`, `{kind="stone",item=id}` or trade preview. `Evolution.prepare(...)` creates an opaque request. `Evolution.complete(request)` immediately replans/revalidates through `GameSession:evolvePokemon(request)`. `Evolution.cancel(request)` is normal level cancellation; `Evolution.abort(request)` is forced interruption without consuming the level event or stone. Request snapshots are detached primitive records.

The same Pokémon object remains owned by the same Party, with active index, party collection, other members and Inventory object preserved. The atomic session method precomputes the detached validated Pokémon, current bag and dex candidates. Optional stone consumption commits through Inventory:_replaceData; afterward only assignments occur. There are no callbacks/yields/fallible validation after the first assignment. Unrelated money, quest/trainer flags, RNG owner, storage and checkpoint remain untouched. Species/type/type2, derived stats, XP threshold, default name and dex update together; selected move/PP values, XP and major status persist. Explicit nil assignments prevent stale secondary type/status fields from surviving reconstruction.

Only canonical old default names change to the new canonical default. Custom ASCII names survive. The model has no independent nickname bit; exact equality with the old canonical default is the agreed existing convention. No saved nickname is guessed or migrated.

`Pokemon:gainXP` keeps its boolean first return and structured learning result, adding optional durable `pendingEvolution={species,level}` only when an actual level increases to an eligible threshold. High-level constructors/captures never infer a historical event. Repeated gains within one battle update the event to its final level, and only one transformation consumes it. Caterpie5→10 becomes Metapod10 once, not immediately Butterfree. Cancelling consumes that event; another actual level can retry. A forced UI exit leaves the event for resume.

Old-species move choices must resolve before preparing evolution. Completion queues distinct unknown evolved-species current-level moves with reason `evolution`; known moves keep their existing PP, and chosen moves are never silently overwritten. Counter capacity is preflighted before mon/bag/dex mutation. Abra16→Kadabra queues Confusion16, not Kinesis1. Late cancellation then evolution at17 does not backfill Confusion16. Existing queue/source-order rules remain authoritative.

Trade preview supports exactly Kadabra→Alakazam, Machoke→Machamp, Graveler→Golem, Haunter→Gengar. `prepareTrade(session,mon,authorize)` is an explicit external **pure authorization** seam. No default policy, Link Cable, NPC, exchange protocol or natural availability is supplied. Without the hook, prepare rejects `trade-hook-required`. The hook must not perform the exchange or mutate game state; implementing actual trade availability is a later product decision.

## Persistence, native UI and hooks

PokemonCodec4 adds optional pendingEvolution and `evolution` learning reason. It explicitly accepts valid old3 records as absent-pending, preserving names/XP/status/sleep/moves/PP/counters exactly. It never infers old historical evolution from a high level. Old3 records claiming new pending data/reasons reject; earlier unsupported1/2 still reject. Newly encoded records use4. Session/save envelope versions and lossless decimal counter encoding remain unchanged.

Only settled exploration can save through the existing captureSession gate. Active evolution cannot save midway. A forced exit before commit saves the old species plus pending level event, or leaves an unspent stone; after commit, it saves the new species and any pending evolved learning. Continue already calls offerPartyLearning, now a compatibility alias to offerPartyProgression, so pending work resumes before normal play.

The native EvolutionState owns a nested StateMachine (`announce`, `animate`, `result`, `closed`). Existing Dialog renders the same framed typography. Animation advances only in update, uses existing original front images at exact integer2× scale and alternates them over120 updates. No sprite approximation, silhouette generation, asset edit, rule RNG draw, SDK timer or global display transform is introduced. The swap cadence is a presentation adaptation to the established1-bit style, not a claim of cartridge-identical3D effects/timing. A is suppressed during animation; B cancels a level evolution only during that window, and cannot cancel a stone evolution. Result acknowledgement returns to learning or its calling bag/world owner. Exit invalidates the screen and callbacks; covered overlays freeze animation/progression.

Root integration uses the narrow patches, not older full snapshots:

- `patches/domain/gameSession.patch`: append only evolvePokemon; merge with harness trainer/currency extensions.
- `patches/game/context.patch`: offerPartyProgression drains all existing old-species learning, one party evolution, evolved learning, then remaining evolutions; the existing offerPartyLearning(callback) contract remains. Trainer source postbattle/reward dialog callbacks run only after this chain completes.
- `patches/game/battleState.patch`: only the afterBattle terminal gate before restoration; harness's future controller already includes this conditionally, so do not duplicate it.
- BagState routes the five stones through the evolution owner and retains medicine behavior. Visit/session guards make stale party/stone callbacks inert.
- Import/register EvolutionState and dev EvolutionContracts in root-owned main; expose top-level diagnostics.evolution and Pokémon pending_evolution/pending_evolution_level. The private validator inserts these hooks into the current copied Source.
- The item generator changes only the five stone category/effect tags to `evolution`; all prices, medicine values, ASCII labels and sourceName metadata remain exact. The medicine-only Items.use still rejects stone effects, rather than bypassing the transactional evolution owner.

## Reproduction and qualification

`foundation-manifest.json` records exact base/candidate hashes and `patches/` contains separate diffs. Original early-combat staging is unchanged. The validator overlays only owned modules onto **current** Source and compiles by default, preserving current unowned capture/export/world code. Runtime requires explicit `--execute` by root.

```sh
# After installing staged tools/reference/test files in the repo:
python3 -m unittest tools.tests.test_evolution_generator -v
python3 tools/generate_evolution_data.py --cache /private/tmp/evolution-primary --fetch --output /private/tmp/evolutionData.lua
cmp Source/data/evolutionData.lua /private/tmp/evolutionData.lua
python3 tools/generate_items.py --cache /private/tmp/pokemon-items-references --output /private/tmp/evolution-items.lua
cmp Source/data/items.lua /private/tmp/evolution-items.lua
# Root only:
python3 /private/tmp/pokemon-evolution/validate_staged.py --project "$PWD" --output /private/tmp/pokemon-evolution-sdk-01 --execute
```

Pre-integration host commands work with the staged tools and existing staged reference cache. `--check` verifies without writes and exits nonzero for missing/corrupt pins, malformed binary/roster data or output drift. Six host tests cover binary offsets/records, exact graph counts/exclusions, unsupported methods/levels/items, checksum/missing inputs, deterministic rendering, and preservation of every nonstone item plus stone prices/names/scalars. Full immutable-source generation/check passed.

Twenty-six supplied SDK groups cover the complete graph/ownership/art, real level events, one-step evolution, pre/post learning/PP, level cancel and stone abort, malformed/foreign/stale requests, bag replan/reorder, exhausted choice IDs, exact HP/status/name behavior, old3 migration, session JSON pending persistence, trade authorization, battle-result gates, actual campaign win+blackout owner order, HSM update/draw/pause/exit/cancel, exit/reentry callback invalidation and callback-chain completion. The follow-up additionally captures the nested leaf phase so a retained same-visit intro callback cannot restart animation or undo result presentation. Fixtures recruit through GameSession, retain a real starter for nonstarter subjects, set valid intro tuples and validate full SessionCodec data. They do not write raw dex/Party/Storage data to evade production validation.

Five staged native scenarios (pass each with `--scenario PATH --execute`) request real input/captures:

- `evolution-natural-level.json`: explicit Charmander15/XP setup, then an actual winning battle causes level16, old Dragon Rage decision, evolution and unchanged chosen PP.
- `evolution-new-species-learning.json`: Abra16→Kadabra then visible Confusion learning.
- `evolution-cancel-level.json`: B stops the animation, keeps species/moves/PP and consumes only that level event.
- `evolution-stone-bag.json`: native pause→bag→party→Water Stone, B cannot stop, stock remains1 until commit then0, same Eevee becomes Vaporeon.
- `evolution-stone-no-effect.json`: Fire Stone/Squirtle visibly fails and preserves stock.

Before/after and sequential animation recordings preserve actual native image evidence. These are supplementary fixture journeys, not claims of natural access to Abra/Eevee/stones in the unfinished campaign. Runtime results and any acceptance fixes must be recorded by root; compilation does not establish those journeys.

The user explicitly chose to add abilities, held items and natures as the next fidelity work; this proof retains the current model without claiming those additions are implemented. Remaining dependencies: actual trade availability/exchange, held items/Everstone (including its Kadabra exception), IV/EV/nature/ability/gender models, cries/evolution music and physical-device profiling. Original151 requires no friendship/location/gender/stat-branch evolution, so no fake traits were added. The existing learning owner still defers old-species choices until after battle; this slice establishes correct ordering relative to evolution, not a new midbattle-learning UI. Enemy-flee/result4, link/doubles result variants and later-generation species are not mapped to an invented terminal policy.

## Frozen follow-up packet

`/private/tmp/pokemon-evolution-followup-01/followup-manifest.json` pins exactly two overrides against the proved original packet: `game/evolutionState.lua` and `dev/evolutionContracts.lua`. `patches/evolutionState.lua.patch` is the two-line leaf-phase guard; the second patch adds a deterministic retained-callback regression. Original fourteen runtime files remain unchanged. The combined validator reads unchanged files from the original packet, overlays only these two changes, and refreshes all compiled fingerprints.

```sh
# Root Simulator owner only:
python3 /private/tmp/pokemon-evolution-followup-01/validate_staged.py --project "$PWD" --output /private/tmp/pokemon-evolution-sdk-02 --execute
python3 /private/tmp/pokemon-evolution-followup-01/validate_staged.py --project "$PWD" --output /private/tmp/pokemon-evolution-native-level-01 --scenario /private/tmp/pokemon-evolution/scenarios/evolution-natural-level.json --execute
```

Remaining native names are `evolution-new-species-learning`, `evolution-cancel-level`, `evolution-stone-bag`, `evolution-stone-no-effect` under the same original `scenarios/` directory. The controller/session/context patches must be merged narrowly with the pending trainer and PC work; do not copy older full controller/session/context files over those owners.
