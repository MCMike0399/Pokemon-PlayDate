# Lane K host suite on 4ce45f5a

Main and E tip: `4ce45f5a745fbf274b794ef8738b4627a325f128` (`Nest the coverage snapshot after the journey projections`). Parent `200fe950` regenerated `Source/dev/ceruleanJourney.json` and `Source/dev/vermilionJourney.json`. Lane K merge `7b080ea2e0d46a9256c7a0612b55b6bd968df915` contains the tip. `Source/` in the merge is E’s.

RedBot’s triage is `docs/validation/lane-e-host-failures-e0e9a209.md`. It marks the three projection names for regeneration and leaves the pin and freeze names.

Reference: pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`. There is no `/tmp/pokered`, and `POKERED` is unset. `MallocPoolSize` was not changed.

```sh
POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered \
KANTO_REFERENCE=/tmp/pokemon-host/pokered \
python3 -m unittest discover -s tools/tests
```

Log: `/tmp/lane-k-suite-4ce45f5a.log`. Exit code 1. Runtime 113.929s.

## Counts on this host

| Result | e0e9a209 | 4ce45f5a |
| --- | ---: | ---: |
| Ran | 1417 | 1420 |
| Passed | 1348 | 1351 |
| Failed | 10 | 10 |
| Errors | 48 | 48 |
| Skipped | 11 | 11 |
| Expected failures | 0 | 0 |

The three extra tests are the battle-UI checks filed on this branch after the `e0e9a209` discover. They are red on purpose. No error name changed.

## Journey projections

`200fe950` cleared all three projection failures from the `e0e9a209` list:

- `test_cerulean_observations` `test_deterministic_projection_matches_consumed_source_bytes`
- `test_vermilion_acquisition` `test_common_blue_tables_and_actual_machine_compatibility_are_projected`
- `test_vermilion_journey` `test_generation_is_exact_and_pins_every_map_and_three_counter_teams`

`test_preexisting_input_art_and_old_manifest_entries_are_unchanged` is still red. The triage leaves that Vermilion preparation freeze.

## Failures

Seven names are the same as the `e0e9a209` host list after the projections:

- `test_lane_g_front_end` `test_title_mons_do_not_cover_the_copyright` (this host only: it reads `POKERED` or `/tmp/pokered`)
- `test_region_registrations` `test_staged_owner_and_import_drift_are_rejected_with_unchanged_checkout`
- `test_region_registrations` `test_staging_race_rejects_copied_owner_and_import_drift`
- `test_source_map_pipeline` `test_original_map_inputs_authored_pallet_and_renderers_are_unchanged`
- `test_substitute_art` `test_every_existing_image_and_grid_matches_the_living_art_freeze`
- `test_substitute_art` `test_mechanics_producer_schema_rng_and_existing_case_names_are_unchanged`
- `test_vermilion_preparation` `test_preexisting_input_art_and_old_manifest_entries_are_unchanged`

Three more are the lane K battle-UI handoffs, still red for E:

- `test_lane_k_learn_name` `test_opened_box_names_the_move`
- `test_lane_k_message_queue` `test_confirm_does_not_install_the_next_say`
- `test_lane_k_shift_slots` `test_fainted_lead_still_asks_before_the_next_foe`

No other failure name is new. The 48 errors match the `e0e9a209` environment set.
