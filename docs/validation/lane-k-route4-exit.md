# Route 4 east exit

pret/pokered `af519899719f0754965776faac0e836a3b906e6d`. Main is `ed1f1b92`. J is `bad53f90`, pause `5a428a2c98f5` at Route 4 `(59, 4)` facing right.

The walk graph matches. No `tools/notes/lane-e-route4-*.patch`. No Center teleport. The blocked steps J recorded are the harness lines.

## Exit warp

`data/maps/objects/MtMoonB1F.asm` warp 8 is `(27, 3) LAST_MAP, 3`. `data/maps/objects/Route4.asm` warp 3 is `(24, 5) MT_MOON_B1F, 8`. `Source/data/sourceSlice/MtMoonB1F.json` and `Route4.json` use those same coordinates. `Source/world/sourceMaps.lua` advances one cell south off a door when that cell is open (`PlayerStepOutFromDoor`, `home/overworld.asm`), which is `(24, 6)`. That is the sequence 10 pause. `(59, 4)` is farther east on the same component, not a second warp.

B2F has no Route 4 warp. Its four warps return to B1F.

## Tiles the pause probed

`maps/Route4.blk` plus `gfx/blocksets/overworld.bst`, foot tile of each 16x16 quadrant, solid when the foot is absent from `Overworld_Coll` (`data/tilesets/collision_tile_ids.asm`). All 1620 cells match `Route4.json` collision and foot. `TilePairCollisionsLand` is cavern and forest only. Route 4's forbidden pairs are empty. The eight `data/tilesets/ledge_tiles.asm` rows match `directional_rules.ledges`.

| Cell | Foot | Collision | In the east-exit component |
| --- | --- | --- | --- |
| `(60, 4)` | `$27` | 1 | no; right from `(59, 4)` |
| `(60, 6)` | `$2C` | 0 | yes |
| `(23, 6)` | `$24` | 1 | no; left from `(24, 6)` |
| `(20, 6)` | `$27` | 1 | no; x=20..23 is solid |
| `(19, 6)` | `$23` | 0 | no |
| `(11, 5)` | door | 0 | no; Route 4 Center, warp 1 |

`$27` stays solid. The Center side is the west side of that mountain.

## Walk to Cerulean

From `(24, 6)` and from `(59, 4)`, with the same ledge hops `MapBindings.movement` applies (`Source/world/mapBindings.lua`, landing two cells ahead when the landing collision is 0; `Player:tryMove` starts that hop):

1. Down from `(59, 4)` to `(59, 6)`. `(60, 4)` is not a step.
2. East through `(60, 6)` along y=6.
3. Down from y=8, x=64..79. Those are `LedgeTiles` hops (`$2C` onto `$37`, or `$39` onto `$36` / `$37`) and land on y=10. Walking only, with no hop, stops at x=79 and never reaches the east edge.
4. East to `(89, 10)` or `(89, 11)`.

`data/maps/headers/Route4.asm` is `connection east, CeruleanCity, CERULEAN_CITY, -4`. The east macro stores Y alignment `(-4) * -2` and X alignment 0 (`macros/scripts/maps.asm`). `CheckMapConnections` (`.checkEastMap` in `home/overworld.asm`) adds that alignment. `SourceMaps.connection` uses the same `entry_lateral_adjustment_cells` of 8 and the target's padding 0. `(89, 10)` arrives at Cerulean `(0, 18)`. `(89, 11)` arrives at `(0, 19)`. Both feet are in `Overworld_Coll`, in `maps/CeruleanCity.blk` and in `CeruleanCity.json`.

The Lass at `(63, 3)` is on the north road, east of the `$27` column. That road is reached by the one-way left ledges (`$2C`/`$39` onto `$27`), from the Cerulean side toward the cave. It is not the eastbound exit.

## Harness line

Pause `5a428a2c98f5`. The bad command is `press right` at `(59, 4)`. J recorded `cliff_step` `blocked`. The next cell is foot `$27`. `press left` at `(24, 6)` is the other bad command: `(23, 6)` foot `$24`, `lastTraversalBlock` `terrain` / `source-collision`.

The land step that leaves this side is `down` at `(59, 4)`, then east on y=6, then `down` on the y=8 ledge (x=64..79), then east off `(89, 10)` or `(89, 11)`. Do not resume by writing the player onto `(19, 6)` or into the Route 4 Center.

`tools/tests/test_lane_k_route4_exit.py` is the graph check. It passes against this tree.
