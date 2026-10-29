# Full-game execution ledger

Updated 2026-10-29. Follow [the goal](../plans/full-game-goal.md).
Progress: **0/222 maps verified playable on Playdate hardware; 65/222 route-verified in Simulator. Current checkpoint: 5.5a, frozen for P0 device boot.**
Last accepted Simulator milestone, 5.4: **7.89 h**, **106.46 maps/day**.
P0 elapsed since the first guarded trace commit: **7.15 h**; hardware pace: **0 maps/day**.
[Milestone times](milestone-times.json) include waits and provider limits.

## 1. Current game on main — not yet playable on Playdate hardware

Simulator-accepted 5.4 baseline code: `1a4a7894aa40125147e8f2d227fd1da6320dd341`.
The approved display update is `a6298a6`. That baseline Source: `7dded0135055be1edd14035a192a65770feb4126516243501303d8c6e4cb1930`.
The three journeys used gameplay Source `3ac88fe4dad4d0b1f5624a6f3eac025ac8814cb57fc14a4b3e7eb7cb34ca628d`; the display update changes rendering only.

Players can continue an earned Cerulean save, cross Routes5/6 and the Underground
Path, use Day Care and the Fan Club, explore every Anne cabin, beat the rival,
receive Cut, beat Surge, cross Diglett's Cave and receive Flash. All three starters
passed an actual process exit and Continue at the Flash aide. The required route
already visited Route11; a compulsory second cave crossing was removed.

The 5.4 game code is on main. Milestone 5.4 is accepted. Production bundles with earned saves and an 84.9-second
real-speed native showcase are delivered outside Git. Later
Kanto, the League, postgame and device release remain unfinished. Nothing pushed.

## Hardware gate — P0, 2026-10-28

The game has never reached its title on the physical Playdate. Milestone 5.4's
acceptance and delivered bundles were Simulator results only. They do not prove
hardware playability. The loading-stage build also requested a restart; its
latest error log must be collected before choosing the next fix. The trainer
lookup change has passed Simulator checks but has not been transferred.

New map/region integration is frozen on main and checkpoint A. Root attention
is limited to exact-build device logs, persistent phase tracing, measured timing,
time slicing and memory. Audio, cleanup and Safari polish are paused. The cleanup
process was stopped; any partial deletion will be audited before reporting space.

Initial memory targets are at most 6 MB live Lua heap at title and earned Continue,
and 9 MB observed before GC during map load and battle start, subject to actual
hardware measurements. Device warp/map load and battle start must be at most
0.5 seconds. Slice and frame budgets must use a measured Simulator/device factor.
A hardware acceptance row requires title, earned Continue, warp, battle start and
save, no new errorlog entry, and trace timings/heap within budget. Until then:
**not yet playable on Playdate hardware**.

### Overnight device preparation

Progress remains **0/222 maps verified on hardware; 65/222 route-verified in
Simulator. Checkpoint 5.5a remains frozen.** The calibration app completed on the
Playdate without a new error log. USB print output and message callbacks work,
and the Simulator starts with the healthy device connected when serial readers
are closed. The app remains awake for unattended control.

Exact calibration payload SHA256:
`dddd464c0c8cc9018b865d44c81103ff689de334a4a7cc91cb0c5120c1028168`.
Evidence: `evidence/p0-calibration-device-cycle-20261028-03` and
`evidence/p0-calibration-simulator-16mb-20261028-01`. Synthetic workloads measured
16.28–17.25 times slower execution on the device; a conservative factor of 35.11
is provisional guidance, not a game performance result.

The failed game's logs were archived before deployment. Its later stalls were
in tile preparation and map bindings, after earlier world-validation and trainer
copying stalls. No new Pokémon game build has been sent to the device yet.

