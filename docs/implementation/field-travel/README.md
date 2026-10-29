# First 5.5 field packet: Surf, Strength, Fly

Prepared from exact accepted `63267b0` on `t3/field-services-behavior`.
This is implementation preparation, not integrated or native acceptance.
No existing Source file, protected art, baseline, ledger, map content or shared
owner was edited. No Simulator, push or delegation was used.

## Implemented modules

`FieldTravel` owns bounded, detached traversal values and pure plans: Soul-gated
Surf, Rainbow-gated Strength, Thunder-gated Fly, city visit history, source Fly
arrival coordinates, outdoor eligibility, shore/water transitions, automatic
landing and symmetric water-pair barriers. Fainted field users remain eligible;
PP and both RNG streams remain untouched. `canUse` also guards party ownership
and pending progression. Restrictions are explicit inputs from their owners.

`FieldTravelWorld` projects source terrain from the existing provider and the
candidate WorldDeltas. It validates saved surfing water/shore cells without
changing collision. Walking retains FieldWorld's exact Cut-restoration policy;
checkpoints always use the ordinary dry-land validator. Fly arrivals resolve
through the existing explicit slice and padded map descriptors. Authored Pallet
uses the existing reviewed (5,6) home/checkpoint cell and its ordinary validator.
Outdoor checks follow source OVERWORLD/PLATEAU tilesets, not map-name guessing.

`FieldTravelRequests` guards party-overlay selections by session/player/zone
identity, party visit/view, field epoch, roster values, flags, checkpoint, world,
actor snapshot and player pose. Prepare/preview/cancel do not mutate gameplay.
Completion rechecks Surf terrain, actor occupancy and restrictions, then makes
one call to root's `game:commitFieldTravel(expected, plan)`. Tokens are one-shot;
a failed commit cannot be retried. Exit must call `cancel`. No standalone field
controller or parallel player/actor owner is installed here.

`FieldTravel.push` plans one source boulder cell after the second held attempt.
It verifies Strength, source sprite/movement byte, adjacency, free terrain,
directional permission and protected cells. It never edits a tile or actor.
The existing NPCMotion owner must lease, animate and publish that push; map
scripts own subsequent holes/switches and rewards.

## Root-owned patch and integration

`root-api.patch` is **unapplied**. It adds one session-owned `fieldTravel` value,
passes candidate travel to player-location validation, and extends the existing
atomic `captureTraversal`. It also carries the current mode into source-scene
position validation. The codec becomes version 4 and retains versions 1–3.
No item, reward, guard, trade or battle transaction is changed.

Import `domain/fieldTravel` before `domain/gameSession`, and import
`game/fieldTravelWorld` and `game/fieldTravelRequests` before creating GameContext.
The domain module's references to GameSession are resolved only at call time.
Root owns final UI/controller registration and these small dispatch hooks:

- Append `FieldTravel.known(mon)` to the current `FieldMoves.known` results.
- Route those three keys to the root's field controller; keep existing Cut/Flash
  through FieldMoveState. Fly first lists `FieldTravel.destinations(session:fieldTravelData())`,
  then calls `FieldTravelRequests.prepare(game, party, mon, "fly", destinationID)`
  while party is still the top overlay. Non-Fly keys use the same prepare API.
- Push the confirmation overlay only after prepare. Pass that actual overlay to
  `isCurrent`/`complete`; cancel its token on all exits. The standard party-only
  boundary is exactly two stack entries, or three with the confirmation overlay.
- Implement `game:fieldTravelRestrictions(position)` with explicit
  `{forcedBicycle = boolean, currentTooFast = boolean}`. Cycling Road owns its
  forced-bike bit. Later Seafoam owns its exact source stairs/current condition;
  absent input fails instead of silently allowing Surf.
- Root's `commitFieldTravel(expected, plan)` must check the field epoch and live
  context, then commit through `FieldWorld.commit(game, expected.world, snapshot)`.
  Snapshot uses `fieldTravel = plan.travel`, the existing world/actors and
  `location = plan.location or expected.position`. FieldWorld already rolls
  native terrain back if session validation fails. Runtime movement/warp must be
  prepared before this call, settled by the owning Player/Overworld transition,
  and rolled back on failure. Do not commit on opening a menu or starting an
  interpolation. Do not implement Fly by saving a new location and independently
  asking a later fallible callback to warp.
