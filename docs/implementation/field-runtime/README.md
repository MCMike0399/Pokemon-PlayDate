# First runtime Surf / Strength / Fly packet

Base: exact root `f96878a`, then actor `dbf662f`, then exact root `41ea57d`.
The final root merge retained root's sourceActors/NPCMotion versions, which include
both actor commits and the stricter source stairs/tile-pair push checks. This
worker did not author shared actor-owner changes. Root's trade/drink restoration,
171 definitions, refreshed shared fixture and arrival helper remain intact.

## Runtime behavior

Party lists the known Surf/Strength/Fly actions beside existing Cut/Flash.
FieldTravelState handles the city picker, default-NO confirmation, announcement,
B cancellation and completion. Opening/picking/confirming a menu alone never
changes the saved mode. A confirms the announcement; Fly then uses the existing
12-frame shade fade. Success closes both field and Party overlays. Read-only
`game:getFieldTravelSnapshot()` reports installation, mode, Strength, visited
city IDs, current key/phase/destination, pending player cell and the latest typed
attempt result. Observation never creates a success receipt.

Surf reserves the adjacent source water/shore cell and advances the existing
reviewed RED frames for eight ticks. Player's logical cell and the session remain
at the origin through tick seven. Native rendering and final target/owner/world
validation finish before the existing `captureTraversal` publishes location,
actors and mode. Only primitive settled assignments follow. Failure or B/exit
cancellation restores the origin pixels and leaves mode/location/RNG unchanged.
The same owner handles every later surfing step and automatic landing on land;
source water-pair barriers, bindings, padding and NPC reservations remain strict.
No logical encounter/door/Day Care step occurs during partial interpolation.
Boarding awards its completed Day Care step once through the field controller.
No replacement RED art or guessed surf sprite is introduced.

Strength activation commits the existing single `fieldTravel.strength` value.
Repeated blocked D-pad attempts on a tracked boulder open the same field
controller. It leases exactly the actor worker's begin/update/cancel API, holds
the player stationary for eight ticks and cancels on exit. No tile mutation or
second actor state exists. The next ordinary held D-pad step can enter the
vacated cell. Current-map actor poses retain the actor owner's Save/Continue and
battle-return behavior; actual map re-entry resets them. Continue resets Strength
activation while preserving a valid surfing/bicycle mode.

Fly uses only visited city destinations. `FieldTravelRuntime.fly` retains the
old player, manager and view, applies candidate world resets with undo, constructs
the actual destination Zone/view/Player/actors, validates source actor occupancy,
prepares the camera and view handoff, then calls `captureTraversal` LAST. No new
session location is published before native installation can fail. On rejection,
new sprites/view are removed, the old runtime identities, camera, registry and
world are restored, and the departing session remains unchanged. On success,
only best-effort old-resource disposal follows publication. Root's
`WorldView.exchangePrepared` hook lets the old view stay available throughout.
The already-installed visit processes ordinary on-enter hooks when exploration
resumes; no input or story step runs during staging. Source Cut reset, darkness,
actor rebuild, exact arrivals and city history use their existing owners.

FieldWorld records city entries in the same traversal transaction as location
and mode, without resetting on battle/menu return. It resets Strength on actual
entry/Continue. Its player-only location fallback now accepts root's immutable
`SourceMaps.isDoorArrival(name,x,y)` cells only on the exact unchanged source key,
with WorldDeltas validation, slice/bounds/facing and explicit blockers intact.
Checkpoints retain the ordinary strict validator. No nearby free-cell relocation
or collision override was added. Root's existing SourceMap arrival contract is
also the owner of that Save/Continue behavior; no duplicate arrival contract.

## Small root hooks

`root-hooks.lua` lists two imports, one controller registration, the existing
Rainbow/Soul badge flag names and the SDK contract registration. Apply the small
`view-handoff.patch` in the shared WorldView owner. Main, dev_imports,
GameSession, SessionCodec and shared actor modules were not edited by this packet.
The root's session v4 API is used as installed. The badge table in `41ea57d`
still needs Rainbow/Soul; unsupported names otherwise throw before eligibility.

## Checks and remaining inputs

SDK 3.1.2 compilation passed with the returned view/badge/import/registration
hooks applied in a private tree. Final evidence is the environment directory
reported with the commit. Thirty-two scoped host checks passed with no skips:
source gear/travel pins, existing field-move/world policy, source placement and
motion. Two EXISTING travel behavior cases were expanded for real SDK objects:
Surf seven/eight-frame publication, landing, cancellation, capture rejection and
codec/Continue; Fly destination install, rejected commit rollback and codec.
They compile but have not executed. Strength uses the actor worker's one already
registered Warden contract. The old pure Strength case was removed to keep the
cap. The earlier gear contract report wrapper was corrected to the actual
Contracts suite API; no new gear case was added.

Root alone must execute the SDK contracts and real input journeys; this packet
claims neither native behavior nor milestone acceptance. Production Source may
still fail a callback or input branch that compilation cannot exercise.

Remaining explicit limitations: authored Pallet Surf still needs its reviewed
terrain adapter (source provider projection deliberately refuses it); cross-map
surfing connections still use the existing land-only connection adapter. Water
encounters need the map/encounter owner's water-policy seam; this packet does not
invent water encounter slots. These do not prevent the first Fuchsia pond Surf,
landing, Warden push or visited-city Fly checks. Seafoam current/hole/switch
behavior remains 5.6 and fails without its exact source controller. The mode uses
reviewed existing RED frames pending source surf/bike/fishing art from its owner.
Bicycle/fishing presentation, Safari mode and Celadon services remain following
packets. Never report their preparation modules as completed journey behavior.
