# Rocket Hideout scene integration

Prepared from exact accepted `63267b0`. Root's `a30d996` restored
`NPCTradeState -> DaycareState -> VermilionStoryState`; preserve that chain.
This branch changes only new story modules, generator/projection/provenance and
source checks. No Simulator, ledger, source extracts, protected art or shared
module edits. This is implementation preparation, not milestone acceptance.

## Reserved content identities

Content worker owns the one event/text/roster registration. Merge
`RocketHideoutStory.descriptors(contentName)` into its descriptors. For existing
trainers Giovanni and key Rocket, retain the ordinary descriptor fields
`before`, `won`, `after`, `victory` but set `kind="bespoke"`. Apply
`RocketHideoutStory.decorate(id, descriptor)` after merging source fields.
It adds Giovanni's confirmed-victory flag and pickup gates.

- `pokered:ROCKET_HIDEOUT_B4F:objects:1`: Giovanni, (25,3).
- `pokered:ROCKET_HIDEOUT_B4F:objects:4`: Lift Key Rocket, (11,2).
- `pokered:ROCKET_HIDEOUT_B4F:objects:8`: ordinary Silph Scope pickup, (25,2),
  visible only after `EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI` and until collected.
- `pokered:ROCKET_HIDEOUT_B4F:objects:9`: ordinary Lift Key pickup, (10,2),
  visible only after `EVENT_ROCKET_DROPPED_LIFT_KEY` and until collected.
- `pokered:GAME_CORNER:background_events:1`: actual poster, (9,4).
- `pokered:ROCKET_HIDEOUT_ELEVATOR:background_events:1`: panel, (1,1).
- B2F `hidden_events:1..43`, B3F `hidden_events:1..16`: reserved synthetic
  trigger identities in the exact source movement-table order. These are not
  fabricated hidden items. Coordinates and decoded paths are in `scenes.json`.

Do not reserve ordinary B4F Rockets 2/3 here; their source trainers stay with
content. Both victories unlock block (12,5) on the next source map load. B1F
object5 opens block (12,8) on load. Game Corner block (8,2) is the poster door.
The six required source block projections are generated from immutable FACILITY
and LOBBY blocksets; ensure their stable keys exist in the shared content atlas.

## Root composition

Import `game/rocketHideoutStory`, `game/rocketHideoutStoryWorld` and
`game/rocketHideoutStoryController` before installation. After content registers
its merged descriptors/texts/rosters, call:

```lua
RocketHideoutStory.install(contentName, {
    openEntrance = RocketHideoutStoryWorld.openEntrance,
    reconcileWorld = RocketHideoutStoryWorld.reconcile,
    reconcileActors = contentReconcileActors,
})
```

Root owns the final class extending **NPCTradeState**, with this delegation:

```lua
-- enter: before parent enter (which calls advance)
RocketHideoutStoryController.enter(self)
-- advance: before parent advance
if RocketHideoutStoryController.advance(self) then return end
-- update: after parent update
RocketHideoutStoryController.update(self)
-- handleButton: before parent handleButton
if RocketHideoutStoryController.handleButton(self, button) then return end
-- draw: after parent draw
RocketHideoutStoryController.draw(self)
-- exit: before parent exit
RocketHideoutStoryController.exit(self)
```

The controller registers no state or dispatcher. Root keeps its existing
trade/daycare/vermilion methods and registration, composing the new delegates.
Root must add the one genuinely absent world seam at the beginning of
`DoorWarpSubstate:enter(door)`:

```lua
door = RocketHideoutStory.resolveDoor(self.owner.game, door)
```

This changes only cabin exits; the existing fade, collision/destination/session
validation and zone switch remain authoritative. The hook on actual completed
floor->cabin traversal records the origin floor before entering the cabin.
Menu selection retains that destination in existing quest flags for Continue.
Cancelling the menu keeps the previous destination. Source raw warp bytes
4/4/2 mean zero-based target entries: (25,19)/(25,19)/(25,15).

`contentReconcileActors` must preserve a pending Giovanni receipt until its
post-victory lines run, then hide Giovanni. Call it after a committed Lift Key
drop and on scene exit/return; initial source actor visibility alone is
insufficient to show a dropped item during an already-loaded map. The root's
exit composition can reconcile after parent exit while session/zone still match.

## Cancellation, retries, persistence and limits

Spinners use EventState's finite movement and Player's eight-frame cells.
Completed cells survive cancellation; the incomplete cell rolls back. Save is
blocked under the existing event overlay. Like the source default script, the settled-world hook tests occupancy rather
than only completed steps, so Continue/cancellation on an arrow resumes it.
Every full source route ends on a non-trigger stop cell.
Paths run backwards through source RLE exactly, with no random samples. Standing
frames rotate down->left->up->right; immutable frames and movement are unchanged.
Animated arrow terrain and original spin audio remain content/audio integration;
this worker does not claim their timing or sound is accepted.

The Rocket drops the key only on a later talk after his confirmed defeat, not in
the win receipt. The key and Scope remain ordinary separate pickups. Full bags
leave both objects/flags available; item+collection flag commit atomically in
GameSession. Giovanni's victory flag is part of TrainerEvents' confirmed victory
transaction; no reward is granted for losses or cancellation. No invented payout
or direct Scope gift is present. Content supplies exact source roster/payout.
All durable scene values use GameSession quest flags/world deltas, existing
codec, and no second owner. Native Save/Continue, bag-full retries, actor refresh,
spinner collision and original source timing remain root's SDK/journey checks.

Sources remain outside Git. Regenerate/check with:

```sh
python3 tools/generate_rocket_hideout_story.py --reference "$POKERED_REFERENCE_DIR" --check
python3 -m unittest tools.tests.test_rocket_hideout_story -v
```

The generator requires reference HEAD exactly equal to the pinned revision,
compares each consumed file against its committed blob, and records SHA256.
