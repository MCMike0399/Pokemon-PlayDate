# Source Strength boulders (worker candidate)

Merged exact root `f96878a` before actor work. The actual owned paths are
`Source/world/sourceActors.lua`, `Source/world/npcMotion.lua` and
`Source/domain/worldMotion.lua` (the latter defines WorldMotionData). No
Player/Overworld/Party/FieldMoveState, GameSession or SessionCodec edits.

## API for the field owner

All methods are on `game.npcManager.motion`:

```lua
motion:isBoulder(npc)                              -- boolean
motion:previewBoulderPush(npc, direction)            -- detached intent | nil, reason
motion:beginBoulderPush(npc, direction, owner)       -- opaque token | nil, reason
motion:updateBoulderPush(token)                     -- false,"moving" (frames 1–7)
                                                   -- true,"complete" (frame 8; releases)
                                                   -- nil,reason (failure; cancels)
motion:cancelBoulderPush(token)                     -- boolean; releases incomplete push
```

The intent is `{id,x,y,toX,toY,direction}`, in runtime padded cells. Preview is
read-only and rechecked at begin. The owner uses the existing script-lease
interface: `game`, `session`, `zone`, `epoch`, `valid()` and `isTop()`. The field
layer alone authorizes Strength/party/badge and owns input/presentation. It must
keep the player stationary during the eight calls; after completion it may move
the player into the vacated cell using its existing Player owner. Cancel on
controller exit. A moved player or stale owner aborts rather than silently
moving either actor. No callback/RNG draw or parallel actor owner is created.

SourceActors recognizes the exact `SPRITE_BOULDER` plus
`BOULDER_MOVEMENT_BYTE_2` source declaration, sets `source_boulder` on the NPC
definition, and describes a nonrandom static `boulder` role. The fixed image
keeps its down pose while motion direction is separate. Boulder steps reuse
claimScript/startScriptStep/updateScript/releaseScript, interpolate one cell in
eight native ticks without pretending fixed art has walking frames, and reserve
both cells through the existing occupancy owner. Land collision, directional
rules, other actors/reservations, player, warps/arrival cells and connections
remain protected. Ordinary NPCs and script art retain their existing paths.

First live map witness: `pokered:WARDENS_HOUSE:objects:3`, source `(8,4)`, runtime
`(9,4)` with padding 1. From source `(7,4)` facing right, push to source `(9,4)`.
A second right push meets adapter collision. Upward movement is initially blocked
by the real Rare Candy actor at source `(8,3)`; no tile replacement is involved.

## Exact pinned Blue reset/save policy

All referenced inputs are checksum-pinned in
`tools/references/strength-boulders.json` to pokered
`af519899719f0754965776faac0e836a3b906e6d`. Raw inputs remain in the external
reference checkout, not Git.

- `constants/map_object_constants.asm:66` defines movement byte 2 as `$10`.
  `TryPushingBoulder` in `engine/overworld/push_boulder.asm` checks that marker,
  active Strength, matching held direction and collision. Source requires a
  repeated pushing attempt; input latch/dust/audio belong to the field owner.
- `engine/overworld/player_state.asm:352` checks passable destination, land tile
  pairs, stairs and sprite occupancy. This packet additionally retains the
  project's existing protected warp/arrival/connection policy.
- `SaveMainData`, `engine/menus/save.asm:224`, copies the complete
  `wSpriteDataStart..wSpriteDataEnd` to SRAM. Loading at lines 70–73 restores it
  and sets `BIT_NO_PREVIOUS_MAP` at line 69. `ram/wram.asm:81–140` includes the
  actual current-map sprite coordinates in that interval.
- Continue enters through `SpecialEnterMap` (`engine/menus/main_menu.asm:327`).
  `LoadMapHeader` (`home/overworld.asm:2015`) sees `BIT_NO_PREVIOUS_MAP` and
  returns before rebuilding object positions, preserving the saved boulder.
- Ordinary map entry reloads source object coordinates in LoadMapHeader's
  `.loadSpriteData` loop (`home/overworld.asm:2132`). Battle return skips that
  reload through `BIT_BATTLE_OVER_OR_BLACKOUT`. Thus settled positions survive
  current-map Save/Continue and battle return; leaving and re-entering resets
  positions. Completed snapshots are not global per-map boulder persistence.
- EnterMap resets active Strength on ordinary entry (including Continue), while
  battle return keeps it; field-owner activation state must follow that policy.

The existing version-1 current-map actor DTO already stores settled static
positions. `canStand` now permits boulders on legal unprotected land beyond their
home, so normalization accepts actual pushed positions. Fresh attachment without
a current-map payload resets home; snapshot/reconcile retain current-map poses.
No codec or GameSession schema change is needed for correctly captured saves.

An old `zone_id=none` actor record with the saved player on the original boulder
home cannot reconstruct the missing pushed position. Legacy migration now rejects
that case explicitly: `legacy boulder overlaps saved player; source pose record
required`. It never relocates player/boulder or guesses progress. Root must decide
recovery if such a legacy save exists. Invalid actual payload overlap remains a
strict normalization failure. Future Seafoam/Victory Road hole/switch effects are
outside this Warden packet and must use their source story state, not persistent
terrain impersonating a boulder.

## Preparation checks

Initial SDK3.1.2 compile passed; 33 existing motion/source-event/placement host
checks passed. Art/behavior/native timing/SaveContinue execution remains root-only.
No Simulator, baseline edits, push or delegation. Field worker received the API
through the authorized thread message.
