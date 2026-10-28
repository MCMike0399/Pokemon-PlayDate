# Celadon services — first incremental packet

Merged exact root49a7135; implementation preparation only. Root retains all shared
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
requires the existing CoinWallet schema4 field and coins() getter from the Safari/
coin packet. No further codec change is needed. commitCeladonService(operation,
observation) prepares canonical data-defined offers on detached owners and commits
bag/money/coins/flags together. Prices/rewards are selected by bounded source
indices, never caller-supplied quantities/payouts. The same small hook includes
prepared prize support for the next packet; its UI is not registered here yet.

First packet reserved IDs:

- CELADON_MART_ROOF background_events:1..3: the three original vending positions.
- CELADON_MART_ROOF objects:2: drink girl (actual moving source actor).
- CELADON_MANSION_ROOF_HOUSE objects:2: immediate Eevee level25 gift.
- GAME_CORNER objects:2: ¥1000 for50 coins; actual Coin Case required.
- GAME_CORNER objects:5/9/10: original10/20/20 coin gifts and original once flags.
- GAME_CORNER objects:7: source conditional Erika dialogue.

All IDs have pokered: prefix. These were reserved, not ordinary registered clerks.
Eevee uses existing price-zero purchaseGiftPokemon. Only successful party/selected
box acquisition sets CELADON_SERVICES_V1_EEVEE_TAKEN, representing the source object
toggle. Full selected box leaves it retryable with no flag/RNG claim. There is no
new nickname UI; the existing naming limitation remains explicit.

Source economic details are preserved: AddBCD saturates coins at9999. Coin sales
refuse at>=9990, including though some lesser balances saturate after+50. The
Gentleman's source check is equality9990, unlike the other gifts' >=9990 check.
Vending displays exact200/300/350 prices but source checks only200 for all three;
SubBCD clamps atzero, so buying a more expensive drink with200..price-1 spends
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
All Blue prize species/levels/prices, three original reels and48 hidden event
identities are projected already for the follow-up slots/prizes work. Hidden
coin event48 shares slot13's cell and is source-shadowed; no extra reachable
hidden coin is invented. No slot payout is active/fabricated in this first packet.

Worker checks: scoped source checks and production SDK compile only. No Simulator,
native behavior contract execution, image/audio approval or milestone acceptance.
