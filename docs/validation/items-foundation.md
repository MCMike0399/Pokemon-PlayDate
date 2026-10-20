# Blue items, medicine and shop foundation

Root integrated the domain foundation after 167/167 actual SDK contracts passed
at `/private/tmp/pokemon-items-runtime-01`, including all 25 new item groups.
Bag/shop UI and battle-item turns remain separate integration work.
Historical staging handoff: `/private/tmp/pokemon-items-foundation`.
The selective `items-foundation.patch` adds only `data/items.lua`,
`domain/items.lua` and `dev/itemContracts.lua`; `foundation-manifest.json` records
the exact bytes. Root reviews and executes the SDK cases before acceptance.

## Primary sources and generation

[The source manifest](../../tools/references/item-sources.json) pins URLs and
SHA-256 values for the original Blue data at pokered revision
`af519899719f0754965776faac0e836a3b906e6d`:

- [Symbolic and numeric item/TM/HM IDs](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/constants/item_constants.asm), [display names](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/items/names.asm), [prices](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/items/prices.asm), [TM prices](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/items/tm_prices.asm), [key flags](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/items/key_items.asm) and [referenced mart inventories](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/items/marts.asm).
- [Original effect routines](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/items/item_effects.asm) and [shop operations](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/events/pokemart.asm).

