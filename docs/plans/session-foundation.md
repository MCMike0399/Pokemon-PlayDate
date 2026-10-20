# GameSession and aggregate persistence

Root integrated the four-file package after all 178 native SDK contracts passed,
including eleven session groups. The later capture run passed 194 total contracts.
[Durable domain evidence](../validation/accepted-session-items-capture/acceptance.json).
GameContext/Story migration and native Save/Continue are separate integration
work; this aggregate codec alone does not establish player-facing persistence.
The remainder records the original API handoff and integration requirements.

## Exact files and dependencies

- Source/domain/gameSession.lua
- Source/domain/sessionCodec.lua
- Source/dev/sessionContracts.lua
- Source/domain/inventory.lua (only new internal `_replaceData` method)

foundation.patch adds the three modules and appends only that validated helper. foundation-manifest.json records hashes
and the live dependency revision/bytes observed while staging. Apply only after
root accepts the pure WorldDeltas seams. Required existing interfaces are Class,
Party/Storage/Inventory, PokemonCodec, SaveStore, DecimalInteger and
RulesRNG.new/toData/restoreData. Required world dependencies:

    validateWorld(payload) -> normalized defensive payload, or throw
    resolveLocation({zone_id,x,y,facing}, candidateWorld) -> same validated copy,
        or throw

The world worker staged these as WorldDeltas.validate and resolveLocation in
/private/tmp/pokemon-world-foundation/Source/world/zone.lua. Validation must use
the COMPLETE candidate world (omitted zone delta means initial baseline), reject
unresolved campaign maps and validate passability for location AND checkpoint.
Session code never calls WorldDeltas.apply while decoding. It also rejects a
normalizer that silently drops input fields, while permitting canonical sorting,
so unsupported world snapshot data cannot disappear during aggregate decoding.

Root integrated the growth worker's PokemonCodec version 2 after its SDK cases passed; old species/XP
records are rejected rather than guessing a migration. SessionCodec delegates semantic Pokémon
validation dynamically to the current PokemonCodec. Aggregate version 1 is new
and unreleased and may nest that codec 2 once root integrates it; no existing
player aggregate saves are silently migrated. The nested numeric transport is a
separate explicit marker, decimal-counters-v1.

## Small interface and ownership

    local deps = {
        itemDefinitions = {potion={keyItem=false},oaksParcel={keyItem=true}},
        validateWorld = WorldDeltas.validate,
        resolveLocation = WorldDeltas.resolveLocation,
    }
    local session = GameSession.newSession(deps, {
        location={zone_id='reds_house_2f',x=5,y=3,facing='up'},
        checkpoint={zone_id='reds_house',x=3,y=7,facing='up'}, seed=42,
    })

GameSession owns exactly one Party, Storage and Inventory. party(), storage() and
inventory() return those actual models; activePokemon() always derives
Party:active(), never stores another mutable Pokémon owner. recruit(actualMon)
uses party first, then ONLY the currently selected box on party-full. It records
seen/owned species only after successful acquisition. Full current box and
already-owned failures leave all state unchanged; another box is never selected
silently. Acquisitions must use recruit, not bypass dex invariants via party:add.

getIntro()/setIntro(tuple) own the entire existing intro tuple: stage,
starter/rivalStarter and nullable boolean rivalOutcome. setIntro validates a
batch so the adapter cannot expose a half-selected starter/counter. No Story
singleton is consulted by the model. The root must migrate Story to delegate to
this owner; script text/functions may remain shared immutable content. The
adapter must batch choose/skip/outcome updates rather than copy fields into a
second persistent singleton. getIntro returns a defensive copy. False rival loss
is preserved distinctly from unresolved nil through the aggregate wire format.

setQuestFlag(id,value) and setTrainerDefeated(id,value) take boolean values with stable keys
1–128 ASCII bytes (letters/digits, underscore, colon, dot, slash, hyphen), at most
4096 each. Corresponding getters default absent flags to false. Root assigns
stable authored trainer IDs, e.g. pallet_town/npc/blue-rematch; never persist NPC
pointer/name-only identity. Pokedex seen/owned use existing canonical 151 species
IDs, not art filenames. owned implies seen and every collection member requires
both flags. Early pre-starter records cannot have owned monsters/history.

