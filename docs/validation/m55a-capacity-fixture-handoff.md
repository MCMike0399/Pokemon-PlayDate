# Capacity fixture preparation collection

Base: exact private candidate `2e1be415`. Only `sessionFixture.lua`,
`kantoServicesContracts.lua` and `vermilionGiftsContracts.lua` changed under Source.
Production Source and root's separately owned preparation/ability contracts are
unchanged.

The shared `SessionFixture.collectPreparationGarbage` helper performs a full Lua
collection after every 32 completed setup iterations. Each capacity setup still
executes and asserts all 4096 real public setter calls, in the original order:
`CAPACITY:1` through `CAPACITY:4096`, or `GIFT_CAPACITY:1` through
`GIFT_CAPACITY:4096`, always with `false`. Each loop performs 128 collections,
including one after the final setter and before the tested gift operation.

This is restricted to synchronous fixture preparation. The public setter replaces
`currentActors` with a fresh `WorldMotionData.empty()` snapshot each time; discarded
snapshots become unreachable. Collection preserves the reachable session, flags,
scene and RNG snapshots. It changes neither collection settings nor production
collection cadence, and adds no frames, actor updates, RNG changes, receipts,
bulk domain writes or contracts. Both contract files are otherwise identical to
the base after removing whitespace and the new collection calls. All assertions
and case counts remain unchanged.

SDK 3.1.2 compile-only passed. Build identity and bundle are retained at
`~/Developer/Pokemon-PlayDate-env/evidence/m55a-capacity-fixture-compile-20261029-01`.
The existing `test_kanto_services` and `test_vermilion_gifts` host modules passed
all 12 checks without skips. `git diff --check` passed.

No concrete production defect was established or edited. These host/compile
checks do not establish that the 16 MB runtime exhaustion is resolved. Root must
execute the two existing SDK suites separately. No Simulator, device, USB, soak,
push or delegation action was performed.
