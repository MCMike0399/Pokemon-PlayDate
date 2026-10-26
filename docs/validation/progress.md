# Full-game execution ledger

Updated 2026-10-26. Follow [the full-game goal](../plans/full-game-goal.md).
[Earlier ledger and preserved failures](progress-history-before-divemac-20261026.md).

## 1. Accepted revision and playable scope

Accepted gameplay/tooling is `28d3f18`, followed by documentation checkpoints.
Production Source remains the tree committed in `82cb207`:
`44bd25bac9b1968cc8691eedc05ecd104faf708796602a492f997dccd1ae9ddc`.
A player can start with any starter, deliver Oak’s parcel, capture Pokémon,
use party/bag/storage/healing, cross Viridian Forest, defeat Brock, receive the
Boulder Badge and TM34, save, exit the process and Continue. The rest of Kanto,
audio and release work remain unfinished. Device validation has not run.
Accepted local commits wait for an explicit request to push.

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

**5.2 — Scale foundations: in progress; private implementation.**

- [x] Loud unsupported-move failure and Whirlwind/Roar prepared.
- [x] Shared map manifest, loader, constructor, provider/cache, bindings,
  connections, actors and registered trainer dispatch prepared.
- [x] Declarative events, scripted NPC leases, source text/pagination and
  production builds without dev modules prepared.
- [x] Independent standards/spec reviews completed; concrete findings repaired.
- [ ] Integrate final activation-seam repair and execute fresh SDK/catalog checks.
- [ ] Native mechanics, real-input integration journeys, restart, blackout,
  full-bag retry and root screenshot inspection.
- [ ] Startup/memory comparison, coverage refresh, full host suite without skips,
  merge acceptance and main commit.

Earlier private Source `4f26ba…` passed 1250 SDK contracts and all 2494 images.
That evidence does not qualify the newer candidate. On `9f3e37b`, 595 of 597 host
tests passed with zero skips; both failures are stale Source-bound coverage pins.
Refresh those only after fresh native evidence.

## 3. Open defects blocking progress

No open defect blocks the accepted Brock path. Three long Charmander failures
are preserved. Native sampling exposed a startup e-list modal and 51.6 GB
physical footprint despite low RSS. With root-level `ShowElist=0` in the Simulator
ini, the full two-process retry passed. Observed footprint was 63–72 MB, peak
120.9 MB. The original ini is backed up under environment evidence; no signup
was submitted. This was an environment repair, not a game Source change.
Diagnostic capture sampling remains optional, default interval 1.

Private foundation activation seams and native acceptance remain pending.
Later regions, common mechanics, audio and release checks remain unfinished.

## 4. Work in flight

| Branch / owner | Work and next step |
|---|---|
| `main` / root | GPT-6.1 Sol, medium effort; sole Simulator owner, integrator, validator and ledger owner. Brock accepted; continue foundation acceptance. |
| `wip/foundations-integration` / root | Durable environment worktree at `9f3e37b`; integrate `f925cd5`, register its SDK suite, then fresh native acceptance. |
| `wip/source-map-activation-seams` / worker | `f925cd5` repairs adapter/blocker/reciprocal-return seams; host/compile passed, eight SDK witnesses pending. |
| `wip/cerulean-map-content` / worker | `48943b7` prepares 18 maps and ordinary content/art/music metadata. Candidate manifest remains inactive. |
| `wip/cerulean-story` / worker | Preparing Bill/Ticket, Mt. Moon fossil choice and Misty reward scenes. |
| `wip/audio-pipeline-research` / worker | `9a1cf87` research complete; root reproduced its silent probe. No playback acceptance. |
| `wip/audio-parser` / worker | Preparing host parser/register traces; no production audio hooks. |

All workers explicitly use `gpt-6.1-sol`, medium effort, provider `codex`.
Earlier foundation workers are composed privately; exact commits/task IDs remain
in environment evidence at `brock-5.1-20261026-01/worker-tasks.json`.

## 5. Decisions since the user check-in

- Keep source identity, component acceptance and campaign acceptance separate.
- Preserve authored Pallet and all 2494 protected catalog images exactly.
- Use worktree branches and durable environment evidence; no new tarballs.
- Root independently accepts work and commits accepted steps to local main.
- Continue all campaign/postgame milestones; push only when explicitly asked.
