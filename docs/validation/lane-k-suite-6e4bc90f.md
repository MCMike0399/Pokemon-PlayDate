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

## Lane I handoffs

`origin/cursor/lane-i-device-perf` is `988d5ad5ded91332f4dbc32273f88324b6b79f6b`. Checked with `git apply --check` against this tip.

| BlueBot item | On I | Against `6e4bc90f` |
| --- | --- | --- |
| Message-queue advance-before-finish | `tools/notes/lane-e-battle-message.patch` | Already landed. Apply fails at `Source/ui/dialog.lua:13`. `Dialog:handleInput` already finishes the line and waits 10 frames before `advance`. |
| Possessive-space | Not in `tools/notes` or `tools/tests` on lane I, and not on main, B, H, G, or F | Waiting on I. |
| Shift prompt | `tools/notes/lane-e-shift-prompt.patch` | Already landed. Apply fails at `Source/battle/battle.lua:250` and `Source/battle/battleScene.lua:653`. |

`tools/notes/lane-e-text-advance.patch` on I is the nurse-audio guard: `textAdvance` must not index `EventState:dialog` as a Dialog. The tip already has that check at `Source/game/kantoAudio.lua:176`. Apply fails there. It is not a distinct handoff.
