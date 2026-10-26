# Pickup policy choice — proposed, not approved

2026-10-26. Research only, on `wip/pickup-policy`. Read the full-game goal,
progress and exact audit `edba4e5ad8f007dc8eb560098935d074dc64c891`.
The audit's private 5.4 candidate is `bad58824b0db68344ebfb11dd5ec22f5fe4ad613`;
ordinary Route 5/6 Meowth can have Pickup (53). Deliberately adding Gen V
abilities/natures/held items did **not** approve a new Kanto loot economy.

## Recommended choice A: explicitly approve the native B2W2 field table

Use the complete table below, its native eligibility and 10% chance, without
substitution, level caps, rerolls, or probability changes. This is a **proposed
Kanto acquisition extension**, not a correction to original Blue rewards.
It adds renewable medicine, money, candy and stones, plus six currently undefined
items. King’s Rock is possible from level 11, so this is an ordinary progression
decision. Root should present this scope to the user before seeking approval.

If approved, a separate implementation must add the missing definitions,
safe held-item/save/transfer support and applicable effects before exposing them.
Holding medicine does not automatically use it. Unsupported manual uses must
remain explicit failures; King’s Rock flinch, Iron Ball speed/grounding and
Leftovers healing require actual hooks. Sun Stone/Prism Scale have no evolution
target among the original 151; Heart Scale does not authorize a new move tutor.
Keep existing Blue prices and item-use/access policies unless separately changed;
this would be an intentional hybrid economy, not full B2W2 economy fidelity.
Record the acquisition extension and retained Blue economy in the fidelity ledger
only after approval; this research does not edit it.

**Until approval and implementation:** at an eligible ordinary-win callback with
at least one legal, empty-handed Pickup party member, show e.g.
“MEOWTH’s Pickup: But it failed!” and record an ability-53/post-battle-policy gap
with holder/outcome context. Do this at the callback, before a chance roll; do not
pretend a missing implementation was a legitimate 90% miss. Award no item, change
no held slot and consume no Pickup RNG. Held-item-ineligible members and excluded
outcomes must not produce this warning. This gate is proposed, not implemented.

**Reasonable alternative B:** deliberately exclude field-generated Pickup loot
from this Blue recreation. Retain the same visible callback failure/dev gap as
an explicit policy deviation; add no loot items or replacement probabilities.
This preserves existing acquisition, but knowingly leaves an obtainable ability’s
field effect unavailable. Battle item recycling remains a separate Gen V mechanic
to implement when exposed. Do not silently disable Pickup or replace it with
Technician. A supported-items-only table would be a third, custom balance policy,
not B2W2 fidelity; it is not recommended here.

## Native eligibility and selection

The pinned [return caller][caller], [selection function][selection] and
[linked tables][return] establish:

- Only field battle types 0 (wild) or 1 (trainer), with result **1 (win)**, call
  `EventBattleReturn_PickupItems`. Capture result 5, loss, player escape and enemy
  escape do not call it. The [result writer][main] and [escape result mapper][calc]
  distinguish these outcomes (escape returns 2/3/4, not 1).
- Iterate the current player party in slot order. Each legal nonzero, non-egg
  species with stored ability 53 and held item 0 gets its own `RandomLC(10)==0`
  check: **10% per eligible member**. There is no HP, participation, lead-position
  or victory-credit test: fainted and unused party members qualify. Boxed Pokémon
  do not. Existing held items block the roll, even inert medicine.
- On success only, draw `RandomLC(100)`. Use band
  `min(9, floor((currentLevel-1)/10))`: 1–10, 11–20, …, 91–100. The caller copies
  the battle party back before this step; evolution demos occur later. Use the
  member’s resulting level, not encounter level or opponent level.
- Common cumulative cutoffs are 30/40/50/60/70/80/90/94/98. Rolls 99 and 98 use
  rare entries `band` and `band+1`, respectively. The award goes directly to the
  Pokémon’s **held slot**, not the bag. A full bag cannot block that award; later
  taking the item must use the existing atomic bag-capacity check.

