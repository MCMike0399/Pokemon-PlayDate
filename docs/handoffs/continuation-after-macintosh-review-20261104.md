# Continue Blue after the Macintosh work review

This is the current starting prompt. It supersedes the frontier and next-action
sections of the earlier November 4 handover; retain that long handover for the
product decisions, evidence locations and machine details. Continue the same
unfinished game, not another audit, infrastructure project or New Game run.

## Read and recover

Read `CLAUDE.md`, `docs/plans/full-game-goal.md`, current
`docs/validation/progress.md`, and `docs/reviews/macintosh-c-20261104.md` completely.
Then read `docs/handoffs/macintosh-20261104.md` for the full historical handoff.
Current goal: complete native original151 Pokémon Blue through credits and
postgame, Red/Blue world/story/art with GenV/B2W2 rules, abilities, held items and
natures. Preserve the approved GB tones, domain owners, modern QoL approvals,
real earned saves, source pins and honest hardware-playability claims.

Fetch origin from a clean checkout. Preserve any local changes before updating.
Accepted main remains **B149**, labelled **Simulator-accepted and hardware-safe;
device latency targets not yet met**. Main's new component `598f64d2` ports only
bounded named-contract dispatch and suite-aware evidence classification from
Macintosh, with Root correctness/readability adjustments. Its production B
runtime/data, art, Save/Continue owners and qualification pins are unchanged.
Use the actual current `origin/main` commit, including its review/host receipts.

The C candidate is already safely published:

```text
origin/pi/checkpoint-c-host-preparation
03c1bae4f465f17e3c00178681e34370c9695c3e
```

It contains all prior C171 work plus the six Macintosh commits:
`de997823`, `a10f6d33`, `873c73cf`, `5b9f4c2e`, `0abbde1e`, `03c1bae4`.
At review, main `ff598ced` was9 commits ahead of their merge-base and C was44 ahead;
the six-commit Macintosh diff is32 files, not the entire C preparation. Main is
now additionally ahead by the independent named-contract component/docs.
Do not fast-forward main to this candidate, force-push it to main, or merge all
909differing files merely to make it portable. C remains **unaccepted**.

Use the active tool to create/select ONE isolated worktree from that remote
branch. The old DiveMac isolated branch `t3/checkpoint-c-host-preparation` was
fast-forwarded to03c1bae4 for review, but is not a new runtime owner. Original
Macintosh work and all unmerged branches remain preserved in Git/bundle.
Merge current main into C carefully when appropriate: retain C171 data and
qualification, the source/elevator fixes and its owner implementation. Keep
main's early unknown-suite rejection and no-argument contract behavior. Do not
replace C pins with B149 pins or rewrite any old proof to remove a conflict.

## First fix: the review's real adoption blockers

The source-backed Fuji visibility fix is correct: Saffron actor14 is visible
only before Fuji rescue and before Silph clear; actor15 only after rescue and
before clear. The elevator's single guarded callback fixes the stale confirm
serial. The persisted-cabin projection matches the runtime resolver. Keep those
fixes, original coordinates/art/warps/flags and genuine progress.

The actor compatibility implementation has three concrete defects; resolve them
on C **before more earned journey acceptance**:

1. `WorldMotionData.normalize` validates coordinate/facing/timer/phase values
   only for visible actors. A known hidden actor with only `{id=...}` or bad
   fields is currently silently dropped. Fully validate required structure,
   types/ranges and intrinsic motion consistency before pruning. Keep checks
   that require a current live reservation/surface separate from structural
   checks so a legitimate historical hidden actor can still migrate.
2. `GameSession._validateActors` removes the entire actor list/count from its
   retained-field check. Custom validators can consequently discard visible
   actors or retained fields. Permit only independently proven hidden-ID
   removals; preserve surviving actor records exactly; prohibit additions,
   arbitrary deletion and wrong counts; use fresh world/location/flags.
3. `HarnessDiagnostics.actorVisibilityMigration` masks both actor lists then
   compares only surviving IDs. It can conceal a changed surviving pose, and
   reports `roundtrip_equal=true` after detecting unequal payloads. Keep raw
   selected-slot identity/sequence and canonical migrated state distinct.
   Literal equality must be truthful. Prove the precise permitted migration and
   reject any surviving-record change or unintended fallback slot.

