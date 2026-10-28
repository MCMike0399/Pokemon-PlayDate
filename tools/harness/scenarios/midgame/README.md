# Earned midgame real-input candidates

Based on exact root `7351c00` (merged before implementation). These scripts start
from accepted `chain/5.4/<starter>` slots through the real title CONTINUE menu.
They never run New Game, fixtures, state setters, free rewards/money or XP grind.
Only Charmander has optional content; Bulbasaur/Squirtle are critical-path runs.

First packet: `east-<starter>.json` continues the Flash-aide save, reuses the
existing Diglett's Cave waypoint script, crosses the north/south Underground Path,
heals, teaches Flash through the real HM Bag flow, cuts Cerulean's source tree,
travels Route9/10, uses actual Flash in dark Rock Tunnel, traverses the four
explicit source ladders and saves in Lavender. Charmander also talks to the
Cubone-house girl. Every case requires a real second-process Continue and complete
canonical codec equality. This is a partial route packet, not 5.5 completion.

Root applies the small returned patch once:

```sh
git apply --check tools/harness/scenarios/midgame/root-registration.patch
git apply tools/harness/scenarios/midgame/root-registration.patch
```

It adds dispatch/restart names, validates accepted Vermilion ancestry before the
existing exact-slot hash import, extends the existing canonical payload checker
for codec4, and adds two read-only observations (`midgame-owners`, `midgame-state`).
It changes no gameplay, main, dev imports or ledger. The observations return
actual registered events/trainers/shops, HM compatibility and field state. They
never advance gameplay, create receipts or capture traversal. Save/Continue
payloads still come only from the existing real boundary observer.

No dev projection or new generator is needed: navigation reads the one active
shared manifest/cache and pinned package definitions from the compiled source.
No new planner features, diagnostics framework, tests or SDK contracts are added.
Generic route failures remain failures. Difficult cave geometry uses explicit
source warp IDs and the existing fixed Diglett waypoints. No missing service
falls back to a fabricated successful outcome.

Root alone executes, after the game owners are integrated:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/harness/suite.py \
  --only midgame--east-charmander,midgame--east-bulbasaur,midgame--east-squirtle \
  --continue-on-failure --output "$POKEMON_ENV/evidence/m55-east-input-UNIQUE"