The guarded 65-map Simulator build now loads the earned Flash save, crosses an
actual door and starts a supplemental battle in the verified 16 MB pool.
`evidence/p0-shared-images-profile-16mb-20261028-21` measured 6130.87 KiB after
Continue, 6889.86 KiB after the door and 6903.55 KiB after battle start; observed
peak 7616.09 KiB. These are Lua heap measurements, excluding native image memory.
Loading time remains over budget. The observer's old update duration included
coroutine suspension; it cannot establish CPU slice timing. Rendering and
loading measurements are still being corrected before hardware deployment.

### Exact private game smoke

Progress remains **0/222 hardware-verified maps; 65/222 route-verified in
Simulator. Current checkpoint: 5.5a, frozen.** The physical device still runs
only the safe calibration app; no further Pokémon build has been deployed.

The exact private build `a8b235b94dc34e0390106a283992ce9a` reached its title,
loaded the accepted Charmander Flash save through real buttons, published a save
and crossed the north Route 2 Gate door. Evidence:
`evidence/p0-exact-game-smoke-20261028-04`, with the unchanged compiled bundle in
`evidence/p0-exact-game-smoke-build-20261028-04`. Lua heap after Continue was
6108.54 KiB; sampled peak was below 9 MiB. An earlier actual SAVE exceeded the
memory ceiling; saving now uses cooperative loading and more frequent GC.

This smoke **failed** the performance gate and has not started a battle. The
map-load span was 343 ms in Simulator, including loading yields; the worst active
slice was 66.10 ms. These are distinct measurements. The small test build uses
one private module and the SDK high-resolution elapsed clock. Loading slices
have the 1-second device ceiling; ordinary gameplay frames have the 33 ms target.
The conservative synthetic factor remains provisional. Nothing is accepted on
hardware from these results.

Existing SDK checks run separately in the 16 MB pool: 20 map cases passed in
`evidence/p0-map-contracts-16mb-20261028-02`, and 16 save cases passed in
`evidence/p0-save-contracts-16mb-20261028-01`. All 526 authored/imported tile pairs
matched pixels in `evidence/p0-render-pixels-20261028-01/comparison.json`.
Generated runtime files reconstruct all 65 original maps exactly; original
map inputs, source grids and protected image baselines remain unchanged.

The next real-input run reached a wild Diglett battle after Cut and the cave
entrance: `evidence/p0-exact-game-smoke-20261028-07`, exact build
`3f5dbee94fff4c3d886691854fe0b4ce`. Title, earned Continue, verified save, doors
and battle start were observed. Battle start took 4 ms in Simulator; the sampled
peak was 8.48 MiB. Map-load, ordinary-frame and slice timing still failed, so
this remains a failed gate and no hardware deployment was attempted.

Archive discovery now uses fresh directory listings instead of probing absent
files. The existing 16 save SDK cases passed with that change in
`evidence/p0-save-contracts-16mb-20261028-02`; Lupa tests from the worker were
excluded. The native view rollback case passed in
`evidence/p0-view-contracts-16mb-20261028-01`. Progress is still **0/222 on
hardware, 65/222 in Simulator; checkpoint 5.5a remains frozen**.

### Hardware preparation, 2026-10-29

Progress: **0/222 maps verified on hardware; 65/222 route-verified in Simulator.
Checkpoint 5.5a remains frozen.** Lazy content loading reduced post-Continue Lua
heap to about 5.03 MiB. The exact real-input run in
`evidence/p0-exact-game-smoke-20261029-01` still reached save, doors, Cut and a
wild battle without a runtime error. Its map, frame and slice estimates fail;
no hardware game build was deployed. The calibration app remains the only
successful hardware run.

Cut diagnosis found an unnecessary full-atlas load and whole-map actor surfaces.
Skipping known tile keys and reading actor cells on demand reduced the measured
commit from 80 ms to 35 ms with temporary probes present. Those probes are removed.
World validation now avoids allocating apply plans it never uses. Field snapshot
checks compare unchanged records cheaply and retain full validation at commit.
Cooperative field publication holds the last animation image instead of exposing
an intermediate world. These changes still need the next exact smoke measurement.

