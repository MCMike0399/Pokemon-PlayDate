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
- The first ordinary `createZone` runs every map bed once, then `unloadAll`, before `definition.begin`, when the 9 MiB sample is off. That is the harness. `move_` files are battle cues, not map beds, so the warm leaves them for first play. Isolated catalogue fixtures skip that warm. The chunks are then in both the first mark and the return, and a new map does not look like growth. A player or device build is inside the sample, so it marks `registry.warm.deferred` and loads each bed on first play through the same `file.run`.

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

## After main b7cdc96e

`git merge` of `b7cdc96e` applied cleanly. `git apply --check tools/notes/lane-e-departed-tile-registry.patch` passed on that merged tree. The 96 KiB bound and the map-20-to-50 span of 96 KiB were not changed. Unpatched, the four-map return was 12548.458 to 13062.327 KiB (+513.869) and the fifty-map tail spanned 457.248 KiB. With the patch applied, both tests passed.

Two fresh processes ran the four-map return from the same fixture (intro skipped, seed 1, Viridian Center at (7, 4) facing right, level-5 Squirtle). Each process dumped every registry slot as `id=stable_key` after the first Center build and again after the return. The two processes matched, and within each process the first build matched the return. There are 62 slots. Slots 1–37 are `base:1` through `base:37`. Slots 38–62 are `pokered:POKECENTER:cell:…`, and slot 62 is `pokered:POKECENTER:cell:5c-5d-5e-5f`.

The same patched walk was continued to 100 maps. The first 50 keys are the fifty-map test. The next 50 are the following compact keys in alphabetical order: the bike shop, Bill's house, Blue's house, the Celadon houses, gym, hotel, mansion floors, mart floors, the Cerulean houses and cave floors, the Cinnabar lab rooms, the daycare, both Diglett gates, the dojo, both forest gates, the Fuchsia houses and gym, the Game Corner and its prize room, and Indigo Plateau plus its lobby. Agatha's room, Bruno's room, Lance's room, Lorelei's room, the Champion's room, and the Hall of Fame were skipped because entering them leaves the overworld in a dialog. The Center `definition.begin` samples were:

| new maps | Center KiB | since start | since the previous sample |
| ---: | ---: | ---: | ---: |
| 0 | 13736.3 | 0 |  |
| 5 | 13846.0 | 109.6 | 109.6 |
| 10 | 13917.1 | 180.8 | 71.1 |
| 15 | 13923.5 | 187.1 | 6.4 |
| 20 | 13936.3 | 199.9 | 12.8 |
| 25 | 13959.5 | 223.1 | 23.2 |
| 30 | 13980.4 | 244.1 | 21.0 |
| 35 | 13985.8 | 249.4 | 5.3 |
| 40 | 13997.9 | 261.6 | 12.2 |
| 45 | 14009.7 | 273.3 | 11.7 |
| 50 | 14021.6 | 285.3 | 11.9 |
| 55 | 14059.0 | 322.7 | 37.4 |
| 60 | 14069.4 | 333.1 | 10.4 |
| 65 | 14080.8 | 344.5 | 11.4 |
| 70 | 14099.2 | 362.8 | 18.3 |
| 75 | 14113.5 | 377.1 | 14.3 |
| 80 | 14130.4 | 394.0 | 16.9 |
| 85 | 14137.3 | 401.0 | 6.9 |
| 90 | 14151.3 | 415.0 | 14.0 |
| 95 | 14170.0 | 433.7 | 18.7 |
| 100 | 14193.7 | 457.4 | 23.7 |

Map 20 through map 50 spans 85.3 KiB, 2.84 KiB per map. Map 50 through map 100 spans 172.1 KiB, 3.44 KiB per map. The highest Lua heap in that trace was 14854.8 KiB, 1401 KiB under the pool. `registry.slots ViridianPokecenter` stayed 62.

