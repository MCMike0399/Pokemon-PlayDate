# Lane K Fly memory

Measured on lane E tip `79fbcba5` (`origin/cursor/lane-e-integration`). That tip already contains the switchZone release (`95554e07`), the Hall release, and the lazy `postgameStory` load. `origin/main` is `ea32b553`, an ancestor of this branch and behind E, so the flights were run on E. Pool size is unchanged (`MallocPoolSize` 16645684, lua peak budget 14000 KiB). No pin edits.

Fly is the party-menu field move. The 12-frame shade fade is unchanged. The release is inside `FieldTravelRuntime.fly`, before `WorldDeltas.ensureZone`. The same player, npc manager, and view object stay available for a failed capture.

## Patch

`tools/notes/lane-e-fly-release-before-build.patch` is a git diff of five files and applies on `79fbcba5` (`git apply --check`). The earlier hunk that added `function SourceEvents.releaseRecentContent()` is gone. E already defines that function. `releaseFlyOrigin` still calls it.

- `Source/game/fieldTravelRequests.lua` nils `request.zone` after the request is committed and before `commitFieldTravel`. That field was the last strong reference to the origin.
- `Source/game/fieldTravelRuntime.lua` adds `releaseFlyOrigin`. It drops stack `.zone` holders, the origin view bitmaps, the checkpoint closure, the imported cache, recent event chunks, and the map bed, then collects, then builds the destination. `currentZone` is set to the destination before `releaseInactive`, or that pass frees the zone that was just built. `gfx.sprite.removeAll` and `TileRegistry:releaseRenderedImages` drop the origin atlas bitmaps. The view is built under incremental collection and the session returns to generational. A failed view rolls the same player, manager, and view back.
- `Source/world/tileRegistry.lua` adds `releaseRenderedImages`. It clears rendered bitmaps only. Tile definitions stay. `TileRegistry:releaseImported` is not called.
- `Source/world/overworld.lua` guards `WorldView:dispose` when Fly has already cleared `view.zone`, and builds a city tile index with `table.create` once the map is past 1024 cells. Doubling that array needs a second copy while the first is still live.
- `Source/game/kantoAudio.lua` lets the single `enterMap` that follows a cross-city Fly keep a missed bed silent. A nil error, `out of memory`, or `inflate` is absorbed for that call. Any other error still raises, and the next map entry is unchanged.

## Harness

Cerulean → Fuchsia and Lavender → Fuchsia stopped on the first menu A because `Harness.afterFrame` wrote a full diagnostics snapshot and opened `trace.jsonl` on every frame. On Cerulean the heap at `actors.end` was about 13457 KiB. The frame whose tick was a multiple of 15 then sat inside the snapshot encode or `playdate.file.open`. Shifting the script so that heartbeat landed on a `wait` instead of A moved the stall with the heartbeat, so the button had been delivered. The product menu was not stuck.

Those six flights were measured with a harness trace change. The empty-snapshot patch stays held. `lane-e-harness-completion-snapshot.patch` is the replacement and is applied with this Fly rebase: a finished command keeps the player and zone, and wait frames can stay stubs.

## Before and after

Real party menu. Level 65 Blastoise, only move `fly`, quest flag `BADGE_THUNDER`. The destination is marked visited without decoding it. Menu path: B, POKEMON, the mon, FLY, the city (fly-list order, so Saffron → Fuchsia takes no extra Down), YES, A on the announce, then the fade. Screenshots are not taken during the flight (`--recent-interval 10000`). Same-city Fly is not in the matrix.

Unpatched `79fbcba5`, Viridian → Fuchsia, `test_viridian_fly_to_fuchsia_stays_under_budget`: Viridian `map.ViridianCity.zone.end` 13248.7 KiB (peak 13248.7). Fuchsia reaches `map.FuchsiaCity.art.end` 13911.2 (peak 13911.2) and never records `map.FuchsiaCity.zone.end`. The run ends with `dev/harness_capture.lua:22: malloc(12018) failed: out of memory`.

