# Full-game execution ledger

Updated 2026-10-28. Follow [the goal](../plans/full-game-goal.md).
Progress: **65 / 222 source maps playable on main. Current checkpoint: 5.5a.**
5.4 elapsed: **8.70 h**; pace: **96.55 maps/day**.
5.5a elapsed so far: **1.76 h**; accepted new maps/day: **0**.

[Milestone times](milestone-times.json) include waits and provider limits.

## 1. Current game on main

Gameplay code: `1a4a7894aa40125147e8f2d227fd1da6320dd341`.
The approved display update is `a6298a6`. Current Source: `7dded0135055be1edd14035a192a65770feb4126516243501303d8c6e4cb1930`.
The three journeys used gameplay Source `3ac88fe4dad4d0b1f5624a6f3eac025ac8814cb57fc14a4b3e7eb7cb34ca628d`; the display update changes rendering only.

Players can continue an earned Cerulean save, cross Routes5/6 and the Underground
Path, use Day Care and the Fan Club, explore every Anne cabin, beat the rival,
receive Cut, beat Surge, cross Diglett's Cave and receive Flash. All three starters
passed an actual process exit and Continue at the Flash aide. The required route
already visited Route11; a compulsory second cave crossing was removed.

The 5.4 game code is on main. Milestone 5.4 is accepted. Production bundles with earned saves and an 84.9-second
real-speed native showcase are delivered outside Git. Later
Kanto, the League, postgame and device release remain unfinished. Nothing pushed.

## 2. Milestones and evidence

| Milestone | Status | Wall clock | Evidence |
|---|---|---:|---|
| 5.0 DiveMac setup | Done | 0.13 h | [Setup](divemac-baseline-20261026.json): smoke, 529 host, 1091 SDK, 2494 images |
| 5.1 Pallet to Brock | Done | 5.62 h | [Brock](brock-acceptance-20261026.json): three starters, rewards, restart, blackout and evolution |
| 5.2 Shared foundations | Done | 1.79 h | [Foundations](foundation-acceptance-20261026.json): 605 host, 1274 SDK and preserved art |
| 5.3 Cerulean, Misty and Bill | Done | 37.35 h | [Cerulean](cerulean-acceptance-20261028.json): three chained saves, 723 host, 1666 SDK; scope limits retained |
| 5.4 Vermilion and HMs | Accepted | 8.70 h | [Vermilion](vermilion-acceptance-20261028.json): 918 host, 2077 SDK, all 2494 images exact |

All three 5.4 journeys began from accepted Cerulean saves, preserving actual
progress across tooling retries. Final runs are
`evidence/m54-progress-retry-<starter>-20261028-09`. Their full save ancestry was
hash-verified in `evidence/m54-save-ancestry-20261028.json`. Earlier failed outcomes
remain failures; completed optional actions in those runs are linked separately.
Bulbasaur covers optional content; Charmander and Squirtle cover the critical path.
No preparation grinding was added. Final logs contain no missing move/ability hits.

Actual slots are outside Git at `evidence/chain/5.4/<starter>`.
Only [hashes and provenance](chain-saves.json) belong in Git.

## 3. Play quality on main

Main uses the approved GB-tone conversion: LIGHT 31.25% black, DARK 68.75%,
with fixed phase. Pallet, its interiors and character pixels are unchanged.
The 186 approved imported-terrain images were updated; the other 2308 stayed exact.
[The approval manifest](gb-tone-approved-images-20261028.json) records the scope.
The final main build passed 2090 SDK checks, 918 host checks and actual process
Continue for every starter. Running, text speed, Options, battle presentation,
crank controls, Town Map registration, Bag sorting and reusable TMs are on main.
Audio remains separate and unaccepted: the first native recording was silent.

## 4. Checkpoint 5.5a in progress

The next acceptance is Rock Tunnel, Lavender and Celadon, including Erika,
Game Corner, Hideout and the Silph Scope. It will have three earned saves from
5.4 and merge to main separately. Tower/Fuji/Flute/Snorlax/Cycling Road/Fuchsia/
Safari/Koga/Surf/Strength form 5.5b; Saffron/Silph/Sabrina/Dojo/Fly form 5.5c.
Each starts from the prior checkpoint's earned saves. Later prepared work must
stay separate from the 5.5a release. The complete private candidate is retained
on `parked/midgame-b-c-before-55a-20261028`; derive the release with East maps only. Main remains **65/222**; the East package
contains 43 new maps, so the planned 5.5a frontier is 108/222, not yet accepted.

Private `wip/midgame-integration` now activates only **108 candidate maps**.
The complete later candidate stays parked. The production build excludes South/
Saffron data and future controllers. Its 14 shared-map host checks pass.
Its latest completed SDK run passed **2331 checks, zero failures** at
`evidence/m55-scenes-sdk-20261028-02`. Later source-encounter and field-gear
additions compile but still need native checks. The prior native catalog exported
8726 images with all 2494 protected images exact. New field art remains unreviewed.

