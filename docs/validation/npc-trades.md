# Nine NPC trades: implementation handoff

Private candidate from exact `0b3aa5d`, branch `wip/nine-npc-trades`.
No Simulator, runtime, real process journey, visual or campaign acceptance is
claimed. Root retains those checks and the frozen 30-map Cerulean checkout.

The approved policy keeps the nine English Blue trades and source dialogue;
normal Gen V ability/nature/sex/six IV samples follow one detached bounded
16-bit source OTID draw. Incoming Pokémon have canonical nickname/TRAINER OT,
local outsider provenance, threshold XP, zero EVs/no item, healthy status-free
HP and full PP, using the existing B2W2 last-four distinct move constructor.
The `mr` species key is the existing dex122 internal key; dialogue explicitly
uses the fixed source name `MR.MIME`, not its current abbreviated species label.
Nidoran sex symbols and Farfetch'd are literal source names through EventText,
SourceText and measured Dialog pagination.

A holding selected mon is rejected before enhanced final confirmation. The
message directs the player to POKEMON → ITEM → TAKE. Taking remains the existing
held-item transaction and may reject a full bag; trade never deletes, refunds,
grants or consumes an item. No trade evolution service or outgoing evolution/
return is present. `_ConnectCableText` is flavor acknowledged through ordinary
dialog, with no hardware/network wait.

`NPCTrades.prepare` captures the exact selected object and slot, every roster
object/codec record, active index, authoritative field/scene epochs, active
session, rules continuation, GameContext/player/zone/position/facing and current
executor identity. Cancel and every confirmation attempt retire the intent.
`GameSession:resolveNPCTrade` builds all candidates before its synchronous
publication. It publishes the rules continuation, private roster/ownership swap,
completion flag and seen/owned sets without yielding. There is no recruit or PC
capacity dependency. No intermediate empty party is published.

Source `RemovePokemon` then `AddPartyMon` order is retained: survivors keep order
and incoming appends. A surviving usable active object's identity stays active;
when the outgoing object was active (or the old active is unusable), the healthy
incoming becomes active. That active-selection rule is an engine adaptation;
there is no claim that Blue's active-member UI used this separate identity.

Pokémon codec v8 adds `acquisition={version=1,kind=neutral}` or validated minimal
NPC trade metadata. Versions3–7 migrate without rerolls, invented history or
changes to existing attributes. Session schema3, fieldWorld and Day Care remain
owned by their existing codecs. Native XP applies local outsider Q12 `0x1800`
after level scaling, ties down, then the100000 cap. It never derives outsider
status from nickname, OTID inequality or an individual NPC label. Existing
pinned native reward and fixed_round sources are reused by host oracles.

## Tiny root bootstrap patch

Apply in the integration checkout, **not** the frozen live-journey checkout.
Production imports (after their named predecessors):

```lua
-- after import "domain/gameSession"
import "domain/npcTrades"
-- after import "game/daycareState"
import "game/npcTradeState"
```

Install after `Daycare.install()` and register the existing event state with its
new final subclass (one dispatcher and one registered executor):

```lua
NPCTrades.install()
-- replace machine:register("event", DaycareState(game))
machine:register("event", NPCTradeState(game))
```

Harness-only registration after Contracts and production imports:

```lua
import "dev/npcTradeContracts"
Contracts.register("npc-trades", NPCTradeContracts.run)
```

These are also supplied as `docs/validation/npc-trades-bootstrap.patch`.
No main.lua/dev_imports.lua change is committed. Four current actors register
through SourceEvents: Route2TradeHouse objects2, UndergroundPathRoute5 objects1,
VermilionTradeHouse objects1, Route11Gate2F objects1. Existing actor binding uses
SourceEvents.has dynamically. The other five identities have complete immutable
trade/text payloads but no registered descriptor or activated map actor. Future
map activation must deliberately add those descriptors; no data import alone
activates a new region.

## Prepared verification

Host checks only inspect immutable primary inputs, generated data and independent
native rounding/order vectors. They do not emulate/transpile Lua or replace SDK.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python -m tools.generate_npc_trades --check
python -m unittest tools.tests.test_npc_trades -v
python tools/check_npc_trade_policy.py --source "$POKERED_REFERENCE_DIR"
```

Root should run the newly registered actual SDK suite in an identified private
harness session. Cases include all nine identities/payloads and five source
branches each, normal detached trait/OTID ordering, exact-object ownership,
last-member/last-usable, full party/all240PC slots, full-bag Take rejection,
cancel/replay/stale roster/HP/moves/PP/item/RNG/context/field epoch, neutral codec
migration, explicit outsider XP rounding/cap and all independent one-time flags.
Four controller cases use actual source providers, states, dispatcher, party
selection callbacks, measured dialog, final confirmation, cable flavor, receipt
and repeat interactions. These are semantic controller witnesses, **not** real
button timing or natural walking journeys. A private-bundle case uses the actual
SDK SaveStore/filesystem, fails publication through a wrapper around real rename,
checks old disk/new in-memory coherence, explicitly recovers the published slot
through existing SaveStore recovery, then retries and reloads via SessionCodec.
The root still must run actual separate-process Save/Continue journeys and inspect
text/UI (including held-item instructions and literal UTF8), protected art and
ordinary source-event regressions. No contract result has been recorded as pass.

Compile-only preparation (installed SDK pdc, private source copy with bootstrap
imports): `~/Developer/Pokemon-PlayDate-env/evidence/nine-npc-trades-preparation/`.
Main/dev imports, active maps/cache, battle item/effect code, field/grass owners,
root ledger/fidelity/coverage/baselines and protected art are untouched.

Preparation checks: all42 focused host tests passed (trade data, growth generator,
specimen traits, individual data and ordinary source events), zero skips. The
standalone primary nine-used/ten-table checker passed against the pinned local
pokered checkout. Generator `--check` and final `git diff --check` passed. A private
copy with the bootstrap imports and SDK contract import compiled under pdc3.1.2.
The initial broader command referenced a nonexistent `test_growth` module; the
correct `test_growth_generator` suite is included in the42 passing tests.

## Exact Source ownership

New complete files:

- `Source/data/npcTrades/policy.json`
- `Source/domain/npcTrades.lua`
- `Source/game/npcTradeState.lua`
- `Source/dev/npcTradeContracts.lua`

Existing-file bodies changed:

- `Source/domain/gameSession.lua`: new `resolveNPCTrade` only.
- `Source/domain/party.lua`: new `_prepareExchange` only.
- `Source/domain/specimen.lua`: `origins` adds `npc-trade` only.
- `Source/domain/pokemonCodec.lua`: VERSION/allowed fields, `checked`, `encode`
  and `decode` gain nested acquisition metadata and neutral migration.
- `Source/domain/growth.lua`: new `outsiderAward`; `battleAward` accepts the
  explicit outsider boolean and applies that modifier before capping.
- `Source/data/pokemon.lua`: `calcExpGain` passes explicit provenance-derived
  outsider status; no species/stat/learnset or unrelated class edits.
