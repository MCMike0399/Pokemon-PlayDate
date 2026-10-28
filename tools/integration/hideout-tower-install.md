# Incremental installation on root 9e8e06d

Root can integrate Hideout/Tower without enabling the separate Silph/gym packet.
New `HideoutTowerContent` transforms detached descriptors during the content
worker's existing one-time registration, retaining its text/roster sources.
New `HideoutTowerController` only delegates from existing NPCTradeState.
`hideout-tower-root-9e8e06d.patch` is the exact unapplied root wiring: package
transform seam, main imports/install/metadata calls and controller delegation.
It keeps `machine:register("event", NPCTradeState(game))` unchanged and captures
existing methods so trade/daycare/Vermilion behavior still runs.

Exact calls introduced by that patch:

```lua
CeruleanContent.registerPackage("midgameEast", "data/midgameEast/", function(events, trainers)
    return HideoutTowerContent.package("midgameEast", events, trainers)
end)
CeruleanContent.registerPackage("midgameSouth", "data/midgameSouth/", function(events, trainers)
    return HideoutTowerContent.package("midgameSouth", events, trainers)
end)
-- after ordinary package registrations and KantoScenes.install:
HideoutTowerContent.install()
```

Main metadata appends `HideoutTowerContent.actorMetadata(event.id,runtimeGame)`.
The adapter registers no independent content resolver, registry or dispatcher.
Root applies `tower-rocket-exit.patch` for only the first Tower Rocket's declared
stair endpoint, and coordinates `hideout-lift-door-hook.patch`'s single resolver
call with the field worker. No shared file is changed on this branch.
Before-spawn story hooks only refresh source descriptors and mark the existing
context for reconciliation; they never spawn/attach a second set of actors.

Hideout can run through Giovanni and the ordinary Scope pickup once this wiring,
source block keys, existing rosters and the elevator resolver are installed.
Tower's Fuji/Flute and all Rocket paths are prepared, but the **7351c00 and
9e8e06d FieldBattle owners do not yet contain the scripted-wild API**. Root must
supply that owner seam before the ghost/Snorlax critical path is playable.
`source-story-battle-hooks.patch` and `tower-snorlax-story.md` specify the exact
small call sites and atomic result/capture requirements. No fake win or ordinary
wild fallback is supplied. Ghost policy must enter Battle construction before
its immediate intro/markSeen; attaching it only after construction is too late.

Source root dialogue packages also lack `_PlayedFluteHadEffectText`, `_GotMonText`,
`_SentToBoxText`, `_BoxIsFullText`; root/content must register those exact common
recipes. This is an explicit integration dependency, not native acceptance.
Fixed source collision/spinner routes are in `hideout-fixed-routes.json`. They
are static preparation, with no new planner code or journey/harness changes.

## Early closed-context replacement (root e6ea040)

Root's corrected authoritative closed-warp collision makes a late DoorWarp
resolver insufficient by itself. The actual source context must be installed
before those exact cells become closed barriers. New pure APIs return detached
bindings, with no world/cache/Player edits on this branch:

```lua
RocketHideoutStory.elevatorBindings(session)
SilphStoryWorld.elevatorBindings(session)
```

Keys are exact source warp IDs, values are bound traversal descriptors. Floor
entry contexts are always known once the story handler is installed; no key is
needed to enter either cabin. Cabin exits are returned only when actual entry
or menu selection has recorded a source floor in GameSession. Root's shared
context/cache owner must use these bindings in place of the closed preparation
context for the same IDs and release only those collision barriers. Keep unknown
cabin exits closed. This supersedes treating a late destination substitution as
complete elevator integration. It does not authorize the Silph inaccessible
LAST_MAP pad, any unrelated warp or a broad collision exception. Coordinate
this small early-binding seam with the field/world owner; no shared file edits
are made here.

Tower2 rival is now included in the same incremental package: source stable ID
POKEMON_TOWER_2F:objects:1, raw content OPP_RIVAL2 parties4/5/6, source payout1625.
The adapter projects those existing immutable records during the same content
registration, rather than shipping another roster package. Exact source triggers
(15,5)/(14,6), facing, both eight-cell departures, source side flag and confirmed
victory flag are implemented through the existing trainer/session/NPC lease
owners. `tower-rocket-exit.patch` now includes its exact (18,9) terminal warp as
well as the first 7F Rocket's stairs. Apply its current version once; the later
combined source-story-script-exits.patch supersedes it when Silph is installed.
The source coordinate array's malformed $0f terminator is recorded honestly:
only the two authored trigger coordinates are implemented; ROM-overread behavior
is not guessed or claimed as reproduced.