Current SDK evidence in the 16 MB pool: 16 field cases in
`evidence/p0-field-contracts-16mb-20261029-02`, 16 world cases in
`evidence/p0-world-contracts-16mb-20261029-01`, 8 generic actor cases in
`evidence/p0-generic-actor-contracts-16mb-20261029-01`, and native wall coverage/
rollback in `evidence/p0-view-contracts-16mb-20261028-04`. Focused host checks:
43 passed in `evidence/p0-integrated-focused-host-20261029-01.log`. The full host
run had 941 tests, 12 failures and 5 errors; stale projections, generator inventories,
old renderer checks and protocol fixtures remain to fix. Coverage is stale.

The full development contract run
`evidence/p0-lazy-content-full-sdk-20261028-03` ran out of memory after reaching
its save/recovery suites. It is a failure, not accepted SDK evidence. Further
existing suites will run in smaller production-based batches without enlarging
the Simulator memory pool. No protected image baseline changed. Nothing pushed.

### Protected catalog and current gate, 2026-10-29

Progress remains **0/222 hardware-verified maps; 65/222 route-verified in
Simulator. Checkpoint 5.5a is frozen.** All 2,494 protected images match exactly
in `evidence/p0-protected-catalog-16mb-20261029-01/comparison.json`, assembled
from separate successful legacy (1,635) and Pewter (859) exports under the 16 MB
pool. The aggregate records both source builds and every image hash; it is not
a single-runtime or hardware acceptance claim. Larger export attempts failed
memory checks and remain failures. No baseline changed.

The lower-copy constructor passed the existing world SDK cases. The extended
registry case checks immutable prepared snapshots, forged/foreign handles,
conflicts before publication, rollback and reuse: 16 cases passed in
`evidence/p0-world-contracts-16mb-20261029-03`. Save listing now preserves read
errors for directory names matching archive files: the existing case went red
and then all 16 cases passed in `evidence/p0-save-archive-directory-green-20261029-01`.
The 37 Vermilion generation checks pass; only current generator hashes changed.
Historical acceptance and evidence identities were not rewritten.

The guarded hardware replay tooling is integrated, including exact-build proof
checks and metrics. Its 33 host checks pass. It must reject the current failed
Simulator proof before any device access. The exact game run
`evidence/p0-exact-game-smoke-20261029-03` still fails frame, slice and predicted
map latency. A temporary diagnostic found sub-millisecond game updates at many
command completions despite much larger outer timing spans; the discrepancy
requires review before hardware admission. Temporary probes were removed.
No new game hardware attempt and no push occurred.

### Encounter-step performance, 2026-10-29

Progress remains **0/222 maps verified on hardware; 65/222 route-verified in
Simulator; checkpoint 5.5a frozen**. Independent review showed that recurring
spikes belonged to the update after a movement completion, when encounter
processing runs, rather than to the completion reply. The reviewed code then
encoded all six party members repeatedly during each attempt. Unchanged field
reads now reuse private validated snapshots; changed values and save encoding
still take the full validation path. World-hook entries without a callback no
longer repeat context checks. No RNG draw order or encounter rates changed.

Existing SDK results: 18 encounter cases in
`evidence/p0-encounter-contracts-16mb-20261029-01`; 21 specimen cases, including
snapshot isolation and invalid-value rejection, in
`evidence/p0-specimen-contracts-16mb-20261029-03`; 15 acquisition cases in
`evidence/p0-acquisition-contracts-16mb-20261029-01`; and 64 event cases in
`evidence/p0-source-event-contracts-16mb-20261029-01`. The preceding full host run
completed 960 tests: 959 passed, with the stale coverage snapshot as its only
failure. Coverage was not relabeled.

A supplemental backend profile is retained at
`evidence/p0-encounter-profile-20261029-01`: warm snapshot reads averaged 0.027 ms,
versus 0.217 ms for a full lead encoding; prepare/resolve averaged 2.07 ms. This
is not a gameplay or hardware timing pass. The exact route still failed timing
in `evidence/p0-exact-game-smoke-20261029-05`; no new hardware attempt or push.

### Remaining loading costs, 2026-10-29

