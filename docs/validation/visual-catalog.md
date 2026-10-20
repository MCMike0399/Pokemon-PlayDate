# Protected visual catalog

`Source/dev/catalog.lua` exports `VisualCatalog.write(absoluteOutputDir)`. Import it after the production factories, player and maps. The Simulator harness owns its invocation, process, output directory and build; do not run a second Simulator/client against that session.

The host must create a fresh absolute output directory before calling it, publish the returned manifest as `catalog.json`, and verify that every `images[].path` exists, decodes, and has the declared dimensions. `playdate.simulator.writeToFile` only writes PNGs and requires an existing host directory; the renderer cannot publish arbitrary host JSON. A Lua return alone does not establish successful PNG publication. Propagate any missing file as a failed catalog command.

Host-published run manifests may set `image_root: "frames"` for run-root `catalog.json` with images under `frames/`. Omitted `image_root` defaults to `.` for existing flat catalogs. Both review and comparison reject absolute paths, traversal and symlink escapes. The manifest has schema version 1, `images` (relative flat filename, category, dimensions, mask flag), `missing` (reason and canonical lookup), `maps`, explicit animation phase and limitations. It includes:

- Every generated tile ID, including roof/ground composites; all eight heartbeat positions for water/shore and four for flowers, including repeated positions.
- RED stand/walk1/walk2 in four directions; all four NPCs in four directions. Every character includes the original transparent image, explicit standalone opacity mask and composites on white, black and checker backgrounds.
- Tall-grass/rustle tiles and the same cropped bottom-half overlays used by the player; four actual production exit-arrow images via `Player.getExitArrowImages`.
- Both canonical battle image lookups for all 151 species, with missing lookups explicit. Existing checked-in battle PNGs remain unchanged. Opaque images receive an explicit white mask artifact.
- Every registered full map at the current zone-definition state, a 400×240 viewport centered/clamped on spawn, a standalone collision bitmap, and declared event overlays. Overlay `D` means step door, `E` edge exit, `N` NPC definition, `S` spawn. Positions are zero-based movement cells, 32 output pixels per cell. All NPC definitions are shown, including conditional NPCs; their predicates are never evaluated.

Catalog rendering pushes/pops graphics context, explicitly zeros the draw offset, clears context clip/stencil, sets copy mode and deterministic text settings. It never advances animations/RNG/timers, mutates maps, switches zones, spawns sprites or invokes story predicates. It creates its own tile imagetable and reads shared character images without modifying their pixels or masks. Display offset is untouched. Context cleanup also occurs after errors. A fresh fixture is required before comparison because story changes to map definitions (such as removing starter balls) intentionally affect map images.

## Local checks

Create a development venv and install the pinned development dependency:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/requirements-dev.txt
.venv/bin/python -m unittest discover -s tools/tests -p 'test_visual*.py' -v
python3 tools/visual/coverage.py --report /tmp/asset-coverage.json
python3 tools/visual/coverage.py --pins tools/visual/protected-source-pins.json
```

The initial runtime catalog reproduced six missing lookups: canonical IDs `nidoranF`, `nidoranM`, `mr` did not match filenames `nidoran-f`, `nidoran-m`, `mr-mime`. `Source/data/pokemon-art.json` now records those three explicit aliases; `PokemonArt.path()` serves both battle rendering and the catalog, and the host validator reads the same manifest. Coverage passes for all 302 images. A regression test deliberately removes the aliases and reproduces all six original failures. No PNG bytes or gameplay species IDs changed. Runtime visual review of the repaired views is recorded separately from this host coverage check.

`protected-source-pins.json` records SHA-256 of the original revision `1cb82252e4d591e9819fdd23caa234e02128263c` from the archived untouched `Source`. It covers all battle PNGs, grids, renderer/palette and relevant map/player sources. Hash mismatches on legitimate logic edits remain visible and require code/visual review; do not regenerate the file to silence them. These are repository preservation pins, not upstream source pins or approval of all images. The original NPC converter fetched mutable pokered `master`; that historical commit/checksum is unknown. RED is intentionally hand-tuned. Battle PNG upstream provenance and full regeneration pipeline are unknown. Future importers must pin their own actual upstream sources.

## Comparing and inspecting artifacts

After the owning harness publishes two completed catalogs:

```sh
.venv/bin/python tools/visual/compare.py artifacts/reviewed-baseline artifacts/candidate --diff-dir artifacts/diffs --report artifacts/comparison.json
.venv/bin/python tools/visual/review.py artifacts/candidate artifacts/review --scale 3
```

The comparator also accepts two PNGs. It compares decoded RGB pixels and alpha separately, without tolerance, cropping or scaling. It returns nonzero for changed pixels, alpha, dimensions, deleted/added inventory, changed missing-art inventory, absent files or invalid/empty image inventories. Reports include exact pixel counts and bounding boxes (exclusive right/bottom), plus magenta changed-region overlays when requested. Standalone mask artifacts additionally protect opacity even when PNG export flattens alpha. No comparison command writes or regenerates the expected baseline.

The tests inject a single black pixel at `(7,11)`, a single alpha-only defect at `(3,5)`, and a standalone mask pixel defect. They assert meaningful failure counts/regions, and the black-pixel case verifies CLI exit status 1. Identical images pass. Dimension and deleted-inventory failures are also tested.

Review pages preserve each asset's native pixels in 400×240 pages and produce nearest-neighbor enlargements. Full maps/overlays and viewports receive enlargements directly. Derived pages are inspection aids, not golden baseline files. Astra must inspect actual native images, enlargements and gameplay motion before declaring a reviewed baseline. Research screenshots alone are insufficient approval.

## Validation boundaries

This static catalog supplements native input-driven journeys. Walking cadence/grass occlusion, scrolling, doors, battle transitions/attacks and display offset need frame sequences produced by the owning harness. Map event overlays do not enumerate imperative story trigger regions; the source currently has no declarative event-region inventory. Full-map renders omit live NPCs/player and use initial factory animation phase. Battle images are isolated source art, not fractional-scale battle-field composition; native battle journey captures cover that composition.

Preservation against a reviewed Playdate catalog and fidelity against pinned original reference transformations are separate checks. This milestone implements preservation tooling and transparently records missing source provenance. It does not claim a new original-reference fidelity oracle or physical-device validation.