For Gen V medicine values, the manifest separately pins Pokémon Essentials
revision `8c5911e4a4b07b07e832e4bb0d5d8859e88b4a9b`:
[the generation boundary](https://github.com/Maruno17/pokemon-essentials/blob/8c5911e4a4b07b07e832e4bb0d5d8859e88b4a9b/Data/Scripts/001_Settings.rb),
[medicine implementation](https://github.com/Maruno17/pokemon-essentials/blob/8c5911e4a4b07b07e832e4bb0d5d8859e88b4a9b/Data/Scripts/013_Items/002_Item_Effects.rb)
and [confusion cleansing](https://github.com/Maruno17/pokemon-essentials/blob/8c5911e4a4b07b07e832e4bb0d5d8859e88b4a9b/Data/Scripts/013_Items/003_Item_BattleEffects.rb).
This is an independently authored primary implementation, not a claim to have
extracted a B2W2 executable's item table. The generator checks the explicit
pre-generation7 branches; Gen V uses20/50/200 HP potions and50/60/80 HP drinks.
These amounts also agree with the original Blue assembly healing routine.

```
python3 tools/generate_items.py --cache /private/tmp/pokemon-items-references --output /private/tmp/pokemon-items-foundation/Source/data/items.lua --check
python3 -m unittest tools.tests.test_item_generator
```

For a fresh cache, add `--fetch` and omit `--check` when creating the explicit
output file. Every fetched/cached file must match its immutable checksum before
parsing. There is no latest-source fallback. `--check` exits nonzero for drift
and leaves output untouched. No live Source default output exists.

The generator retains124 valid bag items:69 ordinary items,50 TMs and5 HMs.
The 20 supported medicine definitions carry explicit effects. Other legitimate
items remain catalogued with `effect="unsupported"`; owning or trading one does
not imply its effect works. Display names retain Blue spelling; canonical IDs
are stable ASCII. Badges, elevator floors, coins, Safari Balls and the Pokédex
are resources/devices outside the normal bag. Unused Surfboard, ITEM_2C and the
unused ITEM_32 duplicate PP Up are excluded. Excluded ordinary-item symbols and reasons are
recorded explicitly; no glitch IDs are accepted as definitions.

## Catalog and session mapping

`ItemData.definitions` is supplied directly to `Inventory` or to the authoritative
session dependency `itemDefinitions`. `session:inventory()` remains the sole bag
and money owner. These modules never create a second persistent bag.

| Original symbol | Canonical ID | Notes |
|---|---|---|
| POKE_BALL | pokeBall | Catalogued ball; capture use unsupported |
| POTION | potion | Gen V20 HP, Blue price300 |
| OAKS_PARCEL | oaksParcel | Key item; explicit story handoff |
| TOWN_MAP | townMap | Unique key item; map UI unsupported |
| PARLYZ_HEAL | parlyzHeal | Original abbreviation preserved |
| ELIXER / MAX_ELIXER | elixir / maxElixir | Canonical spelling; Blue display spelling retained |
| TM_MEGA_PUNCH / TM01 | tm01 | Blue TM price3000; teaching unsupported |
| HM_CUT / HM01 | hm01 | Distinct HM category; unique and unsellable |

`ItemData.bySymbol` supplies the original-symbol mapping; each definition also
retains `symbol` and `numericId`. Session test placeholder `parcel` must not
become a production alias: production events use `oaksParcel` explicitly.
No save schema or session ownership change is needed merely to provide this
catalog. Future quests atomically pair Inventory key handoff with quest flags
through the session transaction owned by the session worker.

Mart keys retain the primary label with only its first letter lowercased:
`viridianMartClerkText`, `pewterMartClerkText`, `ceruleanMartClerkText`,
`vermilionMartClerkText`, `lavenderMartClerkText`, `celadonMart2FClerk1Text`,
`celadonMart2FClerk2Text`, `celadonMart4FClerkText`, `celadonMart5FClerk1Text`,
`celadonMart5FClerk2Text`, `fuchsiaMartClerkText`, `cinnabarMartClerkText`,
`saffronMartClerkText`, `indigoPlateauLobbyClerkText`.
Unreferenced marts are not exposed. Viridian stocks Poke Ball, Antidote,
Parlyz Heal and Burn Heal; it does not stock Potion. The Route1 gift and Red's
PC Potion remain later event work rather than an invented Viridian shelf.

## Domain API

Import `data/items` and `domain/items` after production Inventory/Pokemon/moves.

- `Items.planUse(id, pokemon, moveSlot?)` returns a fresh detached preview or
  `nil, reason`. It mutates neither Pokémon nor bag and is never a commit token.
- `Items.use(inventory, id, pokemon, moveSlot?)` replans immediately and returns
  `true, result` or `false, reason`. It consumes exactly one item only after a
  valid real effect is established. A stale or edited preview is never accepted.
- `Items.buy(inventory, martId, id, quantity)` validates actual stock, native
  quantity1..99, money and existing Inventory capacity. Successful return is
  `true, {kind="purchase",itemId,quantity,total,money}`.
- `Items.sell(inventory, id, quantity)` checks quantity, stock, sellability and
  money ceiling. Successful return has the same fields with `kind="sale"`.

Preview/use results contain `hpBefore`, `hpAfter`, `hpRestored`, `ppRestored`,
`ppChanges` (slot/move/before/after), status/confusion clearing flags and `revived`.
Targets must be actual coherent production Pokémon; a PP selection is an actual
learned move index, never an arbitrary move key. Ether selects one move; Elixir
selects all. PP is capped at current production `moveData.maxPP`. PP Up remains
unsupported until per-instance PP boost counts and their persistence exist.

Supported medicines: Potion/Super/Hyper/Max Potion; Fresh Water/Soda Pop/Lemonade;
Antidote/Burn Heal/Ice Heal/Awakening/Parlyz Heal/Full Heal; Full Restore;
Revive/Max Revive; Ether/Max Ether/Elixir/Max Elixir. HP/status medicines cannot
revive. Revive heals floor half max HP (minimum1), Max Revive heals all; both
clear status counters. Status cures match the actual major status. Full Heal
and Full Restore also clear confusion; Full Restore may work at full HP when
status/confusion needs curing. PP medicine can affect a fainted target without
reviving it. Healing never changes XP, learned choices or move PP. No-effect
returns `false,"no-effect"` and preserves stock and the target.

There is no asynchronous commit between validation and mutation. Production
Inventory mutators are synchronous and call no observers. Buy prechecks money,
uses atomic `Inventory.add`, then performs a guaranteed debit. Sell prechecks
credit room, uses atomic `Inventory.consume`, then performs a guaranteed credit.
Direct production class methods avoid optional instance callbacks. No failure
can occur after the first successful mutation under these production invariants.
Inventory's existing20-slot/99-stack rules remain authoritative, including its
currently supported overflow-stack behavior. Money is capped at999999; an
exceeding sale fails without removing items. Key items/HMs cannot be sold.
Non-key zero-price items retain Blue's explicit zero-value sale behavior.

Expected failure codes include `unknown-item`, `unsupported-item-use`,
`invalid-pokemon`, `invalid-inventory`, `invalid-move-slot`,
`unexpected-move-slot`, `no-effect`, `invalid-quantity`, `unknown-mart`,
`not-stocked`, `insufficient-money`, `insufficient-items`, `bag-full`,
`unsellable-item` and `money-limit`. Key consumption remains blocked by
Inventory; quest code explicitly calls `Inventory:handoffKey("oaksParcel")`.
A failed or unsupported use never reports successful no-op behavior.

## Validation handoff and remaining work

13 offline fixture tests passed. They exercise catalog/category/mapping,
generation boundary, later medicine-value leakage, missing price/key flags,
unknown mart items, incomplete TM/HMs, changed numeric layouts, checksum/cache/
fetch failures and non-writing drift failure.

25 real-SDK contract cases are authored and compiled. They use actual production
Inventory/Pokemon/move interfaces: heal amounts/caps, matching cures/sleep counter,
fainted/no-effect behavior, Full Heal/Restore, revive rounding, all PP medicines,
move ownership/slot validation, stale preview replanning, missing stock, explicit
unsupported effects, Blue prices/stocks, invalid quantities, bag-full partial
stack rollback, maxmoney, key/HM selling and parcel handoff. There is no fake SDK.
Root must import/register `ItemContracts.run()`; its report is
`{ok,passed,failed,tests}` with actual failure detail. No extra fixture command is
required for these domain cases.

The root-owned helper overlays only the three new manifest files onto current
Source, inserts their imports/contract registration into current main, refreshes
all harness fingerprints/config and compiles. It leaves unrelated current
world/growth/session work intact:

```
python3 /private/tmp/pokemon-items-foundation/validate_staged.py --project /Users/burbujamc/Developer/Pokemon-PlayDate --output /private/tmp/pokemon-items-runtime-01 --execute
```

Without `--execute` it only compiles. That mode passed at
`/private/tmp/pokemon-items-compile-01`. The helper's generated
`items-contract-scenario.json` runs the standard production contracts command.
No Simulator was launched by this worker; root SDK acceptance remains pending.

Bag/menu/shop UI, active battle item command timing, captures, throwing balls,
TM/HM teaching/field actions, evolution stones, vitamins/PP Up, Rare Candy,
repels/escape, quest events and the Route1/PC gifts are not implemented by this
slice. These APIs prepare those flows without claiming a playable bag or a
finished item system/campaign. Generation policies for reusable Gen V TMs versus
Blue item acquisition and original TM numbering need explicit later integration.
