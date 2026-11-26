# City switch memory

Pool `MallocPoolSize=16645684`. SDK 3.1.2. Tree under test is E tip `232d44525a3135e795a286045dbcee2dbb29a649` after a fast-forward of `origin/main` (`ea32b553` is an ancestor). The product change is `tools/notes/lane-e-switchzone-release-before-build.patch`. It is not applied on this branch. `tools/tests/test_lane_e_city_to_city_switch_memory.py` runs the Simulator. Zone-end observed peak must stay at or under `LUA_PEAK_BUDGET_KIB` (14000). A fresh fixture disposes the world and then calls `switchZone`, so that path is not this bug.

`switchZone` used to call `WorldDeltas.ensureZone` while the previous city's view, actors, retained runtime, tile-grid cache, decoded event chunks, and playing map bed were still in the pool. The next city's compressed definition then failed with `pd_readcompressed inflate failed, out of memory`. The patch drops that departing world, collects, and only then decodes the destination. `setupOverworld` collects again before the destination tilemap. The door fade still runs inside the existing load. `DOOR_FADE_FRAMES` is unchanged.

## Live Viridian, then switchZone

One session: fixture `kanto_viridian_city` at (20, 35) facing up, then `switchZone` into each city. Unpatched, the first destination dies at its zone build. Patched, the same session finishes all five and the snapshot. Heaps are KiB from `boot-trace.tsv`.

| Destination | Unpatched | Patched zone.end heap | Patched zone.end observed peak | Patched actors.end heap |
| --- | --- | ---: | ---: | ---: |
| Cerulean City | inflate out of memory, zone end 13817.599 | 13432.101 | 13432.101 | 13471.081 |
| Celadon City | inflate out of memory, zone end 13786.270 / peak 13788.468 | 13431.243 | 13471.081 | 13450.737 |
| Saffron City | zone end 13813.973 / peak 13815.072, session did not return | 13564.050 | 13564.050 | 13676.191 |
| Lavender Town | zone end 13793.616, then `not enough memory` | 13193.285 | 13676.191 | 13258.440 |
| Fuchsia City | inflate out of memory, zone end 13822.721 | 13717.041 | 13717.041 | 13710.584 |

Observed peak on a zone-end row is the running maximum. Lavender's own zone-end heap is 13193.285; the row still shows 13676.191 from Saffron's actors. Every patched zone-end peak is under 14000, and the session outcome is ok.

## Cerulean Cave door

H session `181de250` on `d010ec62` (`docs/validation/lane-h-cerulean-inflate-repro.md`): a fresh fixture switch into Cerulean succeeds (zone end 13594.846), then real steps onto `pokered:CERULEAN_CITY:warps:7` at (4, 11) enter `kanto_cerulean_cave_1f` and the next compressed read fails. `door.map.end` heap 13777.843, peak 13857.402. The failure string there is `pd_readcompressed inflate failed, out of memory`.

The same walk on unpatched `232d4452`, with H's party (level 65 Blastoise, Surf / Hydro Pump / Skull Bash / Rain Dance, seed 11, the five quest flags that hide the guard): the cave zone end is 13705.9 and `door.map.end` peaks at 13852.0, then `runtime error: nil`. With the patch, `map.CeruleanCave1F.zone.end` is heap 13461.1 / peak 13461.1, `door.map.end` is heap 13702.0 / peak 13702.0, and the session outcome is ok. A lighter level 5 Squirtle party completes the door either way; the Blastoise party is the one that fails unpatched.

## What real play hits

Unpatched measurements from a live previous map, not from a disposed fixture:

| Path | Result |
| --- | --- |
| Route 10 to Lavender | zone end 13659.760, actors 13588.438. The view finished. The harness command then timed out with no inflate string. |
| Route 7 gate to Celadon | ok. Zone end 13654.104. |
| Route 8 gate to Saffron | ok. Zone end 13677.280. Actors peak 13746.721. |

Those walks enter the city from a route or a small gate. They do not `switchZone` from one full city into another. The cave door does: Cerulean is still the live city when the warp builds Cerulean Cave 1F. That is the real-play hit, and the patch covers it because the door calls `switchZone`.

Fly does not. `FieldTravelRuntime.fly` keeps the origin zone and view, calls `WorldDeltas.ensureZone` for the destination, and only then releases the origin. This patch does not change Fly. A fly from one full city to another still builds the destination beside the origin.

## Suite

Unpatched `232d4452`: 1448 tests, 6 failed, 49 errors, 11 skipped. With the patch applied on that tree: 1451 tests, 10 failed, 49 errors, 11 skipped. The three added tests are this file's patch check and the two Simulator sessions, and they pass with the patch. The four new failures are source-byte pins, not projection output:

- `test_coverage_matrix.CurrentMatrixTests.test_complete_source_indices_without_completion_promotion` (whole `Source` fingerprint)
- `test_cerulean_observations` journey pin, only `sources.game/sourceEvents.lua`
- both Vermilion journey pins, only `sources.game/sourceEvents.lua` and `sources.world/zone.lua`

Those pins were not edited. `test_lane_e_hall_continue_memory` did not join the failure list.