These are findings from the pinned native reconstruction, not ROM execution
claims. Do not broaden the win-only gate from an unpinned recollection.

## Exact full B2W2 table

Cells are **native Gen V item IDs**, resolved through [generated constants][ids],
not Blue `ItemData.numericId` or PokeAPI IDs. Column probabilities are conditional
on the 10% success. Thus 30/10/4/1% columns mean 3/1/0.4/0.1% per eligible member
per qualifying battle; 90% gives nothing. Add probabilities for repeated IDs:
level 1–10 Hyper Potion totals 5% conditional, 0.5% unconditional.

| Level | 30% | 10% | 10% | 10% | 10% | 10% | 10% | 4% | 4% | 1% | 1% |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1–10 | 17 | 18 | 26 | 3 | 79 | 78 | 27 | 25 | 2 | 25 | 92 |
| 11–20 | 18 | 26 | 3 | 79 | 78 | 27 | 25 | 2 | 28 | 92 | 221 |
| 21–30 | 26 | 3 | 79 | 78 | 27 | 25 | 2 | 28 | 50 | 221 | 23 |
| 31–40 | 3 | 79 | 78 | 27 | 25 | 2 | 28 | 50 | 80 | 23 | 38 |
| 41–50 | 79 | 78 | 27 | 25 | 2 | 28 | 50 | 80 | 81 | 38 | 278 |
| 51–60 | 78 | 27 | 25 | 2 | 28 | 50 | 80 | 81 | 93 | 278 | 537 |
| 61–70 | 27 | 25 | 2 | 28 | 50 | 80 | 81 | 93 | 23 | 537 | 40 |
| 71–80 | 25 | 2 | 28 | 50 | 80 | 81 | 93 | 23 | 29 | 40 | 537 |
| 81–90 | 2 | 28 | 50 | 80 | 81 | 93 | 23 | 29 | 51 | 537 | 234 |
| 91–100 | 28 | 50 | 80 | 81 | 93 | 23 | 29 | 51 | 41 | 234 | 537 |

## Every candidate versus present support

Checked the private audit candidate and this branch’s base `6cad2b7`.
[ItemData](../../Source/data/items.lua), [holdable IDs](../../Source/data/specimenData.lua),
[specimen validation](../../Source/domain/specimen.lua), [inventory](../../Source/domain/inventory.lua)
and [manual medicine owner](../../Source/domain/items.lua) are identical between
those revisions. “Yes” below means bag storage and validated held-slot storage/
Give/Take/save support, **not automatic held behavior**. All 19 existing candidates
are inert while held, as expected for these ordinary items. The only current
held battle effect is Light Ball, which is **not** a Pickup table item.

| Gen V ID | Item / current key | Bag + held storage | Implemented use / remaining gap |
|---|---|---|---|
| 17 | Potion / `potion` | Yes | Manual HP healing |
| 18 | Antidote / `antidote` | Yes | Manual poison cure |
| 26 | Super Potion / `superPotion` | Yes | Manual HP healing |
| 3 | Great Ball / `greatBall` | Yes | Battle capture owner |
| 79 | Repel / `repel` | Yes | No active repel producer; unsupported use |
| 78 | Escape Rope / `escapeRope` | Yes | FieldItems escape transaction; location restrictions apply |
| 27 | Full Heal / `fullHeal` | Yes | Manual status/confusion cure |
| 25 | Hyper Potion / `hyperPotion` | Yes | Manual HP healing |
| 2 | Ultra Ball / `ultraBall` | Yes | Battle capture owner |
| 28 | Revive / `revive` | Yes | Manual half-HP revival |
| 50 | Rare Candy / `rareCandy` | Yes | Level-up use unsupported |
| 80 | Sun Stone | **No definition** | No original-151 evolution target |
| 81 | Moon Stone / `moonStone` | Yes | Evolution owner; eligible species only |
| 93 | Heart Scale | **No definition** | No scale-for-relearning service |
| 23 | Full Restore / `fullRestore` | Yes | Manual HP/status/confusion recovery |
| 29 | Max Revive / `maxRevive` | Yes | Manual full-HP revival |
| 51 | PP Up / `ppUp` | Yes | PP-increase use unsupported |
| 41 | Max Elixir / `maxElixir` | Yes | Manual full PP restoration for all moves of one Pokémon |
| 92 | Nugget / `nugget` | Yes | Sell transaction; no manual use needed |
| 221 | King’s Rock | **No definition** | Held flinch missing; later-species trade evolutions outside roster |
| 38 | Ether / `ether` | Yes | Manual one-move PP restoration |
| 278 | Iron Ball | **No definition** | Held speed/grounding missing |
| 537 | Prism Scale | **No definition** | No original-151 evolution target |
| 40 | Elixir / `elixir` | Yes | Manual all-moves PP restoration |
| 234 | Leftovers | **No definition** | Held residual healing missing |

