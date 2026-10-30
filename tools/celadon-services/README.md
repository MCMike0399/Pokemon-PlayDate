# Celadon services — first incremental packet

Merged exact root `49a7135`; implementation preparation only. Root retains all shared
owners, native execution and acceptance. Only new modules/data/generator/checks
are added. Ordinary Department Store clerks, TM18, Coin Case gift, art and the
field worker's MidgameServices files are unchanged.

Import game/celadonServices and game/celadonServicesController, then after ordinary
content registration call:

```lua
CeladonServices.install({reconcileActors=KantoScenes.reconcileActors})
```

Default descriptors use named content celadonServices and its pinned text resolver
inside the SAME SourceEvents registry. Root can instead merge descriptors(content)
into an existing named registration, register that content's text resolver and
pass the same content name to install. No second event dispatcher or state is
created. Append CeladonServices.actorMetadata(id) to the existing metadata resolver
for Eevee's persistent original object toggle.

Root's existing final MidgameServices controller delegates enter BEFORE parent
enter, advance/handleButton BEFORE parent methods and draw AFTER parent draw:

```lua
CeladonServicesController.enter(self)
if CeladonServicesController.advance(self) then return end
if CeladonServicesController.handleButton(self,button) then return end
CeladonServicesController.draw(self)
```

Call each from the corresponding method; do not put the four lines together in
one lifecycle method. Existing parents keep every other event. The new menu phase
is celadon-menu; vending options are FRESH WATER ¥200, SODA POP ¥300, LEMONADE
¥350, CANCEL. Coin sale is YES/NO; girl's second menu contains only drinks actually
in the bag, in original Water/Soda/Lemonade order. All callbacks use the inherited
context/epoch guard, with one shared selection guard for A and B.

Root applies root-session-methods.lua inside GameSession's private scope. It
requires the existing CoinWallet schema 4 field and coins() getter from the Safari/
coin packet. No further codec change is needed. commitCeladonService(operation,
observation) prepares canonical data-defined offers on detached owners and commits
bag/money/coins/flags together. Prices/rewards are selected by bounded source
indices, never caller-supplied quantities/payouts. The same small hook includes
prepared prize support for the next packet; its UI is not registered here yet.

First packet reserved IDs:

- CELADON_MART_ROOF background_events:1..3: the three original vending positions.
- CELADON_MART_ROOF objects:2: drink girl (actual moving source actor).
- CELADON_MANSION_ROOF_HOUSE objects:2: immediate Eevee level 25 gift.
- GAME_CORNER objects:2: ¥1000 for 50 coins; actual Coin Case required.
- GAME_CORNER objects:5/9/10: original10/20/20 coin gifts and original once flags.
- GAME_CORNER objects:7: source conditional Erika dialogue.

All IDs have pokered: prefix. These were reserved, not ordinary registered clerks.
Eevee uses existing price-zero purchaseGiftPokemon. Only successful party/selected
box acquisition sets CELADON_SERVICES_V1_EEVEE_TAKEN, representing the source object
toggle. Full selected box leaves it retryable with no flag/RNG claim. There is no
new nickname UI; the existing naming limitation remains explicit.

Source economic details are preserved: AddBCD saturates coins at 9,999. Coin sales
refuse at or above 9,990, including though some lesser balances saturate after adding 50. The
Gentleman's source check is equality with 9,990, unlike the other gifts' >=9990 check.
Vending displays exact200/300/350 prices but source checks only 200 for all three;
SubBCD clamps atzero, so buying a more expensive drink with200 through price minus one spends
only that remaining balance. This is recorded source behavior, not an invented
price/reward. Delivery sound/timing remains root's native audio/presentation work.

Drink gifts remove one Water/Soda/Lemonade and grant TM13/TM48/TM49 once. Removing
a single-unit stack frees a full-bag slot as in source. With a multi-unit stack
and no room for the TM, the atomic transaction leaves the drink/reward/flag intact
for retry; source removes the drink before GiveItem and can otherwise lose it.
This follows the task's explicit retry requirement. Failed capacity, cancelled
choices, stale observations, missing Coin Case and insufficient funds spend no
coins/money/rewards. Party/box capacity has no bearing on item purchases.

Raw assembly/reference dumps remain outside Git at POKERED_REFERENCE_DIR. The
new generator verifies HEAD and each consumed blob against exact pinned Blue,
records SHA256 and emits only compact runtime policy and used dialogue recipes.
All Blue prize species/levels/prices, three original reels and 48 hidden event
identities are projected already for the follow-up slots/prizes work. Hidden
coin event 48 shares slot 13's cell and is source-shadowed; no extra reachable
hidden coin is invented. No slot payout is active/fabricated in this first packet.

Worker checks: scoped source checks and production SDK compile only. No Simulator,
native behavior contract execution, image/audio approval or milestone acceptance.

## Completed slots and prize layer for checkpoint 5.5a

The next packet adds three prize counters, the original 36 machine identities,
12 hidden coin identities and the Department Store elevator. The existing
ordinary clerks still retain their source shops and TM18. Root applies the
unapplied root-api.patch, or appends the two method files in order, AFTER its
CoinWallet schema 4 owner hook. Only root edits GameSession. No Celadon codec
field is added. Root lifecycle calls are in root-hooks.lua; add update and exit/
failure cleanup to the first packet's enter/advance/input/draw delegation.

