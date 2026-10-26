# Private 5.4 scene packet

Based on **exact `c6882b696fa9e0b8b4f43e7bb46fffacceeb11f6`**, branch
`wip/anne-surge-scenes`. Preparation only. No Simulator, device, natural journey,
visual acceptance, push, shared import/cache/manifest/ledger edits or delegation.

The runtime modules are `game/vermilionStory*.lua`. The generator is
`tools/generate_vermilion_story.py`; its immutable originals and SHA-256 pin are
in `tools/references/vermilion-story`. It reproduces only bespoke dialogue,
events, two scene trainers, movement and small terrain-key projections. It does
not duplicate ordinary Vermilion rosters, map layouts or new bitmap art.

## Root composition

Apply **`tools/patches/vermilion-story-root-api.patch`** separately. It adds:

- `GameSession:forkWorldRNG()` and `:transactScene(expected,changes,scene)`:
  detached world-stream sampling; live world/RNG compare guards; preflight of
  world, location, checkpoint and next stream; rollback through WorldDeltas if
  the existing bag/flag transaction rejects; prepared final owner assignments.
- Thunder badge lookup. Coordinate this line with the Cut/Flash worker.
- The actual DoorWarp descriptor on the existing `onLeave` boundary, and a
  boarding/departed-ship door policy before a transition starts.
- One leased transit exception: BLUE at source `(36,5)`, immediately below his
  actual captain warp home. Actual warp placement remains forbidden. The
  existing eight-frame NPCMotion step/reservation/token owner is unchanged.

Import these AFTER `game/kantoServices` and before scene installation:

```lua
import "game/vermilionStory"
import "game/vermilionStoryTerrain"
import "game/vermilionStoryIntent"
import "game/vermilionStoryHooks"
import "game/vermilionStoryState"
```

After the new map manifest/content owner is installed, before constructing
TrainerEvents, call:

```lua
VermilionStory.install({reconcileActors=KantoScenes.reconcileActors})
-- projectWorld defaults to the pure VermilionStory.sourceWorld projection.
```

Replace the ONE root event registration with `VermilionStoryState(game)`.
It extends KantoServicesState and retains all prior controller layers. Merge
`VermilionStory.actorMetadata(event.id, game).visibility` into the ONE content
resolver, for runtime and immutable validation. The scene exclusively owns its
20 event IDs (`events.json`), including the boarding sailor, Captain, BLUE,
Surge and hidden trash events 4–18. Exclude them from the ordinary event
registration. The two trainer IDs are exclusively registered here. All hooks
use the existing SourceEvents registry; there is no second dispatcher.

## Concrete content dependency

Read-only coordination inspected content worker branch `wip/vermilion-content`
at `fff7f90fca07a83323b37a6035098dbf8da862ed`, especially
`Source/data/vermilionPreparation/proposed-compact.json`. Nothing was copied or
changed in that checkout. Those candidate maps are not installed on this base.

The ordinary candidate atlas already supplies floor and dock-water keys, but
**does not supply `pokered:GYM:cell:20-21-30-31`**. The content owner must generate
that original closed-door cell's grid and collision metadata from Gym block
`$24`, and include it in the shared compact metadata AND grid lookup. No art is
hand drawn here. Initial Gym beforeSpawn intentionally fails loudly until this
key is installed; raw Blue layout has the door OPEN and the script closes it.

`terrain.json` gives exact block locations and quadrant keys: Gym block `(2,2)`
becomes `$24`/`$05`; dock blocks `(5..8,2)` become water `$0d`. The pure projector
preserves unrelated deltas, applies padding once, and returns a detached complete
WorldDeltas payload. The session API commits puzzle result/source flags, terrain
and the advanced world stream together. No direct tiles, live ledger, NPC grid
coordinates or global randomness are assigned by the scene modules.

## State and source behavior

Durable state stays in session quest/trainer flags. `VERMILION_SCENE_V1_*` is a
bounded versioned encoding: initialized, two four-bit can indices, two alternating
transaction revision bits, BLUE shown, and a pending dock-exit intent. The
original `EVENT_1ST_LOCK_OPENED`, `EVENT_2ND_LOCK_OPENED`, Captain/HM01, ship,
Surge, badge and TM24 flags remain the authoritative outcomes. There is no UI
progression owner or new save schema. The alternating revision bits only satisfy
the existing bounded false-to-true transaction guard on reversible operations;
they are not an unbounded event history. Root session-owned opaque intent tickets
are single-attempt and bind the session plus a transient commit epoch, rejecting
ABA/replayed plans even when reversible flags return to the same values. No
transient ticket is serialized. Epoch/serial/session/player/zone guards
remain in EventState, and source actor motion remains under opaque leases.

Boarding checks actual S.S.Ticket quantity and retains the ticket; denial backs
the player up. BLUE appears at the source trigger and uses the existing immutable
`TrainerEvents.rival_parties` resolution/token. Loss pays/hides/defeats nothing;
confirmed victory pays ¥1300, commits the victory flag, then walks the correct
source departure path. Squirtle/Charmander/Bulbasaur player starters face
Ivysaur/Wartortle/Charmeleon respectively, with Pidgeotto19/Raticate16/Kadabra18
and evolved starter20. Gen V construction/battle rules remain unchanged.

