# Reproducible protected NPC grids

`tools/generate_overworld_sprites.py` now reads four local, checksum-verified reference strips pinned in `tools/references/overworld-sprites.json`. The immutable upstream commit is `af519899719f0754965776faac0e836a3b906e6d` of [pret/pokered](https://github.com/pret/pokered/tree/af519899719f0754965776faac0e836a3b906e6d). The four checked-in strips total 1,106 bytes, so normal generation and checking work offline. They are development references, not runtime assets.

This is a newly established reproducibility pin, verified against existing protected grid bodies. It does not recover the unknown historical commit used by the original mutable-`master` importer. Battle PNG provenance remains separate and unknown. No protected Lua grid file or RED art was rewritten for this work.

The original [sprite declarations](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/gfx/sprites.asm) identify the BLUE/Oak/Mom/Daisy strips. The [facing and animation table](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/data/sprites/facings.asm) separates down/up/left standing poses and obtains right facings through horizontal mirroring. The importer selects standing strip frames 0/1/2, respectively. That layout is an explicit validated input contract; no fallback substitutes down when a directional frame is absent. Remaining walking frames in the reference strips are not imported into current stationary NPCs.

| Input | Dimensions | Source SHA-256 | Default transformation |
| --- | --- | --- | --- |
| `blue.png` → rival | 16×96 | `2134b4c3540a600f9e121b271d61e80da5b05b2ec6ff94b103a5c839bf523999` | greyhair |
| `oak.png` → oak | 16×96 | `096e35c3b6d7b0677f3b3841f5091ed2d6da72b28b8c444b31cb1c77c49b2e72` | outline |
| `mom.png` → mom | 16×48 | `f8e5ae7b19d1a68a2fd9b9c78cbf263e4950d2fc98a5f519e3f8a0da9c91a82f` | greyhair |
| `daisy.png` → daisy | 16×96 | `6e3ddee307d5b187b789b247c19527adc9e8ad9368691816d218dc0156c5110e` | greyhair |

Every input must be an exact-byte PNG match, grayscale `L`, with the pinned dimensions and exactly four opaque shades 255/170/85/0. Validation happens for every selected input before writing any output. A reordered strip, altered pixel, incorrect palette, missing file, missing frame or checksum mismatch fails; generation never silently fetches a replacement from `master`.

`greyhair` maps 255/170→white `.`, 85→DARK `2`, 0→black `#`. `outline` maps 255/170/85→white `.`, 0→black `#`. These preserve BLUE/Mom/Daisy hair texture and Oak's white hair/face detail. The old global `bw` default would overwrite their accepted mapping; the new default chooses the existing policy separately for each character. Explicit `--map` overrides remain available for intentional experiments and do not rewrite the defaults in the manifest.

Runtime rendering stays in `TileFactory`/`SpriteFactory`: logical 16×16 cells become native 32×32 images with fine screen-resolution dither. Mask generation uses a four-connected flood-fill from border white cells. Exterior connected white becomes transparent; enclosed white remains opaque body. The generator's check independently derives those opacity bytes from both expected and target grids, reporting changed native mask pixel counts along with logical grid bounds. The SDK-exported standalone mask artifacts remain the final runtime pixel oracle. This check does not establish that an altered Lua renderer still follows the mask contract; the protected renderer source pins and actual catalog comparison cover that separately.

## Commands

Install the pinned Pillow dependency from `tools/requirements-dev.txt` in a venv, then:

```sh
# Read-only check of existing grid bodies; comments/headers may differ.
.venv/bin/python tools/generate_overworld_sprites.py --check

# Generate into a separate review directory, then check the results.
.venv/bin/python tools/generate_overworld_sprites.py --write --output-dir /tmp/pokemon-npc-generated
.venv/bin/python tools/generate_overworld_sprites.py --check --output-dir /tmp/pokemon-npc-generated --report /tmp/pokemon-npc-check.json

# Inspect only Oak; preview is the default and never writes Lua files.
.venv/bin/python tools/generate_overworld_sprites.py --only oak

# Explicitly restore the same pinned inputs, e.g. to an empty cache.
.venv/bin/python tools/generate_overworld_sprites.py --fetch --input-dir /tmp/pokemon-npc-inputs --only oak

# Failure-path and reproduction tests.
.venv/bin/python -m unittest discover -s tools/tests -p 'test_sprite_generator*.py' -v
```

`--check` returns nonzero on changed grid cells, changed derived masks, malformed target rows/declarations, unknown/empty/duplicate keys, RED selection, bad input or invalid frame policy. `--check --fetch` is rejected so check mode stays read-only. JSON reports contain the immutable commit, actual selected mapping, per-facing mask SHA-256 and exact differences. The small parser accepts only the established declarative Lua grid format; it does not interpret or transpile Lua.

`--write` retains its original explicit meaning and defaults to the production directory, so always provide `--output-dir` for experiments. A deliberate reviewed migration would be a separate task. No task command here used `--write` against `Source`. Generated headers now record the immutable commit/manifest; check mode compares the actual data rather than failing merely because historical comments differ.

## Results and remaining acceptance

All 12 standing frame grids (48 rows per character, four characters) match the current checked-in grid bodies exactly using the protected default policies. Temporary-directory generation and subsequent check pass. Ten tests pass, including a single grid-cell/4-native-mask-pixel mutation, a body-mask leak, swapped source frames, unknown keys, palette override discrepancy, malformed rows, invalid dimensions/colors/frame bounds and validation-before-write behavior.

Astra still needs to compare the generated result's actual SDK runtime pixels and masks with the reviewed visual catalog before accepting any future art migration. Grid equality is strong preservation evidence, not permission to replace existing art or claim historical upstream provenance has been recovered.
