# Reproducing the protected battle artwork

All **302 checked-in battle PNGs reproduce exactly** from immutable pret/pokered commit `af519899719f0754965776faac0e836a3b906e6d` through `threshold()` in `tools/generate_battle_art.py`: native size, opaque, no crop, scale, padding, or dither. Shade 0 and 85 become black. Shade 170 and 255 become white. `tools/references/battle-art.json` records that palette and `unchanged_since_import` 302. `--check` against archive `e571972fc926dcb65d94fc989299d38109590aa945ed657bf215eac8561afd05` reports 302/302 exact.

Miguel's approved battle frame is the 400×240 PlaydateSimulator 3.1.2 LCD capture at `/home/ubuntu/.cursor/projects/agent-repos-Pokemon-PlayDate/assets/approved-battle-reference.png`, SHA-256 `d02e55fa472c37c3dc687cf3c65387b1c80e4d6a99e348d60fd82ec37828315a`. It is Squirtle Lv5 19/19 against a wild Pidgey Lv3, with the ground platforms. It is pixel-identical to the style-option captures `2a-battle-undithered.png` and `3a-battle-with-platforms.png` (0 changed pixels). Those captures were the checked-in threshold PNGs, drawn by `BattleScene` into the 80px slots at enemy `(300, 20)` and player `(55, 70)`, then scaled with `min(80/iw, 80/ih)` and nearest `floor`. It differs from `2b-battle-dithered-shared-gray.png` by 1625 pixels. Commit `b3ce7a01` sampled gray 85 through `Shade.LIGHT` and gray 170 through `Shade.DARK` at phase `(0, 0)` inside the PNGs. Scaled the same way, those sprites miss 777 blacks in the two slots and add 772 blacks that the approved frame does not have. The threshold PNGs from `946c4b00`, which this pipeline writes again, miss 0 and add 0 inside those slots once the platform rectangles are left out. The approved frame matches the threshold art. It does not match `b3ce7a01`.

Shade Bayer (LIGHT 31.25% black, DARK 68.75% black, phase `(0, 0)`) stays the mapping for Shade callers, including Pallet and interiors. The ground platforms stay. Option 2b is not the battle-sprite baseline once this frame is the reference. Repository commit `f22b5022bd7be69e840140e63eb1c91109dd5ba6` introduced the undithered 302; the historical upstream revision of that first import remains unknown.

## Original references and version policy