Add meaningful native rejection cases for malformed hidden records, duplicate/
unknown IDs, deletion by custom callbacks, survivor-field loss/mutation, wrong
counts and stale dependency context. Preserve successful genuine historical
migration and current owner immutability. Do not weaken prior assertions to make
the new cases pass. Expand the newly dense Lua callbacks/loops in the same pass.
The independent reviews report overlapping validation findings at different
severities; read their separate Standards and Spec text, not a flattened count.

After changing owners, obtain fresh real SDK exports/qualification and targeted
native regressions through the established pipeline. Prior export bytes and
failed runs stay unchanged. Do not merely rehash old SDK proof or treat the
already-passing positive migration case as coverage of malformed inputs.

## Exact earned frontier: resume the cabin, not older Saffron

Squirtle's latest genuine Save is:

```text
/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/checkpoint-c-saffron-fuji-pilot-20261104-12/01-midgame--restart-55c-squirtle/processes/0001/partial-save.json
SHA256 2204733359f2332c9dd844742cd4d15f457692b880df268e4802ccb15917931b
```

It is inside `pokered:SILPH_CO_ELEVATOR`, `(7,1,right)`, with exactly
`SILPH_STORY_LIFT_V1_1=true`; other floor flags are false. Only
`saffron-guard-entry` is complete. Both raw slot hashes are:

- a: `6a20c09e07b1a8e0f1bb40a0d1532aef077c961b4af91b757103a78dbca556b8`
- b: `00f2d64bb333b19225bacec688d657bc9e2385ac175c881b8673b78ffcce927a`

Use `docs/handoffs/resume-55c-squirtle-silph-cabin-20261104.json` with the
existing guarded runner, a NEW output directory and the actual candidate
checkout/helper hash. Verify the stopped producer, exact archived slots and
original accepted-B ancestry through the existing importer first. This Save is
on Macintosh, where the pilot ran; do not assume the identical absolute path is
hydrated on DiveMac. Hydrate exact dependencies if you change runtime hosts;
never rewrite frozen paths/hashes or use an ARCHIVED stub as input.

Record16 (`ac21...`) and pilot 11 (`64f69...`) remain historical recovery points.
Do not default to those earlier records, restart the route, re-buy the guard
drink, grind again, reset flags or manufacture a fixture. Pilot12 and later
journeys remain failed despite their resumable real Saves. No Silph completion,
rival/Giovanni/Lapras/Sabrina/Dojo/Fly/Copycat acceptance is claimed.

Native-14 has106 total passes:20 common cases and86 Saffron cases, not106 distinct
Saffron cases. Root checked the referenced result/build hashes and five staged
production/test files against the candidate. The native elevator test covers
floor 2, one exit and cancellation. Add bounded coverage of all 11 floors/both
exits, persisted-cabin resume and relevant rollback; don't infer those from it.

## Resolve the runtime gate without another infrastructure detour

The candidate reports C's unqualified deep harness boot reaching roughly900 MB
and then the unchanged1 GiB host ceiling. It also records a much smaller qualified
production observation. This is a diagnosis, not exhaustive attribution or
authority to skip validation. Main's full-contract B149 probe also hit1 GiB in
Root's review; that is a DIFFERENT profile from B149 journeys, so don't conflate
the numbers. Its failed outcome and owned cleanup are retained.

`ShippedDataPolicy` intentionally requires `HarnessBuild == nil` for the qualified
lazy content path. A qualified stage followed by a harness overlay therefore
still selects deep loading. The attempted `--qualified-stage` experiment was
reverted; don't claim it exists or retry it as a solution.

Optimizing redundant copies/allocations and validation organization **while
preserving all deep checks** is already authorized by the original goal. Start
with source-backed allocation analysis and bounded measurements of the existing
path; this does not require asking the user to choose a policy override first.
Do not raise the host guard, alter the pool, bypass the harness trust fence or
omit validators without an explicit new user decision. No new history tooling
or resurrected door census. If a hard limit trips, preserve/report the failure
and continue independent source work rather than repeat the same pilot.

