# Full-game execution ledger

Updated 2026-10-28. Follow [the full-game goal](../plans/full-game-goal.md).
[Earlier ledger and preserved failures](progress-history-before-divemac-20261026.md).

Progress: **12 / 222 source maps playable on main. Current milestone: 5.3.**

## 1. Accepted revision and playable scope

Accepted code is `27443af`, with Source
`2673b352e62b8e145b8a7e19b055db47479bc4f4100caf6f2835137ee85fe079`.
A player can finish Pallet → Brock with any starter, receive badge/TM, save,
exit the actual process and Continue. All three journeys passed again after the
foundation refactor. New regions remain private. Kanto beyond Brock, audio and
release work are unfinished. Device validation has not run. The user requested
a push of current main progress on 2026-10-26; unaccepted candidates stay local.

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
- The first natural Squirtle run reached Mt. Moon after Brock and level-16
  evolution, then exposed a driver release-gate bug. Fix `ab51b14` passes 50
  main host checks. The subsequent early trial was stopped for the reviewed
  contract cleanup. A later run reached Route25 after Misty/Bridge, then blacked
  out with depleted PP, poison and no Potions. Real Center/restock and bounded
  checkpoint recovery were added to the driver. The retry completed Bill/Ticket and
  saved on Route25, then failed screenshot qualification before Continue: its
  saved viewport contains no visible NPC. The shared source-map pose loader is
  repaired; a real visible-actor save location is being prepared. No failed run
  receives campaign acceptance credit.
- Physical-lead field effects passed 1612 native contracts after correcting
  Pikachu's held-item draw expectation. Seven ordinary ability hooks and the
  source indoor-land encounter repair passed all 1659 native contracts, zero failures.
  The cave before-fix witness failed on all three Mt. Moon floors as expected.
- Root independently passed 716 host tests, zero skips, on the frozen private
  Source. Reviewed coverage retains all 1501 rows, 50 scopes and ten stale records.
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

No open defect blocks accepted 5.2. Private Cerulean component checks are green;
final natural/campaign acceptance remains pending. Vermilion still needs native
acceptance of its composed dialogue, grass Cut and Pickup, plus reviewed approval
for its Route2 collision diagnostic. That approval has not been granted.
Later regions, common mechanics, audio and release checks remain unfinished.

Later work is frozen until Cerulean is accepted. All three accepted Brock saves
were recovered under `evidence/chain/5.2/<starter>`; [hashes and provenance](chain-saves.json).
Next runs start there and continue after individual failures.

## 4. Work in flight

| Branch / owner | Work and next step |
|---|---|
| `main` / root | GPT-6.1 Sol, medium effort; sole Simulator owner, integrator, validator and ledger owner. 5.2 accepted; continue Cerulean native validation. |
| `wip/cerulean-integration` / root | `489a439`, unchanged Source from `b1f0bd8`; 1659 SDK and 716 root host checks pass. Resource-aware Squirtle run reached the final save but failed visible-actor screenshot qualification. Loader repair passes 22 root host checks; all three fresh journeys remain pending. |
| `wip/vermilion-integration` / root | Private `380104e` has 65 maps, HMs, grass Cut, dialogue, ship, Day Care, collection, approved Pickup, nine trades and gate guards; visual extension: 1736 images. Latest completed SDK run: 2144 passed/19 failed. Codec fixtures and trade callbacks are repaired; a native diagnostic rerun is active. Remaining field, Day Care and trainer-text failures are under diagnosis. Native acceptance remains pending. |
| `wip/audio-integration` / root | Host parser/rendering and independently assembled RGBDS bytes are composed; 60 host checks pass. Backend runtime probes, listening and APU qualification remain pending. |

All workers explicitly use `gpt-6.1-sol`, medium effort, provider `codex`.
Earlier foundation workers are composed privately; exact commits/task IDs remain
in environment evidence at `brock-5.1-20261026-01/worker-tasks.json`.

## 5. Decisions since the user check-in

- Keep source identity, component acceptance and campaign acceptance separate.
- Preserve authored Pallet and all 2494 protected catalog images exactly.
- Use worktree branches and durable environment evidence; no new tarballs.
- Root independently accepts work and commits accepted steps to local main.
- Continue all campaign/postgame milestones; push only when explicitly asked.
- The user approved the exact B2W2 Pickup table, including all 25 items and six
  new definitions. Preserve existing Blue prices; native acceptance is still pending.
