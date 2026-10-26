# Full-game execution ledger

Updated 2026-10-26. Follow [the full-game goal](../plans/full-game-goal.md).
[Previous ledger and preserved failures](progress-history-before-divemac-20261026.md).

## 1. Accepted revision and playable scope

Accepted code/tooling is `28d3f18`; the campaign gate is still incomplete.
Production Source is the tree committed in `82cb207`, unchanged through this gate: `44bd25bac9b1968cc8691eedc05ecd104faf708796602a492f997dccd1ae9ddc`.
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
- [x] Squirtle passed Brock, badge/TM and real exit/Continue with bounded
  preparation. Saved/continued PNGs are byte-identical; root inspected the saved
  world. Evidence: `brock-squirtle-20261026-01`.
- [ ] Charmander journey with real exit/Continue. The first new
  Charmander attempt was stopped by root to replace the one-hour suite budget
  with four hours; it receives no acceptance credit.
- [x] TM full-bag retry, blackout, restarts, evolution accept and cancel passed
  on current main Source. Root inspected their key images; saved and continued
  restart images are pixel-identical. Evidence: `brock-5.1-supplements-20261026-01`.
- [ ] Inspect key native screenshots and commit accepted tooling and evidence.

The historical Squirtle pass, Bulbasaur driver failure and interrupted Charmander
run retain their original statuses. They do not satisfy this fresh gate.
Charmander retains the level-16 natural evolution witness. Squirtle and
Bulbasaur use bounded level-8 preparation; evolution accept/cancel also have
separate passing supplementary cases. These are not pacing or balance proof.
After 5.1, continue through 5.2 foundations and every later milestone without
stopping at Brock. The full goal defines the completion criteria.

## 3. Open defects blocking progress

The zero-step driver bug is repaired. Bulbasaur, Squirtle and five supplements
pass. Three long Charmander attempts failed after natural evolution and receive
no acceptance credit. Sampling diagnostics alone did not prevent the third stall.
The owned native stack then exposed a startup e-list modal and 51.6 GB physical
footprint despite low RSS. Disabled root-level `ShowElist=0` in the Simulator’s
`com.panic.Playdate Simulator.ini`, retaining its original under environment
evidence. No email was submitted. Fresh stack has no modal; footprint is 63–65 MB
with peaks below 121 MB in short/early-long observations. Full retry is pending.
`brock-charmander-no-modal-20261026-01` is live with interval 60, memory sampling
and an owned-process stall stack watcher. Source remains unchanged at 44bd25.

Unsupported moves, separate map/event pipelines and production dev imports are
scheduled for 5.2. Missing later regions and full mechanics remain release work.

## 4. Work in flight

| Branch / owner | Work and next step |
|---|---|
| `main` / root | GPT-6.1 Sol, medium effort; sole Simulator owner, integrator, validator and ledger owner. Complete the running Charmander gate, then accept 5.1 and validate foundations. |
| `wip/brock-driver` / worker | Completed; `188d0cf` integrated as `895a874`. |
| `wip/move-failure-phazing` / worker | Candidate `025c5c9` complete; no runtime acceptance yet. |
| `wip/source-map-pipeline` / worker | Compact metadata/direct tile lookup plus common constructor are composed privately. |
| `wip/generic-map-bindings` / worker | Repair `88b96d8` composed; followup `c0e7e84` fixes unloaded arrivals and `97dccaa` generalizes registered actors/sight. Root integration is composed; native checks pending. |
| `wip/production-dev-gate` / worker | Candidate `bc22795` complete; production launch and measurements pending. |
| `wip/source-events` / worker | Candidate `38f44a1` complete; native acceptance pending. |
| `wip/source-text` / worker | Native glyph/page checks passed and root inspected them. Unsafe optional SDK getGlyph query removed; production uses pinned fallback. |
| `wip/scripted-npc` / worker | Native ownership checks passed; readability repair `5528b6a` composed as `a019a00`, compile/host passed. |
| `wip/harness-long-stall` / worker | `2258b51` prepares paired capture stress. Source unchanged; both synthetic capture arms passed. |
| `wip/foundations-integration` / root | Private composition at `8f4f34e` under the environment’s `worktrees/foundations`. Main Source remains frozen. Before readability edits: native 1250 passed, host 592 passed/zero skips, catalog 2494 exact. Latest review repairs compile with focused host checks; fresh native, coverage refresh, journeys and performance acceptance remain pending. |

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
