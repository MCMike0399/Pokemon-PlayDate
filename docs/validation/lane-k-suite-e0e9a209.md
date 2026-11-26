# Lane K host suite on e0e9a209

Main and E tip: `e0e9a2095273cc14cec1449bd6244cfd76ce21ad` (`Match the pinned league story encoding and run the C oracles on this host`). Parent `63c4b961`. Lane K merge `51842c73ee11c464ab27e22dd57721972e6cdab5` contains the tip. `Source/` in the merge is E’s.

`e0e9a209` keeps the Victory Road name as UTF-8 `POKéMANIAC` in `tools/generate_endgame_story.py`, and the EV, stat, and reward C oracles use the system temp directory.

Reference: pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`. There is no `/tmp/pokered`, and `POKERED` is unset. `MallocPoolSize` was not changed.

```sh
POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered \
KANTO_REFERENCE=/tmp/pokemon-host/pokered \
python3 -m unittest discover -s tools/tests
```

Log: `/tmp/lane-k-suite-e0e9a209.log`. Exit code 1. Runtime 114.709s. This discover is the tip’s suite. The three battle-UI tests filed after it are not in these counts.

## Counts on this host

| Result | 2e7863ff | e0e9a209 |
| --- | ---: | ---: |
| Ran | 1416 | 1417 |
| Passed | 1337 | 1348 |
| Failed | 13 | 10 |
| Errors | 55 | 48 |
| Skipped | 11 | 11 |
| Expected failures | 0 | 0 |

RedBot’s host on this tip: 1417 ran, 9 fail / 34 err / 11 skip. The same 1417 tests ran here. Daycare is absent from the failure and error lists.

## Failures

The three fixture failures from `2e7863ff` are gone: capture origin (`test_owned_flag_is_read_before_recruit_and_the_field_draws_at_the_origin`), and both Pallet door-census inventory tests. No failure name is new.

The 10 remaining failures:

- `test_cerulean_observations` `test_deterministic_projection_matches_consumed_source_bytes`
- `test_lane_g_front_end` `test_title_mons_do_not_cover_the_copyright`
- `test_region_registrations` `test_staged_owner_and_import_drift_are_rejected_with_unchanged_checkout`
- `test_region_registrations` `test_staging_race_rejects_copied_owner_and_import_drift`
- `test_source_map_pipeline` `test_original_map_inputs_authored_pallet_and_renderers_are_unchanged`
- `test_substitute_art` `test_every_existing_image_and_grid_matches_the_living_art_freeze`
- `test_substitute_art` `test_mechanics_producer_schema_rng_and_existing_case_names_are_unchanged`
- `test_vermilion_acquisition` `test_common_blue_tables_and_actual_machine_compatibility_are_projected`
- `test_vermilion_journey` `test_generation_is_exact_and_pins_every_map_and_three_counter_teams`
- `test_vermilion_preparation` `test_preexisting_input_art_and_old_manifest_entries_are_unchanged`

Nine of those are the pin, freeze, and projection names RedBot still has. The tenth is the title-copyright test. It looks at `POKERED` or `/tmp/pokered` (`tools/tests/test_lane_g_front_end.py`), so it fails on this host and passes on a host that has that checkout. That is the 10-versus-9 gap.

## Errors

No error name is new versus `2e7863ff`. Seven error names from that run are gone:

- `test_lane_e_evolution_cancel_hint` `test_pokered_cancels_on_b_with_no_hint`
- `test_lane_e_exp_points_text` `test_pokered_page_is_two_lines_and_the_award_stays`
- `test_lane_e_healing_machine_balls` `test_pokered_places_one_white_ball_per_party_mon`
- `test_lane_e_trainer_victory_text` `test_gym_leaders_and_a_regular_trainer_match_pokered`
- `test_individual_data` `test_unchanged_primary_c_setters_against_seven_literal_vectors`
- `test_individual_data` `test_unchanged_primary_c_stats_against_ten_literal_vectors`
- `test_rewards_reference` `test_unchanged_native_add_evs_and_six_setters_match_seven_literals`

The first four now read `POKERED_REFERENCE_DIR` (landed in `63c4b961`). The last three are the C oracles `e0e9a209` points at the system temp directory. On the `63c4b961` tree this host had 51 errors; those three tempdir errors are the whole drop to 48.

The remaining 48 errors are the environment set from the `2e7863ff` note (missing SDK, `~/Developer/Pokemon-PlayDate-env` references, and `/tmp/pokered` for the Pewter gym guide). RedBot’s 34 is that set without those 14 host-only errors. `55 - 7 = 48` and `37 - 3 = 34` are the same three oracle fixes on each machine.
