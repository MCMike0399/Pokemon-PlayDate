# MAIN108 coverage review — preparation only

Reviewed Source pin: `d9cbc0018f8f2004f54e8d88b9d6e95e6e2208b8`.
Preparation checkout: `8702f79949335db31e4f0865de3d9da6c2cab1e3`.
Its Source and tools/harness bytes match the pin exactly; no Source extras.
Source tree: `fcfdc06f7b543aaad3a2e808fbbfdceca118adc1`.
Harness tree: `1bc94e592bb45116dc2da13a4526f4d821e60fc0`.
Existing-checker Source fingerprint:
`a5402a570a42cc00cf24f642bed52140eb805bfb8d8b9ec0aacad5f6e08b329c`.

The candidate retains the previous `f86d62577f2288f5ae14f3102158da0f7fd90f82`
snapshot, fingerprint, scope and review in `staged_source_snapshots`. It retains
all prior staged snapshots, original proof hashes, 1,512 row IDs, dependencies,
source inventories, due dates, owners and every facet verification level.
The 248 slots, 430 moves, 131 items and 375 audio sources are unchanged.
`accepted_milestone_rows` stays empty. No move/species/ability/item/audio row changes.

## Semantic review

Read CLAUDE.md, full-game-goal, progress, host-tests, checker/current matrix,
acceptance summaries and relevant retained proofs. Reviewed the actual
`git log` and `git diff f86d625 d9cbc001 -- Source tools/harness`:

- Qualified immutable map/content reads move shipped-data validation to staging,
  fence reads to PDX, bind trust to copied bytes, and retain bounded guard checks.
  Custom/harness inputs and untrusted saves retain deep validation.
- Kanto membership registers before trainer lookup; heavy descriptors/teams use
  the existing eight-record cache. Scene fields load independently; callbacks
  remain at boot. `_usesQualifiedInputs` tests origin eligibility without decoding
  the compact catalogue; constructor identity remains a separate check.
- Scene/world/session/save ownership stays authoritative. No domain, battle,
  renderer, protected sprite or map content inventory changed in this interval.
  The accepted GB-tone/protected-art inventories remain authoritative.
- `Source/dev/doorCensus.lua` is a private Simulator-only observer, absent from
  production imports. Census/helper/profiler tooling supplies no map acceptance.
  Harness protocol now reports fatal errors; archive/storage changes and the
  unexecuted GUI helper do not qualify gameplay. No helper was executed here.
- d9cbc001 changes only dependency hashes in Cerulean/Vermilion projections;
  the committed audit records unchanged recursive gameplay values and 51 passes.

113 map descriptions change: 108 current manifest definitions and five protected
Pallet adapters. This is **not** a claim of 113 accepted maps. The published main
checkpoint count remains **108/222 Simulator-accepted, 0/222 device-playable**.
Manifest membership supplies source evidence only; it does not prove each optional
map/event was visited. Installed indexed campaign implementations become partial;
existing verification levels and fidelity/mechanics limits remain. Historical
Cerulean preparation fields are explicitly historical rather than current blockers.

13 system descriptions change: world, saves, New Game/rewards, starter journeys,
progression, Cut, Flash, puzzles, gyms, Options, resources and device. Main proofs
support Captain/Cut/Flash, Misty/Surge/Erika, Hideout/Scope and persisted Options;
NPC trades remain parked, naming/audio remain unfinished. Indexed implementations
for these implemented subsets become partial without verification promotion.

New evidence references bind actual committed proof bytes: A/title/Save acceptance,
5.4 acceptance, Kanto candidate/measurement/scaling, boot review, idle soak and main
host audit. Each reference states its exact scope. MAIN108 Kanto build `025d4978`
has 13-event/two-team first-use equivalence, 44/0 native scene cases, and hardware
installer 1,119→58 ms (94.8% phase gain). The equivalence file and both retained
hardware reports match their published SHA256 values. Boot-stack review retains
182 native activation cases and its correction/re-review limits. The accepted
idle build `11f5e226` has 120 samples over 60+60 minutes, peak 5.77 MiB and no soft GC.
These are original build-scoped results, not executions on d9cbc001. Candidate
pre-merge wording remains historical; main merge/review is recorded separately.
Scaling `runs[1]` is private B149 comparison only, explicitly excluded from main.

