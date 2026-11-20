# Host failure triage on e0e9a209

All nine names already failed on `63c4b961`. No budget, skip, or expected-failure change.

| Test | Verdict |
| --- | --- |
| `test_deterministic_projection_matches_consumed_source_bytes` | Regenerated `Source/dev/ceruleanJourney.json` with `tools/generate_cerulean_journey.py`. Only the `sources` hashes of landed files changed. |
| `test_common_blue_tables_and_actual_machine_compatibility_are_projected` | Regenerated `Source/dev/vermilionJourney.json` with `tools/generate_vermilion_journey.py`. Only input hashes changed, including the new Cerulean projection hash. |
| `test_generation_is_exact_and_pins_every_map_and_three_counter_teams` | Same Vermilion regeneration. Projected teams and collection were already equal. |
| `test_staged_owner_and_import_drift_are_rejected_with_unchanged_checkout` | Left. `world/sourceMaps.lua` moved in the memory cuts after the SDK export `da33e3cd`. Refreshing `content-transforms-149/provenance.json` needs that export, not a hand-edited hash. |
| `test_staging_race_rejects_copied_owner_and_import_drift` | Same stale SDK provenance. Left. |
| `test_original_map_inputs_authored_pallet_and_renderers_are_unchanged` | Left. Approved Pallet registration sits inside the frozen startup wrapper. `tools/source_preservation.py` has no generator for that hash. |
| `test_every_existing_image_and_grid_matches_the_living_art_freeze` | Left. The approved Bayer pin is still `946c4b00`. `db98ce05` added `TileFactory.image` after that pin. |
| `test_mechanics_producer_schema_rng_and_existing_case_names_are_unchanged` | Left. The diff is the approved shift question in `106686b5`, and the freeze is a commit id with no generator. |
| `test_preexisting_input_art_and_old_manifest_entries_are_unchanged` | Left. The cache-section hash is the reviewed `309194ee` section. Later Bayer and `TileFactory.image` edits are not a generator output. |
