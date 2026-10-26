# Full-game execution ledger

Updated 2026-10-26. Follow [the full-game goal](../plans/full-game-goal.md).
[Earlier ledger and preserved failures](progress-history-before-divemac-20261026.md).

## 1. Accepted revision and playable scope

Component-accepted code is `b7897bd`, with Source
`2673b352e62b8e145b8a7e19b055db47479bc4f4100caf6f2835137ee85fe079`.
The implemented route remains Pallet → Brock. The complete all-starter campaign
proof below belongs to the preceding Source `44bd25…`; real-input preservation
checks on the new foundation Source are still pending. New regions remain private.
The remaining Kanto campaign, audio and release work are unfinished. Device
validation has not run. Local commits wait for an explicit request to push.

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

**5.2 — Scale foundations: in progress; components accepted, journeys pending.**

- [x] Loud unsupported-move failure and Whirlwind/Roar prepared.
- [x] Shared map manifest, loader, constructor, provider/cache, bindings,
  connections, actors and registered trainer dispatch prepared.
- [x] Declarative events, scripted NPC leases, source text/pagination and
  production builds without dev modules prepared.
- [x] Independent standards/spec reviews completed; concrete findings repaired.
- [x] Final repairs integrated: 1274 SDK contracts passed; all 2494 protected
  images exact. Five native phazing/failure scenarios passed; root inspected them.
- [ ] Native mechanics, real-input integration journeys, restart, blackout,
  full-bag retry and root screenshot inspection.
- [x] Production startup/memory comparison, coverage refresh, production compile,
  54 protocol checks and full host suite: 605 passed, zero skips.
- [ ] Merged-main checks and real-input milestone acceptance.

[Foundation component summary](foundation-acceptance-20261026.json) pins exact
evidence. Instrumented startup was 252 ms before, 202 ms with only dev gating,
and 150 ms integrated. Post-GC Lua heap was 10.85, 8.79 and 6.05 MiB respectively.
These are single Simulator observations, excluding native allocations/device limits.
Earlier failed SDK/scenario runs are retained and receive no acceptance credit.

## 3. Open defects blocking progress

No open defect blocks the accepted Brock path. Three long Charmander failures
are preserved. Native sampling exposed a startup e-list modal and 51.6 GB
physical footprint despite low RSS. With root-level `ShowElist=0` in the Simulator
ini, the full two-process retry passed. Observed footprint was 63–72 MB, peak
120.9 MB. The original ini is backed up under environment evidence; no signup
was submitted. This was an environment repair, not a game Source change.
Diagnostic capture sampling remains optional, default interval 1.

Foundation components passed; merged-main real-input preservation remains pending.
Later regions, common mechanics, audio and release checks remain unfinished.

## 4. Work in flight

| Branch / owner | Work and next step |
|---|---|
| `main` / root | GPT-6.1 Sol, medium effort; sole Simulator owner, integrator, validator and ledger owner. Brock accepted; run merged foundation checks and integration journeys. |
| `wip/foundations-integration` / root | Components composed and accepted through `b7897bd`; main integration and journeys are next. |
| `wip/source-map-activation-seams` / worker | Integrated with decoded-encounter, checkpoint-fixture and north-passage repairs; all native witnesses passed. |
| `wip/cerulean-map-content` / worker | `48943b7` prepares 18 maps and ordinary content/art/music metadata. Candidate manifest remains inactive. |
| `wip/cerulean-story` / worker | `f30515e` prepares Bill/Ticket, fossils and Misty; 22 native cases await composition. |
| `wip/audio-pipeline-research` / worker | `9a1cf87` research complete; root reproduced its silent probe. No playback acceptance. |
| `wip/audio-parser` / worker | `9c5ec44` complete: root ran 27 host tests and deterministic inspect; playback remains unimplemented. |

All workers explicitly use `gpt-6.1-sol`, medium effort, provider `codex`.
Earlier foundation workers are composed privately; exact commits/task IDs remain
in environment evidence at `brock-5.1-20261026-01/worker-tasks.json`.

## 5. Decisions since the user check-in

- Keep source identity, component acceptance and campaign acceptance separate.
- Preserve authored Pallet and all 2494 protected catalog images exactly.
- Use worktree branches and durable environment evidence; no new tarballs.
- Root independently accepts work and commits accepted steps to local main.
- Continue all campaign/postgame milestones; push only when explicitly asked.
