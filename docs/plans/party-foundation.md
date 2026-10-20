# Staged party, storage and inventory foundation

Prepared under `/private/tmp/pokemon-party-foundation/Source/`. These files are not imported by the live game. The existing single-Pokémon battle, GameContext, story, data, artwork, menus and harness build remain untouched. This is a domain foundation candidate, not playable party/storage/item support or a completed save system.

The codebase-design skill's deep-module principles guide the seam: three cohesive Class-based modules own collection invariants behind small interfaces. Callers do not edit member arrays, duplicate transfer logic or reconstruct Pokémon during a transfer. There is no new global game manager or class per data row.

## Source policy

All original-world references below are pinned to pret/pokered commit `af519899719f0754965776faac0e836a3b906e6d`, which supplies the original English Red/Blue implementation. Gen V Pokémon species/stats/moves and the project's artwork are preserved.

| Policy | Original source and staged behavior |
| --- | --- |
| Party six, twelve boxes, twenty per box | [Pokémon data constants](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/constants/pokemon_data_constants.asm). Exact capacities retained. |
| Active box and last party member | [Bill's PC](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/pokemon/bills_pc.asm) tests the current box capacity and blocks depositing a single remaining party member. Staged Storage uses an explicitly selected active box; a full box fails even when others have room. |
| Bag twenty slots | [Menu constants](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/constants/menu_constants.asm) define bag capacity 20 and item-PC capacity 50. This module implements only the bag, not the separate item PC. |
| Stack splitting | [Inventory implementation](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/items/inventory.asm) merges matching item stacks and splits at 99 into further slots. Staged Inventory preserves this: capacity means stack slots, not distinct IDs. |
| Key-item classification | [Item constants](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/constants/item_constants.asm) link item IDs to [key-item flags](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/items/key_items.asm). Integration must supply generated item definitions; the module does not invent a complete item catalog. Key items share the bag capacity. |
| Money | [Money comparisons](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/home/money.asm) and [inventory money handling](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/home/inventory.asm) use three-byte BCD money. A six-decimal-digit limit of 999999 follows from that representation; this is an explicit inference. Staged money starts at zero; new-game initialization chooses its reward/start amount separately. |

Recommended deliberate enhancements, implemented in this candidate: block depositing the last **usable** Pokémon even if fainted party members remain; keep key-item quantities unique at one; generic consumption cannot discard a key item; all capacity/quantity/money failures are atomic. Explicit `handoffKey` supports story exchanges such as Oak's parcel. These choices should enter the fidelity ledger when integrated. No user approval is needed for staging; root should assess the concrete behavior during integration.

Money overflow is rejected unchanged, rather than silently wrapped or capped. A future reward flow must decide how to present an already-full wallet; do not discard a battle reward by ignoring the result. PC transfer currently preserves the exact Pokémon object and its HP/status/PP without healing. Any original-PC healing behavior must be researched and implemented deliberately at the relevant interaction seam before claiming PC gameplay fidelity.

## Interfaces

Every collection index is one-based. Capacity/bounds/restriction failures return `false, reason` for mutations and `nil, reason` for lookup/decode; success returns `true` and sometimes the resulting index. Programmer configuration errors (invalid item definitions) assert during construction. Returned arrays/slot records are copies; returned Pokémon references intentionally remain the actual owned objects so battle damage/progression can operate on them.

`Party()` creates an empty bootstrap party. `add(pokemon)` claims an unowned actual `Pokemon` up to six; full-party failure does not claim it, allowing the capture caller to attempt `Storage:receive` explicitly. `count`, `get(index)`, `members`, `active`, `activeIndex`, `firstUsable`, `allFainted` inspect it. `switch(index)` requires a living member. `swap(a,b)` changes order while retaining the same active Pokémon identity. `healAll()` calls each production Pokémon's `fullRestore`, including status/stages/PP. A fainted active member remains representable until the battle/selection flow explicitly switches it; query methods never heal or switch silently. Empty party has active index zero and `allFainted=false`; a nonempty party with no living members has `allFainted=true`.

`Storage()` creates twelve empty boxes with box 1 active. `selectBox(box)`, `activeBox`, `count([box])`, `get(index,[box])` inspect/select; there is no implicit active-box rollover. `receive(pokemon)` stores a new unowned capture in the active box. `deposit(party,index)` and `withdraw(party,index)` atomically transfer the same object between a party and active box. `move(index,targetBox)` moves within storage. Full/invalid transfers leave both sides and active-box selection unchanged. No release/delete operation exists in this candidate.

`Inventory(definitions)` takes plain immutable configuration `{ itemId = {keyItem=boolean} }` and copies it. IDs must be stable lower-camel identifiers; a generated original-item catalog is a separate dependency. `add(id,quantity)` accepts 1–99 per request and splits/merges stacks across twenty slots. `consume(id,quantity)` removes ordinary items across matching slots; `handoffKey(id)` explicitly removes one key item. `quantity(id)`, `slots`, `count`, `money` inspect. `credit(amount)`/`spend(amount)` accept whole nonnegative amounts through 999999; insufficient funds or overflow leaves the wallet unchanged. It contains no item effects, prices, shops, battle turn costs or UI.

A module-private ownership registry associates each actual Pokémon with exactly one party/storage owner. Collection transfers change ownership without copying or invoking user callbacks. The underscore-prefixed functions on Party are an **internal seam** used only by Storage and collection serialization. Game/UI code must use the public transfer methods. No public removal method can detach a party member and lose it between two independently fallible operations.

## Serialization seam

`Party:toData(encodePokemon)` returns `{version=1,active,members}`; `Party.fromData(data,decodePokemon)` reconstructs it. Storage uses `{version=1,active,boxes}` with exactly twelve dense arrays, each at most twenty. Inventory has `toData()` / `Inventory.fromData(definitions,data)` returning version, ordered slot records and money. Arrays/capacities/indices/quantities are validated before admitting decoded state. Duplicate/previously-owned Pokémon returned by a decoder fail without claiming any other decoded objects. Encoding rejects cyclic/nonprimitive tables and returns fresh primitive records; decoding passes copies into its callback.

The callback Pokémon codec is the deliberate seam with the future authoritative Pokémon serializer. It must serialize actual instance choices/state, then decode a new unowned production Pokémon while restoring saved moves/PP/XP/status and pending learning choices after construction. The staged learnset worker confirmed its additional durable fields are `pendingMoveChoices` and `nextMoveChoiceId`; those belong to the Pokémon codec, not these collection modules. The callback must be pure regarding existing world objects, since the collection cannot roll back arbitrary external callback side effects.

The SDK contract uses a deliberately minimal **test-only** codec (species/level/HP/marker) to verify collection roundtrips and callback isolation. That codec is not a proposed complete save format. No save files, schema migrations, checksums, filesystem writes, world-state persistence, continue menu or corruption recovery are implemented here. Party and Storage data are decoded independently into new objects; an aggregate save loader must decode each Pokémon once and preserve ownership across its full transaction before publishing a new session.

## Root integration and validation handoff

Staged files:

- `/private/tmp/pokemon-party-foundation/Source/domain/party.lua`
- `/private/tmp/pokemon-party-foundation/Source/domain/storage.lua`
- `/private/tmp/pokemon-party-foundation/Source/domain/inventory.lua`
- `/private/tmp/pokemon-party-foundation/Source/dev/partyContracts.lua`

After harness qualification, root can copy these into an owned integration checkout/build and import, after `lib/oop` and `data/pokemon`:

```lua
import "domain/party"
import "domain/storage"
import "domain/inventory"
import "dev/partyContracts"
```

Call `PartyContracts.run()` through the existing SDK contract execution seam and retain its returned `{ok,passed,total,results}` report. Do not add these imports to the currently qualifying live Source until the root explicitly chooses integration. Recompute the identified build fingerprint after staging changes so runtime evidence names the actual source. The worker performed SDK compile-only validation in `/private/tmp/pokemon-party-compile.pdx`; no Simulator was launched and no runtime test pass is claimed.

Eight contract groups exercise actual production Pokémon and these exact modules: empty/full/duplicate parties; invalid indices and zero-HP switching; active identity across reordering; healing all HP/status/stages/PP; last-member/last-usable deposit restrictions; full box/full party/invalid box transfer atomicity; all twelve box capacities; primitive roundtrips, duplicate decode and cyclic-codec failures; inventory splitting, key items, quantity/capacity and wallet failures. The current contract module reports groups individually, allowing root to inspect any integration failure. No Playdate/Pokémon mocks or regex Lua transpilation are used.

Next integration work remains explicit: session ownership in GameContext, active-party battle entry/forced selection, starter/capture routing when full, healing center/PC interactions, party/inventory/storage menus, generated item definitions and effects, actual Pokémon codec, aggregate save publication, and native UI/journey validation. Existing player Pokémon must be adopted exactly once during migration; avoid dual mutable owners (`game.playerPokemon` plus an independent party copy).
