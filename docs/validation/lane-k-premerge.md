# Lane K pre-merge check

Scratch worktree of `origin/cursor/lane-e-integration` at `79fbcba560e34945a130d7e1788ab44be5aa8d77`. That tip did not move. `origin/cursor/lane-h-postgame` is `df18a2dfbc198be1ed33a395dcabde4846f31710`. `origin/cursor/lane-f-audio` is `53ad2f815679421dabeb8c6708fc8d3a5144108d`. Pokered is `af519899719f0754965776faac0e836a3b906e6d`. Playdate SDK 3.1.2. `MallocPoolSize` stayed `16645684`. Nothing here was pushed to E or main.

The batch does not pass. With F's audio tree checked out, the host suite adds six failures that are not on E's tip, and `contracts field-travel` fails two tests where E fails one. The no-argument `contracts` aggregate dies at the same suite on both trees.

## Apply order

Check out F's audio tree first, then apply patches in this order. The audio tree is `Source/audio` and `Source/game/kantoAudio.lua` from `53ad2f81` (`git checkout 53ad2f81 -- Source/audio Source/game/kantoAudio.lua`). It is 267 files, `19385` insertions and `14810` deletions against E. F's own done-path note used that same checkout on this E tip.

| Order | Patch | Result on this E tip |
| --- | --- | --- |
| 1 | F audio tree, `53ad2f81` | Checkout, not a diff. Required before heal-count, the original badge hunk, movesfx-import, and the faint cry. |
| 2 | `tools/notes/lane-e-fly-release-before-build.patch` | Clean. The `kantoAudio.lua` hunk still matches F's `enterMap`. |
| 3 | `tools/notes/lane-e-harness-trace-handle.patch` | Clean. |
| 4 | `tools/notes/lane-e-fly-contract-release.patch` | Clean. |
| 5 | `tools/notes/lane-e-type-display-names.patch` | Clean, then `pdc` rejects it. See the import fix. |
| 6 | `tools/notes/lane-k-premerge-type-display-import.patch` | Clean after type-display. `pdc` compiles. |
| 7 | `tools/notes/lane-k-premerge-hof-dex-rating.patch` | Clean on E, and after type-display. Replaces H's hof patch. |
| 8 | `tools/notes/lane-e-audio-badge-item.patch` | Clean once F's `events.lua` is checked out. On E's own cue table, use the badge fix below. |
| 9 | `tools/notes/lane-e-audio-heal-count.patch` | Clean on F's `kantoAudio.lua`. Calls `playSequence`. |
| 10 | `tools/notes/lane-e-audio-pokedex-cry.patch` | Clean on E. `KantoAudio.playCry` is already there. |
| 11 | `tools/notes/lane-e-audio-source-cries.patch` | Clean on E. Same. |
| 12 | `tools/notes/lane-e-audio-movesfx-import.patch` | Clean on F's file. Required with the audio tree. |
| 13 | `tools/notes/lane-e-audio-player-faint-cry.patch` | Clean after that import. Uses `sfxFrames` from F's file. |
| 14 | `tools/notes/lane-e-credits-audio-snapshot-test.patch` | Needs F's `tools/tests/test_lane_e_coverage_fingerprint.py` copied in first. The patched test then fails until the coverage pin is regenerated. |

Left out, on purpose:

- `lane-e-hof-postgame-import`. Superseded.
- `lane-e-mew-gift-dispatch`. Not a diff (`git apply` reports no valid patches). It was written against `d010ec62` and says `PostgameStory.installEvents` has no gift registration. On `79fbcba5` that function already registers `giver.id`, the dispatch id, and `registerWorldHooks`. Do not add a second registration.
- G's `lane-e-ui-fidelity.patch`. Still being revised.

## What conflicts, and what needs F's audio tree

`lane-e-hof-dex-rating.patch` does not apply, on clean E or after type-display. The first hunk, `EndgameStory.hallPageLines` after `playerHallPages`, matches. The second hunk expects `gfx.drawText(page.text, px, py)` at the hall page. E already draws with `EndgameStory.drawPokeredText(gfx, page.text, px, py)`. `tools/notes/lane-k-premerge-hof-dex-rating.patch` keeps H's line layout and draws each line with `drawPokeredText`. `git apply --check` succeeds on E and on the type-display file.

`lane-e-type-display-names.patch` applies, and `pdc` then stops at `Source/game/endgameStory.lua:3` with `No such file: function`. The guard is `if type(import) == "function"`, and `pdc` reads that `import` as a file named `function`. `tools/notes/lane-k-premerge-type-display-import.patch` replaces the guard with a file-scope `import "game/drawnText"`, which is the form `battleScene.lua` and `gbFont.lua` already use. After that fix, `pdc` compiles the integrated `Source`. It also compiles clean E.

