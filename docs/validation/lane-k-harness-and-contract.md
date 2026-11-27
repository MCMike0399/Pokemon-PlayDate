# Lane K harness trace and Fly contract

Measured on lane E tip `79fbcba5`. Pool size is unchanged (`MallocPoolSize` 16645684). `origin/main` is `93c15d86`, which is that tip plus the lazy postgame load. The completion snapshot below is applied on top of main and is not itself on main yet.

## Harness trace handle

`tools/notes/lane-e-harness-trace-handle.patch` stays held. Its empty snapshot is encoded as `[]`, and the Hall four-step walk then fails reading the player. `tools/notes/lane-e-harness-completion-snapshot.patch` replaces it: every finished command keeps a settled player and zone, and only frames inside a wait stay stubs once the heap is at least 13000 KiB. That snapshot is applied on this branch.

## Fly visited-cities contract

The product should not release inside `ImportedMaps:ensure`. That cache is two slots on purpose, and `switchZone` already drops the departing city before the next decode. The contract never called `switchZone`. It ensured Cerulean, entered it, then ensured Pewter while that city and the previous scenes' retained definitions were still live. The failure is `not enough memory` at `fieldTravelContracts.lua:91`. On unpatched `79fbcba5` the trace ends at `overworld.field_prepare.end` after `map.CeruleanCity.zone.end` 13770.8 KiB, with no Pewter zone. Surf and expired Surf still pass (`contract-progress` passed 2, failed 1).

`tools/notes/lane-e-fly-contract-release.patch` applies on `79fbcba5`. The contract releases retained runtime definitions, tile grids, recent event chunks and the map bed at the start and end of each scene, matching `sourceMapContracts`. Between the two cities it releases Cerulean the way `switchZone` does, against the scene's own context, after the visit is in the session. `ensure` is unchanged.

With the patch, `contracts field-travel` passes all 23 tests in 22.513s. `contract-progress` is field-travel, passed 3, failed 0. Pewter `zone.end` is 13454.5 KiB after Cerulean's definition has been dropped (Pewter `definition.begin` 12821.0). The rejected capture and the successful fly each rebuild Cerulean (`zone.end` 13722.1 and 13758.5, peak 13862.9).

`tools/tests/test_lane_e_fly_contract.py`:

- `FlyContractTest.test_patch_is_a_diff_and_does_not_raise_the_pool` passes.
- `FlyContractTest.test_fly_visited_cities_stays_under_the_pool` fails on `79fbcba5` at line 91 and passes with the patch.

## Pin to regenerate

`docs/validation/coverage-current.json` `snapshot.source_sha256`, via `tools.harness.run.fingerprint`. `Source/dev/harness.lua` and `Source/dev/fieldTravelContracts.lua` are both in that hash. `CurrentMatrixTests.test_complete_source_indices_without_completion_promotion` is the check. Cerulean and Vermilion journey pins hash `game/sourceEvents.lua` and `world/zone.lua`, which these patches leave alone.
