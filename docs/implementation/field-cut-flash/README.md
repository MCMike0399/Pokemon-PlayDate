# Private 5.4 Cut / Flash packet

Base: **c6882b696fa9e0b8b4f43e7bb46fffacceeb11f6**. Branch:
`wip/field-cut-flash`. This packet is prepared implementation, not activated or
accepted gameplay. No Simulator, runtime, device, push, or delegation was used.

## What is prepared

`FieldMoves` owns opaque, one-shot field intents. The actual party member must
know the move; Cut requires Cascade, Flash requires Boulder. Field use consumes
no PP and permits a fainted user, matching the original party menu. It checks the
settled field boundary, source map identity/dimensions, facing, exact source block,
all changed endpoints, NPC reservations and source-event occupancy. Retained
callbacks reject changed sessions, players, party order/active member, badges,
move/PP/HP records, checkpoints, world deltas and actors.

`FieldMoveState` provides native party-menu handoff, confirmation, cancellation,
move announcement and the source tree effect. Eight native logical frames split
the original upper/lower tree rows in opposite directions, alternating original
OAM palettes `$e4`/`$80`. All tree pixels and masks derive from pinned source art;
there are no hand-drawn assets. The world commits after the eighth frame, so an
interrupted effect has no terrain side effects. This commits later than pokered,
which replaces the block before animating. That bounded cancellation adaptation
needs root review. Art and animation have compiled, but have not been viewed.

The generator binds twelve tree sites across the bounded source map inventory,
including the Vermilion Gym approach, six Route 2 trees, the Museum approach,
Cerulean and Route 25. It uses original block IDs and all four replacement
quadrants, not a generic grass tile. Authored Pallet is absent. The original
nine-pair swap table is pinned and checked; grass Cut and later-region Cut sites
are outside this packet. No map, NPC, connection or collision geometry is added.
The GYM source tileset is pinned, but Vermilion Gym itself has no tree site.

`FieldMoveWorld.commit` couples existing `WorldDeltas.apply` rollback with existing
atomic `GameSession.captureTraversal`. It validates first, applies native terrain
through the existing Zone/provider transaction, and rolls runtime back on a view
or session rejection. It never assigns `zone.tiles`, owns no progression state,
and refuses a world no-op. Flash never writes `worldData`.

`fieldMoveBattleData.lua` supplies source-resolved B2W2 Cut (50 power, 95 accuracy,
30 PP, physical/contact) and Flash (100 accuracy, 20 PP, accuracy -1). It leaves
core battle and `MoveSupport` untouched. Under this exact base both records
therefore use the existing loud-failure path: “But it failed!” plus a recorded
dispatch gap. Root's battle owner can subsequently review dispatch support.
MachineData, all 151 species permissions and the existing Teaching/Learning owners
are unchanged. At this exact base there is no `worldMutation` or `machineTeaching`
module; their existing equivalents are `WorldDeltas` in `world/zone.lua`,
`GameSession.captureTraversal`, `Teaching`, and `LearningState.openTeaching`.

## Required owner integration — unapplied

`root-api.patch` applies cleanly to the exact base plus this packet. It contains
only imports/registration, the context transaction handoff, and a harness-only
native-view isolation seam. All three generated field cell keys already exist
with identical metadata and pixels in the source cache; it needs no changes. It was applied
**only to a private compile stage**. It deliberately does not wire map lifecycle
or add darkness persistence. Do not activate it alone.

The map/session owner must provide a source reload boundary before activating Cut:

1. Use `FieldMoves.reloadWorld(world, zoneID, descriptor.padding)` on the departing
   source map on a genuine map transition, and on every supported Cut map during
   Continue. Do not call it for a menu/dialog or battle return.
2. The projection removes only complete exact generated Cut block replacements,
   preserving unrelated terrain deltas. Validate the result through the existing
   world, location, actor and codec owners; apply runtime and session together
   using their rollback contract. Source map reloads must reset the cut collision,
   while ordinary menus/battles retain it. New Game keeps the existing empty-world
   owner. No flags or additional save fields are needed to identify Cut deltas.
3. **Unresolved owner conflict:** the source reload may put a tree beneath a saved
   player standing on its cut endpoint. Original `LoadTileBlockMap` restores that
   tree; this codebase's location codec rejects a blocked location. The supplied
   endpoint contract demonstrates the existing rejection without relocation.
   Root must explicitly adapt the location/movement validation seam for this
   source case, preserving source position and avoiding a teleport or permanent
   cut policy. This packet does not bypass the codec or claim that case works.

The transaction API, if root already has a newer `WorldMutation` owner, is exactly:

```lua
game:commitFieldTerrain(expectedRuntimeWorld, candidateWorld, playerLocation, actorSnapshot)
-- -> true, receipt OR false, reason; no yield
-- Guard expected runtime, validate all candidate owners, update native terrain
-- and retained session identity atomically; rollback both on rejection.
```