Captain rub completion persists even when the bag is full; HM01 and its flag
commit together on retry. This packet grants HM01 only; no field menus or Cut/
Flash APIs are introduced. Confirmed Surge victory grants Thunder badge,
source victory flag, ¥2376 and gym trainer deactivation; TM24 retries separately
without consuming badge/payout twice. Surge's original team is Voltorb21,
Pikachu18, Raichu24.

Actual SSAnne1F warp 1 OR 2 after HM01 arms the dock intent. Arbitrary dock entry,
Continue, HM possession, Captain dialogue or earlier ship exits do not depart
it. The dock controller commits source departure/terrain and uses the real north
warp. Door policy prevents reboarding after departure. Cancellation before the
60-tick initial delay commits no departure; an already committed pending exit
resumes without another departure commit. The source lower-ship erase blocks
are retained. **The original scrolling ship/smoke/horn animation is not rendered
by this packet**; only its initial source delay, durable outcome and automatic
walkout are prepared. Content/audio/root must finish and visually accept that
presentation. Automatic walkout uses the importer's actual dock arrival (2 or 3
cells to the north exit), followed by the existing DoorWarp owner.

## Narrow fidelity recommendation

| Topic | Pinned Blue observation | Recommendation |
|---|---|---|
| Surge trash selector and entry | 15 cans; first `Random & $e` on Vermilion **City** load; second `swap(Random) & mask` minus one. Underflow reads ROM padding and can select nonadjacent can 0. Wrong second resets first lock/index; city/Gym scripts do not clear the lock flags on entry. | Keep the pinned selector, including rare can 0, as implemented. Do not claim strictly adjacent/uniform selection or Gym-entry lock reset. Continue preserves the saved world stream/index rather than silently rerolling. If root elects adjacency or every-Gym-entry reset, approve an explicit adaptation before changing it. |

No broad fidelity dossier or shared ledger was modified.

## Validation prepared / still pending

Host: 12 new primary pin/generator checks and 38 scoped checks passed, zero skips;
54 protocol host checks passed. No host Lua execution/transpilation. Generator
uses literal UTF-8 and stops at ANY ASM global-label boundary, preserving local
movement fallthrough. Pins verify both vendored and external original bytes.

SDK: real provider-owned fixture + cases in `dev/vermilionStoryFixture.lua` and
`dev/vermilionStoryContracts.lua` cover both trigger paths/all three teams,
confirmed win/loss, immutable/stale trainer tokens, eight-frame leases and
cancellation, Captain full-bag retry, wrong first/second, terrain rollback,
source entry/reset behavior, solved terrain, world RNG isolation, codec round
trips, badge/TM24 retry and departure authorization/cancellation. They require
actual installed maps/art and root APIs; missing integration fails, never skips.
The fixture uses actual SDK sprites, provider Zones, session, event, motion and
battle owners; its settled exploration shell does not claim traversal acceptance.

Root-only registration (outside this branch's unchanged dev import overlay):

```lua
import "dev/vermilionStoryFixture"
import "dev/vermilionStoryContracts"
Contracts.register("vermilion-story",function()
    return VermilionStoryContracts.run(VermilionStoryFixture.withScene)
end)
```

The two `tools/harness/scenarios/vermilion-story/*real*restart.json` jobs prepare
actual separate-process Save/Continue witnesses: a real second-switch solve,
and an actual post-HM01 ship exit/automatic walkout. They use existing explicit
supplementary fixtures for starting state, real input for transitions and Save,
no fixture in generation two, and native saved/loaded owner observations. Root
must compare saved/loaded world/RNG payloads, process IDs/generations, door
collision and images. These are NOT natural campaign completion proof.

Compile-only evidence under `$POKEMON_ENV/evidence/`:
`anne-surge-scenes-build-20261026-01` (standard harness), and
`anne-surge-scenes-integrated-compile-20261026-02` (private copy with root API
patch and explicit module/SDK imports). Neither launched Simulator or executed
contracts. Host log: `anne-surge-scenes-host-20261026.log`.

Root still owns content activation, missing closed-door art, resolver/composition
changes, full source departure presentation, SDK execution, process restarts,
new art review, natural Ticket→HM01→Surge journeys, protected catalog comparison,
coverage/baseline review and independent acceptance. **5.4 is not complete.**

## Exact next-packet dependencies outside this scope

- Fan Club chairman/voucher: source `scripts/PokemonFanClub.asm` and
  `EVENT_GOT_BIKE_VOUCHER`; bag-full retry must hand `bikeVoucher` to existing
  `KantoServices.bicycleExchange`. No second Bicycle owner.
- Old Rod house: `scripts/VermilionOldRodHouse.asm`, `EVENT_GOT_OLD_ROD`, key item
  `oldRod`, full-bag retry and a separate fishing owner/Gen V encounter policy.
- Day Care: `scripts/Daycare.asm`; requires cohesive deposited-specimen ownership,
  storage capacity, per-step XP/fee/retrieval and save/blackout semantics. A gift
  or ordinary shop descriptor is insufficient.
- HM05 aide: `scripts/Route2Gate.asm`, original owned-species count threshold 10,
  `EVENT_GOT_HM05` and `hm05`; grant/full-bag retry belongs in the next content
  packet. Actual Flash/Cut teaching/field intent belongs to the field-move worker.
