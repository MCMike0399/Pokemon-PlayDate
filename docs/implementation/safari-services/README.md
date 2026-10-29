# First Safari services packet

Prepared on the existing field branch after `2220cdd`. All shared runtime,
actor, session, codec, main and harness-import files remain untouched by this
packet. No Simulator/runtime, push, delegation, baseline or ledger changes.

## Implemented preparation

SafariGame owns pure versioned lifecycle plans. GameSession retains the sole
saved `{version=1,active,steps,balls,ending}` tuple through the returned patch.
Admission is exactly ¥500, 30 separate Safari Balls and the raw source 502-step
counter. Source checks zero before decrement; a check at zero begins the return.
The module does not silently translate this to a 500 budget. Root must count the
actual source entrance/rest-house simulated cells once, alongside ordinary cells,
and never count overlay/idle/partial interpolation frames. The source active and
game-over flags are mirrored in the same session commit as the tuple and fee.
Confirmed early leave retains the source's unused counter values; completed
forced return zeroes balls and clears both flags. No Safari Ball enters the bag. Source Escape Rope clears active Safari and
Safari Balls without a fee refund; the returned GameSession wrapper composes
that already-validated tuple/flag change around the existing guarded Escape Rope
item/world commit. A failed Rope commit leaves Safari unchanged. It does not use
a separate after-warp mutation callback or modify the shared FieldItems owner.

SafariBattle owns a separate command tuple and bounded source turns: ball, bait,
rock and run only. It never instantiates Battle or exposes attack/switch/Bag
commands. Bait halves the current catch byte (possibly to zero); rock doubles it
with saturation. Their 1–5 duration draw retains source rejection and saturating
stacking. Each clears the other counter. Source eating/anger decrement occurs
before the escape test, including catch-rate restoration when anger expires.
Escape uses the Gen V enemy specimen's actual speed low byte with the source
Blue doubling overflow, bait division, anger saturation and byte comparison.
Run is guaranteed and draws nothing. No damage, PP, fainting, combat XP or
player/party reorder is produced by this loop.

Typed Safari turn requests bind session/epoch/location/resources, real enemy
codec, party values, flags, inventory, selected storage box and rules snapshot.
Prepare/cancel publish no state or RNG. `_commitPlan` samples on a detached
RulesRNG and rechecks before returning privately validated publication values.
The returned root session method preflights capacity, recruits a caught specimen
through GameSession, then publishes already-validated balls/RNG. Full storage,
stale requests, missing capture policy and sampling failure spend nothing.
Turn tokens are single-use. The root controller owns admission/presentation and
must not mistake preparation for a caught receipt.

MidgameServices is the ONE added service dispatcher over SourceEvents, with one
inherited MidgameServicesState executor preserving NPCTradeState/Day Care/story
behavior. It registers only the reserved Safari gate workers and Warden. HM03
and Gold Teeth already have installed source gift/pickup descriptors and are
asserted/reused: no duplicate grant or flag is created. Warden removes Gold Teeth
before adding HM04 in one detached inventory/session transaction, so a full bag
with Teeth has room afterward. Cancellation before commit loses nothing; an
actual failed gift preserves the item/flags for retry. Existing
EVENT_GAVE_GOLD_TEETH supports source retry when Teeth were handed over earlier.
Already received HM04 produces only the original explanation. Warden's initial
YES/NO gibberish and the second gate worker's information choice use source text.
Receipts follow the guarded transaction. The shared service dispatcher is the
extension point for subsequent Celadon services, not another event machine.

## Root-owned state and hooks

`root-api.patch` is unapplied and limited to GameSession/SessionCodec. It proposes
private codec v4 (unchanged version); v1–3 migrate to an empty inactive tuple. A legacy save claiming active
Safari source flags without resource provenance fails explicitly rather than
inventing 30 balls/remaining steps. V4 requires the tuple and the coin counter and validates it against
the source flags before candidate session publication. Active Safari budgets
survive Continue; they do not reset on reload, map entry or battle return.
Coins join that same private v4 shape as a true 0–9999 session counter, not a
bag stack or encoded flags. The limit is derived from Blue's two-byte BCD source;
no coin service or public setter is installed in this first packet. Accepted v3
saves migrate coins to zero, never an inferred payout. Root updates its existing
SessionFixture conversion once; this worker does not repair native fixtures.
Counters fit SDK JSON integers exactly. HM/Teeth flags/items retain existing v4
inventory and quest serialization; no second reward store exists.

