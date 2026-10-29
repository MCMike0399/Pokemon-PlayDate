# Silph Card Key, elevator and story packet

Source-only preparation from exact Blue revision; root owns shared modules,
activation, event composition, Simulator and native acceptance. No raw source
extracts are committed. Generators compare external files against exact pinned
Git blobs and store SHA256. The content worker's `22eee05` owns maps, text,
source trainer classes and ordinary rosters under `midgameSaffron`.

Import `game/silphStory`, `game/silphStoryWorld`, `game/silphStoryController`.
Merge `SilphStory.descriptors()` into that one content registration, then call
`SilphStory.install({reconcileActors=contentReconcileActors})`. Root's final
controller delegates enter/advance/handleButton/draw/exit/fail as shown in the
updated unapplied `midgame-story-controller.patch`. Parent remains NPCTradeState,
preserving trade/daycare/Vermilion and previous controllers. Failure delegation
must precede parent fail: rollback departure leases before parent releases them.

Reserved event IDs:

- SILPH_CO_7F `objects:1`: Lapras, `objects:9`: rival.
- SILPH_CO_9F `objects:1`: source nurse (no new healing checkpoint).
- SILPH_CO_11F `objects:1`: President/Master Ball, `objects:3`: Giovanni.
- SILPH_CO_ELEVATOR `background_events:1`: original panel (3,0).
- Floors 2..11 `hidden_events:1001..1000+doorCount`: synthetic door script
  triggers in exact callback order, separated from actual hidden item IDs.
  Counts by floor: 2,2,2,3,1,3,1,4,1,1. All twenty source flags/block positions
  and immutable stable tile keys live in `Source/data/silphStory/scenes.json`.

## Card Key and elevator

Card Key pickup remains the ordinary content worker's floor-5 object. Interacting
with a closed door tests source foot tile $18/$24 (plus $5e on 11F), faced cell,
actual Card Key inventory and the exact source block coordinate. No arbitrary
wall opens, no key is consumed, no flags are inferred from item acquisition.
The existing session scene transaction commits world collision/tile deltas and
that door's flag together with unchanged world RNG. Continue reconstructs the
exact open/closed blocks before actor spawn. Closed blocks differ (including
$20 on 11F); open blocks are $0e elsewhere and $03 on 11F.

The shared helper refactor touches only the newly added rocketHideoutStoryWorld
module: `projectBlock` is pure source-block projection; `commitWorld` reuses the
same existing GameSession transaction. It adds no owner or session schema.

Root extends the single previously requested DoorWarpSubstate seam with:

```lua
door = RocketHideoutStory.resolveDoor(self.owner.game, door)
door = SilphStoryWorld.resolveDoor(self.owner.game, door)
```

Cabin entry records the actual origin floor via the completed traversal hook.
Eleven mutually exclusive session flags retain selection through Save/Continue;
cancelling the existing scrolling BattleMenu preserves the previous floor.
Source raw warp bytes are 3, then nine 2s, then 1. They select zero-based target
warp entries, whose coordinates are generated, never guessed. Silph's elevator
requires no key. The root's source travel binding must permit cabin exits whose
original destination is UNUSED_MAP_ED until the dynamic resolver runs; treating
that placeholder as campaign-inaccessible would prevent leaving the cabin.

All Silph warp pads remain the content maps' exact existing warp descriptors,
not new script handlers. For the required path, floor3 pad (11,11), warp9 goes
to floor7 pad (5,3), warp5; floor7 pad (5,7), warp4 goes to floor11 pad (3,2),
warp4. Do not change the source inaccessible floor11 LAST_MAP pad (5,5) into a
new route. Generic traversal currently owns fade/pad transitions; original pad
animation timing is root's presentation acceptance, not claimed by this packet.

## Rival and Giovanni

The content package already contains OPP_RIVAL2 parties 7/8/9 and base money65.
Root/content registration must project them into the reserved rival trainer's
`rival_parties`: player Charmander->7 (Blastoise), Squirtle->8 (Venusaur),
Bulbasaur->9 (Charizard). Each team has five members and source payout2600.
Use those actual data records; no duplicate roster package lives here. The
immutable TrainerEvents definition needs stable id/map_id, name BLUE,
sprite_source SPRITE_BLUE, default team7 and sight_range_cells0. Giovanni's
ordinary source roster is already in the content package; do not redefine it.

`CheckCoords` in home/map_objects increments **before** matching. Its CoordIndex
is one-based despite misleading comments in these scripts. The actual rival
trigger (3,2) gets four UP from (3,7), stopping at (3,3), then RIGHT2 to (5,3).
Trigger (3,3) gets three UP, stopping at (3,4), then LEFT,UP,UP,RIGHT3,DOWN to
(5,3). That final cell is a source pad. `source-story-script-exits.patch`
supersedes the earlier Tower-only patch and permits only those two exact source
actors' declared leased exit cells. No other warp/arrival protection changes.

Giovanni starts (6,9), walks DOWN3 to (6,12). Trigger (6,13) makes player face
UP / Giovanni DOWN; trigger (7,12) makes player LEFT / Giovanni RIGHT. Source
pre-battle dialogue is printed before actor movement, so the controller uses
existing TrainerEvents prepare/launch directly after motion instead of printing
it twice. NPCMotion leases own placement, every cell and facing. Battle admission,
source teams, payouts and victory flags remain TrainerEvents' atomic transaction.
There is no temporary actor, direct NPC coordinate write or parallel dispatcher.

Rival departure hides him only after the exact leased path completes, through a
bounded quest flag. Cancellation restores the departure's actual approach pose
and exploration retries; committed trainer victory/payout never replays. Root's
failure delegate must run before EventState.cancelNPCMove to preserve that
rollback. Giovanni victory's source flag controls the source toggle table. The
generator resolves all 40 hidden and 6 shown object IDs by the original constants
and object tables; it does not assume suffixes are object indices. Merge
`SilphStory.actorMetadata(id,game)` into content metadata, respecting existing
collection flags for any independently collectible actors. Pending Giovanni
receipt keeps him visible until the source return presentation can finish.

## Gifts, recovery and limits

Lapras is exactly level15, before or after Giovanni, gated only by BIT_GOT_LAPRAS.
It uses existing price-zero purchaseGiftPokemon for an atomic specimen, party/
selected-box, Pokédex, acquisition flag and RulesRNG commit. Full box leaves it
retryable; full party uses the selected box; bag capacity is irrelevant. Source
text changes after Giovanni only once Lapras has been given. The source does
not require rival victory in the gift script; geometry supplies normal gating.
No extra prerequisite or reward is invented. Existing lack of a gift naming
screen remains explicit; no nickname UI is added by this worker.

President is a separate ordinary Master Ball gift with EVENT_GOT_MASTER_BALL,
source full-bag retry and completed description. Source checks only whether the
item was given; it does not add a Giovanni flag check inside the gift script.
Do not invent a new prerequisite beyond actual source geometry. No other item
or Pokémon reward is introduced. The nurse heals through the authoritative Party
owner before Giovanni and only thanks the player after Giovanni, matching source;
it does not register a Center or alter the healing/blackout checkpoint.

Save is blocked beneath existing overlays. Settled saves persist flags/world/
actor poses and elevator choice in existing codecs, never a scene phase or lease.
No cry, white/black fade or original audio timing is accepted by this source-only
packet. Native actor/door/pad/cabin behavior, first/second rival paths, full-bag/
full-box retry, blackout and actual separate-process Continue remain root checks.
