# Private B coverage refresh — data only

Reviewed fixed B `c1ef3b7a680ae4b0f736a93ec7715c58f263a10e` in read-only
`/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2c976160`.
Source fingerprint: `97e5517e1a09d0f9b405abea64c9235bf4de15173d2fe5505691b835d04d226e`.
The worker checkout is output only. No published matrix, ledger or Source edits.

Read canonical instructions, CLAUDE.md, full-game-goal, progress, host-test and
coverage guidance, existing coverage review/checker/tests, actual Git delta,
committed Root composition summaries and retained raw results. This is a source
and evidence reconciliation, not independent gameplay acceptance. Gameplay
Standards/Spec reviews of `00ce443a..12ecefec` remain pending.

## Source and evidence reasoning

Actual delta `e1824e6917b21e55c73a739d72973389ee7f680c..c1ef3b7a`:

- Runtime Cut/Flash/Fly/Surf/Strength now explicitly register singles battle
  dispatch. Fly shares charge/cleanup ownership, rejects ordinary airborne hits,
  permits its named exceptions/No Guard and doubles Gust/Twister final damage.
  Surf underwater/doubles semantics remain outside this implementation.
- Haze/Clear Smog use a stage-only helper. Haze clears living active stages;
  Clear Smog resets the primary-hit defender through ordinary hit gates.
  Substitute remains unsupported and the Clear Smog owner fails closed against
  enabling it without body-hit routing.
- Producer epoch 17 adds Rest/Snore/Yawn/Foresight/Revenge through existing
  status, condition and round-receipt owners. Rest uses explicit `applyRest`
  and a private helper, preserving the shared secondary-effect ABI. Snore
  obeys sleep/PP gates, Yawn retains delayed source/residual identity, Foresight
  reuses Odor Sleuth, Revenge tracks opposing move HP loss in the logical round.
- All 425 core move keys remain. Across the full requested interval, 418 core
  declarations are identical and seven change (the five plus Haze/Clear Smog).
  From `00ce443a` after stage-reset integration, exactly 420 non-five declarations
  remain identical. No claim that all 425 declarations are byte-unchanged.
- Exactly 2,546 R100 chunk renames introduce digest-prefix directories; the old
  and new records retain their bytes. The loader follows the prefix and
  SourceBindings checks the existing cooperative budget after objectDefinition.
  All 32 cache indexes remain identical. Eight-record retention, publication
  boundaries, map inventory and source pins remain unchanged.
- Fresh collected Kanto SDK export/provenance belongs to original
  `3603da2f:97e5517e` build. Export values equal the prior export except build_id.
  The reduced journey profile and exact hook passed; recorded host peak was
  189,285,360 bytes. Qualification was collected, with no Source/slot substitution.
  Sharding hardware performance is **UNMEASURED in this refresh**. The earlier
  production publication failed because output was inside stage; that failed
  bundle is not a deliverable. DeviceSmoke uses a fresh qualified build.
- Vermilion changes only its two dependency hashes. Dev imports and host
  expectations retain ordered checks. Schema 4, canonical saves, art, map content
  and AI are unchanged. No additional maps are accepted.

Raw retained results and original build/source identities are hashed in
`smallproof.json`. Native01 **28 passed / 5 failed** exposed the Rest/secondary
boolean collision. The explicit ABI repair precedes native02 **33/33** and
regressions **145/145** (combat 34, charge-lock 31, ability 46, HM 25, stage-reset 9).
The separate original epoch17 selection passed **54/54** assertions across 11
suites. These are original SDK results, not executions on c1ef by this worker.
Root summaries are read from exact main commit `80701fca`; their committed blob
hashes are retained separately in the snapshot and small proof. No raw report,
build identity, failed history or historical proof hash is relabeled.

## Candidate changes

All 1,512 row IDs/order, owners, dependencies, deadlines, source/inventory
pointers, capability/staged fields and every implementation/verification level
are preserved. Inventory remains 248 slots, 430 moves, 131 items and 375 audio
sources. `accepted_milestone_rows` remains empty. The entire previous snapshot
object is retained verbatim as `snapshot.previous_snapshot`; the original matrix
file remains untouched and its byte hash is recorded in the small proof.