location()/checkpoint()/worldData()/flags()/pokedex() return defensive values.
captureTraversal({location,world,checkpoint?}) validates the candidate fields
together before one commit. Root uses this at the settled snapshot boundary: a
new world may close the old player position while the player has moved elsewhere.
Separate setWorld then setLocation calls would incorrectly reject that valid
snapshot. The convenience setWorld/setLocation methods retain their strict
individual semantics. setLocation validates against the session's complete candidate world; optional
true checkpoint mode updates checkpoint as well. setWorld preflights the new
world plus current location/checkpoint before replacing its stored payload.
These methods do not mutate the active global world or sprites. The injected
WorldDeltas module remains the actual world mutation seam; root keeps its live
view synchronized with the session's normalized persistent world snapshot.
Numeric tile-registry slots are never serialized, only stable world keys.

Title metadata is fixed playerName RED, rivalName BLUE for this version. There
are no arbitrary extension objects, dynamic naming UI, generic event framework
or class per data row. All persistent fields are explicit and versioned.

## Bounded item/quest event transaction

    local expected={flags={EVENT_GOT_OAKS_PARCEL=false},items={oaksParcel=0}}
    local changes={
        items={{op='add',id='oaksParcel',quantity=1}},
        flags={EVENT_GOT_OAKS_PARCEL=true},
    }
    local ok,reason=session:transact(expected,changes)

The operation covers item transfers and boolean quest flags only, not world,
dialogue, Pokémon effects or arbitrary callbacks. Requirements check exact item
quantities and flag values at execution time, so a dialogue-time observation
cannot commit after relevant state changes. Limits are 32 guards/operations/flag
writes; quantities are 1–99 per add/take, or exactly one for handoff. `take` calls
ordinary Inventory.consume; `handoff` explicitly consumes a key item. Every
transaction must check a false completion flag and write that flag true, making
repeating the same one-time reward fail rather than duplicate it. A flag-only
unlock uses an empty items array and still needs the one-time guard.

All item changes run on detached Inventory state and every new flag/value/count
is validated before commit. A full bag, absent parcel, later operation failure,
stale guard, wrong quantity or flag-limit error leaves the original bag, wallet,
flags and RNG unchanged. Semantic failures such as bag-full, insufficient-items,
stale-flag and stale-item return stable reason strings. The internal
Inventory:_replaceData helper validates once more then swaps private data while
preserving the same Inventory object identity; retained bag references remain
valid. It invokes no user scripts/yields. Root's source event planner/executor
owns dialogue and effect ordering. This deliberately repairs original full-bag
flag-before-grant behavior; root records the deviation in the fidelity ledger.
Canonical production item IDs are lowerCamel, including oaksParcel; source flags
may keep their exact EVENT_* names. A Pokédex unlock is a quest flag, not an
invented bag item.

## Codec and SaveStore composition

    local gate={root='overworld',overworld='explore',settled=true}
    local record,err=SessionCodec.encode(session,gate)
    local candidate,err=SessionCodec.decode(record,deps)
    local store=SessionCodec.store('player-save',deps)
    local ok,metadata=SessionCodec.save(store,session,gate)
    local candidate,metadata=SessionCodec.load(store,deps)

The gate is a root-supplied observation of the actual runtime, not a persisted
claim. Root must construct it from the current top state/substate/settled player;
never allow callers to save during battle, movement, door/iris transition or
modal overlay. Only stable intro stages pre_oak/choose/pre_rival/done are savable;
there is no dialog index, coroutine, animation timer or partial battle resume.

The aggregate has a strict known field set: version/pokemonEncoding/title,
intro, questFlags, trainerFlags, pokedex, location, checkpoint, complete world,
party, storage, inventory, RNG. It rejects unknown versions/fields, malformed
nested collection schemas/indices, item definitions/quantities, unowned dex
members, bad story pairs/outcomes and unavailable locations/world revisions.
The entire candidate is semantically validated before any Pokémon is decoded
into privately owned collections. Decode uses actual production Pokemon objects,
not saved stat copies. It never touches the current session or global RNG/world.

The authoritative PokemonCodec primitive format is preserved semantically.
SessionCodec's explicit wire adapter converts XP, nextMoveChoiceId and pending
choice IDs to bounded canonical decimal strings before JSON, then reconstructs
native integers BEFORE invoking PokemonCodec on load. Source choice tuples and
all selected moves/PP/status/HP remain intact. This avoids losing otherwise-valid
wide counters without changing the growth worker's codec schema. Global RNG uses
its accepted toData/restoreData string format; no raw numeric snapshot is saved.
Bag amounts, collection indices and coordinates have small validated bounds.

