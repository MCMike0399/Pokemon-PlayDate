# Full-game execution ledger

Updated 2026-10-28. Follow [the goal](../plans/full-game-goal.md).
Progress: **65 / 222 source maps playable on main. Current milestone: 5.5a.**
5.4 elapsed: **7.89 h**; current pace: **106.46 maps/day**.
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
| 5.4 Vermilion and HMs | Accepted | 7.89 h | [Vermilion](vermilion-acceptance-20261028.json): 918 host, 2077 SDK, all 2494 images exact |

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