Additional static support checks: [capture](../../Source/domain/capture.lua),
[evolution](../../Source/domain/evolution.lua), [field items](../../Source/game/fieldItems.lua),
[bag routing](../../Source/game/bagState.lua), [held effects](../../Source/battle/effects.lua)
and [Give/Take owner](../../Source/domain/gameSession.lua). Existing unsupported
manual uses are not evidence that their real effects are implemented.

## Battle Pickup is separate

Pinned Showdown `9b136a8c8cdb860a8ab96fa063f906604e352547`
[Pickup callback][ps] (base → gen8 → gen7 → gen6 → gen5) runs at residual order
28/suborder 2: an empty-handed active holder retrieves a randomly selected adjacent
battler’s last item actually used that turn. This supplies **no field loot table**.
In the current singles exposure the other battler is the opponent. Approved wild
Pikachu Light Ball acquisition does not consume its item; ordinary held medicine
does not auto-consume. Hence the audit identifies no ordinary current producer
for battle recycling. Do not infer berries or other acquisitions from this hook.

## Pins, checks and limits

All native links below use `pokebw2 b279bbefa99bb2f6fbabcc95e4b6d3e939290353`.
SHA-256 (first two already pinned by existing evolution/traits manifests):

| Native file | SHA-256 |
|---|---|
| `src/ov166/event_battle_return.c` | `6165ec0229b0c67201e489226b9ae215aaf1bd5fa69fbdf441943ca730adc68e` |
| `generated/items.txt` | `565a8abd48d786bd166f3c93b522644b7a4a1aacfc54b329767a84c7c84f7f23` |
| `src/ov167/btl_main.c` | `4a94eb399501b1eda6cd1fce05870eec9e481296bdd1bfc7904a5cd159d7b9dc` |
| `src/ov167/btl_calc.c` | `7a85311212044df299b64ebe9de1996c1ac3a736a591217973c4cf0e71b6ba17` |

Host checks: exact native Git pin and file hashes; extracted all 110 table cells
from the linked arrays and checked probability totals; cross-checked all 25 IDs/
names against existing pinned Gen V item-index CSVs; verified the five Showdown
ability-chain hashes; statically compared all candidate storage/use/held support.
No table entries or eligibility facts remain unresolved within these pinned
sources. User acquisition-policy approval and implementation remain open.
No ROM rebuild, Lua emulation, SDK/Simulator/runtime, visual or campaign validation
was run. No production code, world data, imports, ledgers, coverage or baselines
were changed; no push or further delegation. This document grants no approval.

[return]: https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/ov166/event_battle_return.c#L90-L108
[caller]: https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/ov166/event_battle_return.c#L177-L204
[selection]: https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/ov166/event_battle_return.c#L396-L431
[ids]: https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/generated/items.txt
[main]: https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/ov167/btl_main.c#L3443-L3463
[calc]: https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/ov167/btl_calc.c#L766-L786
[ps]: https://github.com/smogon/pokemon-showdown/blob/9b136a8c8cdb860a8ab96fa063f906604e352547/data/abilities.ts#L3263-L3282
