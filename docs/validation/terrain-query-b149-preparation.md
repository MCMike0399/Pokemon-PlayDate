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
