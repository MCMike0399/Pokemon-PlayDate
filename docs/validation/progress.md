# Full-game execution ledger

Updated 2026-10-28. Follow [the goal](../plans/full-game-goal.md).
Progress: **65 / 222 source maps playable on main. Current milestone: 5.5.**
5.4 elapsed: **8.70 h**; pace: **96.55 maps/day**.
5.5 elapsed so far: **0.59 h**; accepted new maps/day: **0**.
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

## 4. Milestone 5.5 in progress

Main remains **65/222**. Private `wip/midgame-integration` contains 171 source maps,
including 106 new maps. This is preparation, not a playable-map acceptance claim.
The native catalog exported 8726 images at
`evidence/m55-native-catalog-20261028-02`; all 2494 protected images match.
Five representative new native viewports were inspected. Motion and journeys
remain pending. Source-backed mansion stairs now retain their forced arrival step
without changing ordinary collision. The shared map host checks pass (14 tests).

Three Sol/medium workers continue in parallel: story scenes; field travel and
services; and chained journeys from the earned Flash saves. Charmander covers
optional content; Bulbasaur and Squirtle cover the critical path. The Warden's
boulder movement is integrated privately and awaits native execution. Trades and
Saffron guards have returned only on this private 5.5 branch; their earlier native
run passed 2182 checks. Their restoration does not change accepted 5.4.

Keep journeys in the background. Use fixed waypoints for troublesome geometry,
Centers and items instead of grinding, and one contract per new game behavior.
Do not add driver contracts or replay New Game before the final release pass.

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
