# Reproducing the protected battle artwork

All **302 checked-in battle PNGs reproduce exactly** from immutable pret/pokered commit `af519899719f0754965776faac0e836a3b906e6d`, using native front/back images and one deterministic threshold: 0/85 become black, 170/255 become white. There is no resizing, cropping, padding, dithering or transparency conversion. The generated opaque 1-bit candidates have zero decoded pixel or opacity differences; with the current pinned Pillow 12.0.0 environment, all 302 PNG files are byte-identical too.

This proves an exact reproducible source/transformation for the accepted appearance. It does **not** establish which historical upstream revision/download or importer originally produced these files. Repository commit `f22b5022bd7be69e840140e63eb1c91109dd5ba6` introduced all 302; every current file's Git blob still matches that import. The historical upstream revision/script remains unknown. No Source image was rewritten to establish the new reference pin.

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

No Simulator was launched, no Data/mailbox accessed, and no Source/RED/NPC/map/save/RNG files changed. The isolated image pipeline is proven; native battle-field composition and fractional display scaling remain the existing renderer's behavior. Root retains actual capture inspection and acceptance before any future migration. Exact reproduction does not authorize a bulk asset replacement or claim original-import history has been recovered.
