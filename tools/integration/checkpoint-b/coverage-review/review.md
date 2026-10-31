# Private B coverage candidate — 2026-10-30

For later Root integration into **B only**, after Root releases its pinned traversal/census packet. Main remains 108 accepted Simulator-route maps, hardware-safe with latency targets unmet; 0 device-playable maps. B remains private/unaccepted at 149 maps. This worker performed read-only host inspection/validation, with no runtime, Simulator, locks, device, USB, Source edit, delegation or push.

Input B: `64512fa7423df9fc160bc55eeab01c67d862402c`; reviewed Source fingerprint: `63285be81ad66d2b1d6b6629c96cf0ed29dd8773f1505c88deca42d73a6d585b`. The old `ddaf38044e47959381d3443cca5180d0232cb591` snapshot, fingerprint, scope and review survive verbatim in `snapshot.previous_snapshot`. B checkout/HEAD remain unchanged.

## What changed and why

- Reviewed every row/facet, owner, dependency and inventory against B, the matrix's history (especially e7270b8c, f949997e and e792a587), frozen declarations, and committed Root evidence. All row IDs/order, inventory source pointers, owners, dependencies, due dates and original evidence SHA256 values are preserved. All moves, abilities, species, items, held-item and audio inventory rows are byte-for-byte unchanged. There are 164 changed map/system rows; no rows are removed or added.
- Corrected campaign descriptions for the 108-map accepted-main manifest at c946efdf. Those campaign facets now say integrated/native_scoped, tied to the frozen 5.5a acceptance summary, explicitly limited to its original builds and checkpoint inventory. 96 classifications change; 12 already had that classification. The five pre-existing authored Pallet rows outside that manifest retain their earlier scoped proof; do not add them to the published 108-map count. No regional/full-mechanics map facet is promoted and `accepted_milestone_rows` stays empty.
- All 41 private South map rows retain partial/source_only campaign and regional classifications. Their notes now acknowledge completed earned B journeys/restarts on frozen builds, without inferring every map/event was exercised or rerun on B64512fa7. The 18 old Cerulean staged records retain their historical state but no longer imply that subsequent main acceptance never happened.
- Corrected system descriptions for accepted progression, gyms, Cut/Flash, partial South field owners, Options, isolated audio, measured resources/device, first-use loading and earned-save gates. Cut/Flash campaign facets use accepted 5.4/5.5a native scope. South field/puzzle campaign facets remain partial/source_only. Options/audio implementation is partial/source_only; device remains unreviewed. Naming, trades, Fly, League/postgame and release gaps remain. Historical component SDK labels remain their named original scopes, not current whole-engine tests.
- Added four B-local committed documentary proofs: accepted 5.4, accepted 5.5a, first-entry preparation, and isolated audio. The audio report's native safety pass is explicitly separated from its incomplete/silent capture and unaccepted listening. The first-entry preparation document predates Root qualification; its pending language is historical.
- Found five incorrect historical commit attributions that the checker itself does not verify. Replaced only `historical_source_commit` with an actual Git blob SHA256 match; retained the previous attribution in `previous_historical_source_commit`. Frozen file hashes are unchanged: battle → a20ab7e7293a09c88a555b2d8d3bd36986ac64b7; effects → c55bff0ea4e74d5785738ab29e635dc549efd516; conditions → 8c3947f638d9d8a701d6463363801e20202b5a28; sessionCodec → b2100c946039d2baf1a18ca1554202c9b05a8ea2; sourceMaps → ea65ec95e46d42766fa085fccd24eb9e688bb91e. The other historical declarations already matched and remain unchanged.

## Actual Source diff and proof boundaries

`git diff ddaf3804 64512fa7 -- Source` changes 12 files, 304 insertions/76 deletions. The substantive changes are ShippedDataPolicy and PDX-only qualified reads; generated region membership/transform identities and eight-record chunk resolution; qualified compact-map validation fences; lazy Cerulean story fields, route declarations and unrelated-map early returns; installer tracing; and the Simulator-only after-GC live-heap distinction (the physical 6 MiB guard remains). The two development projections change dependency hash entries only; their projected gameplay values are recursively unchanged. There is no new map, move, item or audio inventory in this delta. These loading/registration changes are substantive, so the fingerprint refresh is accompanied by row/evidence review rather than being a behavioral equivalence claim.