Once corrected and admitted, resume ONE cabin pilot, then the three-starter
earned two-process sequence. Hardware is on DiveMac, not Macintosh; re-detect
actual connection and acquire its existing fences. No simultaneous SDK owner or
duplicate campaign. Native/resource evidence never substitutes for visuals.
At this review no DiveMac `/dev/cu.usbmodemPD*` port was present. Hardware work
therefore needs the device reconnected; continue independent source/host work
until then rather than inventing a physical run or blocking the whole project.

Keep the parallel playability work from reviewer 8: at least 30 physical doors
with shipped-equivalent GC and `memory.soft` clock/before/after/duration/walking
marks; correlate B3's hitches. Then a paired black-hold collection candidate if
supported, >=10% in its declared phase, guards unchanged. Next attribute store
read/checksum/JSON/deep validation/construction and the remaining Surf-Save cost.
Do not abandon C content while working these phases. The latency bar still gates
C acceptance; B memory already cleared its prerequisite. All earlier rejected
atlas/compact-terrain/door-tier/title-split/census experiments stay rejected.

## Tooling and evidence boundaries

The new main named-contract API preserves all20 common tests, then selects the
explicit registered suite. No-argument runs retain all registered suites/order.
Catalog/field qualifiers now require their own requested suite, not any unrelated
named run. Root's guarded API probe passes21 selected/22 aggregate checks with
dispatch sentinels and unknown-suite/RNG preservation. It boots qualified
production and then runs the API/core cases; it is **not** a full harness,
untrusted C content, journey or performance qualification. Do not use that small
host footprint to waive the earned-journey deep path.

The new Swift helper and `JourneyHistory` reply changes remain only on C.
Accepted main lacks that JourneyHistory owner, so a lone restarting hunk is not
an independent port. Preserve matching source/binary/helper/consumer identities
and native qualification before reuse. The C receipt records helper source
`c532a89f0885f8158e071281187e56af07f2e45f5b7b957f2ee34401335ecb32`,
binary `46c2bd90cd883ea3af9d7e2928f6a8dc6ae9cb545d8774a3668b3c43dfb2fa8f`.
Verify actual files and current AX trust; a historical grant isn't current proof.

Keep **31 GiB admission/30 GiB reserve,16 MiB Simulator pool,1 GiB host hard stop,
736 MiB Clear trigger,64 Clears/131 helper calls per generation,6/8/9 MiB Lua guards**,
command/progress/overall deadlines and exact owner/PDX/source identities.
Preserve schema 4, epoch 19 main and original inverse policies. Telekinesis937c1382
and selected-slot1952 remain separately unadopted with their native/measurement
requirements in the long handover. Before Sabrina acceptance, qualify the three
actual Telekinesis trainer exposures; a loudly unsupported move is a real gap,
not something a successful route automatically qualifies. Audio remains held. Never relax typed SDK
JSON equality or silently replace an untrusted-load validation boundary.

Storage is background exception-only. No new inventories, compression or broad
cleanup unless actual capacity blocks primary work. Both requested Brock roots
are safely archived; keep acceptance references, chains, newest failures, current
inputs and active state. Use only the existing qualified wrapper/fences for
eligible closed paths. Do not treat the100 GiB maintenance target as an admission
requirement; the user's runtime reserve is30/31 GiB.

## Persistence and finish line

Create your own local persistent goal/plan for this continuation. Old app goals,
task IDs, delegates, PIDs and wakeups are not transferred; don't revive an old
session on DiveMac. Read-only reference/bootstrap inputs are already on Macintosh
from the reviewed handoff. Recheck volatile runtime state before starting work.

Use Sol as root; explicitly requested workers are gpt-6.1-sol/medium in
tool-managed isolated worktrees. Root alone integrates and validates SDK/device
work. Fix real defects, keep existing assertions, and record exact evidence scope.
Report terminal results/new failures/device numbers without polling filler.
End a turn about every 2 hours with a short ledger update; don't abandon the goal.

Commit accepted work locally. This review's main push is explicitly authorized;
**future pushes need a new request**. C only merges after its actual earned,
restart, visual, hardware, memory and latency gates. Continue then through 5.6
and 5.7, credits and postgame; do not call B, a memory fix or this handoff the goal.
