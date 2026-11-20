# Lane K host suite on 9a33a835

New main and E tip: `9a33a835df5777f600d683b69afe2b212afac480` (`Nest the coverage snapshot after the gym atlas and Pallet tones`). Parent `1b466640` pins `flower1.png` and lands the approved gym atlas and Pallet tones. This replaces the `6e4bc90f` host baseline.

Lane K merge `7c209db1d4bd5b65e399cf7f0c1e5a3afc07b78f` contains that tip. The discover ran on that merge. `Source/` in the merge is E’s; this note does not change it.

Reference: pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`.

```sh
POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered \
KANTO_REFERENCE=/tmp/pokemon-host/pokered \
python3 -m unittest discover -s tools/tests
```

No Playdate SDK, no `PARCEL_BUNDLE_SOURCE`, and no `~/Developer/Pokemon-PlayDate-env`. `MallocPoolSize` was not changed. Log: `/tmp/lane-k-suite-9a33a835.log`. Exit code 1. Runtime 120.879s.

## Counts

| Result | 6e4bc90f | 56414b63 | 9a33a835 |
| --- | ---: | ---: | ---: |
| Ran | 1382 | 1333 | 1399 |
| Passed | 1302 | 1243 | 1324 |
| Failed | 13 | 12 | 13 |
| Errors | 51 | 67 | 51 |
| Skipped | 11 | 11 | 11 |
| Expected failures | 5 | 0 | 0 |
| Unexpected successes | 0 | 0 | 0 |

Passed is `ran - failed - errors - skipped`. The extra 17 ran tests versus `6e4bc90f` are the flower-pin and Pallet-tone cases added on this tip. They passed. The five expected failures from `6e4bc90f` stay passed.

## Flower pin

The 16 `unpinned consumed source: gfx/tilesets/flower/flower1.png` errors from `56414b63` are gone. The log has no `flower1.png` hit. Those classes run again:

- Cerulean content, routes, and native text
- map generator pin checks
- source-map activation and the extra-maps fixture
- Vermilion ambient, installed inventory, preparation `setUpClass`, and ship
- Viridian generator

`test_vermilion_preparation...test_preexisting_input_art_and_old_manifest_entries_are_unchanged` is a failure again, with the same sha256 as the `6e4bc90f` baseline (`537c712d…` != `1a688c48…`). On `56414b63` that class never reached the assertion because `setUpClass` died on the flower pin.

## Failures (13)

Same thirteen names as `docs/validation/lane-k-suite-6e4bc90f.md`. No new assertion failure.

| Test | Report |
| --- | --- |
| `test_capture_followup...test_owned_flag_is_read_before_recruit_and_the_field_draws_at_the_origin` | nil `machine` in the host draw probe |
| `test_cerulean_observations...test_deterministic_projection_matches_consumed_source_bytes` | projection bytes differ |
| `test_door_census...test_authored_portals_separate_and_all_case_ids_unique` | connections only; expected 11 authored doors |
| `test_door_census...test_pin_corruption_and_unsupported_authored_syntax_fail` | `ValueError` was not raised |
| `test_lane_g_front_end...test_title_mons_do_not_cover_the_copyright` | looks for `/tmp/pokered`, not `POKERED_REFERENCE_DIR` |
| `test_region_registrations` staged-owner drift | `transform dependency changed: world/sourceMaps.lua` |
| `test_region_registrations` `main.lua` relative case | same dependency message |
| `test_source_map_pipeline...test_original_map_inputs_authored_pallet_and_renderers_are_unchanged` | `Source/data/maps.lua` |
| `test_substitute_art...test_every_existing_image_and_grid_matches_the_living_art_freeze` | `Source/world/tilefactory.lua` |
| `test_substitute_art...test_mechanics_producer_schema_rng_and_existing_case_names_are_unchanged` | `Source/dev/battlePresentationContracts.lua` |
| `test_vermilion_acquisition...test_common_blue_tables_and_actual_machine_compatibility_are_projected` | machine projection differs |
| `test_vermilion_journey...test_generation_is_exact_and_pins_every_map_and_three_counter_teams` | same collection mismatch |
| `test_vermilion_preparation...test_preexisting_input_art_and_old_manifest_entries_are_unchanged` | sha256 `537c712d…` != `1a688c48…` |

## Errors (51)

Same environment pins as the `6e4bc90f` write-up: missing Playdate SDK, missing `Pokemon-PlayDate-env`, `/private/tmp` C references, the B2W2 move cache, `/tmp/pokered` for the Pewter gym guide, the authored Pallet startup hash, and the `world/sourceMaps.lua` transform dependency. No new error name versus that baseline.

## Head-only reds

None. The gym atlas and Pallet tones in `1b466640` did not add a failure or an error beyond the thirteen and the fifty-one already recorded on `6e4bc90f`.
