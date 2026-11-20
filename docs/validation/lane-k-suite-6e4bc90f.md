# Lane K host suite on 6e4bc90f

Tree under test: `cursor/lane-k-qa` at `6e4bc90fe6c9c72a23f8249ff453babc777193aa` plus the lane K notes already on that branch. `origin/main` and `origin/cursor/lane-e-integration` were still `6e4bc90f`. `MallocPoolSize` was not changed.

Reference: pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`.

```sh
POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered \
KANTO_REFERENCE=/tmp/pokemon-host/pokered \
python3 -m unittest discover -s tools/tests
```

`KANTO_REFERENCE` is the same checkout. The documented host recipe also sets it. Lua 5.4.6 and Pillow 12.1.0 were installed so the probes that need them can run. There is no Playdate SDK, no `PARCEL_BUNDLE_SOURCE`, and no `~/Developer/Pokemon-PlayDate-env` pin tree.

## Counts

| Result | Count |
| --- | --- |
| Ran | 1382 |
| Passed | 1302 |
| Failed | 13 |
| Errors | 51 |
| Skipped | 11 |
| Expected failures | 5 |
| Unexpected successes | 0 |

The five expected failures are the queued lane K live assertions (gym tones, flower tile `$03`, iris stencil, Viridian sight, trainer-card and Pay Day yen). They still fail on the live tree. No lane K test failed unexpectedly.

This VM has no earlier suite log for `6e4bc90f`, so these 13 failures are the failures of this run. They are not a head-only device score.

## Failures

| Test | What it reported |
| --- | --- |
| `test_capture_followup.CaptureFollowupTests.test_owned_flag_is_read_before_recruit_and_the_field_draws_at_the_origin` | `battleScene.lua:1205` indexes a nil `machine` inside the host draw probe |
| `test_cerulean_observations.ProjectionTests.test_deterministic_projection_matches_consumed_source_bytes` | generated projection does not match the pinned bytes |
| `test_door_census.InventoryTests.test_authored_portals_separate_and_all_case_ids_unique` | census found `authored_connection` where it expected authored doors |
| `test_door_census.InventoryTests.test_pin_corruption_and_unsupported_authored_syntax_fail` | `ValueError` was not raised |
| `test_lane_g_front_end.LaneGFrontEndTests.test_title_mons_do_not_cover_the_copyright` | `engine/movie/title.asm` did not parse `.tileScreenCopyrightTiles` |
| `test_region_registrations` staged-owner drift, and the `main.lua` relative case | message is `transform dependency changed: world/sourceMaps.lua`, the test still expects `owner imports changed` |
| `test_source_map_pipeline.SourceMapManifestTests.test_original_map_inputs_authored_pallet_and_renderers_are_unchanged` | `Source/data/maps.lua` |
| `test_substitute_art` living-art freeze | `Source/world/tilefactory.lua` bytes differ from the freeze |
| `test_substitute_art` mechanics producer | `Source/dev/battlePresentationContracts.lua` bytes differ from the freeze |
| `test_vermilion_acquisition` machine projection | generated collection does not match the pin |
| `test_vermilion_journey.ProjectionTests.test_generation_is_exact_and_pins_every_map_and_three_counter_teams` | same collection mismatch |
| `test_vermilion_preparation` old manifest | sha256 `537c712d…` != `1a688c48…` |

## Errors

These are missing machine pins, not new gameplay assertions.

| Count | Cause |
| --- | --- |
| 9 | Playdate SDK missing at `~/Developer/PlaydateSDK` |
| 9 | `authored Pallet/lab startup body changed` from the harness protocol |
| 6 | saffron-guard manifest missing under `~/Developer/Pokemon-PlayDate-env/references` |
| 5 | `ps_data_abilities.ts` missing from that same preparation tree |
| 4 | `transform dependency changed: world/sourceMaps.lua` during region registration |
| 4 | npc-trade reference manifest missing |
| 3 | field-move pin missing |
| 2 | hidden-item asm looked up under `~/Developer/Pokemon-PlayDate-env/pokered` instead of `POKERED_REFERENCE_DIR` |
| 1 | `test_endgame_story` runs `git -C ~/Developer/Pokemon-PlayDate-env/pokered` |
| 1 | `test_lane_e_battle_review` reads that tree's `data/moves/moves.asm` |
| 1 | `test_lane_a_boulder_push_grid` reads that tree's Seafoam objects |
| 1 | `test_lane_e_pewter_gym_guide` reads `/tmp/pokered`, not the checkout above |
| 1 | B2W2 move cache missing (`tools/verify_moves/cache/.../move_changelog.csv`) |
| 3 | `/private/tmp` C reference directories for IV/EV and reward setters are absent |
| 1 | SDK `VERSION.txt` missing |

## Skipped

Four parcel-journey tests skip until `PARCEL_BUNDLE_SOURCE` is an identified staged build. Five restart tests skip because the Linux resident guard wants a real `/proc` pid. Two door-census tests skip because they want Darwin `libproc`.

## Champion continue and the thirteen warps

`tools/tests/test_lane_e_postgame_continue.py` passed inside this suite. Detail is in that module. No new `lane-e-*.patch`. The thirteen historical debug-warp names now resolve a sprite strip, and `DebugState` zone switch does not call `FieldWorld.enter`, so the Rock Tunnel outside-entry assert is not on that path. That assert stays. It is the source rule for an outside step into a dark map other than `ROCK_TUNNEL_1F`.

## Triage of the 13 failures

None of these is a new product patch. The 51 errors stay environment pins and are not in this table.

| Failure | Class | Why |
| --- | --- | --- |
| `test_capture_followup` field draws at the origin | Harness stub | `scene:draw` now calls `syncMessage`, which reads `battle.machine`. The probe's battle is `{}`. Production scenes have a machine. |
| `test_cerulean_observations` projection bytes | Projection pin | Generated projection does not match the committed snapshot. |
| `test_door_census` authored portals | Stale census pin | Expects 11 `authored_door` rows. Pallet's houses are source warps now (`REDS_HOUSE_1F`, `BLUES_HOUSE`, `OAKS_LAB`). The doors are still in the map. |
| `test_door_census` unsupported authored syntax | Stale census pin | A mutated `maps.lua` no longer takes the old `unsupported authored` path. |
| `test_lane_g_front_end` copyright tiles | Env path | The parser looks at `POKERED` or `/tmp/pokered`, not `POKERED_REFERENCE_DIR`. The checkout used here is `/tmp/pokemon-host/pokered`, so `title.asm` was not opened. |
| `test_region_registrations` owner-import cases | Harness string | The raiser now says `transform dependency changed: world/sourceMaps.lua`. The test still matches `owner imports changed`. |
| `test_source_map_pipeline` `maps.lua` unchanged | Byte freeze | `PROTECTED_DRIFT` pins an older `Source/data/maps.lua`. |
| `test_substitute_art` tilefactory freeze | Byte freeze | `tilefactory.lua` is pinned to an older blob. |
| `test_substitute_art` mechanics producer | Byte freeze | `battlePresentationContracts.lua` differs where the landed shift question replaced the old announcement text. |
| `test_vermilion_acquisition` machine projection | Projection pin | Generated collection does not match the pin. |
| `test_vermilion_journey` three counter teams | Projection pin | Same collection mismatch. |
| `test_vermilion_preparation` old manifest | Byte freeze | Stored sha256 does not match the current preparation bytes. |

## Lane I handoffs

`origin/cursor/lane-i-device-perf` is now `51e1efc45735ec9f3f08b0533f1f1c3931fc8759`. The preverify is in `docs/validation/lane-k-patch-preverify.md`.

| Patch | Against `6e4bc90f` |
| --- | --- |
| `lane-e-message-queue.patch` | clean |
| `lane-e-possessive.patch` | clean |
| `lane-e-shift-hold.patch` | clean |
| `lane-e-battle-message.patch` | already-landed (`dialog.lua:13`) |
| `lane-e-shift-prompt.patch` | already-landed (`battle.lua:250`, `battleScene.lua:653`) |

`lane-e-text-advance.patch` remains the nurse-audio guard already at `kantoAudio.lua:176`.
