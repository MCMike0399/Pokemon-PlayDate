# Detached terrain queries on accepted checkpoint B

Unadopted composition `c7bac066`, based on accepted main `7726ea49`.
Normal merge `608d93aa` ports field-terrain candidate `56c398aa`; `c7bac066`
ports Vermilion membership candidate `c5639f94`. All accepted-main files remain.
Only three production files differ from main.

`SourceMaps.terrain(key)` returns a detached terrain record through the existing
lazy compact-data owner. Unknown keys return nil; no art grids or catalogue
reference escape. FieldTravelWorld no longer permanently retains a full
catalogue copy. Its lookups now follow active `_withRecords` fixture scopes,
rather than retaining the first fixture forever. Runtime-definition scopes are
unchanged. Vermilion scene assertions use existing boolean `hasTile` instead of
copying the catalogue: four copies removed for each gym effect, sixteen for
ship departure. These are source call counts, not measured memory gains.

18 existing host checks pass:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 -m unittest tools.tests.test_field_travel_sources tools.tests.test_vermilion_story tools.tests.test_source_map_activation
```

Diff whitespace checks pass. No SDK build, Simulator, hardware or new tests were
run for this composition. Free space was 47.325 GiB, below unchanged 51 GiB
runtime admission. Main and accepted saves are untouched.

Next: actual fresh SDK exports and semantic comparison for SourceMaps-dependent
East/South and Kanto qualification; never merely replace provenance hashes.
Then run existing field-travel Surf/Fly and Safari completion cases, field-world
checkpoint/blocked-cell/session and renderer rollback cases, and Vermilion
solved-puzzle/rejected-solution/departure/codec cases. Verify detached terrain
mutation and nested fixture restoration in the existing native selection.
Measure heavy-map collected live heap and matched physical route before review
and adoption. This composition establishes no device gain or C memory margin.

## Root qualification progress — 2026-11-02

Actual SDK export `terrain-query-b149-exports-20261102-01` completed. The retained
collector verifies the complete copied source, SDK/build/outcome identity, exact
East/South output values and Kanto prerequisite sets, unchanged imports/cache,
and SourceMaps as the only changed transform dependency. Previous receipts are
retained under `terrain-query-prior-*`; no pins were changed without real export.
27 focused field/source/activation/registration host checks pass.

The full harness and then the combined thin native batch hit the unchanged1GiB
host guard and published no result; neither earns correctness credit. Running
the Surf case alone in a fresh thin process passed1/0, including Safari boarding
and Save/Continue, with373,785,776-byte sampled peak host footprint. The next
expiry case timed out before boot output; lidwatch reports open/awake and no
Screen Sharing. Its owned child was stopped and data retained. No production
defect is established by that startup failure; Root requested Screen Sharing.

One added source-map contract checks terrain parity, detached values, unknown
keys and nested fixture restoration through actual FieldTravelWorld queries.
It compiles in `terrain-query-b149-query-contract-native-20261102-01`; execution
is pending. All original field assertions remain intact. Disk headroom is now
user-authorized31GiB admission/30GiB reserve; memory/ownership guards unchanged.
Physical memory margin, remaining native cases and review still gate adoption.
