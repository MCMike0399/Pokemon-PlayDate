# Host failure triage on e142281e

Lane K `751ca76e` contains main `e142281e`. The seven names are the host failures in `docs/validation/lane-k-suite-e142281e.md`. Reference checkout: pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`. `POKERED` is unset. No `MallocPoolSize` change. `Source/` is not edited. The patch below is unapplied; `git apply --check` succeeds, and with it applied the Vermilion test passes.

## Priority: Vermilion preparation

| Test | Class | What fails | Patch |
| --- | --- | --- | --- |
| `test_preexisting_input_art_and_old_manifest_entries_are_unchanged` | fixture | Cache section between `-- PUBLIC API` and `-- TILE DEFINITIONS` is `537c712d…`, not the `309194ee` review `1a688c48…`. | `tools/notes/lane-e-tilefactory-image-freeze.patch` |

The old manifest entries, sprite bytes, shade pin, and tile-definition tail all match. The cache-section diff against `309194ee` is only `TileFactory.image`, added by `db98ce05` (14 lines, and that commit’s `tilefactory.lua` blob is still HEAD). Stripping that function restores `1a688c48…`. `946c4b00` changed the Bayer header, which this test already rewrites back. This is not a pokered map or text mismatch; af519899 is the pinned reference and is not consulted by this assertion.

The patch deletes that exact function, requires it once, then keeps the `309194ee` hash. Any other cache-section edit still fails. The hash is not replaced with `537c712d…`.

## The other six

| Test | Class | Why | Patch |
| --- | --- | --- | --- |
| `test_title_mons_do_not_cover_the_copyright` | environment | `_copyright_tiles_from_asm` reads `POKERED` or `/tmp/pokered`. Neither exists here. `engine/movie/title.asm` is at `/tmp/pokemon-host/pokered`. RedBot’s host does not fail this name. | none |
| `test_staged_owner_and_import_drift_are_rejected_with_unchanged_checkout` | fixture | `tools/references/content-transforms-149/provenance.json` pins `world/sourceMaps.lua` at `5ccdccb3…`. The file is `e18ff147…`. `build` raises `transform dependency changed: world/sourceMaps.lua` before `owner imports changed`. | none |
| `test_staging_race_rejects_copied_owner_and_import_drift` | fixture | Same stale SDK provenance. The `main.lua` case expects `owner imports changed`. | none |
| `test_original_map_inputs_authored_pallet_and_renderers_are_unchanged` | fixture | `tools/source_preservation.py` requires the `maps.lua` startup wrapper hash `2d758127…`. That hash matches `c00b14ea` and `42f92863`. It diverges at `3d3ef552` (Pallet collision), then `6dcf09c3` and `837a61e6` (Oak at the padded lab cell). Current wrapper is `9f413741…`. There is no generator for that hash. | none |
| `test_every_existing_image_and_grid_matches_the_living_art_freeze` | fixture | Stops on `Source/world/tilefactory.lua` against `946c4b00`. The file delta is the same `db98ce05` function. Pointing `PROTECTED_DRIFT` at `db98ce05` does not clear the test: the next mismatch is `Source/data/maps.lua` against `42f92863`, the Pallet wrapper above. | none |
| `test_mechanics_producer_schema_rng_and_existing_case_names_are_unchanged` | fixture | `Source/dev/battlePresentationContracts.lua` matches `106686b5` and not the freeze `0721a2b2`. The diff splits the shift prompt to `Will RED\nchange POKéMON?` and samples the `é` glyph through `GbFont` instead of the system font. The freeze is a commit id. | none |

Region provenance stays on the SDK export `da33e3cd`. Pallet and the presentation contract stay on their commit ids. Refreshing those hashes here would bless more than one reviewed edit.

## Not this pass

Lane J is `1764e7d5` (Route 4 Center skip when the cave exit cannot reach it), merged through `e142281e`, and still short of the Cascade Badge. That tip moved during this pass, so there is no Misty assist. Lane I `07117b0a` and lane B `ecdcea7f` are not on main.