Prize IDs are pokered:GAME_CORNER_PRIZE_ROOM:background_events:1, 2 and 3.
The first counter offers Abra level 6 for 120 coins, Clefairy level 12 for 750,
and Nidorino level 17 for 1,200. The second offers Pinsir level 20 for 2,500,
Dratini level 24 for 4,600, and Porygon level 18 for 6,500. The third offers
TM23 for 3,300, TM15 for 5,500 and TM50 for 7,700. These are the Blue versions,
not Red's roster or prices. Successful Pokémon prizes repeat through normal
Gen V gift acquisition; the owner prevalidates active box capacity and prepares
specimen, Pokédex, coins and RNG before one non-yielding claim. Item prizes use
the bag owner. A full bag, full selected box, missing Coin Case or insufficient
coins cannot spend the price or advance prize RNG. There is no invented
Here-you-go line: that source prize text is unreferenced.

The slot engine translates actual source flags, slips, reels, paylines and reroll
order. It never draws a random payout. Coin wagers are exactly 1, 2 or 3, with
source menu order ×3, ×2, ×1. The source compares five lines in this order when
eligible: ascending diagonal, descending diagonal, top row, bottom row, middle
row. Only the first match pays, without multiplying by the wager. Rewards are
300 for 7, 100 for BAR, 8 for CHERRY and 15 for the three creature symbols.
The machine can suppress matches or enable 7/BAR according to the original
byte thresholds. It steers/slips wheels 1 and 2 and rerolls wheel 3 exactly as
source. The erroneous wheel 1 HIGH(symbol)<2 check is retained. The byte after
the two slip counters is the third-reel reroll counter, initialized to 4 on each
wager. The opening routine clears all 20 working bytes, including reel offsets,
after drawing the initial graphics; first-spin offsets therefore begin at 0.

GameSession holds the opaque round token, bound event/player/zone/epoch, actual
coin debit, private reducer value and RulesRNG continuation. The controller
receives detached view data only. It can submit a wager, advance native frames
and forward actual A edges; it cannot supply a payout or chosen reel positions.
Each completed result credits the real bounded wallet once, with source BCD
saturation at 9,999. Duplicate or stale calls cannot pay again. One-more-go
retains source match flags and allow-match counter; ending the source screen
releases the transient state. Nothing about slots is serialized. After a real
accepted wager, a forced event abort keeps that wager spent and claims no
unproduced result. B cannot cancel a spinning round; it cancels the bet menu.

Map entry chooses the original lucky index using the original byte transform,
including byte 7 mapping to index 0 (no lucky machine). Only indices 1 through
31 can be lucky. Broken/occupied machines can be selected by that original
lottery; no reroll substitutes a playable machine. All economic random draws
come from the session's active RulesRNG; drawing and reel animation never sample
randomness. The Game Corner onEnter hook samples on actual map entry,
a fresh Continue, and battle return, matching the source CUR_MAP_LOADED_2 flag.

A native 30 Hz update represents two GB frames. Ordinary GB spin iterations use
three GB frames, with 20 initial iterations at two frames and two-frame third-
reel rerolls. The display uses the six immutable Blue symbol images, decoded
from their original 2×2 tile order and rendered through the existing reviewed
imported shade path. No protected image is edited. Original SFX, palette flashes,
per-coin count-up presentation and SGB timing are not claimed: the actual payout
publishes once and the source dialogue presents that real result. Root must
inspect native controls, timing, new art and audio before acceptance.

Slots and hidden coins use actual hidden_events:1 through 48, with source
facing-tile lookup order. Machines 6, 9 and 28 print the original keys/lunch/out-
of-order text. Normal machines require horizontal facing, a Coin Case and
positive credit. Hidden coin event 46's source argument says 40 but the script
credits 20 due to its original branch typo; the generator records both values.
Event 48 is shadowed by a machine at the same coordinate and remains unreachable.
A full Coin Case saturates and uses the original dropped-coins message/once bit.
No extra collectible coins are invented.

The Department Store elevator is the existing shared warp engine with five
source floor choices. Root declares the exact IDs in root-elevator-bindings.json
and includes CeladonServices.elevatorBindings(session) in its single resolver.
The owner records the actual entry floor and selection in five existing quest
booleans; cancellation retains the old destination. No sixth roof floor, mutable
map cache, new warp engine or invented LAST_MAP target is introduced.

## Verification and exact integration status

The five SDK cases cover vending, drink exchange, coin wallet services, prize
claim ownership, and the source slot rules. They use real collections, the
production codec, actual Gen V specimen creation and actual RulesRNG streams.
Slot rule examples do not credit a wallet or fabricate a machine result. The
session owner accepts only its privately advanced reducer; callers cannot submit
those example offsets or a payout. Root must run an actual complete round and
inspect the source symbol images through the native controller. No driver or
fixture behavior contract is added, and the existing Eevee gift mechanism is
not re-proven with another duplicated gift contract.

Root harness registration is root-contracts.lua. Scope checks are:

```sh
"$POKEMON_ENV/venv/bin/python" tools/celadon-services/prepare.py --reference "$POKERED_REFERENCE_DIR" --check
"$POKEMON_ENV/venv/bin/python" -m unittest tools.tests.test_celadon_services_sources -v
make compile
python3 tools/celadon-services/compile.py --output "$POKEMON_ENV/evidence/celadon-services-compile-UNIQUE"
```

The private compile includes the unapplied owner append and contract module.
It proves compilation only, not runtime linkage, numeric wallet initialization,
controller timing, payouts, protected art, audio or actual Save/Continue. Root
must first compose its existing schema 4 CoinWallet hook and then the Celadon
append. This worker edits none of those shared owners or MidgameServices files.
All payout and purchase methods are reviewable text patches for root.

Final worker checks passed 14 scoped host cases across the Celadon projections
and shared source-event data checks. Production compilation passed. The private
compile with the owner hooks and contract module is outside Git at
`/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/celadon-services-compile-20261028-02`.
No Simulator or SDK behavior contract was executed. Root alone supplies native
acceptance and the three earned saves for checkpoint 5.5a.
