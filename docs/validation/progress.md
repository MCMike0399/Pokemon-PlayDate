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

- [ ] Verify and compose the frozen warp-reentry and learning-capture patches.
- [ ] Run the native warp-return check.
- [ ] Run natural Bulbasaur, Charmander and Squirtle journeys through Brock,
  each with a real process exit and Save/Continue.
- [ ] Run TM full-bag retry, blackout, restarts, evolution accept and cancel.
- [ ] Inspect key native screenshots and commit accepted tooling and evidence.

The historical Squirtle pass, Bulbasaur driver failure and interrupted Charmander
run retain their original statuses. They do not satisfy this fresh gate.
Level 16 training is an evolution witness, not evidence of normal pacing.
After 5.1, continue through 5.2 foundations and every later milestone without
stopping at Brock. The full goal defines the completion criteria.

## 3. Open defects blocking progress

The host driver can choose a zero-step arrival warp after blackout; its frozen
repair awaits review and native verification. Learning-panel captures also await
composition. No new production defect appeared in the 5.0 baseline checks.
Unsupported moves, separate map/event pipelines and production dev imports are
scheduled for 5.2. Missing later regions and full mechanics remain release work.

## 4. Work in flight

| Branch / owner | Work and next step |
|---|---|
| `main` / root | GPT-6.1 Sol, medium effort; sole Simulator owner, integrator, validator and ledger owner. Accept 5.0 docs, then review Brock patches and run journeys. |
| `wip/brock-driver` / worker | Explicit `gpt-6.1-sol`, `reasoningEffort=medium`, provider `codex`; isolated git worktree. Recompose only host driver/scenario/test paths, run relevant host tests and return a commit. No Simulator access. |

## 5. Decisions since the user check-in

- Resumed on DiveMac under the new full-game goal; the old pause is superseded.
- Keep the existing Source frozen during the 5.0 and 5.1 baseline/campaign gate.
- Use git worktree branches for new worker output and durable environment evidence
  directories for runtime artifacts. Existing tarballs remain historical inputs.
- Root independently accepts work; workers prepare bounded changes. Commit to
  `main` after acceptance and push only when asked.