The first east journey sets stopped on two missing harness registrations, then
an unnecessary early trip to Pewter to make room for later Lapras. Those failed
runs remain failures. The early Lapras detour is removed; the next partial set is
`evidence/m55a-east-chains-20261028-05`. The previous set reached Cerulean
but lacked a party member that can learn Flash. The driver now checks earned PC
Pokémon; if none can use Flash, its fixed route keeps the tunnel dark rather than
inventing a helper or grinding. No planner feature or
training fight was added. Preserve partial earned slots from actual later runs.
Charmander covers optional content; Bulbasaur and Squirtle cover the critical path.

Three Sol/medium workers are active: Celadon services for 5.5a, Safari runtime
for 5.5b, and source water travel for 5.5b. Root owns the Simulator and acceptance.
All reports and briefs must use normal words and spacing. Technical worker
questions go to root; three old invisible questions were answered and cleared.

At every acceptance, record production Simulator post-GC Lua heap and worst
map-load/battle-start frame time. The accepted 5.4 build was copied to the physical Playdate and launched by USB.
All 495 payload files match; 522 macOS metadata files are excluded from that count.
`evidence/device-main-verification-20261028-01/comparison.json` records the check.
Runtime/title feedback and physical memory measurements remain unverified.
The data disk mounted slowly; main now allows 90 seconds for deployment mount.
After 5.5a, accept the smallest audible town/route/battle/cry path on main.
The native audio probe reports system volume **0**; listening waits for its slider,
while game work continues. At each checkpoint, ask once whether to push.

## 5. Housekeeping and decisions

Eleven stale queued notifications (old runs 31–45) were cancelled. Only current
work notifications should resume this thread. Acceptance cleanup must retain
referenced runs, earned saves and hashes, plus the newest checkpoint failure;
remove compile-only and superseded bundles and report freed GB.

At least 94 clean superseded worktrees were removed without force; branches and
dirty worktrees remain. Two evidence cleanup passes freed **16.13 GB**, retaining
acceptance references and current failures. The second pass removed 57 compile-only
bundles; `evidence/cleanup-20261028/second-pass-result.json` records them.

Both journey JSON files live under `Source/dev`, outside production. The 36,141-line
field-reference dump was removed; its 57 inputs regenerate outside Git from the
unchanged checksum manifest. The approved museum and Route2 collision updates
remain recorded. Crank scrolling, registered A+B, manual Bag sorting and reusable
Gen V TMs were explicitly approved; do not ask those policy questions again.

Commit locally. Push only when asked. The full-game goal is still active.

Production packages: `/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/player-packages/5.4-playable-20261028`. Double-click the starter’s `Play.command`
and choose CONTINUE. Normal saves are untouched.

Showcase: `/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence/milestone-5.4-showcase-20261028/PokemonBlue-5.4-showcase.mp4`
(84.9 seconds, original native frame timing, clearly labelled supplemental scenes, silent).
Final-build checks: 2090 SDK, 918 host, all three actual process continuations.
Audio remains unaccepted; the full-game goal is unfinished. Nothing pushed.

## Device startup check — 2026-10-28

Progress remains **65/222 playable maps on main; current checkpoint 5.5a**.
The physical Playdate still requested a restart after the first startup fix.
Its error log identified a ten-second startup stall while validating world data.
Main now validates sparse changes without rebuilding every map cell, and the next
build separates context setup from initial loading with a visible loading screen.
The revised loading build passed 2090 SDK checks, 54 harness host checks and all
2494 protected image comparisons in
`evidence/device-loading-fix-sdk-20261028-01`. It has not yet been tested on the device.

The production Simulator resource check at
`evidence/device-deferred-context-resources-20261028-01/startup-probe.json`
measured 10696.66 KiB Lua heap after GC at the earned checkpoint,
11420.60 KiB after map loading and 11432.33 KiB after battle start.
Worst measured updates were 170 ms for the selected map load and 5 ms for battle
start. These include observer overhead and do not measure physical-device RAM.
The three private 5.5a journeys stopped before meaningful gameplay; they grant
no acceptance. Their tooling failures are being repaired separately.

## Checkpoint 5.5a checks — 2026-10-28

Progress: **65/222 playable maps on main; current checkpoint 5.5a**. The private
build contains 108 candidate maps. It has not been accepted.
The loading-stage merge passed **2271 SDK checks, zero failures** in
`evidence/m55a-loading-merge-sdk-20261028-01`. The production bundle excludes
South/Saffron packages and journey data; the file audit is
`evidence/m55a-production-scope-20261028.json`.

The full host run completed 947 tests with 16 failures and seven errors in
`evidence/m55a-current-host-20261028-01.log`. Several checks still assume the
65-map inventory; the shared fixture setup is being updated while preserving
checks for the original maps. Regenerating the development journey data for
current save format 4 cleared all 46 related acquisition/journey host checks.

Squirtle's earlier retry pressed B before the healing-dialogue input had been
released. The driver now waits one neutral frame and retains its pause assertion.
The next three-starter set is `evidence/m55a-loading-chains-20261028-02`; it is
not acceptance evidence until every required journey and process Continue passes.
Elapsed checkpoint time and maps/day remain tracked in milestone-times.json;
accepted new maps/day is zero until these saves are earned and accepted.
