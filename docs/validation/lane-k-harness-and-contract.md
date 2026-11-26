# Lane K harness trace and Fly contract

Measured on lane E tip `79fbcba5`. Pool size is unchanged (`MallocPoolSize` 16645684). No pin edits. `origin/main` is still `ea32b553`.

## Harness trace handle

`tools/notes/lane-e-harness-trace-handle.patch` is held. It is not applied on this tip. Each finished command kept a full diagnostics snapshot and opened `trace.jsonl` again. On Cerulean a snapshot is about 30 KiB, so forty `wait 1` commands climbed 13365.6, 13488.2, 13634.8, 13781.0, 13927.2 KiB and the runtime raised `not enough memory`. The heartbeat stayed at tick 15. The product was idle on `kanto_cerulean_city`.

The patch keeps one trace handle and skips the full snapshot once `collectgarbage("count")` is at least 13000 except on tick 1 and the last command. That empty snapshot is encoded as `[]`, and `test_hall_continue_matches_pallet_and_walks_four` then fails reading the player. K is fixing the patch so a completed command a host test reads still keeps a real snapshot. Intermediate `wait` frames can stay stubs.

## Fly visited-cities contract

The product should not release inside `ImportedMaps:ensure`. That cache is two slots on purpose, and `switchZone` already drops the departing city before the next decode. The contract never called `switchZone`. It ensured Cerulean, entered it, then ensured Pewter while that city and the previous scenes' retained definitions were still live. The failure is `not enough memory` at `fieldTravelContracts.lua:91`. On unpatched `79fbcba5` the trace ends at `overworld.field_prepare.end` after `map.CeruleanCity.zone.end` 13770.8 KiB, with no Pewter zone. Surf and expired Surf still pass (`contract-progress` passed 2, failed 1).

`tools/notes/lane-e-fly-contract-release.patch` applies on `79fbcba5`. The contract releases retained runtime definitions, tile grids, recent event chunks and the map bed at the start and end of each scene, matching `sourceMapContracts`. Between the two cities it releases Cerulean the way `switchZone` does, against the scene's own context, after the visit is in the session. `ensure` is unchanged.

With the patch, `contracts field-travel` passes all 23 tests in 22.513s. `contract-progress` is field-travel, passed 3, failed 0. Pewter `zone.end` is 13454.5 KiB after Cerulean's definition has been dropped (Pewter `definition.begin` 12821.0). The rejected capture and the successful fly each rebuild Cerulean (`zone.end` 13722.1 and 13758.5, peak 13862.9).

`tools/tests/test_lane_e_fly_contract.py`:

- `FlyContractTest.test_patch_is_a_diff_and_does_not_raise_the_pool` passes.
- `FlyContractTest.test_fly_visited_cities_stays_under_the_pool` fails on `79fbcba5` at line 91 and passes with the patch.

## Pin to regenerate

`docs/validation/coverage-current.json` `snapshot.source_sha256`, via `tools.harness.run.fingerprint`. `Source/dev/harness.lua` and `Source/dev/fieldTravelContracts.lua` are both in that hash. `CurrentMatrixTests.test_complete_source_indices_without_completion_promotion` is the check. Cerulean and Vermilion journey pins hash `game/sourceEvents.lua` and `world/zone.lua`, which these patches leave alone.
