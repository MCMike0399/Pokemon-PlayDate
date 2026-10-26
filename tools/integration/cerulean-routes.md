# Bounded rival and Rocket integration

Base: exact foundation `b7897bd`, merged into `wip/cerulean-rivals-rockets`.
Read-only dependencies: map/content `48943b7` and Bill/fossil/Misty story
`f30515e`. This branch does not activate maps or wire main. It does not claim
completion of milestone 5.3.

## Compose once

1. Compose the two dependency candidates and the story's common API delta on
   the root integration branch. Keep foundation fixes: the story patch builder's
   old object-ID replacement does not match the newer `local stable` validation.
   Add Bill's exact hidden event alongside objects/background events rather than
   replacing that validation with the older version.
2. Apply `cerulean-routes.patch` after the story API patch. Alternatively emit it
   for the composed checkout with `build_cerulean_routes_patch.py --root <root>
   --output <patch>`. This script only writes the requested patch, never Source.
   The delta validates all rival variants on immutable registration, permits a
   validated facing with leased placement, and presents source loss dialogue.
   The only existing Source edit on this branch is the narrow dynamic roster
   projection in TrainerEvents; its token snapshots still own the selected team.
3. Import `game/ceruleanStory` before `game/ceruleanRoutes` and
   `game/ceruleanRoutesState`, then register `CeruleanRoutesState(game)` as the
   single root `event` state. It extends the story executor when imported in
   that order, and delegates every non-route scene to it.
4. Install ordinary content first, story second, routes third, before contexts
   construct TrainerEvents. Call `CeruleanRoutes.install({reconcileActors=fn})`
   with the root's shared source-actor rebuild function. Preserve both ordinary
   Rocket trainer definitions. Only the two rivals are newly registered teams.
5. Initialize source first-rival availability with
   `CeruleanRoutes.initialize(session)` after the lab and before spawning Route
   22 actors, including Continue. It is idempotent and migrates old pre-Brock
   saves. A Boulder Badge or completed first rival prevents reactivation.
   The existing Brock victory transaction clears its availability flags.
6. Call `CeruleanRoutes.check(game)` before ordinary trainer sight, doors and
   field encounters in settled exploration. It checks the exact source trigger
   cells and declines while another overlay, movement or traversal owns input.
   Source interactions still use the common SourceEvents dispatcher.

## Stable IDs and ordinary overlap

These five rows belong to this module:

- `pokered:ROUTE_22:objects:1`: first optional rival.
- `pokered:ROUTE_22:objects:2`: later rival, explicitly unavailable in this slice.
- `pokered:CERULEAN_CITY:objects:1`: bridge rival.
- `pokered:CERULEAN_CITY:objects:2`: robbery Rocket and retryable TM28 return.
- `pokered:ROUTE_24:objects:1`: Nugget gift and Rocket sequence.

Exact `48943b7` ordinary **event descriptor overlap is empty**. Therefore omit
no ordinary descriptor from that candidate. Its two Rocket **trainer** rows do
exist: retain them. If the root has since introduced ordinary descriptors for
these IDs, omit only those descriptor rows before ordinary event registration;
never replace or duplicate their imported rosters. Keep Route 24 objects 2–8
and the robbed-house owner's quantity-dependent TM28 dialogue unchanged.

The second Route 22 object shares the first rival's origin. Bind its explicit
reserved handler, with `EVENT_2ND_ROUTE22_RIVAL_BATTLE` visibility false, so an
unresolved blocker does not sit on the first rival. Calling that handler fails
explicitly; this module never sets the second-rival availability flag. Do not
claim a later-campaign battle implementation for this row.

## Actor composition and returns

Merge `CeruleanRoutes.actorMetadata(id, game)` into the root's **one** source
actor metadata resolver. Preserve the Bill owner for Cerulean guards 6 and 11:
`EVENT_GOT_SS_TICKET` shows guard 6 and hides guard 11. This module neither writes
that flag nor owns either guard. No additional Ticket requirement is invented
for the thief's source script; access follows the real guard/map geometry.

The actor rebuild must evaluate route metadata against the current game, not
capture the old result forever in a cached Zone NPC definition. In particular,
after victory, rebuild the rival's object definition while `peekReceipt(id)` is
still available. That temporary receipt keeps the actor visible for the common
`restoreReturnedTrainer` and explicit departure controller. Only EventState
entry takes the receipt. After departure or on a later Continue with no receipt,
normal trainer/source visibility hides the rival. Refresh the thief after a
successful TM transaction, including an overlay cancelled after that commit.
The supplied `reconcileActors` callback must rebuild definitions and reattach
NPCMotion from current source metadata. It must not retain stale actor payloads
with actors that source visibility now excludes.

Before the bridge trigger, the original actor row is off the walkable approach.
The root may defer its display until the trigger when rebuilding source actors;
this worker does not add a durable spawn flag. All scripted coordinates come
from the pinned projection, with importer padding applied exactly once. There
are no collision exceptions in either rival path. NPCMotion owns placements,
standing facings, eight-tick cells, cancellation rollback and lease handoff to
TrainerEvents. The Route 22 notice uses the existing exclamation art.

The small loss-text patch displays the pinned source taunt after the existing
blackout return/learning continuation. It does not change defeat economics or
claim a second receipt. Source loss-text ordering within the battle presentation
remains a root journey review point.

## Validation and pending acceptance

Register only in the root harness overlay:

```lua
import "dev/ceruleanRoutesContracts"
Contracts.register("cerulean-routes", CeruleanRoutesContracts.run)
```

Twenty prepared native cases use actual imported maps, SDK sprites, EventState,
NPCMotion, trainer tokens, real Battle terminal emissions, session transactions
and SessionCodec. They cover all six starter-dependent teams, frozen team/RNG
ownership, fixed Blue IVs, both rival losses, four source departures, stale
callbacks/leases, full-bag Nugget retry, gift-before-Rocket outcomes, thief loss,
TM28 retry and Brock closing Route 22. Missing map/API integration fails; there
is no host Lua interpreter, fake SDK or skipped native fallback.

Worker validation: 21 focused host tests passed, zero skips (eight new pinned
input/generator tests). Vendored and external pinned regeneration are byte
exact. SDK 3.1.2 compiled a private composition of the two dependency candidates,
the story API patch, the separate routes delta and all new modules/contracts.
All 22 source text references resolve against the unchanged imported text.
The routes patch passed `git apply --check` against that private composition.
Large evidence is in
`~/Developer/Pokemon-PlayDate-env/evidence/cerulean-routes-work/`.

**Not executed:** the twenty native cases, natural journeys, actual process
Save/Continue, blackout UI, visual/catalog checks, device checks or full merged
host suite. No Simulator, push or further delegation occurred. Root must wire,
run those witnesses and inspect actual approach/departure/reward screenshots
before campaign acceptance. No protected art, existing data/manifests, main,
coverage or ledger files were edited by this worker.
