# Private Vermilion catalog handoff

Base: exact root `bdcb1a9` merged first on `wip/vermilion-catalog` (merge
`b40717f`). Includes ship `b2a497b`, 65 active maps and Cerulean's fixed
18-map scope. No runtime, native acceptance, milestone acceptance or push.

The reviewed declaration is **1702 new PNGs**, with **1450 existing Cerulean
PNG dependencies**. The 35 maps are selected by exact
`data/vermilionPreparation/<name>.json` package paths, cross-checked against
`manifest-entries.json`. Five layers per map contribute 175 images. There are
190 new global tile keys (380 image/mask paths), excluding all earlier Pewter
and Cerulean keys. All 34 actor strips / 164 original frames / 312 directional
poses are accounted for: 20 / 94 / 176 reference existing Cerulean paths;
14 / 70 / 136 are newly emitted (1100 image/mask/background paths). Shared NPC
keys retain their previous exporter owner. Cerulean's 2448 declarations, paths,
metadata, defaults and 18-map selection are preserved; its raw strips and poses
are neither renamed nor replaced. Native pixel preservation remains root work.

Ship adds hull 256×96, smoke 32×32 and water 32×32 with masks/backgrounds
(15 paths), plus 14 deterministic 896×96 **presentation band** samples at source
frames 0,4,124,130,137,138,258,770,1153,1154,1156,1276,1280,1283. These are
production `VermilionShipArt.render` / `VermilionShipTimeline` band captures,
not full gameplay/camera captures or an audio witness. Cut contributes two
production palette images with masks/backgrounds (10), and eight 64×32 clipped
split-tree presentations over source ground (8). Cut uses `FieldMoveState.draw`
on a private presentation record, with target at output pixel 16,0; it never
enters, updates or commits a field action. Immutable ship/field art caches warm
only at exporter bootstrap; writers read them afterward.

Provenance: English Blue pokered `af519899719f0754965776faac0e836a3b906e6d`.
Package PNG pins are `tools/references/vermilion-preparation.json`; actor grids
and tile quadrants are independently checked against those original PNGs.
Ship provenance/generation is `tools/references/vermilion-ship/manifest.json`
and `tools/generate_vermilion_ship.py`; Cut is
`tools/references/field-moves/pins.json` and `tools/generate_field_moves.py`.
Raw source/tiles retain explicit phase zero. Shared BLUE world poses use the
production canonical rival stands and greyhair, legacy-omitted-phase strides.
No protected art, baseline, diagnostic, manifest/cache, ledger or coverage edits.

Root integration: after the production
`CeruleanContent.registerPackage("vermilion", "data/vermilionPreparation/")`
has executed, insert these lines **only into the private harness stage**:

```lua
import "dev/vermilionCatalogExporter"
VermilionCatalogExporter.register()
import "dev/vermilionCatalogContracts"
Contracts.register("vermilion-catalog", VermilionCatalogContracts.run)
```

Registration before package loading cannot resolve the 14 new actors. Do not
register/install the production content a second time. Root must adapt the
existing global-total assumptions in `CeruleanCatalogContracts` and
`ComprehensiveCatalogContracts` to independently sum the named inventories;
per-exporter Pewter 859 and Cerulean 2448 assertions remain unchanged. Combined
expected inventory is 6644. This worker intentionally does not edit those suites
or the real main/dev-imports. Existing Route2 newly resolved gates produce a
concrete protected collision diagnostic difference for root review; there is
no authorization to accept it. Only the earlier museum diagnostic change was
approved in the private protected2494 baseline.

Validation: 28 focused host tests pass, zero skips (`test_vermilion_catalog_inputs`,
`test_cerulean_catalog_inputs`, `test_vermilion_ship`, `test_field_move_data`).
Host declaration SHA-256 (canonical sorted JSON):
`ed4c3443850b40809237d923b45545e28c0de58b3a4c97d504b80c5d4aeda645`.
Real SDK3.1.2 compile-only stage with the proposed registration passed at
`~/Developer/Pokemon-PlayDate-env/evidence/vermilion-catalog-build-20261026-02/`;
`proposed-registration.json` identifies the separately compiled `Proposed.pdx`
and overlay fingerprint (the original `build.json` describes `Harness.pdx`).
The 39 prepared SDK cases cover independent pixel/mask/phase oracles, all35
isolated maps, output protocol rejection, consumer failure and live-state
purity. They have **not run**. Root alone executes them, verifies actual PNG
publication/missing/extra output, compares protected/Cerulean pixels, and
inspects native size and scene motion. Existing harness invariance evidence
still covers only its named Pewter859 suite; it does not certify these additions.