The pinned [Pokémon picture declarations](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/gfx/pics.asm) name front images under `gfx/pokemon/front` and corresponding back images under `gfx/pokemon/back` (back filenames carry a final `b`). The pinned [Makefile](https://github.com/pret/pokered/blob/af519899719f0754965776faac0e836a3b906e6d/Makefile) builds English Red/Blue variants from that shared picture module. The roster picture declarations are unconditional: there is no separate English Red versus Blue front source selection in this module. Blue remains the project's working default.

The repository also contains an alternate `gfx/pokemon/front_rg` directory. It was measured separately; none of its 151 roster fronts matches a current protected front under any searched transformation. The directory name alone is not treated as proof of historical region/version provenance. It is not substituted for the pictures actually referenced by the English build.

`tools/references/battle-art.json` pins all **455 inputs**: 151 fronts, 151 backs, 151 alternate fronts, `gfx/pics.asm` and `Makefile`, with immutable URLs and SHA-256 checksums. It also pins each existing PNG's byte checksum, decoded RGBA checksum, dimensions, canonical species/view, original-reference checksum, direct reproduction differences and alternate-front mismatch count/bounding box or dimension discrepancy.

The production `Source/data/pokemon-art.json` remains the shared runtime alias authority. The generator reuses and checks its pinned checksum, including `nidoranF→nidoran-f`, `nidoranM→nidoran-m` and `mr→mr-mime`. Separate original-reference stem aliases are explicit: `nidoranf`, `nidoranm`, `mr.mime`. No runtime ID or production alias was changed by this work.

| Asset group | Count | Native dimensions | Current format |
| --- | --- | --- | --- |
| Front | 48 | 40×40 | Opaque PNG mode 1 |
| Front | 48 | 48×48 | Opaque PNG mode 1 |
| Front | 55 | 56×56 | Opaque PNG mode 1 |
| Back | 151 | 32×32 | Opaque PNG mode 1 |

Every referenced original image is grayscale `L` with exactly four shades 0/85/170/255. The reference directories contain two additional fossil fronts outside the supported 151-species roster; they are not silently counted as supported Pokémon.

## Systematic measurement

The search below was run against the historical threshold-128 import. It explains why that import matched one undithered mapping. It does not describe the current Bayer files.

The source search tested **134,088 exact comparisons across 888 profiles**:

- All 16 possible binary assignments of the four input shades, including inverse/degenerate assignments.
- Floyd–Steinberg plus 2×2/4×4 Bayer dithering with every output phase: 37 palette/dither profiles in total.
- Native image; tight black-content crop; tight crop recentered/bottom-aligned in the original canvas; 56×56 centered/bottom padding; nearest-neighbor 2×/3× scaling.
- The referenced fronts/backs and every alternate `front_rg` front.

Only the native `0011` palette mapping (shade order 0/85/170/255) matches every corresponding asset. Thresholds 86–170 produce that same mapping for this four-shade input; threshold 128 is the explicit regeneration rule, not a claim that its original importer used precisely that number. Some geometry profiles are no-ops for individual fronts: tight crop is identical for 16, recenter for 41, bottom alignment for 44, and padding for the 55 already-56×56 images. Those coincidences do not justify adding a geometry step to the proven direct pipeline. No scaled or dithered profile produced an exact match.

All 151 alternate fronts differ. Their measured regions/counts are retained per front in the manifest/report, rather than being described as approximately similar. For example Bulbasaur differs at 166 pixels with exclusive bounding box `[1,12,34,40]`; Venusaur differs at 1211 with `[0,0,56,56]`. Pixel and alpha comparisons are separate; the proven current battle images have fully opaque masks, including white body/background regions. The NPC border flood-fill mask policy is not applied to battle art.

## Reproduction commands

Install `tools/requirements-dev.txt` into a venv first. The generator accepts either an extracted pinned source tree or its checksum-verified archive; it does not fetch mutable URLs or require a machine-specific cache path.

```sh
# Download immutable input once, then use it offline.
curl -L https://codeload.github.com/pret/pokered/tar.gz/af519899719f0754965776faac0e836a3b906e6d -o /tmp/pokered-battle-source.tar.gz

# Read-only check: archive hash and every referenced file are validated.
.venv/bin/python tools/generate_battle_art.py --check --archive /tmp/pokered-battle-source.tar.gz --report /tmp/battle-art-check.json

# Reproduce the complete finite search and per-asset differences.
.venv/bin/python tools/generate_battle_art.py --check --search --archive /tmp/pokered-battle-source.tar.gz --report /tmp/battle-art-search.json

# Explicitly generate candidates into a NEW directory outside Source.
.venv/bin/python tools/generate_battle_art.py --archive /tmp/pokered-battle-source.tar.gz --output /tmp/battle-art-candidates --report /tmp/battle-art-candidates.json

# Alternatively supply an already-extracted immutable tree.
.venv/bin/python tools/generate_battle_art.py --check --reference-root /tmp/pokered-af519899719f0754965776faac0e836a3b906e6d

.venv/bin/python -m unittest discover -s tools/tests -p 'test_battle_art*.py' -v
```

Archive SHA-256 is `e571972fc926dcb65d94fc989299d38109590aa945ed657bf215eac8561afd05`. The tool validates it before reading exact tar members and never extracts arbitrary paths. Tree mode verifies the same individual file hashes, dimensions and palette. Missing/changed references or protected targets, unknown roster/view inventory, changed aliases, bad mode/colors/dimensions and output paths inside Source fail. Candidate directories must not already exist. `--check` forbids candidate publication. Reports are explicit requested outputs; report paths inside production/input Source are also rejected. There is no pin or baseline regeneration switch.

Seven self-contained host tests pass. They verify all current protected PNG hashes/aliases, palette/search geometry, wrong archive/input checksums, missing input, invalid palette/dimensions, source/report output guards, an actual trace with a one-pixel defect and a separate opacity-only defect. The pixel mutation fails with exactly one changed pixel and its actual rectangle while leaving the defective target untouched; tests do not rewrite protected images to make checks pass.

## Handoff and limits

Worker artifacts are `/private/tmp/pokemon-battle-art-check.json`, `pokemon-battle-art-tree-check.json`, `pokemon-battle-art-search.json`, `pokemon-battle-art-candidates.json` and the 302 candidates under `/private/tmp/pokemon-battle-art-candidates/`. Root should archive the accepted reports with its execution ledger after independent review. The manifest provides durable per-file reproduction/mismatch evidence even if temporary search outputs expire.

The 2026-11-09 `b3ce7a01` redraw sampled the shared Shade patterns into the 302 PNGs. The approved frame does not match that result, so production returned to `threshold()` and the 302 files were regenerated from the pinned archive. Native battle-field composition and the 80px presentation slot are unchanged. The ground platforms stay; the fidelity ledger records that as presentation choice 3a. Exact reproduction of `threshold()` does not recover the unknown history of the first import.
