# Full-game execution ledger

Updated 2026-10-26. Follow [the full-game goal](../plans/full-game-goal.md).
[Previous ledger and preserved failures](progress-history-before-divemac-20261026.md).

## 1. Accepted revision and playable scope

Accepted game Source is the tree committed in `82cb207`, unchanged through
`f57d708`: `44bd25bac9b1968cc8691eedc05ecd104faf708796602a492f997dccd1ae9ddc`.
A player can complete the Pallet intro, deliver Oak’s parcel, capture Pokémon,
use party/bag/storage/healing, traverse Viridian Forest and challenge Brock.
Brock, badge and TM exist, but the current all-starter campaign gate is pending.
The remaining campaign, audio and release work are unfinished. Device validation
has not run. Accepted local commits will wait for an explicit request to push.

## 2. Current milestone and checks

**5.0 — Re-establish on DiveMac: done.**

- Environment sourced; clean `main` found at `f57d708`. Goal and setup docs were
  already committed as `1a75a04` and `f57d708`; no pending doc changes existed.
- `make harness-smoke` passed without a ready-handshake timeout.
- Full host suite: 529 passed, zero failures and zero skips.
- SDK contracts: 1091 passed, zero failures. Catalog: all 2494 protected images
  exact, including masks; no additions. [Baseline summary](divemac-baseline-20261026.json).
- CLAUDE.md now describes the world through Pewter, domain owners, imported-map
  providers and source encounter rates. The old ledger is archived above.

Evidence is under `~/Developer/Pokemon-PlayDate-env/evidence/` in
`m50-smoke-20261026-01` and `m50-contracts-catalog-20261026-01`.

**5.1 — Close Pallet → Brock: in progress.**

- [x] Verified both archive checksums and composed the narrow host patches in
  `895a874`. Integrated full host suite: 539 passed, zero skips.
- [x] Native warp return passed; root inspected both completed-frame images.
  The frozen scenario asserted capture phase before the frame update; corrected
  the scenario and checked finalized capture metadata instead. Original failed
  run is retained under `brock-5.1-20261026-01/native-warp-return`.
- [x] Bulbasaur passed Brock, badge/TM and real exit/Continue on Source above.
  Root inspected saved/continued Gym and learning panels.
- [ ] Charmander and Squirtle journeys with real exit/Continue. The first new
  Charmander attempt was stopped by root to replace the one-hour suite budget
  with four hours; it receives no acceptance credit.
- [ ] Run TM full-bag retry, blackout, restarts, evolution accept and cancel.
- [ ] Inspect key native screenshots and commit accepted tooling and evidence.

The historical Squirtle pass, Bulbasaur driver failure and interrupted Charmander
run retain their original statuses. They do not satisfy this fresh gate.
Level 16 training is an evolution witness, not evidence of normal pacing.
After 5.1, continue through 5.2 foundations and every later milestone without
stopping at Brock. The full goal defines the completion criteria.

## 3. Open defects blocking progress

The zero-step arrival-warp driver bug is repaired and the native return passes.
Bulbasaur and its learning panels pass; Charmander, Squirtle and supplements
remain pending.
No production defect appeared in the 5.0 baseline or native return check.
Unsupported moves, separate map/event pipelines and production dev imports are
scheduled for 5.2. Missing later regions and full mechanics remain release work.

## 4. Work in flight

| Branch / owner | Work and next step |
|---|---|
| `main` / root | GPT-6.1 Sol, medium effort; sole Simulator owner, integrator, validator and ledger owner. Accept 5.0 docs, then review Brock patches and run journeys. |
| `wip/brock-driver` / worker | Completed; `188d0cf` integrated as `895a874`. |
| `wip/move-failure-phazing` / worker | Candidate `025c5c9` complete; no runtime acceptance yet. |
| `wip/source-map-pipeline` / worker | Candidate `e137dcf`; followup replaces eager whole-map scans with generated compact metadata. |
| `wip/production-dev-gate` / worker | Candidate `bc22795` complete; production launch and measurements pending. |
| `wip/source-events` / worker | Candidate `38f44a1` complete; native acceptance pending. |
| `wip/source-text` / worker | Prepare full source character handling, UTF-8 typing and pagination. |
| `wip/foundations-integration` / root | Private composition at `28ddf98` under the environment’s `worktrees/foundations`. Main Source remains frozen. Combined compile passes; host evidence refresh awaits actual SDK run. |

All workers explicitly use `gpt-6.1-sol`, medium effort, provider `codex`.
Task IDs and local orchestration state are retained in the evidence directory’s
`brock-5.1-20261026-01/worker-tasks.json`.

## 5. Decisions since the user check-in

- Resumed on DiveMac under the new full-game goal; the old pause is superseded.
- Keep the existing Source frozen during the 5.0 and 5.1 baseline/campaign gate.
- Use git worktree branches for new worker output and durable environment evidence
  directories for runtime artifacts. Existing tarballs remain historical inputs.
- Root independently accepts work; workers prepare bounded changes. Commit to
  `main` after acceptance and push only when asked.
