# Lane K host suite on 56414b63

Scored tip: `56414b632d906074c7f7d78d7bb21b44061fa3c8` (`Record the 6e4bc90f host suite and the Champion continue check`). It contains `51764017`. `Source/` is identical to `51764017`. `origin/main` is still `6e4bc90fe6c9c72a23f8249ff453babc777193aa`.

The discover ran on lane K merge `2c816f816e16366a74f793a11ce06977108b2fe7`, which already contained `51764017` and the same `Source/` and `tools/tests/test_lane_e_postgame_continue.py` as `56414b63`. The following merge `23118c0a05486c4774471e465a94ace665abd9b1` adds `56414b63` and does not change `Source/`.

Reference: pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`.

```sh
POKERED_REFERENCE_DIR=/tmp/pokemon-host/pokered \
KANTO_REFERENCE=/tmp/pokemon-host/pokered \
python3 -m unittest discover -s tools/tests
```

No Playdate SDK, no `PARCEL_BUNDLE_SOURCE`, and no `~/Developer/Pokemon-PlayDate-env`. `MallocPoolSize` was not changed. Log: `/tmp/lane-k-suite-51764017.log` (name is the tree the process started on). Exit code 1. Runtime 111.863s.

## Counts

| Result | 6e4bc90f | 56414b63 |
| --- | ---: | ---: |
| Ran | 1382 | 1333 |
| Passed | 1302 | 1243 |
| Failed | 13 | 12 |
| Errors | 51 | 67 |
| Skipped | 11 | 11 |
| Expected failures | 5 | 0 |
| Unexpected successes | 0 | 0 |

Passed is `ran - failed - errors - skipped`. The drop of 49 ran tests is classes whose `setUpClass` now stops on the flower pin, so the methods inside them are not counted.

## Prior expected failures

These live assertions pass. None of the modules appear in the failure or error list, and none still carry `@unittest.expectedFailure`:

- gym terrain tones
- flower tile `$03`
- battle-text iris stencil
- Viridian sight
- trainer-card and Pay Day yen
- battle message queue
- possessive ligatures
- shift hold

The first five were the expected failures on `6e4bc90f`. The last three were expected failures on lane K until E landed them in `a1740550`.

## Failures (12)

All twelve are names from the `6e4bc90f` thirteen. The missing name is `test_vermilion_preparation`, which is now an error (below) instead of an assertion failure.

| Test | Report |
| --- | --- |
| `test_capture_followup...test_owned_flag_is_read_before_recruit_and_the_field_draws_at_the_origin` | `battleScene.lua:1237` indexes a nil `machine` |
| `test_cerulean_observations...test_deterministic_projection_matches_consumed_source_bytes` | projection bytes differ from the pin |
| `test_door_census...test_authored_portals_separate_and_all_case_ids_unique` | census has connections and no authored doors |
| `test_door_census...test_pin_corruption_and_unsupported_authored_syntax_fail` | `ValueError` was not raised |
| `test_lane_g_front_end...test_title_mons_do_not_cover_the_copyright` | looks for `/tmp/pokered`, not `POKERED_REFERENCE_DIR` |
| `test_region_registrations` staged-owner drift | `transform dependency changed: world/sourceMaps.lua` |
| `test_region_registrations` `main.lua` relative case | same `sourceMaps.lua` dependency message |
| `test_source_map_pipeline...test_original_map_inputs_authored_pallet_and_renderers_are_unchanged` | authored Pallet startup body changed |
| `test_substitute_art...test_every_existing_image_and_grid_matches_the_living_art_freeze` | `tilefactory.lua` bytes differ from the freeze |
| `test_substitute_art...test_mechanics_producer_schema_rng_and_existing_case_names_are_unchanged` | `battlePresentationContracts.lua` bytes differ |
| `test_vermilion_acquisition...test_common_blue_tables_and_actual_machine_compatibility_are_projected` | machine projection differs |
| `test_vermilion_journey...test_generation_is_exact_and_pins_every_map_and_three_counter_teams` | generated journey pin differs |

## New head-only errors (16)

These names were not in the `6e4bc90f` failure list or its 51 errors. Every one raises `MapError: unpinned consumed source: gfx/tilesets/flower/flower1.png`. The flower substitution that consumes `flower1.png` lands in `a1740550` and is still in `51764017` and `56414b63`.

- `test_cerulean_content.CeruleanContentTests` (`setUpClass`)
- `test_cerulean_routes` approach endpoints
- `test_cerulean_routes` declared cells
- `test_cerulean_routes` original triggers
- `test_cerulean_routes` byte-exact projection
- `test_cerulean_routes` six rival rosters
- `test_map_generator` byte-identical artifacts
- `test_map_generator` route and mart dimensions
- `test_native_cerulean_text` literal UTF-8
- `test_source_map_activation.SourceMapActivationInputs` (`setUpClass`)
- `test_source_map_pipeline` extra-maps SDK fixture
- `test_vermilion_ambient.VermilionAmbientTests` (`setUpClass`)
- `test_vermilion_installed_inventory.VermilionInstalledInventory` (`setUpClass`)
- `test_vermilion_preparation.VermilionPreparationTests` (`setUpClass`) — this name was a baseline failure; the cause is now the flower pin
- `test_vermilion_ship.VermilionShipSources` (`setUpClass`)
- `test_viridian_generator.SliceTests` (`setUpClass`)

## Errors that match the baseline environment

The other 51 errors are the same classes as the `6e4bc90f` run: missing Playdate SDK, missing `Pokemon-PlayDate-env`, `/private/tmp` C pins, the B2W2 move cache, `/tmp/pokered` for the Pewter gym guide, the authored Pallet startup hash, and the `world/sourceMaps.lua` transform dependency. They are not new product reds.

## FF call

No. `main` `6e4bc90f` cannot fast-forward to `56414b63` under no-new-reds. The sixteen flower-pin errors are head-only. The same `Source/` is on `51764017` and on `a1740550`, so those ancestors are out too. The newest ancestor before the flower pin is `e218b491` (Oak at the padded lab cell, five lines in `Source/data/maps.lua`). This discover did not re-score that ancestor.