`root-hooks.lua` gives imports, ONE event executor replacement, source trigger,
completed-step/battle hooks and the exact passage requirements. The entrance
state deliberately fails with `safari-owner-or-passage-not-installed` until root
supplies `prepareSafariPassage`. That hook must preflight source alignment/walk/
warp, retain the current EventState identities during dialogue, commit fee and
counters together, and use the existing guarded warp executor. Native transition
failure recovery is root-owned; this packet does not claim atomic native passage.
Root must also implement the confirmed early-exit and forced gate return
controller. Source gate warp3 and its walk are used unchanged, never a nearby
free-cell substitute. Doors must not bypass admission merely because map data
is installed. `SafariGame.observe(game)` exposes read-only resource/source reward
facts and separately reports whether the session API and Safari battle state are
installed. It never synthesizes a success receipt.

## Concrete capture gap

`docs/validation/capture-foundation.md` explicitly leaves the Blue Safari / Gen V
capture combination unresolved and forbids an ordinary Great Ball fallback.
This packet makes no new policy. `SafariBattle.plan(..., captureAttempt)` requires
an explicit root capture owner callback for ball throws. If absent it returns
`safari-capture-policy-not-installed` without publishing RNG or spending a ball.
The callback receives the actual enemy, source-modified catch byte, caught count
and a detached stream. It must return a real `{caught=boolean,...}` capture result.
It must not mutate bag/session/global RNG. No multiplier or invented odds are
hidden in this API. Source Safari ball accounting, capacity and last-ball return
rules are implemented independently of that missing formula decision. Capture
art/presentation and a real SafariBattleState are not installed by this packet.

## Verification and remaining field seams

Three SDK behavior cases are PREPARED, not executed: admission/resources/Continue/
exit; Safari command/resource/flee order and explicit missing capture failure;
Warden's full-bag handoff/retry protection. They reuse the existing real-map
fixture and add no fixture/driver case. Existing HM03/pickup tests remain their
owners. Host checks reproduce small runtime policy/text from exact external Git
objects. Only checksums and bounded runtime recipes are committed; no ASM dump.
SDK 3.1.2 compilation includes the unapplied API patch and imports privately.
The evidence path and host count are reported with the commit. Root alone must
execute contracts and earned-save inputs before accepting any Safari behavior.

Remaining runtime Surf requirements, without editing transferred files:

- Authored Pallet: expose pure candidate terrain/foot metadata for its existing
  reviewed `Wt`/`Sh` cells through its Zone adapter. Preserve stable keys, source
  collision, art and ordinary checkpoint validation. Do not infer source water
  from a guessed pixel, whiten terrain or replace a source map with another.
- Water connections: existing KantoWorld/PewterWorld connection guards require
  land-passable origins. Root must project the existing immutable header
  connection, validate both source surfaces with the candidate travel mode,
  reserve a legal unoccupied target and carry Surf through the same atomic
  world/actor/location install. Clear it only on genuine land landing. Do not
  save a new location then invoke an independent fallible warp callback.
- Water encounters: Zone:encounterPolicyAt currently admits grass/indoor land.
  Root/map owner must expose the pinned Blue water byte and weighted water slots
  for eligible source foot cells, then use the existing FieldEncounters and
  Specimen transaction. Do not use grass slots, invent encounters in Fuchsia's
  disabled water table, or bypass Safari's own battle admission for Safari fish.

Celadon Department Store, vending/drink exchanges, coins/prizes and slot-machine
behavior remain following packets. Existing `freshWater`, `sodaPop`, `lemonade`
and root's Saffron guard consumer remain authoritative and untouched.