```

Keep `--continue-on-failure`: a failed starter must not prevent the other two
from running. The runner imports the exact accepted slots into private Data;
existing stopped-process archives retain all resulting earned saves. It does
not publish partial Lavender progress into `chain/5.5` or touch accepted 5.4
slots. Root publishes accepted chain/5.5 saves only at its milestone gate.

The field worker must finish ordinary Cut coverage for the newly active route
maps and actual darkness/Flash integration before this packet can succeed.
The driver raises a concrete error when an earned compatible HM user, field
menu action, service registration or source collision route is unavailable.
Wild encounters are fled using the existing real battle controls; no preparation
fights are permitted. Required trainer battles use the shared observed-move and
confirmed-reward driver. Centers/shops are the recovery policy.

Preparation: 20 existing journey-path/dialog/restart/suite-discovery checks passed.
All three scenario identities/bounds and accepted 5.4 ancestor metadata passed
host checks. SDK3.1.2 compilation passed, including the returned read-only Lua
observation patch in a private staged tree. No Simulator executed and no native
journey result is claimed. Evidence: environment
`evidence/m55-journey-east-compile-01/`. The registration patch is unapplied.

## Full-route follow-up

`restart-<starter>.json` extends the same earned save through Celadon/Erika/HM02,
Hideout/Scope, Tower rival/ghost/Rockets/Fuji/Flute, drink/Saffron/Silph/Lapras/
Giovanni/President/Sabrina, Route12 Snorlax, Fuchsia/Koga, Safari Gold Teeth/HM03,
Warden HM04/actor push, Surf/landing and a real visited-city Fly round trip.
The first pass uses the actual Pewter PC if needed to reserve a party slot for
Lapras; it keeps the starter, learned HM users and earned Fly-compatible species.
It never constructs or replaces a specimen. A missing earned compatible user
is an explicit failure, not a fixture fallback.

Charmander additionally plans Dojo/Hitmonlee, Mr Psychic's TM29, both rods,
Route16 Snorlax, the genuine Fan Club voucher/Bicycle exchange, Cycling Road,
Coin Case/TM18/Eevee and fishing. Core starter runs omit those optional actions.
The coin wallet/prize/slot owner and the remaining service controllers have no
runtime observation contract in the supplied field packet. The optional coin
phase therefore raises an explicit unavailable-owner error; it cannot publish a
successful full receipt until the field worker supplies that API and its native
service behavior. Likewise, absent registered vending/rods/Safari/Eevee handlers
fail at their exact stable source ID. Prepared modules are not acceptance.

The fixed scripts are data, not planner features:

- `hideout-fixed-routes.json`: supplied by the story worker's source handoff,
  four scripts including each exact spinner approach/trigger/automatic stop.
- `silph-fixed-routes.json`: Card Key's 5F->9F->5F round trip, corridor/door/
  Giovanni legs and explicit Sabrina pad index sequences. Paths were enumerated
  once with the EXISTING source path API; runtime never solves a pad graph.
- `safari-fixed-routes.json`: Center->East->North->West, Gold Teeth approach and
  Secret House, approximately300 actual cells. After HM03, leave the HOUSE and
  use one actually purchased Rope from FOREST. Original
  `engine/items/item_effects.asm:ItemUseEscapeRope` explicitly clears Safari,
  and `data/tilesets/escape_rope_tilesets.asm` includes FOREST. The driver checks
  actual Rope consumption and Safari flag clearing, rather than inventing a
  RETIRE menu, resetting steps or manufacturing a timeout. Runtime Safari mode,
  source balls/steps and that Rope hook still belong to the field worker.
- Optional Mansion/Eevee uses fixed source backstairs warp indices, preserving
  root7351c00's exact forced-down arrival even on an originally solid cell.

All frames start `m55-<current-map>-`; inherited brock/parcel/cerulean/vermilion
prefixes are removed. Saves include a unique sequence in frame names. Generic
collision planning still reads the actual settled Zone collision through the
existing read-only observation; no live state or source grid is edited.
Ordinary battle move/reward/payout handling stays in the shared driver. Actual
rival diagnostics must match a pinned Rival2 roster, the correct counter family
and source payout. Scripted Marowak/Snorlax use actual battles and committed
source flags; ordinary wild encounters are fled. No XP grinding is permitted.

Supplies use real Centers/shops and earned money. If the bag needs room before a
long dungeon, the script may sell owned prior-campaign Nugget/TM34/TM11/TM28/TM24
through the actual Shop UI, checking its actual result total and inventory/money
change. It preserves key items/HMs/new5.5 rewards and creates no currency. Missing
sellable items, source stock or affordable medicine remain concrete failures.

After applying the UPDATED returned root patch, root alone runs all three:

```sh
python tools/harness/suite.py \
  --only midgame--restart-charmander,midgame--restart-bulbasaur,midgame--restart-squirtle \
  --continue-on-failure --output "$POKEMON_ENV/evidence/m55-full-input-UNIQUE"
```

Successful **full** Save+actual-process-Continue exports exact final slot bytes
only to `chain/5.5/<starter>`, with SHA256/build/source/starting ancestry and
review-pending provenance through the existing export helper. Partial `east-*`
runs never export there. Failed runs never export final slots. The accepted
`chain/5.4` slot bytes are only read/checksummed/copied to private Data and stay
unchanged. The ledger remains root-owned at65/222 until its acceptance gate.

The updated observation patch uses actual `ItemData.marts`, actual registered
object AND background events, `MachineData.compatibility`, existing generic UI
snapshots and `game:getFieldTravelSnapshot()` from field packet2220cdd. Its finite
phase adapter handles `destination/confirm/announce/fade/moving/push/result` on
root `fieldTravel`. It does not infer success from presentation or consume any
owner receipt. `midgame-state` returns only existing field data and that getter;
there is no independent diagnostics framework or dev projection.

Final checks: the same20 existing host checks pass, all six scenario configs
validate, returned Python patch parses/applies, fixed-script cell continuity
passes, and SDK3.1.2 compilation passes with the final observation patch in a
private staged Source. No new tests/contracts. Evidence:
`evidence/m55-journey-full-compile-01/`. No Simulator, push or delegation.

## Root already installed 722ed45

Use `root-followup.patch` instead of replaying `root-registration.patch`:

```sh
git apply --check tools/harness/scenarios/midgame/root-followup.patch
git apply tools/harness/scenarios/midgame/root-followup.patch
```

The incremental patch assumes the original722 registration plus root's
`midgame-owners`/`midgame-state` observe-allowlist fix. It updates only the existing
observation payload and successful full-slot export. The clean-base registration
patch now also contains that allowlist change, so future clean composition does
not repeat the startup failure. Neither patch runs a Simulator or installs game
behavior. Root's current2331/0 SDK result remains separate from these unrun
journeys; main remains65/222. Apply one patch path, not both.