- Fly uses the existing departure/reload lifecycle: reset temporary Cut terrain,
  derive target darkness through FieldWorld, prepare target actors and the
  existing door/warp transition, then publish world/location/actors/travel in
  one traversal. A failed target install must preserve the departing session and
  runtime. The generic request intentionally calls root rather than bypassing
  this lifecycle. Check target actor occupancy during target preparation.
- Every actual map entry calls `FieldTravel.enter(oldTravel, stableID, carriedMode)`
  inside that same traversal commit. Strength resets there; battle/menu returns
  never call it. Explicit surfing connections carry `"surfing"`, blackout/Fly/
  Escape carry `"walking"`; Continue preserves the decoded movement mode while
  resetting Strength and recording the loaded city. Do not reset Surf on every
  OverworldState entry, since that state also resumes after battle.
- Player calls `surfStep` with current source terrain and occupancy before each
  water move. Commit its returned mode/location at the completed cell. Surfing
  and landing must keep the original sprite art, step cadence and encounter
  ownership; water encounter tables belong to the map worker.

## Durable state and migration

`fieldTravel = {version=1, mode="walking"|"surfing"|"bicycle",
strength=boolean, visited={stable city IDs}}` is owned only by GameSession.
Codec validation runs before session publication. Arrays are dense, unique,
bounded to the eleven cities and canonicalized; routes are never Fly choices.
Modes are validated before the candidate player's location. A water exception
never applies to the healing checkpoint or unresolved source bindings.

Versions 1–3 migrate to walking, Strength off, and **empty** Fly history. There is
no complete prior visit ledger; deriving visits from badges, map availability or
healing would invent history. Real later city entries (including the loaded city
on Continue) add that city. Root may choose a separately source-backed migration
if actual additional provenance exists; this packet does not infer it. Current
5.4 saves cannot contain a genuine surfing location. New schema 4 requires the
record and rejects malformed/missing data. Strength resets on the Continue map
entry; a saved surf/bicycle mode is retained when legal.

## Concrete unavailable inputs and later packets

The accepted manifest has no Fuchsia, Celadon, Cycling Road, Warden's House or
Safari content yet. Source sprites, encounter rosters and new map definitions
belong to the map worker. Existing source actor descriptors cannot yet represent
`BOULDER_MOVEMENT_BYTE_2` as a facing selector, nor persist an arbitrarily pushed
STAY boulder. They need an explicit NPCMotion/WorldMotionData source-boulder seam
and an allowed-placement rule; **do not** fake this with tile replacements or
hand a boulder to the ordinary random NPC selector. The Warden's source boulder
is `pokered:WARDENS_HOUSE:objects:3`, at source (8,4); object 2 is the Rare Candy.
No reward or HM acquisition is invented here. HM03/HM04 and their source events
remain separate source-event content work.

Authored Pallet surfing needs its existing reviewed terrain adapter; this first
projection deliberately accepts provider-owned source surfaces only. Missing
maps, unbound arrivals, absent restrictions and absent root commit hooks return
concrete failures. No root-owned registration or Player change is hidden in this
commit. The three prepared SDK contracts cover planner behavior, not completed
runtime integration, disk Continue, actor pushing or visual acceptance.

Bicycle/Cycling Road, fishing, Safari and Celadon services are following packets.
Root privately restored trades/guard drinks in `a30d996`: reuse its Fresh Water,
Soda Pop and Lemonade IDs and existing guard consumption/source bit. Root will
activate Route7/8 guards. This worker must not duplicate that logic or merge
private shared-owner work merely to copy its implementation.

## Checks

`prepare_data.py --reference "$POKERED_REFERENCE_DIR" --check` verifies all
consumed primary bytes against exact Git objects and reproduces two small JSON
outputs. Full extracts remain outside Git. The related host run passed 13 tests
(field-travel pins, existing field-move generation and existing field-world
schema/pins), with no skips. One SDK contract is prepared per new behavior.
No SDK contracts were executed by this worker.

Compile the unapplied patch plus imports in a private tree with:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/field-travel/compile.py --output "$POKEMON_ENV/evidence/field-travel-root-compile-UNIQUE"
```

Root can register `FieldTravelContracts.run` after importing
`dev/fieldTravelContracts`. Its tests neither edit shared fixtures nor add driver
contracts. Compilation does not establish gameplay or migration correctness;
root must run the integrated SDK and earned-save journeys after integration.
