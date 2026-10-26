# Full-game execution ledger

Updated 2026-10-26. Follow [the full-game goal](../plans/full-game-goal.md).
[Earlier ledger and preserved failures](progress-history-before-divemac-20261026.md).

## 1. Accepted revision and playable scope

Accepted code is `27443af`, with Source
`2673b352e62b8e145b8a7e19b055db47479bc4f4100caf6f2835137ee85fe079`.
A player can finish Pallet → Brock with any starter, receive badge/TM, save,
exit the actual process and Continue. All three journeys passed again after the
foundation refactor. New regions remain private. Kanto beyond Brock, audio and
release work are unfinished. Device validation has not run. Local commits wait
for an explicit request to push.

## 2. Current milestone and checks

**5.0 — Re-establish on DiveMac: done.** Environment and smoke passed; the goal
and setup docs were already committed. Host: 529 passed, zero skips. SDK: 1091
passed; all 2494 protected images exact. CLAUDE.md and this ledger were updated.
[Baseline summary](divemac-baseline-20261026.json).

**5.1 — Close Pallet → Brock: done.**

- Both archive checksums were verified; narrow driver/learning patches and native
  warp return passed. All three natural starter journeys passed Brock and rewards.
- Each starter survived actual process exit/Continue. Root inspected learning,
  evolution, Gym, save and continued captures; saved/continued worlds match.
- TM full-bag retry, blackout, restart persistence, evolution accept and cancel
  passed. Main Source has 544 passing host tests, zero skips, 1091 passing SDK
  contracts and 2494 exact protected images.
- Bulbasaur/Squirtle used level-8 preparation. Charmander’s level-16 evolution
  witness required 95 natural preparation fights; this is not pacing proof.
- [Acceptance summary](brock-acceptance-20261026.json) retains exact evidence
  directories and previous failures, which receive no acceptance credit.

Evidence under `~/Developer/Pokemon-PlayDate-env/evidence/`: Bulbasaur in
`brock-5.1-20261026-01/acceptance-suite`, Squirtle in
`brock-squirtle-20261026-01`, Charmander in
`brock-charmander-no-modal-20261026-01`, supplements in
`brock-5.1-supplements-20261026-01`.

**5.2 — Scale foundations: done.**

- Shared map/provider/cache/bindings, source events, script leases, text and
  production dev gating are integrated. Unsupported moves fail loudly; Whirlwind
  and Roar have native trainer/wild success/failure witnesses.
- On merged main: 1274 SDK contracts and 605 host tests passed, zero skips;
  production compile and 54 protocol checks passed. All 2494 protected images
  remain exact. Root inspected the new mechanics/text images.
- All nine real-input cases passed on one frozen Source: three full natural
  starter Brock/restart journeys, warp return, TM full-bag retry, blackout,
  seen/trainer restart persistence, evolution accept and cancel. Root inspected
  key images and confirmed distinct process generations and matching saves.
- Instrumented startup: 252 ms before, 202 ms with only dev gating, 150 ms
  integrated; post-GC Lua heap 10.85, 8.79 and 6.05 MiB. These are single
  Simulator observations, excluding native allocations/device limits.
- [Acceptance summary](foundation-acceptance-20261026.json) pins all evidence under
  `m52-main-sdk-20261026-01`, `m52-main-build-20261026-01` and
  `m52-main-journeys-20261026-01`. Earlier failures retain their failed status.

**5.3 — Pewter → Cerulean: in progress on a private branch.**

- Thirty shared source maps are installed privately, including eighteen new
  maps, ordinary events, trainers, art and music metadata. Bill/Ticket, fossils,
  Misty, rivals, Rockets, museum/bike/Magikarp services and earlier tutorial/escort
  scenes are composed. Natural per-starter journey drivers are prepared.
- Independent standards review repairs are composed. Spec review found missing
  guard dialogue and exposed abilities: guards and ordinary entry/contact/residual ability hooks are repaired privately.
  The fourth native pass passed all 1596 contracts. The frozen ambient blocker
  is resolved through an owned source-script movement intent. Center healing was
  extended to the pinned standard layout; its actual blackout supplement passed.
- New visual exporter declares 2448 additions. Native scene, map, art and journey
  acceptance remain pending. The user approved exactly the museum collision diagnostic update (two door cells,
  2048 pixels); all other 2493 protected images match. Private baseline approval
  is recorded and the approved protected comparison passes. All 18 new map
  viewports and source-strip families were inspected; scene motion review remains.

## 3. Open defects blocking progress

No open defect blocks the accepted Brock path. Three long Charmander failures
are preserved. Native sampling exposed a startup e-list modal and 51.6 GB
physical footprint despite low RSS. With root-level `ShowElist=0` in the Simulator
ini, the full two-process retry passed. Observed footprint was 63–72 MB, peak
120.9 MB. The original ini is backed up under environment evidence; no signup
was submitted. This was an environment repair, not a game Source change.
Diagnostic capture sampling remains optional, default interval 1.

No open defect blocks accepted 5.2. Private Cerulean ability exposure and native
acceptance remain pending.
Later regions, common mechanics, audio and release checks remain unfinished.

## 4. Work in flight

| Branch / owner | Work and next step |
|---|---|
| `main` / root | GPT-6.1 Sol, medium effort; sole Simulator owner, integrator, validator and ledger owner. 5.2 accepted; continue Cerulean native validation. |
| `wip/cerulean-integration` / root | Durable environment worktree at `c6882b6`; fresh Squirtle New Game → Bill/restart journey is live. Ticket, TM11, both fossil retries, blackout and observation restart witnesses pass. Other starter journeys remain unrun. |
| `wip/vermilion-integration` / root | Private `4c85150` composes 35 prepared maps, Cut/Flash, quest gifts and Anne/Surge scenes. The active 30-map manifest is unchanged; shared API patches and native acceptance remain pending. |
| Field-world worker | Preparing temporary Cut reload ownership and persisted Flash darkness. |
| Day Care worker | Preparing the source-backed deposited-specimen service and separate owner patch. |
| Anne/Surge worker | Finishing source ship departure presentation and the closed Gym-door tile dependency. |
| `wip/kanto-entry-abilities` / worker | `e8844a3` composed; actual native entry cases passed after fixture repairs. |
| `wip/kanto-contact-abilities` / worker | `a408642`/`3cc5925` composed; actual native contact cases passed after live-ledger fixture repairs. |
| `wip/audio-rgbds-oracle` / worker | `dadb7b3` independently qualifies emitted bytes with isolated pinned Bison/RGBDS; no engine/APU claim. |
| `wip/audio-offline-renderer` / worker | `8def326` prepares deterministic PCM mix/stems; listening and independent APU qualification pending. |
| `wip/audio-sdk-probe` / worker | `7e8c496` prepares two compiled backend probes; runtime is root-only and unrun. |

All workers explicitly use `gpt-6.1-sol`, medium effort, provider `codex`.
Earlier foundation workers are composed privately; exact commits/task IDs remain
in environment evidence at `brock-5.1-20261026-01/worker-tasks.json`.

## 5. Decisions since the user check-in

- Keep source identity, component acceptance and campaign acceptance separate.
- Preserve authored Pallet and all 2494 protected catalog images exactly.
- Use worktree branches and durable environment evidence; no new tarballs.
- Root independently accepts work and commits accepted steps to local main.
- Continue all campaign/postgame milestones; push only when explicitly asked.