Progress: **0/222 maps verified on hardware; 65/222 route-verified in Simulator.
Checkpoint 5.5a remains frozen.** The latest exact private build is
`26f1123b02144acd89ffe2f7c74af27c`, retained in
`evidence/p0-exact-game-smoke-build-20261029-10`. Its real-input run at
`evidence/p0-exact-game-smoke-20261029-10` reached title, earned Continue, save,
doors, Cut and a wild battle without a runtime error. It still fails the timing
gate: worst ordinary update 14.376 ms, worst slice 46 ms, worst map-load wall
span 363 ms. The provisional factor predicts 4.76 seconds for that map span;
this is not a hardware measurement. Lua heap was 5.06 MiB live and 5.96 MiB at
sampled peak. No game build was sent to the device.

Encounter requests retain immutable private snapshots instead of copying all
six records. Map construction validates tile IDs and collision in one pass and
reuses matching registry records; publication still checks conflicts. Field
freshness reads compare session values without cloning them, and Cut reads the
shared effect data while the public getter still returns copies. The full-route
results do not establish a map latency improvement.

Existing SDK checks passed under the 16 MB pool: 18 encounter cases in
`evidence/p0-encounter-contracts-16mb-20261029-02`, 16 world cases in
`evidence/p0-world-contracts-16mb-20261029-07`, and 16 field cases in
`evidence/p0-field-contracts-16mb-20261029-04`. The focused host groups passed
33 map checks, 45 device/field checks and 27 field/map checks; these groups
overlap. No new behavior contracts were added. Temporary private timing builds
at `evidence/p0-step-cost-20261029-01` and `-02` are supplemental diagnosis,
not hardware admission. They locate first-use Cut costs in terrain planning
and effect preparation. Main contains none of those temporary probes.

## 2. Milestones and evidence

| Milestone | Status | Wall clock | Evidence | Hardware result |
|---|---|---:|---|---|
| 5.0 DiveMac setup | Done | 0.13 h | [Setup](divemac-baseline-20261026.json): smoke, 529 host, 1091 SDK, 2494 images | Not tested on hardware. |
| 5.1 Pallet to Brock | Done | 5.62 h | [Brock](brock-acceptance-20261026.json): three starters, rewards, restart, blackout and evolution | Not tested on hardware. |
| 5.2 Shared foundations | Done | 1.79 h | [Foundations](foundation-acceptance-20261026.json): 605 host, 1274 SDK and preserved art | Not tested on hardware. |
| 5.3 Cerulean, Misty and Bill | Done | 37.35 h | [Cerulean](cerulean-acceptance-20261028.json): three chained saves, 723 host, 1666 SDK; scope limits retained | Not tested on hardware. |
| 5.4 Vermilion and HMs | Accepted | 7.89 h | [Vermilion](vermilion-acceptance-20261028.json): 918 host, 2077 SDK, all 2494 images exact | Title fails; Continue/warp/battle/save unverified. Not yet playable on Playdate hardware. |

All three 5.4 journeys began from accepted Cerulean saves, preserving actual
progress across tooling retries. Final runs are
`evidence/m54-progress-retry-<starter>-20261028-09`. Their full save ancestry was
hash-verified in `evidence/m54-save-ancestry-20261028.json`. Earlier failed outcomes
remain failures; completed optional actions in those runs are linked separately.
Bulbasaur covers optional content; Charmander and Squirtle cover the critical path.
No preparation grinding was added. Final logs contain no missing move/ability hits.

Actual slots are outside Git at `evidence/chain/5.4/<starter>`.
Only [hashes and provenance](chain-saves.json) belong in Git.

## 3. Play quality, separate from the game above

The user rejected whitening and chose the original GB grey tones as the target.
Main now uses the closest measured Bayer conversion: LIGHT 31.25% black,
DARK 68.75%, fixed phase. Pallet, its interiors and character pixels stay unchanged.
Native walking: `evidence/gb-tone-native-clip-20261028-02/native-proposed-motion.mp4`.