SaveStore validates aggregate payloads through SessionCodec.validate and retains
its accepted two-slot checksum/sequence/corruption policies. Loading a store only
returns an unattached candidate. No Continue UI or global GameContext assignment
occurs. A malformed payload leaves current objects, world and rules RNG unchanged.

## Explicit activation and root lifecycle recipe

Candidates keep validated RNG wire data, not a second active mutable stream.
activateRNG() deliberately restores the single production RulesRNG facade. The
previous active session is retired with a frozen copy of its last RNG wire state;
the newly active session thereafter reads the facade directly. deactivateRNG()
freezes it without altering the global stream. Decoding/validation never calls
activation. GameSession.activeRNGSession exposes only that explicit ownership.

Root owns the remaining lifecycle transaction:

1. Read/validate the full candidate without changing context, Story, world or RNG.
2. Stop old runtime input/update at a safe frame. Preflight location/checkpoint
   against candidate world; stage the replacement scene and preserve rollback
   information for existing view/world changes.
3. Apply candidate world through its transactional owner. If it rejects, retain
   the old session/RNG. Then activate candidate RNG and replace the single
   context.session pointer in the same non-yielding lifecycle operation. Root
   owns rollback if any later lifecycle step can fail; do not claim the model
   itself swaps arbitrary UI/sprite graphs atomically.
4. Restore Story adapter delegation, selected zone/player/checkpoint and stable
   trainer bindings from the new session. Dispose retired views/listeners.

Do not leave game.playerPokemon as an independent owned record. Replace reads
with context.session:activePokemon() (or a forwarding accessor) and route starter,
capture, storage and battle selection through the real party. Do not keep
Story.stage fields and session intro fields independently mutable. Whole-session
fixtures/new game create a new GameSession instead of clearing half the old one.
Root still owns these existing files and their migration; this patch changes none.

## Root-only SDK validation

After applying the four-file patch to an owned integration build and using the
new pure world seams, import after domain/world/map dependencies:

    import 'domain/gameSession'
    import 'domain/sessionCodec'
    import 'dev/sessionContracts'
    Contracts.register('session',SessionContracts.run)

The preferred staged helper uses CURRENT project Source and overlays ONLY the
four manifest files, adds imports/registration in its private build, recomputes
the actual identified fingerprint and preserves normal artifact publication:

    python3 /private/tmp/pokemon-session-foundation/validate_staged.py \
      --project <checkout> --output /private/tmp/pokemon-session-compile-UNIQUE

The same command with `--execute` is for the sole root Simulator owner only.
It runs contracts/catalog/a native checkpoint and finalizes evidence under the
normal runner. Without that flag it only compiles and never creates bundle Data.
The Inventory base must match the handed-off original or already-integrated bytes;
new owned files may not overwrite unexpected current changes. No old world, growth,
codec, main or Story source is copied from staging.

For an already integrated root checkout, recompute the identified build and run:

    python3 tools/harness/run.py contracts catalog 'shot session-foundation' \
      --output /private/tmp/pokemon-session-foundation-sdk-01

The eleven real SDK groups cover empty/new pre-starter records; starter and full
party/current-box acquisition/ownership; complete aggregate JSON roundtrip with
sleep0/0PP/wide choice IDs/last box/flags; malformed candidates preserving active
objects/world/RNG; typed setters and candidate-world solid/open location cases;
atomic traversal snapshots; partial/full-bag/repeat/stale item+quest transactions with retained bag identity; unsafe save gates; explicit RNG activation/retirement; actual SaveStore aggregate
roundtrip without automatic install. RNG activation tests restore the prior owner
and exact initial global RNG. The filesystem case requires the private harness
bundle and uses only a unique session-contract-<session>-<invocation> prefix;
normal slots are retained for evidence. No fake Playdate or fake Pokemon engine.

Run protected visual comparison and native intro regressions on the integrated
revision before acceptance. Those regressions protect the existing game while
this remains unconnected foundation code; they do not establish party/PC/menu/
Save/Continue gameplay. Next UI, checkpoint/healing, capture, battle party switch,
trainer/quest binding and campaign ownership integrations remain root tasks.