`lane-e-audio-badge-item.patch` does not apply to E's `Source/audio/events.lua`. E's cue table is alphabetical, so `badge` sits between `arrow_tiles` and `bicycle`. The patch context is F's table, where `badge` sits between `arrow_tiles` and `ball_poof`. The `tools/audio/events.py` hunk does apply to E. `tools/notes/lane-k-premerge-audio-badge-item.patch` is the one-line cue change plus that Python hunk, and it applies on E without the rest of F's table. After the audio-tree checkout, the original patch's Lua hunk applies and this fix is unnecessary.

These depend on F's audio tree, not just a textual apply:

- `lane-e-audio-heal-count.patch` applies on E's `kantoAudio.lua` and on F's. The replacement calls `playSequence`. That function, plus `sfxFrames` and `enqueueSFX`, exist only in F's file. Landing the hunk alone makes a heal call a missing global.
- `lane-e-audio-movesfx-import.patch` adds a file-scope `import "audio/moveSfx"`. F's `moveScore` still has a lazy import. `pdc` does not compile an import it only sees inside the function, so `KantoMoveSfx` stays nil and the champion's first move crashes at `kantoAudio.lua` (`attempt to index a nil value`). Apply this whenever the audio tree is applied.
- `lane-e-audio-player-faint-cry.patch` is written against F's faint block and calls `sfxFrames`.
- `lane-e-credits-audio-snapshot-test.patch` edits `tools/tests/test_lane_e_coverage_fingerprint.py`, which is not on E. The file on `53ad2f81` is the one-test module the patch expects.

`lane-e-audio-pokedex-cry.patch` and `lane-e-audio-source-cries.patch` do not need the rest of the audio tree. They call `KantoAudio.playCry`, which E already defines.

F's `tools/tests/test_lane_e_audio_fidelity.py` (six tests, no skip and no expected failure) was copied into the scratch tree. All six passed against this batch: heal count, source cry, pokedex cry, badge fanfare, player faint cry, and the file-scope move-SFX import.

## Host suite

`POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered KANTO_REFERENCE=/tmp/pokemon-host/pokered PLAYDATE_SDK_PATH=/tmp/pd-sdk/PlaydateSDK-3.1.2 python3 -m unittest discover -s tools/tests`

| Tree | Tests | Time | Failures | Errors | Skipped |
| --- | --- | --- | --- | --- | --- |
| E `79fbcba5` | 1428 | 216.072s | 36 | 74 | 11 |
| Integrated, with the audio tree | 1435 | 396.091s | 41 | 75 | 11 |

The seven extra tests are F's six fidelity tests, which passed, and the credits fingerprint test, which failed. No failure that is present on E disappeared. Of E's 110 failed or errored tests, 96 are this VM missing Lua 5.4 or a reference tree under `/home/ubuntu/Developer/Pokemon-PlayDate-env`, `/tmp/lua-5.4.7`, or `/tmp/pokered`. These 14 also fail on E, and they fail the same way on the integrated tree:

- `test_brock_preparation` `test_identified_source_training_lanes_are_real_blue_grass_not_door_shortcuts`
- `test_brock_warp_reentry` the six warp-reentry tests
- `test_cerulean_journey` `test_real_unified_cache_and_header_geometry_load_without_lua_or_sdk`
- `test_vermilion_acquisition` `test_real_prepared_geometry_has_common_grass_lanes_and_honest_cave_gap`
- `test_lane_a_seafoam_current` `test_predicate_matches_is_surfing_allowed`
- `test_lane_g_front_end` `test_title_mons_do_not_cover_the_copyright`
- `test_source_map_pipeline` `test_original_map_inputs_authored_pallet_and_renderers_are_unchanged`
- `test_substitute_art` `test_every_existing_image_and_grid_matches_the_living_art_freeze`
- `test_substitute_art` `test_mechanics_producer_schema_rng_and_existing_case_names_are_unchanged`

New on the integrated tree:

1. `test_coverage_matrix` `test_complete_source_indices_without_completion_promotion`. `matrix stale: Source fingerprint differs`. The pin is `f81d5bd07148e57dd4f85f500dcc784afd7e291a39288ceaa50cadcfc5457db4`. The live fingerprint is `e133ed8c4b13e1facb795d184e3c51d9149f6649e2be05784d2cc3c859e518be`.
2. `test_lane_e_coverage_fingerprint` `test_snapshot_records_the_credits_path_audio`. Same two hashes. This test is not on E. Do not hand-edit `docs/validation/coverage-current.json`. Regenerate it.
3. `test_cerulean_observations` `test_deterministic_projection_matches_consumed_source_bytes`. `project(Source)` no longer matches `Source/dev/ceruleanJourney.json`. The projection hashes `game/eventState.lua`, which `lane-e-audio-source-cries.patch` changes. Regenerate with `tools/generate_cerulean_journey.py`. Do not hand-edit the pin.
4. `test_lane_e_city_to_city_switch_memory` `test_cerulean_cave_warp_stays_under_budget`. The command timed out. `map.CeruleanCave1F.zone.end` was `13544.1` KiB, peak `13597.0`. The heartbeat stayed at tick 30, command 5, `12078` ms. The last frame is still the city side of the entrance. Cancellation was unconfirmed.
5. `test_lane_e_city_to_city_switch_memory` `test_live_viridian_switch_stays_under_budget`. Runtime error `nil` at tick 8 on Lavender, heap `13294.5` KiB. Cerulean, Celadon, and Saffron recorded `zone.end`. Fuchsia did not. The thrown value is nil, so this is not an out-of-memory string. Map entry now goes through F's `KantoAudio.enterMap`.
6. `test_lane_e_hof_continue_releases_hall` `test_hall_continue_matches_pallet_and_walks_four`. The Hall-versus-Pallet heap check passed. The following read, `move["snapshot"]["player"]`, raised `TypeError: list indices must be integers or slices, not str`. The harness patch stores an empty snapshot on a non-final command once `collectgarbage("count")` is at least `13000`, and Playdate's encoder writes that empty table as `[]`. The walk's snapshot is not the last command. The four-step assertion never saw a player.

The harness patch is what the Cerulean one-frame-wait case needs, and it is also what empties the Hall walk snapshot. A command that a host test reads has to keep a real snapshot when it completes. Intermediate frames of a `wait` can stay stubs.

## Contracts

`python3 tools/harness/run.py --sdk /tmp/pd-sdk/PlaydateSDK-3.1.2 --timeout 1500 --ready-timeout 120 --max-frames 18000 --recent-interval 10000 contracts`

`max-frames` above `18000` is rejected. `recent-interval` was `10000` so a per-frame capture does not `malloc(12018)`.

The no-argument aggregate does not finish on E. `Source/dev/contracts.lua` already says the full report cannot be published inside the 16 MiB pool. Both trees ran until `individual-stats-v1` returned, then the process died before `result.json` was published.

| Tree | Last checkpoint | Heap | How it died |
| --- | --- | --- | --- |
| E | `individual-stats-v1` returned, 16 passed, 1 failed | `13804.4` KiB | `harness_capture.lua:22: malloc(12018) failed`, then `pd_readcompressed inflate failed, out of memory` |
| Audio tree | `individual-stats-v1` returned, 11 passed, 6 failed | `13824.2` KiB | `not enough memory` |

Run alone, that suite scores. `contracts individual-stats-v1` is 17 passed, 0 failed on E (`12922.8` KiB) and on the audio tree (`13215.0` KiB). The extra aggregate failures are the audio tree sitting higher in the same pool, not a new individual-stats rule.

`contracts field-travel` does reach a scored report. E's tip fails the Fly test and passes the other two. The audio tree, with `lane-e-fly-contract-release.patch` applied, fails Fly and also fails expired Surf.

| Test | E `79fbcba5` | Integrated, audio tree plus the release patch |
| --- | --- | --- |
| Surf enters water | pass | pass |
| expired Surf takes input before held traversal | pass | fail. `fieldTravelContracts.lua:367`, `pd_readcompressed inflate failed, out of memory` |
| Fly uses durable visited cities | fail. `fieldTravelContracts.lua:91`, `not enough memory` | fail. `fieldTravelContracts.lua:99`, `not enough memory` |

Suite progress was 2 passed / 1 failed on E and 1 passed / 2 failed on the audio tree. The release calls are in the integrated file. They are not enough once F's scores are linked: the Fly scene still runs out of memory, and expired Surf, which fits on E, inflates out of memory too.

## Pins

Do not hand-edit these. Regenerate them after the batch lands.

- `docs/validation/coverage-current.json` `snapshot.source_sha256`. Pinned `f81d5bd07148e57dd4f85f500dcc784afd7e291a39288ceaa50cadcfc5457db4`. Live integrated fingerprint `e133ed8c4b13e1facb795d184e3c51d9149f6649e2be05784d2cc3c859e518be`.
- `Source/dev/ceruleanJourney.json`. The projection hashes `game/eventState.lua`.