Root's newer B journey/common-build/visual/host/scaling summaries are **not present in pinned B**. Their real committed bytes were read and SHA256-verified from `971beaeb7d297d165ea0549052094c927322b64d`, with exact commit/path/hash recorded under `snapshot.external_review_documents`. They are review context, not B-local facet proof or a dynamic test produced here. Existing checker validates the B-local `evidence` registry; external identities were separately checked with `git show <commit>:<path>`. No missing main document was fabricated or copied into B. The candidate is self-contained for the checker against the present B tree.

All three earned B journeys and real two-process restarts passed; common-build cold loads and six real-input restart processes also passed. Those reports keep their original Source/build identities, canonical saves and explicit ordinary-NPC-motion equality exception. They do not prove execution on the refreshed B Source. The 1,058-test full audit remains **1,054 passed, four failures, zero errors/skips**, log SHA256 `018d25d9aaab6e10869f6e2b9b2769a70450a5c6f629862f11f71062a23c2fa1`. Three projection failures were repaired in d6228e06/64512fa7 with 65 targeted passes. This candidate addresses the coverage freshness assertion; no complete-suite rerun or green result is claimed.

## Validation and open gates

Existing B checker passes against actual B: **1,512 rows, 248 map slots, 430 moves (425 generated + five runtime), 131 items (six Pickup additions), 375 audio sources**, `no_completion_claim: true`. Separately verified every B-local proof hash, all historical Source blob hashes, all seven committed external-document identities, unchanged row/inventory/dependency fields and unchanged non-map/system rows. No historical runtime registry or unverified record was rewritten. Optional JSON-schema validation was unavailable (`jsonschema` is not installed in the existing environment); the existing matrix checker passed without installing dependencies.

Unmet: current-B per-map trigger/fidelity and broad rules verification; long physical traversal/resource acceptance (including unresolved long-session native-memory risk); census completion and worst-five physical doors; latency targets and shipped-equivalent timing; B showcase/package and Root acceptance decision. Protected-image/full-overlay/scoped SDK successes retain their limited identities and do not close these gates. No census outcome is inferred. No runtime blocker is converted to a fabricated green.

## Root integration and checks

**Do not run the mutation commands while the long-traversal packet requires B's strict pin.** Until Root explicitly releases it, only the first read-only validation is appropriate:

```sh
coverage_b=/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2c976160
coverage_worker=/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-0817d08b
coverage_rel=tools/integration/checkpoint-b/coverage-review
test "$(git -C "$coverage_b" rev-parse HEAD)" = 64512fa7423df9fc160bc55eeab01c67d862402c
PYTHONDONTWRITEBYTECODE=1 python3 "$coverage_b/tools/check_coverage_matrix.py" --project "$coverage_b" --matrix "$coverage_worker/$coverage_rel/coverage-current-candidate.json"
```

After Root releases the pin, from B only (review commit is also given in the worker handoff):

```sh
coverage_commit=$(git -C "$coverage_worker" log -1 --format=%H -- "$coverage_rel/review.md")
git -C "$coverage_b" cherry-pick "$coverage_commit"
cd "$coverage_b"
cp "$coverage_rel/coverage-current-candidate.json" docs/validation/coverage-current.json
PYTHONDONTWRITEBYTECODE=1 python3 tools/check_coverage_matrix.py --project "$coverage_b" --matrix docs/validation/coverage-current.json
git diff --check
git diff --stat -- docs/validation/coverage-current.json
```

The snapshot commit remains the exact reviewed Source pin even after documentation-only commits. If Source changes first, stop and review the actual new delta and proofs; do not relabel this candidate. Leave accepted evidence files unchanged. Update B's prose summary separately if desired; do not replace main's matrix with this private-B snapshot.

Root must then run the complete host recipe in `docs/validation/host-tests.md`, using verified pinned references and a fresh **compile-only** bundle. Example with the existing environment, on B after matrix integration:

```sh
source /Users/burbujamc/Developer/Pokemon-PlayDate-env/env.sh
coverage_host_root=$(mktemp -d /Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/m55b-coverage-host.XXXXXX)
python3 tools/harness/run.py --build-only --output "$coverage_host_root/bundle" snapshot
PARCEL_BUNDLE_SOURCE="$coverage_host_root/bundle" python3 - <<'PY'
import unittest
suite = unittest.defaultTestLoader.discover('tools/tests')
result = unittest.TextTestRunner(verbosity=2).run(suite)
if result.skipped:
    raise SystemExit('Unaccepted skipped checks: ' + repr(result.skipped))
raise SystemExit(not result.wasSuccessful())
PY
```

Stop on setup/build failure. This is host/compile validation only; runtime, hardware, showcase and acceptance remain Root-owned. Commit the reviewed B integration locally only after the appropriate checks. No push or main promotion is included.