`wip/play-quality-native` passed 2090 SDK checks at
`evidence/play-quality-sdk-20261028-04`. The four new QoL behavior cases passed.
Its catalog changed only 186 approved imported-terrain images; 2308 stayed exact.
[The image-approval manifest](gb-tone-approved-images-20261028.json) records the update. Ship/Cut background calls were subsequently made consistent and need the
next native rerun before publication.

Actual input checks in `evidence/quality-input-native-20261028-03` verified the
fresh title, Town Map registration, A+B and manual Bag sorting using a clearly
labelled test inventory. Crank controls and reusable TMs have native contracts;
further input/motion review remains. Text speed, running, battle presentation and
music are implemented privately. Audio loading/listening and cries remain separate
from campaign acceptance. No unverified quality code has been released on main.

Production preview bundles exist at
`evidence/player-packages/quality-preview-20261028`, but remain unpublished and
must be rebuilt from the final reviewed code. Supplemental battle/learning/evolution
recipes and an actual-window recorder are ready; they are not natural journey proof.

## 4. Remaining work and order

5.4 is accepted. Begin 5.5 from the earned Flash saves. Verified display and
non-audio QoL changes are on main. NPC trades and Saffron guards are preserved on
`parked/npc-trades-saffron-20261028` and excluded from this 5.4 game. Pickup stays.
Workers use GPT-6.1 Sol at medium effort; root alone controls the Simulator.

Keep journey sets in the background and react to pass/fail/new defects. Use fixed
map waypoints when tooling cannot handle geometry. Fix frequent actual missing
effects first, with one contract per new game behavior. Do not add fixture contracts
or replay New Game before the final release pass.

## 5. Housekeeping and decisions

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

## Physical startup follow-up — 2026-10-28

Progress: **65/222 playable maps on main; current checkpoint 5.5a**. The user
confirmed that the loading-stage build still requested a restart on hardware.
The preceding device log had advanced past world validation and stalled while
copying trainer definitions. Controllers now retain a lookup of validated
registrations and copy only a requested roster; public catalog getters remain
defensive. Existing trainer/actor host checks passed (13), both builds compiled,
and `evidence/device-trainer-lookup-sdk-20261028-01` passed all 2090 SDK checks.
The new physical-device test is pending.

A separate Simulator launch failure was traced to USB serial setup before the
game loaded, in `PlaydateSerialOpen` / `tcsetattr`. Unplugging the physical
Playdate restored readiness. The sample is
`evidence/m55a-visible-resume-20261028-05/charmander-startup-sample.txt`.
These startup failures do not provide checkpoint A gameplay acceptance.

## First 16 MB boot profile — P0

Hardware-verified frontier remains **0/222**; 65 maps have Simulator route
evidence. Checkpoint 5.5a is frozen. The user selected the Simulator's 16 MB
pool; SDK 3.1.2 persisted `MallocPoolSize=16645684`. This value is now required
by runtime preflight. It is a memory constraint, not CPU emulation.

`evidence/p0-guarded-profile-16mb-20261028-02` recorded KantoWorld installation
at 473 ms on the M5, with Lua heap rising from 6691.8 to 12719.8 KiB. The
9 MiB test guard rejected it. The subsequent sliced profile at
`evidence/p0-sliced-profile-16mb-20261028-03` stopped at the same installation;
its error screen continued updating through at least 90 frames, recorded in
`runtime-data/boot-trace.tsv`. Neither run is a passed memory or hardware gate.

BootTrace now writes and closes a phase line to Data and prints it over serial.
Imports remain inside PDZ loading and have a protected Lua-error path; content
installation runs in the SDK update coroutine with cooperative boundaries.
Title/Continue, door and battle phases are instrumented. Device-test guards stop
at 9 MiB observed heap, 6 MiB post-GC live heap, or a 1-second unchecked slice.
The 1-second ceiling avoids crashes; calibrated performance limits remain
unmeasured and cannot be treated as passed. The Simulator/device factor is still
unknown. No new device build has been deployed since the failed loading build.