Five historical Source attributions were wrong. All eight historical declarations
were checked against actual Git blobs. Preserve their existing hashes, correcting
only the five mismatching `historical_source_commit` fields to matching commits:

| Evidence | Correct blob attribution |
| --- | --- |
| production-battle | a20ab7e7293a09c88a555b2d8d3bd36986ac64b7 |
| production-effects | c55bff0ea4e74d5785738ab29e635dc549efd516 |
| production-conditions | 8c3947f638d9d8a701d6463363801e20202b5a28 |
| production-sessionCodec | b2100c946039d2baf1a18ca1554202c9b05a8ea2 |
| production-sourceMaps | ea65ec95e46d42766fa085fccd24eb9e688bb91e |

These commits locate the original hash; they do not date or renew behavior proofs.
The checker itself only validates historical declaration shape, so this separate
blob check matters. The old snapshot identifies the unchanged root matrix.

## Validation and missing proof

Existing checker passes against actual pinned MAIN Source: 1,512 rows, 248 slots,
430 moves (425 generated + five runtime), 131 items (six Pickup), 375 audio.
All four existing CurrentMatrixTests pass when their input is the candidate,
including rejection mutants; no new generator/framework/contracts were added.
Additional read-only assertions verified exact pinned bytes, historical blobs,
unchanged inventories/dependencies/due dates/owners/verifications and proof hashes.
`git diff --check` passes.

The retained full-main log's SHA256 matches the audit: 1,091 tests, four freshness
failures, no errors/skips. The repair's 51-test log also matches. This preparation
runs neither the full host suite nor runtime. Root's published matrix stays stale
until integration; a candidate checker pass is not full-suite green.

Boot 11.263 s, raw boot slice 1.267 s, sampled door 3.014 s and cave p95 96.969 ms
still miss targets. Diagnostic GC is included; shipped-equivalent timing, complete
first-entry laziness, full census/worst-five hardware doors, long physical
traversal/native memory, audio listening and user play judgement remain unverified.
B149 remains private/unaccepted despite three journeys and its 1,058 host passes;
no B coverage candidate or new Safari correction was used. No Simulator, GUI, AX,
device, USB, runtime lock, delegation or push was used. Only this two-file packet
is committed; root Source/matrix/ledger/accepted evidence remain untouched.

## Root integration and checks

From root's main checkout, import this packet from the worker branch if needed:

```sh
git cherry-pick t3/77543fe1
```

Then verify the pin and inspect the candidate diff before publishing:

```sh
git diff --exit-code d9cbc0018f8f2004f54e8d88b9d6e95e6e2208b8 -- Source tools/harness
python3 tools/check_coverage_matrix.py --project "$PWD" --matrix tools/integration/main-coverage-review/coverage-current-candidate.json
git diff --no-index docs/validation/coverage-current.json tools/integration/main-coverage-review/coverage-current-candidate.json
# The reviewed diff above intentionally returns 1.
cp tools/integration/main-coverage-review/coverage-current-candidate.json docs/validation/coverage-current.json
python3 tools/check_coverage_matrix.py --project "$PWD" --matrix docs/validation/coverage-current.json
python3 -m unittest tools.tests.test_coverage_matrix -v
git diff --check
```

Root should reconcile coverage-current.md's stale f86d625/B-running prose. With
the existing pinned references/cache provisioned as in host-tests.md, the exact
compile-only/full-host follow-up is below (not executed by this worker):

```sh
(
set -eu
source ~/Developer/Pokemon-PlayDate-env/env.sh
coverage_host_root=$(mktemp -d "$POKEMON_ENV/evidence/main-coverage-host.XXXXXX")
python3 tools/harness/run.py --build-only --output "$coverage_host_root/bundle" snapshot
export PARCEL_BUNDLE_SOURCE="$coverage_host_root/bundle"
python3 - <<'PYHOST' > "$coverage_host_root/host.log" 2>&1
import unittest
suite = unittest.defaultTestLoader.discover('tools/tests')
result = unittest.TextTestRunner(verbosity=2).run(suite)
if result.skipped:
    raise SystemExit('Unaccepted skipped checks: ' + repr(result.skipped))
raise SystemExit(not result.wasSuccessful())
PYHOST
)
```

If Source changes before integration, stop and review the new delta rather than
changing only the fingerprint. Runtime acceptance remains with root.
