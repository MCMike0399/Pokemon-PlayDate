# NPC trade contract and policy packet

Research: 2026-10-26. **Proposal only; acquisition choices below need approval.**
The [goal](../plans/full-game-goal.md#1-what-we-are-building) fixes English Blue
world/content, Gen V rules/learnsets/individuals, original 151, and **the nine used
NPC trades** (§5.7). Keeping them is settled. No link/network play, extra Pokémon
rewards, or acquisition route for other trade evolutions follows from that decision.
Read against private `57164a6`, with owner additions `61891d7` and `426f7d4`;
report branch starts at `8740e2e`. Cerulean native journeys remain root-owned.

## Exact English Blue inventory

All rows use [TradeMons][table] and the linked map's script/object declarations.
IDs below expand to **`pokered:<MAP>:objects:<n>`**; `i` is the original zero-based
`TRADE_FOR_<nickname>` index and completed-trade bit, **not** a new numbering.
“Wanted” leaves the player; “offered” enters the player party. C/E/H select
CASUAL/EVOLUTION/HAPPY dialogue respectively. Common construction is below.

| i | MAP / n (original actor) | Wanted → offered | Canonical nickname | Text |
|---|---|---|---|---|
| 0 | [ROUTE_11_GATE_2F / 1][r11] (Youngster) | Nidorino → Nidorina | TERRY | C |
| 1 | [ROUTE_2_TRADE_HOUSE / 2][r2] (Gameboy kid) | Abra → Mr. Mime | MARCEL | C |
| 3 | [CINNABAR_LAB_FOSSIL_ROOM / 2][fossil] (Scientist 2) | Ponyta → Seel | SAILOR | C |
| 4 | [VERMILION_TRADE_HOUSE / 1][verm] (Little girl) | Spearow → Farfetch'd | DUX | H |
| 5 | [ROUTE_18_GATE_2F / 1][r18] (Youngster) | Slowbro → Lickitung | MARC | C |
| 6 | [CERULEAN_TRADE_HOUSE / 2][cer] (Gambler) | Poliwhirl → Jynx | LOLA | E |
| 7 | [CINNABAR_LAB_TRADE_ROOM / 2][lab] (Gramps) | Raichu → Electrode | DORIS | E |
| 8 | [CINNABAR_LAB_TRADE_ROOM / 3][lab] (Beauty) | Venonat → Tangela | CRINKLES | H |
| 9 | [UNDERGROUND_PATH_ROUTE_5 / 1][r5] (Little girl) | Nidoran♂ → Nidoran♀ | SPOT | H |

Index **2**, Butterfree → Beedrill / CHIKUCHIKU / H, is an **unused table row**,
not a tenth playable trade. This pinned table contains no Red/Blue conditional:
English Red uses these same trades. Japanese Blue's Graveler/Haunter trades and
Yellow's revised evolution dialogue are historical differences documented in the
[source comments][table], not English Blue inventory. FireRed/LeafGreen names,
fixed IDs and trade definitions do not apply.

## Original transaction and dialogue

[DoInGameTradeDialogue / InGameTrade_DoTrade][engine] test
`wCompletedInGameTradeFlags[i]` first. Already completed goes directly to after
text. Otherwise offer → Yes/No → party selection; No or party cancel uses refusal,
wrong species uses wrong-mon, success prints exchange then thanks. Only exact
species matters: no level, HP, sex, name or move predicate. Flags are independent;
there is no trade-order requirement. The original sets the bit before animation,
removes the selected party member, appends the received one, then checks evolution.
The new owner should commit the flag with the swap, not copy this unsafe ordering.

[AddPartyMon][add] and [WriteMonMoves][moves] determine **every row's** payload:

- Level equals the selected outgoing level; XP is the received species' threshold
  at that level. Moves come from received-species initial moves plus eligible
  level-up moves through that level, skipping duplicates and shifting at four;
  PP starts full. No outgoing moves, XP remainder, damage or training is copied.
- Fresh random two-byte DVs (four 0–15 nibbles; HP DV derives from their low bits [in CalcStat][dv]),
  zero stat experience, fresh stats, full HP and no status. There are **no fixed
  per-row DVs, level, moves or HP numbers**. Playdate must instead use its chosen
  Gen V stat/learnset system; do not transplant Gen I base stats or DV formula.
- Nickname is the exact table string; no naming prompt. OT is the `<TRAINER>`
  control rendered **TRAINER**, not an individual NPC's name ([text expansion][ot]).
  OT ID is two bytes copied from adjacent `hRandomAdd`/`hRandomSub` after `Random`;
  it is not a published fixed ID per trade. It is not guaranteed distinct from
  player ID. Original code supplies no held item (its catch-rate byte is not a
  Gen V held-item reward).
- Source completion is the two-byte `wCompletedInGameTradeFlags` bitset, using
  table indices 0,1,3…9 ([constants][constants], [RAM][ram]). Proposed durable
  session flags: `pokered:trade:TRADE_FOR_TERRY` etc., retaining original index
  metadata; never use trainer-defeated flags or mutable NPC definitions.

[Text recipes][text] are `_WannaTrade{1,2,3}Text`, `_NoTrade{1,2,3}Text`,
`_WrongMon{1,2,3}Text`, `_Thanks{1,2,3}Text`, `_AfterTrade{1,2,3}Text`.
C→1, E→2, H→3. All substitute wanted/received **species names**, not nicknames.
C asks for the wanted species and later praises the old offered mon; E asks a
formal exchange and later says the outgoing mon evolved; H asks whether you have
one and later asks about the offered mon while praising the outgoing one.
No/cancel and wrong-mon remain distinct; thanks and later repeat remain distinct.
`_ConnectCableText` is source flavor and `_TradedForText` is the exchange receipt;
it requires no connectivity. E's post-trade claim is retained source dialogue,
not authorization to evolve or award anything. [The original evolution check][evo]
is a leftover name-prefix test for Graveler/“Spectre”; none of the nine received
species qualifies. No received mon in this inventory has a Gen V trade evolution.

## Current 5.4 boundary and existing owners

`57164a6:Source/data/vermilionPreparation/reservations.json` reserves all four
present trade actors: **Route2TradeHouse objects:2**, **UndergroundPathRoute5
objects:1**, **VermilionTradeHouse objects:1**, **Route11Gate2F objects:1**.
All say source control requires an explicit planner; empty `source_flags` here
means unresolved extraction, not repeatability. They remain reserved in
`61891d7` and `426f7d4`. The Route 2 scientist (objects:1) is ordinary dialogue;
the Route 11 aide (objects:2) is the separate Itemfinder service. The Cerulean
trade house, Route 18 gate and Cinnabar rooms are later activation work.
`61891d7` adds ordinary source effects; that API explicitly forbids transfers.
`426f7d4` concerns grass Cut/catalog work. Neither implements trades.

Existing seams, verified in source (future file ownership requires root assignment):

| Owner | Relevant boundary / proposed change |
|---|---|
| `domain/gameSession.lua` | Sole durable committer. `transact` handles flags/items/money, not party exchange. Add a bounded trade commit; use detached planning as in `purchaseGiftPokemon`, not sequential `recruit` + flag writes. Preserve Day Care/schema 3 and later scene/Pickup/source-effects work. |
| `domain/party.lua`, `storage.lua` | `_owner`/`_claimMany`/`_moveOwner` enforce exact-object ownership. Add one validated internal replacement primitive. `_take` rejects last/last-usable and is not a swap. `recruit` may overflow into selected PC box; it is inappropriate here. No Storage changes needed for party-only exchange. |
| `domain/specimen.lua`, `individualStats.lua` | Factory has wild/starter/trainer/gift/debug, no trade origin. Extend explicitly after approval; no live RNG during preview. Existing normal acquisition has normal ability slot, nature, sex and six IV samples, zero EVs; no hidden ability. |
| `domain/pokemonCodec.lua`, `sessionCodec.lua` | Nested Pokémon v7 allows `name` but no OT/trade provenance; rejects unknown fields. Add bounded validated metadata and migrate without rerolls. Session schema 3 includes Day Care: do not regress it. |
| `domain/growth.lua`, `data/pokemon.lua` | Current scaled XP is unboosted/original OT. No outsider input. Add any approved modifier at the native post-scaling step, with integer-safe rounding and award cap. |
| `domain/evolution.lua`, `teaching.lua` | `prepareTrade` requires explicit authorization; trade evolution cannot be cancelled. Teaching's private request, exact object, codec snapshot and single-use resolution are a useful pattern. Do not manufacture learning/evolution events for the outgoing mon. |
| `game/eventState.lua`, source event planner/data | Future bounded trade-selection overlay should pass intent to owner; map scripts/UI never construct awards or write flags. Root owns dispatcher/import registrations. |
| `game/saves.lua`, `context.lua` | Existing two-slot publication and settled-exploration capture exclude overlays. Keep that boundary; no persisted half-trade or request tokens. |

Naming remains release work (§5.7): store canonical nickname in existing `name`
and minimal immutable provenance `{kind=npc-trade, sourceId, tradeIndex,
sourceRevision, otName=TRAINER, otId}` in a versioned codec field. Future nickname
editing changes display name only. Do not add a naming screen or player identity
system to this packet; source NPC labels are not OT names.

## Choices for root to present, with concrete recommendations

These are **recommendations, not an approved acquisition policy**. The goal fixes
species, nine locations/actors, one-time exchange, source names/dialogue, original
151, and Gen V mechanics. It does not resolve the following acquisition bridges.

| Choice | Recommended behavior | Concrete alternative / consequence |
|---|---|---|
| Incoming enhanced traits | New `npc-trade` normal Gen V specimen: sample ability slot/nature/sex/six independent IVs as gifts do; zero EVs, no held item. Independently sample a 16-bit source OT ID once before those nine API draws on a detached rules stream. Preserve actual raw RNG counters. No preview/cancel draws commit. | Explicit fixed Gen V trait preset, published per trade, with no trait RNG. Requires user-approved values; source contains no such presets. Never copy outgoing genotype or invent fixed “Blue” IVs. |
| Outgoing held item | Reject a holding mon before confirmation; ask player to use existing Take action, which can fail on full bag. Trade stays available. | Explicitly confirm that the item leaves with the offered object permanently; no bag refund. Or atomically return it to bag and reject on capacity. Blue cannot choose among these enhanced behaviors; none permits silently deleting/refunding it. |
| Outsider / OT semantics | New NPC trades carry explicit local-language outsider provenance; apply native 1.5× XP. Store randomized 16-bit source OT ID plus TRAINER for provenance; outsider status must not be inferred from a nickname or random ID inequality alone. Older mons get neutral/unknown provenance with unchanged XP behavior. | Record source provenance now but defer outsider XP with an explicit fidelity deviation; or add full player OT identity and native comparison, a larger naming/identity packet. Do not label neutral legacy mons as historically traded. |
| Trade evolutions / accessibility | Keep the existing guarded hook; these nine exchanges trigger no player-owned trade evolution. Ask separately how Alakazam/Machamp/Golem/Gengar should become obtainable offline; offer a specified service only after approval. | A deliberate offline evolution service needs its location, eligibility, price/item, cancellation and repeat policy approved. No extra NPC trade or returned/evolved outgoing reward is implied. |
| Later-species evolution targets | Enforce original151: no Politoed/Slowking/Steelix/Scizor/Kingdra/Porygon2 or other later target, even with a qualifying held item. No item consumption for blocked targets. | Expanding roster would revise the fixed goal; it is not part of keeping the nine trades. |

Native B2W2 [XP source][bw-xp] (`b279bbefa99bb2f6fbabcc95e4b6d3e939290353`)
checks `IsTrainerOT` after level scaling and applies Q12 `fixed_round` with
`0x1800` for local outsiders, `0x1b33` for a different region/language, then item
modifiers and the 100000 cap. Do not substitute an arbitrary floor(award×1.5)
or invent foreign-language NPCs. The [native evolution contract][bw-evo] has a
trade mode, partner input and Everstone suppression. Its [field-trade structure][bw-offer]
has explicit IVs, OT, nickname and held-item fields: B2W2 offered items are content
inputs, not permission to add them to Blue. That header alone does **not** prove
outgoing held-item disposition; no native transfer implementation was qualified
here. An exact B2W2 transfer claim would require a separate primary algorithm pin.

## Bounded implementation and acceptance packet

1. Pure offer lookup resolves one stable actor and original trade index. Prepare
   an ephemeral, one-shot request bound to session identity, field/scene context,
   party identity, selected **object and slot**, full codec snapshot, completion
   flag and rules RNG snapshot. Reject wrong species, non-party ownership or
   pending learning/evolution. Dialog/selection/cancel mutate no durable state.
2. Confirm rechecks every captured condition; reorder, deposit/release, changed
   HP/item/moves, changed session/zone, another trade, stale RNG or completed flag
   rejects before mutation. Retire request on cancel/commit; terminal stale
   requests require fresh selection. Never select a replacement by species search.
3. Build/validate incoming object, nickname/provenance, approved traits, full HP,
   no status, species-threshold XP and **B2W2 last-four eligible distinct moves**
   with full PP on detached state. Validate codec, ownership transition, flags,
   dex seen/owned and any approved bag/item plan before touching live state.
4. One session commit swaps exactly the selected object, updates ownership,
   completion flag, Dex and RNG together, with no yield/callback/fallible work
   between writes. Recommend retaining its slot and active index (source appended;
   document this small ordering deviation). All other object identities/attributes
   remain unchanged. Six-party/full-PC succeeds because count stays constant;
   one-member/last-usable succeeds with the healthy replacement. No overflow,
   temporary empty party or dependence on free PC capacity.
5. Replays/duplicate callbacks cannot pay twice. No save during offer/animation;
   Save after settled completion captures swap+flag+provenance+RNG together.
   Quit before saving resumes the previous complete snapshot. Failed publication
   retains the prior valid disk slot and a coherent completed in-memory session;
   retry saves it. Never promise crash persistence before Save succeeds.
6. Migration preserves all pre-existing names, HP/status, XP/queues, nature,
   ability/sex, IVs/EVs, held items, ownership and both RNG streams. Add only neutral
   absent provenance; no historical trade receipts, flags, IDs or random samples.
   Root's SDK checks should cover duplicate/stale/cancel, full party/PC/bag,
   last-member, exact-object duplicates, both successful and failed saves, and
   real process Continue after all nine independent flags. Root alone runs native
   execution and natural journeys; host checks must never emulate Lua/SDK.

## Pins, host checks and limits

`python3 tools/check_npc_trade_policy.py --source <pokered-git-checkout>` reads
immutable Git blobs at the full pin, checks ten rows/nine used mappings through
script text pointers and original object indices, and emits inventory plus SHA256.
Passed locally against the existing checkout, including a complete script-usage
scan and three rejected corruptions (used row, unused row, object/text mapping).
It downloads nothing and executes no Lua. Primary SHA256 values:

| File | SHA256 |
|---|---|
| `data/events/trades.asm` | `e3c374712f6eb119bda9097d1d08ffdb9447b1691b4f8b3e9042fde4c5563fb4` |
| `engine/events/in_game_trades.asm` | `4d96264f01a6888e5fd1d5faaaf9997691b0a05bf6f178d4283a1fcb7860afae` |
| `engine/pokemon/add_mon.asm` | `4a0c02fbbfdd6dc1e9357069be2b4b94342777de94efb2a67bd4e25ca62bddfe` |
| `data/text/text_7.asm` | `8fcfc31197c3c75c248474eab47378573ffb4546406cc957c7e913cf0eb07cfe` |
| native `btl_server_flow_sub.c` | `224b984bfeb441a1761cb82cf11447b2507beda8a6e5644d1bbbf19cd9f9736a` |
| native `include/pml/evolution.h` | `1957dfcb6739bf39f1ee024a1e4597b6e5b06b132ba5321a36f3582d5cd410d1` |
| native `include/field/fld_trade.h` | `a8a38c04207505992e0091555076f9bd8d300eaaa43b1fc62546ba06e68d0742` |

No game implementation, native acceptance, source-data activation or ledger claim
is made. Blocking decisions: enhanced acquisition/OT/outsider/item policy; later
offline trade-evolution accessibility is a separate product question. Existing
reserved content and Gen V metadata gaps are implementation work after approval.

[table]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/events/trades.asm
[engine]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/events/in_game_trades.asm
[add]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/pokemon/add_mon.asm
[moves]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/pokemon/evos_moves.asm#L383
[evo]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/engine/events/evolve_trade.asm
[text]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/text/text_7.asm#L56
[constants]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/constants/script_constants.asm
[ram]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/ram/wram.asm#L2122
[ot]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/home/text.asm#L180
[r11]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/Route11Gate2F.asm
[r2]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/Route2TradeHouse.asm
[fossil]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/CinnabarLabFossilRoom.asm
[verm]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/VermilionTradeHouse.asm
[r18]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/Route18Gate2F.asm
[cer]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/CeruleanTradeHouse.asm
[lab]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/CinnabarLabTradeRoom.asm
[r5]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/scripts/UndergroundPathRoute5.asm
[bw-xp]: https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/src/ov167/btl_server_flow_sub.c#L562
[bw-evo]: https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/include/pml/evolution.h
[bw-offer]: https://github.com/fuddlesworth/pokebw2/blob/b279bbefa99bb2f6fbabcc95e4b6d3e939290353/include/field/fld_trade.h

[dv]: https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/home/move_mon.asm#L109
