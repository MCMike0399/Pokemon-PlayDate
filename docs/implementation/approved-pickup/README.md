# Approved B2W2 Pickup implementation

Private base: `e4dd1701caa28c69b90788fe77ea3b290735b7b7` (65-map Vermilion root).
Branch: `wip/approved-pickup`. The user's explicit choice approves the unchanged
proposal at `e826d0a:docs/research/pickup-policy.md`; that report's historical
"proposed" heading does not revoke the subsequent approval.

## Implementation

`Source/data/pickupData.lua` is generated from checksum-pinned native arrays and
item identities. All 110 cells and 25 identities are retained. Its six additive
item definitions use historical Gen V prices: Sun Stone 2100, Heart Scale 100,
King's Rock 100, Iron Ball 200, Prism Scale 500, Leftovers 200 (sell for half).
The existing generated Blue catalog, shops, prices and item-access policy are
unchanged. Native IDs and PokeAPI held-whitelist IDs remain distinct.

`domain/pickup.lua` binds a disposable receipt to the actual admitted Battle,
session and party. Only its confirmed `emitEnd` callback can resolve it. Wild
field type 0 and trainer field type 1 admit the receipt; only `victory` (native
result 1) rolls. `caught`, `run` (player/enemy escape) and `defeat` do not roll.
Party iteration retains physical slot order, includes fainted and unused members,
excludes boxes and requires the stored Pickup ability and an empty held slot.
The 0..9 gate succeeds on zero; only success draws 0..99. Current resulting
level determines the band; native rare roll 99 uses rare[band], 98 uses
rare[band+1]. The normal terminal hook flushes XP first and runs Pickup before
evolution. Holding medicine remains inert.

The session commits a detached RulesRNG continuation and primitive held-slot
assignments synchronously. Bag capacity is irrelevant. Party, Pokémon, inventory
and storage identities remain intact. Planning failure commits no award or RNG
change; the consumed battle receipt prevents a reroll. Receipts are not persisted
or reconstructed on Continue. Existing string-held codecs validate the added
whitelist entries without changing Pokémon or session versions; schema 3 Day Care
and field/world owners are untouched.

`battle/pickupHeld.lua` contains the held callbacks. King's Rock uses the existing
Stench typed-secondary path, once per supported actual damaging hit (including
multi-hit and fixed hits), with no stacking with Stench or an existing flinch.
Shield Dust and Inner Focus retain their actual gates. Iron Ball halves effective
speed, grounds the active holder and bypasses Levitate. The pinned Showdown
Flying-holder Ground effectiveness is neutral, including another type; the
necessary two-line `Battle:typeMatchup` seam preserves that distinction from
merely removing Flying. Leftovers heals through `Pokemon:heal` at order 5,
suborder 4 in the existing residual cohort, with active/living/one-event guards.
No alternate battle, HP, reward, session, RNG or evolution owner was introduced.

## Integration ownership

Cherry-pick this branch onto the private 65-map root. Do not integrate into the
frozen 30-map Cerulean journey Source. Then review and apply:

```sh
git apply docs/implementation/approved-pickup/root-bootstrap.patch
```

The unapplied patch adds exactly two production imports, the `pickup` SDK suite
registration/import, and the corresponding ordered-import fixture entries.
`Source/main.lua`, `tools/harness/dev_imports.lua` and that fixture remain
unmodified on this worker branch. The patch is required before runtime use.

Existing Source ownership changes are limited to:

- `domain/gameSession.lua`: bind/resolve methods and atomic held-slot commit.
- `game/battleState.lua`: bind admitted field battle; resolve after rewards and
  before evolution; retain the primitive report in `lastBattleOutcome.pickup`.
- `battle/effects.lua`: held speed, grounding/immunity and residual callbacks.
- `battle/contactAbilities.lua`: combine King's Rock with the existing typed
  Stench secondary without stacking.
- `battle/battle.lua`: two-line effectiveness override seam for Iron Ball.

New Source files are `data/pickupData.lua`, `domain/pickup.lua`,
`battle/pickupHeld.lua` and `dev/pickupContracts.lua`. There are no edits to map
manifests/caches, ledgers, coverage, protected art or baselines.

## Verification and prepared bodies

Passed: **45 host tests, no skips**, in these six modules:

```sh
python3 -m unittest tools.tests.test_pickup_data \
  tools.tests.test_specimen_generator tools.tests.test_specimen_traits \
  tools.tests.test_item_generator tools.tests.test_contact_ability_sources \
  tools.tests.test_field_acquisition_sources -v
python3 tools/generate_pickup.py --check
```

These validate primary bytes, the exact 110-cell matrix, 25 identity crosswalks,
historical prices, native selection/gating, inherited Showdown gen5 callbacks,
existing generators and negative source mutations. They execute no Lua.

SDK **3.1.2 production and prepared harness compilation passed**. The final
compile-only composition is retained at:

`~/Developer/Pokemon-PlayDate-env/evidence/approved-pickup-compile-20261026-03`

Original Source SHA-256:
`5a1dbc9e548012c2bd368b38317d824ddda41c9d97d801f25467b10088eef7ca`.
Composed Source SHA-256:
`49bc2cf91c59a96e69c26263a1b57f1ceadcf96abcfccf003bda95ffd9cd8efd`.
The import/registration order was also compared exactly to the patched fixture.
Reproduce compilation, without any runtime, using a fresh durable output:

```sh
python3 tools/prepare_pickup.py --output <new-durable-directory>
```

**42 real-SDK cases are prepared, not executed.** Their bodies cover all 100
selection rolls at both boundaries of every band; invalid bounds; wild/trainer
wins; excluded outcomes; success-only selection; party order, fainted/unused,
held/box exclusions; full-bag award and atomic Take retry/Give; actual faint XP
crossing level 10→11; exhaustion after a detached award with both RNGs and all
identities unchanged; replay/rebind and Continue rejection; foreign/premature/
inactive owners; each new item's Give/Take, PC Pokémon storage and SDK JSON
roundtrip; actual isolated SaveStore reload of all six held IDs and both RNGs;
ordinary BattleState terminal integration; successful flinch, multi-hit chance
counts, Stench/native-flinch nonstacking, Shield Dust/Inner Focus, absent/status/
closed hooks; Iron Ball actual Ground hit/Spikes/speed/type/Levitate/lifecycle;
Leftovers actual ordered healing-before-poison, clamping, event replay,
fainted/withdrawn/closed exclusions, and held-medicine absence.

Root must apply the registration patch, run the real contracts on its integrated
candidate, inspect outcomes and perform any needed ordinary acquisition/Save
journeys. Compilation and host success do not certify these runtime bodies.
No Simulator, runtime, device, push or delegation occurred in this worker task.

## Remaining conditional gaps

Battle Pickup recycling is explicitly recorded as `no-item-consumption-producer`
in the terminal report. There is no berry/Fling/Trick or item-suppression producer
added to fabricate it. Sun Stone and Prism Scale have no original-151 evolution
target; Heart Scale adds no tutor. Manual uses of all six entries explicitly
return `unsupported-item-use`. Existing unsupported uses and field access
restrictions remain unchanged. Root owns fidelity/coverage/ledger updates and
independent native acceptance.