Patched `79fbcba5` plus the harness change. Peaks are the destination `zone.end` row. Resting heap is the result snapshot.

| Flight | Destination `zone.end` | Peak | Resting | Arrival |
| --- | ---: | ---: | ---: | --- |
| Viridian → Fuchsia | 13524.4 | 13524.4 | 13346.4 | (19, 28) `kanto_fuchsia_city` |
| Cerulean → Fuchsia | 13602.0 | 13602.0 | 13435.8 | (19, 28) `kanto_fuchsia_city` |
| Lavender → Fuchsia | 13575.9 | 13575.9 | 13388.9 | (19, 28) `kanto_fuchsia_city` |
| Celadon → Saffron | 13555.1 | 13555.1 | 13460.1 | (9, 30) `kanto_saffron_city` |
| Fuchsia → Saffron | 13628.8 | 13628.8 | 13504.7 | (9, 30) `kanto_saffron_city` |
| Saffron → Fuchsia | 13588.1 | 13588.1 | 13395.0 | (19, 28) `kanto_fuchsia_city` |

`FlyMemoryTest.test_viridian_fly_to_fuchsia_stays_under_budget` passes on that tree in 18.449s (Viridian row above). `FlyMemoryTest.test_every_visited_city_can_fly` passes in 113.815s and covers all six rows. `FlyMemoryTest.test_patch_is_a_diff_and_does_not_raise_the_pool` passes against the rebased patch.

The Celadon `zone.end` 13574.3 KiB `not enough memory` figure was the older `10e43dcf` tree. On this tip the same flight arrives at Saffron `zone.end` 13555.1.

## Field-travel contracts

On `79fbcba5`, unpatched and patched, the `contracts field-travel` suite runs 23 tests and fails one: `field-travel: Fly uses durable visited cities without granting route destinations` raises `not enough memory` at `dev/fieldTravelContracts.lua:91`. Surf and `expired Surf takes input before held traversal` both pass. Safari Zone `zone.end` is present, so the expired-Surf Safari inflate from `10e43dcf` does not reproduce here. That older failure happened because main had not yet picked up E's switchZone and Hall releases.

The remaining contract builds Cerulean (`map.CeruleanCity.zone.end` 13770.8 unpatched, 13781.8 patched) and then `provider:ensure` of Pewter while Cerulean is still live. The trace has no Pewter City zone, and the scene never reaches `FieldTravelRuntime.fly`. Party-menu Fly is a different path and does release the origin. This patch does not change that contract result.

## Pins to regenerate

Do not hand-edit. Regenerate with the owning generator after the Source change lands.

- `docs/validation/coverage-current.json` `snapshot.source_sha256`. `tools/check_coverage_matrix.py` compares it to `tools.harness.run.fingerprint` of the whole `Source` tree (`Source/dev/harness_build.lua` is the only excluded file). `tools/tests/test_coverage_matrix.py` `CurrentMatrixTests.test_complete_source_indices_without_completion_promotion` fails when any of the five product files or `Source/dev/harness.lua` changes.

`tools/generate_cerulean_journey.py` hashes `game/sourceEvents.lua`, and `tools/generate_vermilion_journey.py` hashes `game/sourceEvents.lua` and `world/zone.lua`. This patch and the harness change leave those bytes alone, so `Source/dev/ceruleanJourney.json` and `Source/dev/vermilionJourney.json` stay valid. Historical inventories under `tools/integration/` and `docs/validation/` are not live pins.

## Ready for RedBot

Ready: `tools/notes/lane-e-fly-release-before-build.patch` on `79fbcba5`. The harness snapshot change is held. Proof is `test_viridian_fly_to_fuchsia_stays_under_budget` and `test_every_visited_city_can_fly` in `tools/tests/test_lane_e_fly_memory.py`.

The field-travel contract that died while Cerulean was still live is fixed separately in `tools/notes/lane-e-fly-contract-release.patch`. See `docs/validation/lane-k-harness-and-contract.md`.
