# Route 2, cave side

Faithful. pret/pokered `af519899`. J is `cursor/lane-j-squirtle` `97339b68`, sequence 53, standing on Route 2 `(11, 2)` facing left after Diglett's Cave. The door is `(12, 9)` (`warp_event 12, 9, DIGLETTS_CAVE_ROUTE_2, 1`). One step left is `(10, 2)`, foot `$55`, and `$55` is not in `Overworld_Coll`. That step stays blocked. `maps/Route2.blk` has no four-direction path from `(12, 9)` to the north edge `(8, 0)` or `(9, 0)` while the tree is still there. `Source/data/pewterSlice/Route2.json` matches those feet, the ledge rules, and the collision grid. `tools/tests/test_lane_k_route2_cave_side.py` locks both.

The missing step is Cut, not another route. The only tree that joins the cave side to Pewter is `(5, 10)`. Its block is `$32`. `CutTreeBlockSwaps` replaces `$32` with `$6D`, and that quadrant is `2c-2c-2c-2c`, which is walkable. `UsedCut` accepts the tile in front when it is `$3d`. The only open neighbor of that tree on the cave side is `(5, 11)`, so stand there and face up. The west grass (`$52`) is already in `Overworld_Coll`, so it is walked, not cut. Viridian Forest's north gate `(3, 11)` is on the Pewter side of the same tree. Going back through the cave returns to Route 11. Route 6 north is the Saffron gate. Neither reaches Cerulean.

## Walk from `(11, 2)`

Turn around. The building south of `(11, 2)` is solid, so the path goes east around it.

1. Right four, to `(15, 2)`.
2. Down three, to `(15, 5)`.
3. Right three, to `(18, 5)`.
4. Down five, to `(18, 10)`.
5. Left eight, to `(10, 10)`.
6. Down one, to `(10, 11)`.
7. Left five, to `(5, 11)`.
8. Face up. Cut. The tree at `(5, 10)` becomes `pokered:OVERWORLD:cell:2c-2c-2c-2c`.

Then north:

1. Up six, to `(5, 5)`.
2. Right one, to `(6, 5)`.
3. Up three, to `(6, 2)`.
4. Right two, to `(8, 2)`.
5. Up two, to `(8, 0)`.
6. Up again. The north connection is Pewter, offset `-5` blocks, `entry_lateral_adjustment_cells` 10. That step lands on Pewter `(18, 35)`, still facing up. `(9, 0)` would land on `(19, 35)`. Both Pewter cells are open.

From Pewter `(18, 35)` the east edge `(39, 16)` through `(39, 19)` is open without another Cut. A step right uses the east connection, offset `4`, adjustment `-8`, and lands on Route 3 `(0, 8)` through `(0, 11)`. Route 3, Mt. Moon, and Route 4 are the same road J already used into Cerulean. From Cerulean, Route 9, Rock Tunnel, and Lavender are unchanged.

## Cut tree saves

Not a product red. No patch.

`ReplaceTreeTileBlock` writes the swap into the live `wOverworldMap` block. `wCutTile` is the tile in front for that animation. `LoadTileBlockMap` copies the map from `wCurMapDataPtr` on the next load. There is no saved cut list, so a tree is back after a map change. That part of J's report is faithful.

Vermilion's tree is the same swap shape. `fieldMoveMaps/VermilionCity.json` site block `$35` (53) at `(14, 18)` changes only `(15, 18)`, from `2d-2e-3d-3e` to `2c-2c-2c-2c`. `CutTreeBlockSwaps` has `$35, $4C`. Sequence 49 was saved on that open tile, so the session still held the live replacement and the file stored it. Entering the Gym is a map change. `OverworldState:enter` calls `FieldWorld.enter` with the departing zone, and `FieldWorld.reloadWorld` removes a complete cut replacement on that zone before the Gym session exists. Sequence 50 was saved after that, so the cell is already gone. Continue runs the same removal for every field-move map (`FieldWorld.prepareContinue`), which is why a save that still contains the cell also grows the tree back. Sequences 52 and 53 were saved on Route 2 after leaving Vermilion, so the second cut had already been removed on that departure. Dock tiles are not this cut site, and the reload leaves every other delta in place. The two files differ because one was taken before the city reload and one after it, not because the save writer drops a zone that is still in the session.