The score chunks are not this tail. The warm still moves the heap once, from 12595.2 to 13722.3 KiB (+1127), before the first Center sample, and `KantoScores` was empty at every later sample. Skipping `KantoAudio.enterMap` left the revisit step unchanged. After map 50 the per-map step does not track score-file size (correlation -0.03) or runtime JSON size (correlation -0.17).

At each Center sample the event-source tables stayed 219814 bytes, text sources 368, content indexes and content fields empty, the recent chunk cache 3 entries (999 bytes), `SpriteFactory.npc` 8 keys, `zoneRegistry` 6 zones, packed rows 16, and the retained runtime 1. `zoneProfiles` gained one profile string per map. None of those is a few KiB per visit. Turning the boot-trace print off, and then making `BootTrace.mark` return without writing, left the same step, so the trace log is not the holder either.

What remains is live data that is still there after `releaseDepartingWorld` and two full collections. Twelve round trips through Pallet Town and the Center, from the same fixture, climbed by 2.125 KiB on each of the later returns (2176 bytes). From the second return to the twelfth, the floor rose 21.8 KiB and did not level off. That cost is per visit, not per new map, so the catalogue of 222 maps does not cap it.

Map 100 sits at 14193.7 KiB. The pool is 16255.6, which leaves 2062 KiB. At 2.125 KiB per Pallet/Center round trip, about 970 more of those trips fit. The maps still unseen, at the post-50 rate of 3.44 KiB each, are about 420 KiB. A first visit of the manifest fits, and so do several hundred revisits. The tail is not flat, and re-entering a map does not stop it. The 96 KiB tests were not loosened. `MallocPoolSize` stayed `16645684`.

## The 9 MiB sample

`BootTrace.checkGuard` errors when the Lua heap is at least `9 * 1024` KiB. The comment above `BootTrace.memoryBudgetEnabled` names the three admission limits: 6 MiB is the post-collection live cap on hardware, 8 MiB is the soft collection point, and 9 MiB is the hard sample. `docs/validation/progress.md` records the same three limits. The budget is on for a device-test build and for any process where the harness is off. A private harness session leaves it off, which is why the 96 KiB walks can hold the map-bed chunks and still be inside the pool. The guard numbers were not changed, and `MallocPoolSize` stayed `16645684`.

On `f79bce30`, a production `.pdx` (the `dev` tree dropped) played with the simulator's buttons from the title, through Oak's speech, to the grass north of Pallet. That commit already spills harness results and releases departed actor profiles (`a87c8d89`), so `tools/notes/lane-e-revisit-leak.patch` does not apply on it. The unpatched boot is that code.

| build | guard | phase | sample KiB |
| --- | --- | --- | ---: |
| unpatched `f79bce30` | fires | `door.map.end` | 9270.576 |
| map beds warmed | fires | `registry.warm.end` | 9874.775 |
| warm deferred | fires | `door.map.end` | 9279.074 |

The full map-bed warm moved the heap from 8695.074 KiB at `registry.warm.begin` to 9873.194 KiB at `registry.warm.end`. The deferred warm stays at 8695.135 then 8695.273. The lab overworld still crosses the sample at `door.map.end` with no score warm at all (unpatched trace 9270.153 KiB). That is the player path, not the warm, and the guard was left as it is.

The harness still warms every map bed before the first measured floor. On this tree that warm is `registry.warm.begin` then `registry.warm.end`, and the Center return moved from 13694.188 KiB to 13717.009 KiB (22.821 KiB, slots 62 both times). Map 20 through map 50 spanned 42.523 KiB, and the highest of those Center samples was 13931.778 KiB. `move_` cues stay on the first-play path in both builds. `KantoSynth.identity` mixes the notes `ensureScore` binds after `file.run`. The identity session loads each score, drops it, and loads it again. Those two mixes match, and the ticks, loop, and note count match the score file. The 30-trip revisit test, which is already in `f79bce30` rather than applied as a second note, passed inside 8 KiB.
