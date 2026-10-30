# Lazy map fixture repair

Base: private candidate `32b00784`. Production Source remains identical to
`2a015c89`; only three development fixture modules changed.

`SessionFixture.loadZone` resolves imported keys through the installed production
provider on each request. Traversal actors, connection origins and the runtime-art
Player jump use it instead of assuming legacy registry entries remain resident.
`SessionFixture.createZone` uses the production binding profile and art preparation
with the existing private registry. Both mutable traversal fixtures use it, so
Viridian City's original Gambler art is prepared before binding. Existing ledge
metadata modifications remain confined to the private fixture registry and Zone.

All original assertions and test names remain. Counts remain 11 traversal cases
and 3 runtime-art cases. No contracts, canonical data, production changes, input,
receipts or RNG setup were added. The retained failures identify invalid fixture
setup; no concrete production defect was found.

SDK 3.1.2 compile-only passed. Bundle and build identity are retained in
`~/Developer/Pokemon-PlayDate-env/evidence/m55a-lazy-fixture-compile-20261029-01`.
The existing `test_jump_art`, `test_runtime_art`, `test_source_map_pipeline` and
`test_source_map_activation` host modules passed all 30 checks without skips.
`git diff --check` passed. This is not native runtime acceptance.

Root should rerun the existing traversal and runtime-art SDK batches against this
commit. No Simulator, device, USB, soak, push or delegation action was performed.
