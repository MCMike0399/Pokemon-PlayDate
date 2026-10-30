# Bicycle and fishing packet

Prepared after `651f26c`, with no shared Source owner edited. Root alone runs
Simulator and integrates the returned hooks. No push or delegation was used.

`FieldCycling` implements source mount/dismount eligibility, the four Route16/18
forced-bike entry cells, gate reset/admission paths, Route17 automatic descent,
A/B brakes, and source speedup suppression for up/sideways steering. Coordinates
for this policy are source cells; subtract runtime map padding. FieldTravel keeps
the existing saved movement mode. The source forced-bike status uses one existing
saved boolean flag, `pokered:status6:BIT_ALWAYS_ON_BIKE`; no extra codec field.
The existing Bicycle exchange and its source reward remain unchanged.

`FieldFishing` implements Old/Good/Super Rod responses from pinned Blue tables.
Old Rod always yields level-5 Magikarp. Good/Super sampling preserves source byte
rejection: two-slot tables bite one-third of the time, three-slot tables 3/7 and
four-slot tables 1/2. Unlisted Super Rod maps return no-fish without drawing.
Sampling is bounded; exhaustion fails without publishing detached RNG. A bite
uses the existing Specimen owner for the actual original-151 Gen V Pokemon and
its acquisition traits; existing acquisition gaps fail visibly to the caller.
These are Blue field/script odds; no new Gen V fishing field-ability policy is
introduced. Combat, capture, party/storage rewards and Safari battle admission
remain in their existing owners. Rods are never consumed or implicitly granted.

`FieldGearRequests` supplies Bag/registered-item preparation, cancellation and
one-shot completion. It checks settled exploration, owner/visit/pose/epoch,
inventory, flags, both RNG streams, actors and world. Rods require facing the
source water/shore surface and refuse surfing, matching FishingInit. They do not
add Surf's pair-collision test. Rechecking occurs before sampling. Cancellation
or failed validation publishes no RNG. A completed no-bite attempt legitimately
advances rules RNG; a successful bite creates a detached enemy, never recruits it.

Root hooks are in `root-hooks.lua`; the small private-session method to compose
is `root-cycling-method.lua`. Neither is applied. The session method validates a
mode-only candidate, compares the field epoch/current mode/source bit, commits
the boolean through the existing session transaction, preserves settled actors,
then publishes the already-validated mode with no intervening fallible work.
Root must compose forced-bike changes with map traversal atomically on entry;
do not publish the flag/mode after an independent fallible warp callback.

Register the same four item actions (`bicycle`, `oldRod`, `goodRod`, `superRod`)
for ordinary USE and registered A+B through the existing Bag action table. The
approved registered-item feature is reused, not replaced. Root's final controller
must cancel on exit, close overlays and use FieldBattle for a caught bite. Root
must preflight battle registration/admission before completion and retain its
normal recovery for native battle construction failure; this packet does not
claim atomic native battle construction or compensate RNG by re-resolving a rod.

Remaining concrete inputs: runtime bike/fishing art belongs to the map/art worker;
this packet changes no protected RED frame. Root still owns Player interpolation,
logical step/encounter timing and the UI/controller registration. Authored Pallet
fishing needs its terrain adapter; FieldTravelWorld currently projects provider
surfaces only. Gate dialogue/bindings belong to the source-content worker:
`pokered:ROUTE_16_GATE_1F:objects:1` and
`pokered:ROUTE_18_GATE_1F:objects:1`. The returned gate plan gives the source
approach/return walk for EventState. It does not add another player/NPC owner.
Good/Super Rod acquisition events remain source-content work. Safari fish must
enter Safari's own battle mode, never the normal battle hook in isolation.

Checks: 14 scoped host checks passed with no skips (source pins/generation and
existing field policy checks). The API candidate plus small root cycling method
compiled with SDK 3.1.2 at environment evidence `field-gear-compile-20261028-01`.
Two behavior contracts are prepared (Bicycle/Cycling Road and rods/fishing); none
was executed. They cover pure source sampling and cancellation/stale/one-shot
RNG behavior with real session/specimen owners, not natural input acceptance.
No fixture/driver contracts were added. The final compile path is recorded in
the commit handoff. Generator inputs remain in the external pinned checkout;
only small checksums and bounded runtime policy are committed.

Root's privately restored drink/trade logic remains untouched. Later Department
Store work must use `freshWater`, `sodaPop`, `lemonade` and the root guard owner.