Only 14 rows change: seven new move descriptions, five HM descriptions/source
links, and resource/device status notes. The seven core moves retain
indexed/unreviewed full-mechanics status. HM levels remain partial/source_only.
The remaining 1,498 rows are identical, including historical scoped SDK labels;
those labels remain scoped to their original builds, not renewed on c1ef.

Two stale references are resolved without replacing their hashes:

- `runtime-scopes-cave-rng54` points to the byte-identical committed
  `runtime-move-coverage-before-earned-b-20261101.json` frozen copy.
- `runtime-hm-definitions` retains its old Source path/hash with an independently
  checked historical declaration attribution to e1824e69. A separately named
  `runtime-hm-current` supplies current declaration membership only.

Separately named evidence records bind the existing epoch17 registry, 54-case
summary/raw bytes, chunk proof and Kanto export/provenance. The 33/145 reports
remain external build-scoped references, since they are not B-local matrix
files. No unavailable current source evidence is fabricated. Source-only/gap
records and deliberately stale runtime records remain in the registry; native
membership alone causes no facet promotion or full-move certification.

Main108 remains accepted; B149 private/unaccepted; C171 inactive. Census is
permanently STOPPED/incomplete. Static ranking and real worst-door route remain
open. Long physical B traversal (110 doors, 30 maps, 20 battles), resource gates,
showcase and user play judgement remain open; audio is held. Root owns hardware
writer24912; this worker does not watch it or infer its outcome.

Root's earlier 1,064-test run had seven stale failures. Its targeted import/
projection 65 and runtime coverage 8 checks reportedly pass after their fixes;
this packet does not claim a fresh full-host green result. Host coverage checks
below do not qualify gameplay or performance.

## Host validation and integration

The existing checker passes against fixed B: 1,512 rows, 248 slots, 430 moves,
131 items and 375 audio. All four existing matrix tests pass with no skips,
including their rejection mutants. Only the test class data loader was redirected
to the candidate; fixed B files and production validation were not patched.
Source fingerprint/HEAD remained fixed before and after reading and host checks.
All 3,963 Source files were compared to fixed Git blobs, including extra-file
rejection. Historical declaration hashes were independently matched to Git blobs.
All 50 registry keys, states, definitions, capabilities, scopes and cited assertion
hashes are preserved; all non-verified records are verbatim. Validation results
and before/after source checks are in `smallproof.json`.
No SDK runtime, compile, Simulator, USB/device, AX/OpenClaw, locks, network,
Pi, full-host run, delegation or push was performed.

Root should import only this packet's commit, review candidate data/claims
independently, and complete its pending gameplay/performance gates. Do not copy
this private B matrix onto main or activate C. If Source changes, stop and review
the actual new delta; do not merely update a hash.

From the actual B checkout after importing the packet:

```sh
git diff --exit-code c1ef3b7a680ae4b0f736a93ec7715c58f263a10e -- Source
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
from pathlib import Path
from tools.harness.run import fingerprint
assert fingerprint(Path.cwd()) == '97e5517e1a09d0f9b405abea64c9235bf4de15173d2fe5505691b835d04d226e'
PY
python3 tools/check_coverage_matrix.py --project "$PWD" --matrix tools/integration/checkpoint-b/coverage-refresh-20261101/candidate.json
git diff --no-index docs/validation/coverage-current.json tools/integration/checkpoint-b/coverage-refresh-20261101/candidate.json
# The reviewed data diff intentionally returns 1.
```

After independent review and Root's gates, publish only in private B:

```sh
cp tools/integration/checkpoint-b/coverage-refresh-20261101/candidate.json docs/validation/coverage-current.json
python3 tools/check_coverage_matrix.py --project "$PWD" --matrix docs/validation/coverage-current.json
python3 -m unittest tools.tests.test_coverage_matrix -v
git diff --check
```

Root then runs the full host suite using its fresh qualified bundle and existing
pinned reference/cache setup from host-tests.md. Preserve the earlier 1,064-test
failure history; record the new full result separately. Recheck the fingerprint
before/after integration. Coverage freshness does not accept B or promote data.
