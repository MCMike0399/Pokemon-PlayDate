# Bounded 5.4 Day Care preparation

`wip/daycare` merged exact root preparation `acaa8e2` before implementation.
The worker did not merge root `2a207be`; it inspected that exact commit read-only
and used its shared files in an isolated compile-only evidence copy. Existing
checkout Source files, main/dev imports, manifest/cache, ledger and baselines
remain untouched by the Day Care implementation. No Simulator, runtime, push,
delegation, native acceptance or milestone acceptance occurred.

## Behavior and ownership

`game/daycare.lua` is a session-composed transaction helper. GameSession owns
`current.daycare={version=1,earned=<native integer>,mon=<actual Pokemon or nil>}`.
The Party ownership registry names the **GameSession itself** as the held mon's
owner. It does not use Storage, quest flags, module globals or a second provider
for persistence. Immutable content caches and private weak one-shot request
records are the only module state.

One original Blue slot accepts the selected party member, rejecting the final
member and all five original HM moves. Existing last-usable-party protection is
retained. Pending battle learning/evolution must finish before deposit. The
chosen object moves through `Party:_take` / `Party:_receive`; the remaining
active party member and original Party/Inventory objects retain their identity.
Withdrawal appends the held mon; no automatic box fallback exists. Cancellation,
full-party, insufficient-money and stale-request failures preserve the slot,
party, growth and money. A failed request is consumed; retry requires a new quote.

`Daycare.plan` observes detached primitive data without constructing a Pokemon,
mutating owners or drawing RNG. `prepare` seals that plan, exact member references,
held-slot identity and field context epoch in an ephemeral request. Commit guards
the roster, active selection, Pokémon records, growth, balance and context again.
Caller mutation of a detached preview cannot replace the chosen mon or fee.
Withdrawal constructs and validates a detached growth candidate and bag before
transferring the original object and paying. No asynchronous work occurs between
preflight and publication. Neither rules RNG nor world RNG is consumed.

Blue increments XP once per ordinary completed step, excluding scripted movement.
The slot banks that XP separately so its deposited Pokémon remains a valid
PokemonCodec record until withdrawal. At withdrawal it derives the new level
from the existing B2W2 species growth curve, capped at 100, recalculates existing
Gen V stats and restores HP to maximum. Source status and retained-move PP remain
unchanged. New moves get their Gen V base PP. Only levels crossed since deposit
are scanned, in the existing ordered B2W2 learnset; currently known moves are
skipped, free slots append, otherwise the oldest move and its PP are discarded.
There is no battle learning queue, evolution, EV gain, breeding, egg or RNG draw.
A level-100 mon receives no further banked XP.

Fees are Blue's ¥100 plus ¥100 per level gained. Original two-byte AddBCD saturates
at ¥9,999, including the otherwise unreachable-in-Blue level-1-to-100 case that
this project's domain can represent. Refused withdrawal does not reset the growth
baseline or charge money. All fifteen original text labels and their RAM/numeric
recipes reuse `data/vermilionPreparation/dialogue.json`; no duplicate text owner
is introduced. The existing source text renderer owns wrapping and pagination.

One proposed fidelity-ledger row, for root to record during integration:

| Area | Chosen policy | Primary basis / deliberate difference |
|---|---|---|
| Day Care | Blue single slot, completed-step XP, fees, automatic crossed-level FIFO learning, no evolution; B2W2 growth/stats/learnsets/PP; reject the last usable member and unresolved battle progression. | Pinned Blue `scripts/Daycare.asm`, `engine/overworld/daycare_exp.asm`, `engine/pokemon/evos_moves.asm`; Gen V data owners replace Gen I battle data, and party/progression guards prevent project softlocks or lost choices. |

## Root API and schema 3 handoff

`daycare-api.patch` is **unapplied**, targets exact `2a207be`, and touches only
GameSession, SessionCodec and OverworldState. It is 115 lines including context;
root must compose it with the field-world worker's readability changes. It adds
`GameSession:resolveDaycare(request, decision)` and `GameSession:daycareStep()`.
Successful transfers invalidate the existing field-world context epoch without
changing the persisted palette. Cancelled/failed transfers do not invalidate it.

The codec becomes **VERSION 3**, preserving schema 2's `fieldWorld` rules:

- V1 must omit both `fieldWorld` and `daycare`; migrate to palette 0 and empty slot.
- V2 must contain valid `fieldWorld` and omit `daycare`; preserve palette 0 or 6,
  and migrate only the Day Care slot to empty.
- V3 requires both fields. A missing/malformed Day Care record is an error,
  never an empty-slot repair that could silently discard a held mon.

The Day Care wire field is `{version=1,earned="<canonical decimal>",pokemon=...}`,
with `pokemon` absent for an empty slot. The existing lossless Pokémon wire codec
owns XP/choice counters. Earned XP is also a checked decimal string; validation
bounds it against the held specimen's remaining growth. Held Pokémon join the
existing Pokédex checks, pre-starter ownership count and duplicate-object encode
check. Decode fully preflights the record before claiming the new held object
for the restored session. SaveStore remains the existing two-slot owner.
The optional player-only Cut endpoint resolver and strict checkpoint resolver
are preserved exactly. No world, palette, quest, RNG, party or storage state is
reconstructed from Day Care history.

