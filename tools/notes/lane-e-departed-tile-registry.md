# Departed maps leave a Lua heap residue

`tools/tests/test_lane_e_departed_tile_registry.py` switches from the Viridian Center to Mt. Moon 1F, Route 4, and Cerulean City, then back to the Center. It reads `map.ViridianPokecenter.definition.begin` in the boot trace. That mark is the `collectgarbage("collect")` at the start of `SourceMaps.createZone`, before the destination is decoded. The return visit must stay within 96 KiB of the first visit. Unpatched, it does not. The fix is `tools/notes/lane-e-departed-tile-registry.patch`. Apply it before the two tests. A registry release by itself was not enough; the measurements below are the unpatched baseline.

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

## Fifty unique maps

The same mark, on the current tree, through 50 maps that had not been visited yet. The session is a Center fixture with all eight badges and a level-65 Blastoise that knows Surf and Fly, the same moves as the Hall save. `switchzone` was injected for the run and both dev files were restored. `MallocPoolSize` was `16645684`, which is 16255.6 KiB. The pool was not exhausted. The highest Lua heap in the trace was 14441.5 KiB, during Safari Zone Center. The Center samples below are `map.ViridianPokecenter.definition.begin` after every five new maps.

| new maps | Center KiB | since start | KiB per map | since the previous sample |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 12486.2 | 0 |  |  |
| 5 | 13163.7 | 677.5 | 135.5 | 677.5 |
| 10 | 13189.2 | 703.0 | 70.3 | 25.5 |
| 15 | 13318.4 | 832.1 | 55.5 | 129.2 |
| 20 | 13519.0 | 1032.7 | 51.6 | 200.6 |
| 25 | 13477.1 | 990.9 | 39.6 | -41.9 |
| 30 | 13807.3 | 1321.1 | 44.0 | 330.2 |
| 35 | 13669.7 | 1183.5 | 33.8 | -137.6 |
| 40 | 13644.9 | 1158.7 | 29.0 | -24.8 |
| 45 | 13685.7 | 1199.4 | 26.7 | 40.7 |
| 50 | 13920.9 | 1434.6 | 28.7 | 235.2 |

The order was Pallet, Viridian, its Mart and Gym, Route 1; Route 2, Viridian Forest, Pewter, its Mart and Gym; Route 3, Mt. Moon 1F, B1F, B2F, and the Moon Center; Route 4, Cerulean, its Mart and Gym, Route 24; Routes 25, 5, and 6, Vermilion and its Mart; Vermilion Gym, Route 11, Diglett's Cave, Route 9, Rock Tunnel 1F; Lavender, its Mart, Pokémon Tower 1F, Routes 8 and 7; Celadon, Celadon Mart 1F, Saffron, its Mart and Gym; Fuchsia, its Mart, Routes 12 and 16, Cinnabar; Cinnabar Gym, Seafoam 1F, Victory Road 1F, the Power Plant, and Safari Zone Center. Each return to the Center is the sample.

It has not plateaued. The first five maps cost 135 KiB each, because they bring in the overworld, the Mart, and the Gym. Maps 6 through 50 cost 16.8 KiB each (757 KiB), and the Center at map 50 is the highest sample. A group that only repeats a tileset gives back 25 to 140 KiB. The next new tileset takes it back. A line through the eleven Center samples is `12915.7 + 21.13 × maps`. That line crosses 16255.6 KiB at map 158. At 200 maps it is about 17140 KiB, about 890 KiB over the pool. At the 222 maps in the manifest it is about 17610 KiB. This projects an out-of-memory failure before a full playthrough has visited every map. The 50-map run itself did not run out.

The shade grids are the per-tileset payload that grows on a first visit. Each grid is a 16×16 shade string in the runtime definition, keyed by `stable_id`, and a tileset is counted once. All 222 maps together hold 938 unique grids, 234.5 KiB of shade text. This 50-map walk saw 308 of them, 77.0 KiB. The Center heap rose about 19 KiB for each KiB of newly seen shade text, and that ratio stayed between 17 and 25 the whole way. The largest tilesets, in KiB of unique shade text, are:

| tileset | grids | shade KiB |
| --- | ---: | ---: |
| OVERWORLD | 117 | 29.2 |
| SHIP | 63 | 15.8 |
| FOREST | 60 | 15.0 |
| INTERIOR | 55 | 13.8 |
| LOBBY | 52 | 13.0 |
| FACILITY | 51 | 12.8 |
| CLUB | 48 | 12.0 |
| GYM | 47 | 11.8 |
| LAB | 47 | 11.8 |
| MANSION | 46 | 11.5 |
| MART | 37 | 9.2 |
| GATE | 37 | 9.2 |
| MUSEUM | 36 | 9.0 |
| HOUSE | 35 | 8.8 |
| PLATEAU | 35 | 8.8 |
| CAVERN | 32 | 8.0 |
| SHIP_PORT | 30 | 7.5 |
| DOJO | 28 | 7.0 |
| POKECENTER | 25 | 6.2 |
| REDS_HOUSE_2 | 16 | 4.0 |
| REDS_HOUSE_1 | 13 | 3.2 |
| CEMETERY | 12 | 3.0 |
| UNDERGROUND | 8 | 2.0 |
| FOREST_GATE | 8 | 2.0 |

The walk had already paid for Overworld, Gym, Mart, Pokecenter, Cavern, Facility, and most of Forest. The tilesets still unseen are the ones in that table from SHIP down through FOREST_GATE, except the rows the walk already touched. Their shade text is the other 157 KiB. At the same 19 KiB of heap per KiB of shade text, that remainder is about 2900 KiB, which from the map-50 Center (13920.9) lands near 16850 KiB and still over the pool. The shade text itself is only 234.5 KiB, so the strings are not what fills the pool. The heap that tracks them is.

## What reaches the 96 KiB bound

Content-addressing the shade rows does not. The four maps in the 96 KiB test have 122 stable ids and 122 distinct grids, so sharing rows removes nothing. Compacting the entry tables does not either: after the imported entries, the slice catalogue, the field-move decodes, and the prepared encounter zone were dropped, the Center return was still about 190 KiB up. That remainder is the score chunks. `playdate.file.run` keeps each `audio/score/<name>` chunk after `KantoScores` is cleared, and `unloadAll` does not drop the chunk. The first play of the Center, Mt. Moon, Route 4, and Cerulean paid about 156 KiB of those chunks between the two marks.

The patch does three things:

- Identical shade rows in one registration share a single grid table. The share dies with the batch, so a later eviction can free the rows.
- `releaseDepartingWorld` and the Fly origin release drop imported registry entries and their images, the two atlas slots, the slice and Pewter and source sprite caches, the field-move decodes, and the prepared encounter zone. The next visit registers the same stable keys, in definition order, into the same slots above the 37 authored bases. The Center's `registry.slots` line stays `62` on every rebuild.
- The first ordinary `createZone` runs every score file once, then `unloadAll`, before `definition.begin`. Isolated catalogue fixtures skip that warm. The chunks are then in both the first mark and the return, and a new map does not look like growth.

`MallocPoolSize` stayed `16645684`.

With the patch applied, `test_lane_e_departed_tile_registry.py` passed inside 96 KiB and both Center `registry.slots` counts were 62. The fifty-map walk, same fixture and the same order as the table above, sampled the Center at:

| new maps | Center KiB | since start | since the previous sample |
| ---: | ---: | ---: | ---: |
| 0 | 13693.0 | 0 |  |
| 5 | 13802.7 | 109.7 | 109.7 |
| 10 | 13872.3 | 179.3 | 69.6 |
| 15 | 13880.2 | 187.2 | 7.9 |
| 20 | 13899.1 | 206.1 | 18.9 |
| 25 | 13916.1 | 223.1 | 17.0 |
| 30 | 13939.4 | 246.4 | 23.3 |
| 35 | 13942.4 | 249.4 | 3.0 |
| 40 | 13953.3 | 260.3 | 10.9 |
| 45 | 13966.4 | 273.4 | 13.1 |
| 50 | 13978.3 | 285.3 | 11.9 |

Map 20 through map 50 spans 79.2 KiB. The highest Lua heap in that trace was 14811.4 KiB, 1444 KiB under the 16255.6 KiB pool. The old line crossed the pool near map 158. This tail is about 2.6 KiB per map; carried to map 200 it is still near 14400 KiB. `registry.slots ViridianPokecenter` was 62 after every return.

`python3 tools/generate_terrain_atlases.py --check` regenerated the 24 atlases, 938 frames, and matched the files in `Source/terrainAtlases`. That is the Pallet overworld pin and the Gym pin shared by Celadon Gym and Fuchsia Gym. The battle-art pins are `tools/generate_battle_art.py --check` against archive `e571972fc926dcb65d94fc989299d38109590aa945ed657bf215eac8561afd05`. That archive is not on this machine. The patch does not change the generator, the shade grids, or the battle PNGs. On the patched tree, `contracts cave-encounters` passed 8, `contracts field-travel` passed 3, and `contracts individual-stats-v1` passed 17.
