# Bounded 5.4 quest-gift preparation

Branch `wip/vermilion-quest-gifts` starts exactly at
`760a58e30124e3be1115c29e9a006c3000ef85c6`. This is a preparation packet;
no active map, scene, main import, shared owner, coverage snapshot or acceptance
ledger was changed. No Simulator/runtime, push or delegation occurred.

`Source/game/vermilionGifts.lua` registers exactly four stable source objects:

- `pokered:POKEMON_FAN_CLUB:objects:5`: BIKE VOUCHER, actual full RAPIDASH story,
  YES/NO, source voucher-flag/bicycle-in-bag/voucher-in-bag repeat conditions.
- `pokered:VERMILION_OLD_ROD_HOUSE:objects:1`: OLD ROD, YES/NO and repeat.
- `pokered:ROUTE_2_GATE:objects:1`: HM05, YES/NO, at least 10 owned species.
- `pokered:ROUTE_11_GATE_2F:objects:2`: ITEMFINDER, YES/NO, at least 30 owned species.

All four retain full-bag retry. Success text is displayed only after the owner
transaction succeeds. Decline is side-effect free. The aides count distinct
`GameSession:pokedex().owned` entries after YES, as CountSetBits does in the
source; seen entries, party size and duplicate specimens do not qualify.

The three source EVENT flags remain `EVENT_GOT_BIKE_VOUCHER`, `EVENT_GOT_HM05`,
`EVENT_GOT_ITEMFINDER`. Old Rod is **not** an invented EVENT constant:
`wStatusFlags1.BIT_GOT_OLD_ROD` is mapped explicitly into the existing quest-flag
codec as `pokered:wStatusFlags1:BIT_GOT_OLD_ROD`. It means that bit only; no
other status bits are inferred. There is no source-clock, rules/world RNG,
PP, battle outcome, encounter, teaching, fishing-menu, Cut/Flash traversal,
trade, exclusive-species, Mew or obedience-policy change.

## Root integration

Apply `tools/integration/vermilion-gifts.patch` in the integrated checkout after
cherry-picking the packet. It contains only main import/install/state composition
and harness contract registration. The patch applies to the exact base. In the
root's combined tree, place `VermilionGifts.install()` **after the ordinary
Vermilion source package is installed and before any GameContext is created**.
Import the module after `game/kantoServices`; register `VermilionGiftsState(game)`
as the one `event` state. It extends `KantoServicesState`, which retains the
current Cerulean/EventState chain. There is no second dispatch path.

The ordinary package must continue omitting these four IDs. Its actor/content
resolver can merge `VermilionGifts.actorMetadata(event.id)` alongside other scene
metadata; this packet returns an empty visibility list because all four actors
remain visible after completion. No placement exemptions, actor movement,
additional trainer rosters, world hooks or map aliases are required. Root owns
ordinary source-package installation, the 65-map inventory activation, manifest,
cache, metadata composition and any final executor subclass composition with
other workers. This packet alone intentionally leaves the maps inactive.

The module consumes the existing read-only
`data/vermilionPreparation/dialogue.json`, including RAM/decimal recipes and
layered receipt/explanation labels. It does not duplicate that resource or any
ordinary roster. Six special script/constant files are vendored with SHA256 pins
at `tools/references/vermilion-gifts/manifest.json`, revision
`af519899719f0754965776faac0e836a3b906e6d`. The generator asserts actual story,
choice, threshold, source flag and grant ordering. Host tests independently
verify every used prepared text recipe against the primary checkout and the
existing preparation pins.

The pure `VermilionGifts.plan` accepts detached observations from actual session,
Pokédex and Inventory owners. The descriptor flow reuses `SourceEvents.compile`
for the item/flag transaction. `GameSession:transact` owns capacity validation,
optimistic item/flag guards and atomic publication. An aide also compares the
observed owned count immediately before that synchronous transaction. There is
no asynchronous gap between that check and the transaction. UI uses inherited
EventState guards and the Kanto service YES/NO menu; callbacks are invalidated
by epoch, serial, replaced session/player/zone and state ownership.

## Checks and precise limits

Executed with `source ~/Developer/Pokemon-PlayDate-env/env.sh`:

```sh
python3 -m unittest tools.tests.test_vermilion_gifts tools.tests.test_kanto_services -v
python3 -m tools.generate_vermilion_gifts --check
git apply --check tools/integration/vermilion-gifts.patch
```

All 12 host tests passed. These are pins/projection tests, not host Lua execution;
no Lupa or fake SDK is used. Real SDK 3.1.2 compile-only succeeded with the private
main importing the production module and new SDK suite:
`~/Developer/Pokemon-PlayDate-env/evidence/vermilion-gifts-compile-20261026-163621`.
Final compile after the last contract additions also passed:
`/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/vermilion-gifts-final-compile-20261026-163748`. Compile success establishes syntax preparation only.

`Source/dev/vermilionGiftsContracts.lua` prepares 30 real SDK tests: 9/10 and
29/30 owned-versus-seen/duplicate thresholds, four gift capacity/retry/once/item-ID
and SDK JSON/SessionCodec round trips, declines, optimistic stale item/owned
checks, detached plans/text previews, flag-capacity rollback, chairman source
repeat conditions, draw purity, native cancellation, stale epoch and replaced
session callbacks. Native scene tests use the existing real SDK map/NPCMotion/
Player/Dialog fixture and replace its event registration with the composed gift
state. Missing root map integration fails explicitly.

Root must register/run `vermilion-gifts` with the existing service/event suites
and inspect native dialogue/menu behavior after map integration. Update the
root-owned dev-import baseline consistently when applying the harness patch.
No SDK test was executed here; no gameplay, visual, performance, device,
process-restart or milestone acceptance is claimed. Raw SDK JSON/codec round
trips are expressly not Save/Continue process proof. Existing accepted 5.2
Source `2673…` and the private live 5.3 journey receive no new acceptance claim.