The ordinary-step hook runs immediately after exploration's real sprite update,
so warp/sight/event preemption in the next frame cannot skip or double count it.
Successful map connections skip that animation in this engine, so their completed
handoff receives one separate call. Warps/Continue do not grant arrival XP.
Script/event sprite updates never execute the exploration hook. Root must verify
this placement after composing its lifecycle changes, including ledge jumps,
connections, warp tiles, overlay pause/resume, script movement and blocked steps.

## Root wiring, kept outside the API patch

Keep one source dispatcher and one registered event state:

1. Import `game/daycare` before any GameContext/session construction, after the
   domain definitions. Import `game/daycareState` after `game/vermilionGifts`.
2. Install the ordinary prepared Vermilion source package, then existing gifts,
   then `Daycare.install()`. The ordinary package must keep omitting
   `pokered:DAYCARE:objects:1` as it does in the prepared data.
3. Register `DaycareState(game)` as the one `event` state. Its superclass is
   `VermilionGiftsState`, retaining KantoServices/EventState. If root also composes
   Anne/Surge's subclass, place the classes in one inheritance chain; do not
   register competing `event` states. Day Care adds no second provider.
4. The map worker can merge `Daycare.actorMetadata()` into the existing actor
   resolver. It returns empty visibility constraints; the gentleman remains.
5. Root activates the prepared Daycare map and registers the `party` state as
   usual. No map/cache/manifest edits are supplied by this worker.
6. Register `dev/daycareContracts` / `Contracts.register("daycare", DaycareContracts.run)`
   in root's harness overlay and update the dev-gate fixture together.

Schema evolution also requires root to adjust the existing field-world SDK test
at `Source/dev/fieldWorldContracts.lua` near line 351: compare the saved version
to `SessionCodec.VERSION` (now 3), and remove **both** `fieldWorld` and `daycare`
from its manually downgraded v1 record. Keep its v1-with-fieldWorld rejection.
This is a fixture update for schema 3; the worker did not edit that shared file.

## Checks and remaining root witnesses

Executed under `source ~/Developer/Pokemon-PlayDate-env/env.sh`:

- Nine new host checks passed; together with gift/Kanto-service checks:
  **21 passed, zero skips**. Log:
  `~/Developer/Pokemon-PlayDate-env/evidence/daycare-host-20261026.log`.
- `python tools/generate_daycare.py --check` passed. The generator verifies
  pinned bytes, guard/price/step/learning rules and the stable prepared actor.
  Host tests independently compare pins against exact git source bytes and
  compare every reused text recipe. A mutated step-XP pin is rejected.
- Actual Playdate SDK **3.1.2 compile-only** passed for the worker source, and
  for the schema-3 API applied to a read-only archive of exact root `2a207be`:
  `~/Developer/Pokemon-PlayDate-env/evidence/daycare-schema3-compile-20261026-03`.
  `candidate/build.json` records the composed source hash and explicitly says
  `runtime_executed=false`. Candidate imports both modules and registers the
  SDK suite. Map activation is intentionally not included.

Reproduce the composed compile without editing the checkout:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python -m unittest tools.tests.test_daycare tools.tests.test_vermilion_gifts tools.tests.test_kanto_services -v
python tools/generate_daycare.py --check
python tools/prepare_daycare_witness.py --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/daycare-root-compile-UNIQUE"
```

The first schema-3 staging attempt (`...-01`) failed because the older gift main
patch no longer applied to root's changed registration context. It remains a
failed staging attempt. The helper now wires the exact root main explicitly;
the subsequent `...-02` and final `...-03` compiles passed. No failure is runtime/acceptance evidence.

`dev/daycareContracts.lua` prepares **14 real SDK tests**, including exact-object
transfers, mutated detached previews, cancellation/double resolution, stale
roster/money/step/context guards, all five HM exclusions, last-member/last-usable
and progression guards, party-full/funds retry, actual SDK JSON/codec roundtrip,
strict v1/v2/v3 migration and fieldWorld preservation, cap/BCD overflow, B2W2
crossed-level FIFO/retained PP/Gen V stats/no evolution, and real Player/Explore
completed-step versus blocked/idle/other-sprite updates. The final controller
fixture uses actual imported geometry, NPCMotion, DialogState and PartyState.
These tests are **prepared and compiled, not executed** by this worker.

Root must run those tests on the composed tree, inspect source dialogue and
party-selection UI, and run a natural Route 5 Day Care deposit → walk → quote →
withdraw flow. Supplement it with cancel/full-party/insufficient-money retries,
actual process quit/Continue while occupied, withdrawal after Continue, and
another real restart after payment. The codec test alone is not disk-write or
process-restart proof. Run the normal regression/catalog checks during integration.
This packet establishes no playable activation, native result or milestone acceptance.
