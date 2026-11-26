# Lane K Fly memory

Pool size is unchanged (`MallocPoolSize` 16645684, lua peak budget 14000 KiB). No Source commit on this branch. No pin edits. `origin/main` is still `ea32b553`, already an ancestor of this branch, so nothing was merged.

Fly is the party-menu field move. The 12-frame shade fade is unchanged. The release is inside `FieldTravelRuntime.fly`, before `WorldDeltas.ensureZone`. The same player, npc manager, and view object stay available for a failed capture.

## What the patch drops

`tools/notes/lane-e-fly-release-before-build.patch` is a git diff of six files:

- `Source/game/fieldTravelRequests.lua` nils `request.zone` after the request is committed and before `commitFieldTravel`. That field was the last strong reference to the origin.
- `Source/game/fieldTravelRuntime.lua` adds `releaseFlyOrigin`. It drops stack `.zone` holders, the origin view bitmaps, the checkpoint closure, the imported cache, recent event chunks, and the map bed, then collects, then builds the destination. `currentZone` is set to the destination before `releaseInactive`, or that pass frees the zone that was just built. `gfx.sprite.removeAll` and `TileRegistry:releaseRenderedImages` drop the origin atlas bitmaps. The view is built under incremental collection and the session returns to generational. A failed view rolls the same player, manager, and view back.
- `Source/game/sourceEvents.lua` adds `SourceEvents.releaseRecentContent`. This is the same function as in `tools/notes/lane-e-switchzone-release-before-build.patch`. If that patch lands first, drop this hunk.
- `Source/world/tileRegistry.lua` adds `releaseRenderedImages`. It clears rendered bitmaps only. Tile definitions stay.
- `Source/world/overworld.lua` guards `WorldView:dispose` when Fly has already cleared `view.zone`, and builds a city tile index with `table.create` once the map is past 1024 cells. Doubling that array needs a second copy while the first is still live. That copy is the allocation that failed after Fuchsia `zone.end`.
- `Source/game/kantoAudio.lua` lets the single `enterMap` that follows a cross-city Fly keep a missed bed silent. A nil error, `out of memory`, or `inflate` is absorbed for that call. Any other error still raises, and the next map entry is unchanged. The destination bed often has no 32 KiB inflate window after the atlas. Loading the bed before the city aborts the build.

`TileRegistry:releaseImported` is not called.

## Before and after

Real party menu. Level 65 Blastoise, only move `fly`, quest flag `BADGE_THUNDER`. The destination is marked visited without decoding it. Menu path: B, POKEMON, the mon, FLY, the city, YES, A on the announce, then the fade. Screenshots are not taken during the flight (`--recent-interval 10000`); a 12 KiB capture malloc fails on this cliff and hides the game error. Same-city Fly is not in the matrix.

| Flight | Unpatched `10e43dcf` Source | Patched |
| --- | --- | --- |
| Viridian → Fuchsia | No `map.FuchsiaCity.zone.end`. Player stays at (23, 26) in `kanto_viridian_city`. Stack `overworld>party>fieldTravel`. Snapshot heap 13892.8 KiB. | Four arrivals at (19, 28), zone `kanto_fuchsia_city`. `zone.end` heap 13862.1, 13862.1, 13863.4, 13862.1 (peak equal to that heap). Resting snapshot 13627.6, 13716.8, 13627.6, 13715.6. The shipped patch, with the bed miss limited to the following `enterMap`, landed again: `zone.end` 13862.9, resting 13716.3, player (19, 28). `tools/tests/test_lane_e_fly_memory.py` `FlyMemoryTest.test_viridian_fly_to_fuchsia_stays_under_budget` passes on that tree (`zone.end` 13864.1, resting 13629.6, player (19, 28)) and fails on unpatched Source. The unpatched run publishes `dev/harness_capture.lua:22: malloc(12018) failed: out of memory` and never records `map.FuchsiaCity.zone.end`. |
| Viridian → Saffron | Not separated from the capture malloc. | One arrival at (9, 30), zone `kanto_saffron_city`. `zone.end` 13857.8. Resting snapshot 13619.3. Measured on the patch before the bed miss was limited to one `enterMap`. That limit still covers this flight. |

Cerulean → Fuchsia and Lavender → Fuchsia did not reach a destination `zone.end`. The frame stopped on the first menu A (harness command 10). Cerulean origin `actors.end` was 13650.6. Lavender origin `zone.end` was 13246.5. Celadon → Saffron raised `not enough memory` with Celadon `zone.end` 13574.3 and no Saffron `zone.end`. Those three are not passes.

The `field-travel` contract suite already fails on unpatched `10e43dcf` while loading Fuchsia for the Surf scene (`pd_readcompressed inflate failed, out of memory`) and while building the Fly scene (`not enough memory`). The patched tree fails those two the same way, and also fails `expired Surf takes input before held traversal` while inflating the Safari Zone. This lane does not have a green field-travel run.

## Pins the patch will need regenerated

Do not hand-edit these. Regenerate with the owning generator after the patch is applied to Source.

- `docs/validation/coverage-current.json` `snapshot.source_sha256`. `tools/check_coverage_matrix.py` compares it to `tools.harness.run.fingerprint` of the whole Source tree. `tools/tests/test_coverage_matrix.py` `CurrentMatrixTests.test_complete_source_indices_without_completion_promotion` fails on any of the six files.
- `Source/dev/ceruleanJourney.json` `sources["game/sourceEvents.lua"]`, from `tools/generate_cerulean_journey.py`. `tools/tests/test_cerulean_observations.py` `ProjectionTests.test_deterministic_projection_matches_consumed_source_bytes`.
- `Source/dev/vermilionJourney.json` `sources["game/sourceEvents.lua"]`, from `tools/generate_vermilion_journey.py`. `tools/tests/test_vermilion_acquisition.py` `PlanningBoundaryTests.test_common_blue_tables_and_actual_machine_compatibility_are_projected`.

`Source/dev/vermilionJourney.json` also pins `world/zone.lua`. This patch does not change that file. Historical inventories under `tools/integration/` and `docs/validation/` are not the live pins.
