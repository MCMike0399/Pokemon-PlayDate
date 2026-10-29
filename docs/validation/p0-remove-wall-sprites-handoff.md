# Remove unused WorldView wall sprites

Based on exact main `b6179a4efe029d4ac83bbf5777516c76f7f5e073`.
Confirmed across Source Lua: only the old dev rollback case queried SDK collision;
production `Player:canMoveTo` reads `collisionMap`. No movement/collision-query
consumer needs the wall sprites.

WorldView no longer creates SDK walls or owns `_wall`, `_wallRow`, `walls`,
`wallRuns`, registration snapshots or wall rollback. `hasWallAt(x, y)` keeps its
zero-based Boolean interface and reads `zone.collision`; out-of-bounds is false.
`applyTiles(plan)` remains a rendering operation returning its undo closure;
Zone transactions own collision commits and restoration. Tile/image rendering,
animation phase, tilemap attachment policy and tilemap/image rollback remain.

Replaced the one existing WorldViewRollbackContracts case; added no cases.
It checks actual Zone commits/undo/reset, native tilemap/image restoration,
palette growth at the current animation phase, attached/offscreen tilemap
membership, manually detached tilemap rollback and disposal counts.

Passed `git diff --check`, all 54 `make test-harness` host checks, and eight
checks in `tools.tests.test_production_build` / `tools.tests.test_world_profile`.
The build checks compile real production and harness bundles with SDK 3.1.2.
No Simulator, USB, gameplay, visual comparison or timing measurement was run.
Root must run the existing world/rollback SDK cases, one review and the same
hardware route. Runtime savings and device playability remain unmeasured here.
No gameplay/map/art/session/rules inputs or baselines changed. No push.