The implementation is `FieldMoveWorld.commit`; root can bind that to the existing
owner instead of installing the context method. Do not create another progression
owner. `WorldView.withIsolation` in the patch lets contracts use real native views
without disposing the live view; it is guarded by `HarnessBuild`.

## Flash input adapter and 5.5 boundary

Rock Tunnel remains uninstalled. Flash is meaningful only for an installed source
dark map with offset 6; an absent adapter or already light map refuses field use.
The original menu technically allows Flash elsewhere and clears an already-zero
offset. Refusing that meaningless use is a deliberate requested usability guard.
It requires no new map geometry or circular-light renderer.

Root's existing source darkness/save owner must explicitly supply:

```lua
game.fieldDarkness = ownerAdapter
ownerAdapter:read(game)
-- Defensive {zone_id, source_revision, offset, epoch}.
-- source_revision = af519899719f0754965776faac0e836a3b906e6d
-- offset = original wMapPalOffset; epoch is a positive integer context epoch.
ownerAdapter:clear(game, expectedInput)
-- Compare-and-set offset 6 -> 0 atomically; false on context mismatch/failure.
-- Keep the same location, maps, actors, party, inventory and worldData.
```

The native overlay supplies original `GBPalWhiteOutWithDelay3`'s three white
frames. The adapter must clear offset before the normal palette is restored.
This packet does not store offset, invent an unversioned save field, or implement
an alternate darkness owner. Until root supplies a versioned source owner, Flash
has only the prepared adapter and provenance. Future real Rock Tunnel contracts
must verify clear, cancellation, floor transition, battle return, Save/Continue,
exit/re-entry, Escape Rope/blackout and New Game against that owner.

## Primary source provenance

All consumed inputs are vendored under `tools/references/field-moves`, with exact
SHA-256 values in `pins.json`. The generator rejects unpinned or changed inputs.

- pokered **af519899719f0754965776faac0e836a3b906e6d**: `engine/overworld/cut.asm`,
  `cut2.asm`, `data/tilesets/cut_tree_blocks.asm`, source headers/layouts/blocksets,
  original graphics and collision lists supply targets, replacements and effect.
- `engine/menus/start_sub_menus.asm` supplies original Cascade/Boulder gates,
  field party selection and Flash offset clearing. No PP or fainted check is
  added to that original field permission.
- `home/overworld.asm: LoadTileBlockMap` reloads ROM block IDs, so Cut is temporary
  across real map loads. The map block buffer is outside the saved main data.
- The same file's outside-map warp into Rock Tunnel 1F sets offset 6; internal
  floor warps retain it; leaving for LAST_MAP clears it. `home/fade.asm` reads the
  offset. `home/palettes.asm` supplies the three-frame whiteout. `ram/wram.asm`
  places `wMapPalOffset` inside saved main data; `engine/menus/save.asm` copies it.
  Blackout and special escape/fly warps clear it. Flash is consequently not an
  ordinary per-map flag and cannot reset on each Rock Tunnel floor.
- Showdown **9b136a8c8cdb860a8ab96fa063f906604e352547**, full move file plus
  gen8 → gen7 → gen6 → gen5 move chain: inherited Cut/Flash battle scalars and
  Flash accuracy reduction. Hashes also match the existing MoveSupport oracle.

## Verification and prepared SDK contracts

Source the normal environment first. Host checks execute no Lua or SDK stand-in:

```sh
python3 tools/generate_field_moves.py --check
python3 -m unittest tools.tests.test_field_move_data -v
git apply --check docs/implementation/field-cut-flash/root-api.patch
```

Fifteen host tests passed (eight new field input/generation checks and seven
existing teaching-data checks). The field checks cover: deterministic generated artifacts, complete primary pins,
source tamper rejection, all nine source block swap pairs, exact bounded sites,
collision endpoints, existing imported grid/terrain equivalence and battle data
policy. Production and composed private SDK 3.1.2 compilation passed.

Durable compile artifacts:
`~/Developer/Pokemon-PlayDate-env/preparation/field-cut-flash/production-stage`
and `sdk-prepared-final` (includes `verification.json`, staged Source, root patch and
prepared `.pdx`). Neither bundle was executed. The staged SDK contracts are
**not runtime results**.

`Source/dev/fieldMoveContracts.lua` prepares sixteen real-owner SDK contracts:
full-bag HM teaching/cancel, compatibility, native confirmation/cancel/stale
callbacks, Cascade/Boulder/actual-move permissions, source-position/occupancy
rejection, party/PP/context invalidation, eight-frame mutation with zero PP/fainted
user, native view rejection, session rejection after native terrain application,
SaveCodec and source reload/reset, blocked saved endpoint, New Game context,
explicit darkness inputs and actual battle loud failure. Add the scoped
`tools/field-moves/sdk_imports.lua` snippet through root's harness overlay workflow;
do not edit production dev imports or existing suite baselines in this packet.
The blocked endpoint test records a limitation, not successful source restoration.

No runtime, screenshot, pixel protection, frame timing, campaign, restart, device,
full suite or acceptance claims are made. Root still owns all of those checks and
must resolve lifecycle/darkness ownership before activation.
