# Departed maps leave a Lua heap residue

`tools/tests/test_lane_e_departed_tile_registry.py` switches from the Viridian Center to Mt. Moon 1F, Route 4, and Cerulean City, then back to the Center. It reads `map.ViridianPokecenter.definition.begin` in the boot trace. That mark is the `collectgarbage("collect")` at the start of `SourceMaps.createZone`, before the destination is decoded. The return visit must stay within 96 KiB of the first visit. It does not. There is no patch with this note. A registry release was tried and the test still failed.

## What the device measured

`MallocPoolSize` was `16645684`. The harness injected `switchzone` for the run and restored `Source/dev/harness.lua` and `Source/dev/autopilot.lua`. `Source/` was `origin/main`. Outcome was ok. The Center was rebuilt. No `conflicting duplicate tile key`.

`definition.begin` heap, one lap, KiB:

| map | heap |
| --- | ---: |
| Viridian Center, first | 12500.1 |
| Mt. Moon 1F | 12644.9 |
| Route 4 | 13003.3 |
| Cerulean City | 13153.4 |
| Viridian Center, return | 13014.1 |

The return is 514 KiB above the first definition. The same four maps a second time, on an earlier run of this tree, landed the Center at 13015.3 KiB and then 13020.5 KiB. The second return was 5 KiB above the first. Revisiting does not add another copy. The residue is paid on the first visit and kept.

The step that matters is leaving Mt. Moon. Route 4's definition begins 358 KiB above Moon's. Cerulean adds another 150. Coming back to the Center gives 139 of that back and keeps 514.

## What is not the residue

`TileRegistry` is append-only. `registerPreparedBatch` keeps a key forever. `releaseDepartingWorld` drops the view, the two retained runtime definitions, the tile-grid cache, and the imported zone cache, then collects. It does not forget tile keys. A suffix release was applied on top of that: ids above the highest id still used by a live zone were removed, and their keys were cleared, so the next Center could register `pokered:POKECENTER:cell:01-0b-11-1b` again. `checkpointRuntime` kept the entry objects by pointer so an outer rollback could put the same tables back. After that release every `definition.begin` in the walk reported `tiles37` (the authored base) and `runtimeDefinitions` was nil. The Center still rebuilt. The return definition was 12877 KiB, 366 KiB above the first, still far past 96. The second lap again added about 5 KiB. Dropping the keys avoids the duplicate-key fault and does not bound the heap.

Niling a departed grid and leaving the key in place is the fault from the previous session. `same()` compared the empty grid with the Center's grid and raised `conflicting duplicate tile key: pokered:POKECENTER:cell:01-0b-11-1b`. Do not ship that.

These roots were the same size at the first Center definition and at the return, after a full collect:

- Tile-registry string bytes, about 3 KiB, once the suffix release had run.
- The compact catalogue, 707233 string bytes. `ImportedMaps` holds that table. Niling `SourceMaps`' local does not free it.
- Event and content tables, including the weak content indexes, 191537 string bytes. Replacing those tables and collecting freed about 300 KiB that was already live on the first visit.
- Retained runtime definitions, empty. `runtimeDefinitions` itself was nil. `_runtimePadded` only fills it inside `_withRuntimeDefinitions`.
- Tile-grid cache, empty. `SourceMaps._releaseTileGrids` already nils it.
- `zoneRegistry`, 6 zones. The imported zones were unregistered.

Twelve extra `collectgarbage("collect")` calls did not move the return definition. The Playdate runtime has no `debug` library, so function upvalues could not be attributed. A walk of every table reachable from `_G` saw `SpriteFactory` grow by about 10 KiB and nothing else over 8 KiB. The 514 KiB is live, it survives the collects in `releaseDepartingWorld` and `createZone`, and it is not the shade-grid entries once those entries are actually dropped.

## What E would have to find

The residue appears at `definition.begin`, which is before `padded()` decodes the next map. It is whatever the previous map's build stored beyond the zone, the view, the retained definitions, and the tile registry. The first visit of Mt. Moon is the large step. A second visit of Moon, Route 4, and Cerulean does not allocate it again, so a cache filled on first use fits the shape, and an append of one full copy per crossing does not. A full game that enters each map once still keeps one residue per map. That is the long-playthrough risk. Bounding it means finding the retainer that is still referenced after `releaseDepartingWorld`, not only the registry suffix.
