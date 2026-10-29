# Full-game execution ledger

Updated 2026-10-29. Follow [the goal](../plans/full-game-goal.md).
Progress: **0/222 maps accepted for device playability; 65/222 route-verified in Simulator. Current checkpoint: 5.5a, frozen for P0 device boot.**
Last accepted Simulator milestone, 5.4: **8.70 h**, **96.55 maps/day**; [times](milestone-times.json).
P0 elapsed since the first guarded trace commit: **12.20 h**; hardware pace: **0 maps/day**.

## 1. Accepted game and current main

Simulator-accepted 5.4 gameplay: `1a4a7894aa40125147e8f2d227fd1da6320dd341`.
[Acceptance](vermilion-acceptance-20261028.json), [earned-save hashes](chain-saves.json).
All three starters reached Vermilion, explored Anne, received Cut, beat Surge,
crossed Diglett's Cave and earned Flash, starting from earned Cerulean saves.
Bulbasaur covered optional content; the others covered the critical path.
All passed actual process exit/Continue. These are Simulator results.
**Hardware now boots and loads the earned save; playability is not accepted yet.**
The full hardware smoke passed, but map loads still exceed the revised target.

Current P0 game change on main: `4da7f65`. Imported maps use two cache slots.
Startup work yields; map cells use validated packed rows. Field data/art prepares
at map entry. Encounter policy reads retain every commit guard without repeated
slot copying. Original source grids, world/story/rules and protected pixels remain.
The approved GB tones and non-audio QoL remain; no new regions are active.

Simulator preview packages: `evidence/player-packages/5.4-playable-20261028`.
Showcase: `evidence/milestone-5.4-showcase-20261028/PokemonBlue-5.4-showcase.mp4`.
These are not verified device deliveries.

## 2. Current checkpoint and checklist

**P0 hardware boot: in progress. Checkpoint 5.5a: frozen.**

- [x] Persistent phase trace, guarded error screen, cooperative loading.
- [x] Simulator 16 MB pool verified (`MallocPoolSize=16645684`).
- [x] Calibration, serial print/messages and attached-device coexistence verified.
- [x] Earned-save smoke reaches title, Continue, save, doors, Cut and wild battle.
- [x] Simulator Lua heap fits 6 MiB live / 9 MiB sampled-peak targets.
- [x] Hardware measurement safety: error-free 16 MB route, peak <=9 MiB, slice <=150 ms.
- [ ] Hardware walking, map load and battle start meet the new playability targets.
- [x] Exact hardware build reaches title and earned Continue.
- [x] Hardware warp, battle, save and memory smoke pass without new crash logs.
- [ ] Hardware loading meets the playability target, then the user plays it.

Then accept 5.5a (Rock Tunnel/Lavender/Celadon/Erika/Hideout/Scope),
5.5b (Tower/Fuji/Flute/Fuchsia/Safari/Koga/Surf/Strength), and
5.5c (Saffron/Silph/Sabrina/Dojo/Fly), each on main with three chained earned saves.
Only one starter covers optional content. Sets continue after a starter fails.

## 3. Hardware result and remaining loading problem

Main `95fea99` completed the real hardware smoke in
`evidence/p0-game-device-measurement-20261029-05` (build `3f89d85554a74258bb56b3ea2670bd5d`).
Title, earned Continue, a verified save, doors, Cut and wild Diglett battle all ran.
No new errorlog/crashlog appeared. Lua heap: **3.48 MiB live / 4.63 MiB sampled peak**.
The save repair passed on device: the SDK had refused publication onto an existing
inactive slot. SaveStore now keeps the latest opposite slot and verified candidate
while replacing the inactive target. Seventeen SDK save cases and 64 event cases
passed; both save reviews and the startup performance review were clear.
Compile and all 54 protocol checks passed. No protected art or rendering changed.

Hardware battle start was **22 ms**. Across the sampled walking commands:
Route2 median **33 ms**, p95 **34.35 ms**, worst **39.39 ms** (317 frames);
Diglett's Cave median **33 ms**, p95 **106.16 ms**, worst **114.93 ms** (217 frames).
These wall intervals include observer/display overhead; they are not a campaign-wide
frame guarantee. See `hardware-summary.json` in the run. Device playability is
not accepted yet: map loads were **4,789 / 1,337 / 1,705 ms**, above the ~1.5 s target.
The player has not yet tried a normal production build.

Measured Route2 load costs, including cooperative waits: view **1,995 ms**,
Zone construction **1,163 ms**, field preparation **373 ms**, definition **268 ms**,
field reload **245 ms**. Raw phase/active segments are in `hardware-phase-spans.json`.
The provisional 35.11 estimate no longer blocks deployment or establishes acceptance.
Actual phase ratios will replace it; wall spans containing waits are not CPU ratios.

SDK 3.1.2 does not expose `debug.sethook`: the attempted sampling build stopped
with that explicit error (`evidence/p0-sampled-load-20261029-01`). Native Sampler
UI automation is unavailable because Accessibility permission is false. Do not
claim a sampling profile. Device phase timing is available and ranks view work first.
Removed unused SDK wall sprites on main; production Player and the updated
rollback case use the Zone collision grid. The hardware smoke passed again in
`evidence/p0-no-wall-hardware-20261029-01`: map load **4,284 ms** (505 ms faster),
battle start **19 ms**, live/peak Lua **3.47 / 4.56 MiB**, no new error/crash logs.
All 17 SDK world/rollback cases passed. An image-wrapper identity assertion was
corrected to compare actual pixels; no animation behavior changed.

## 4. Work in flight

Root owns main, Simulator and hardware. Hardware memory/boot/save are now proven;
loading speed remains the P0 blocker. Use the new safety admission (9 MiB peak,
150 ms Simulator slice, active crash guards), not guessed-factor performance gates.
The hardware crash guard is 5 s, below the 10 s watchdog. Hard crashes still stop
attempts and require one A press; none occurred in these guarded game attempts.

The wall-rectangle experiment remains excluded after no useful Simulator gain.
Its replacement removes unused SDK wall sprites, keeping collision in Zone.
Compiled terrain was retested on hardware and stays off main: worst map load
worsened from **4,789 to 6,262 ms**, with a complete smoke and no new crash logs.
See `evidence/p0-device-terrain-decision-20261029.json`. Removing unused wall
sprites is now on main after a clear review, SDK checks and the hardware gain.
The device method profile completed without errors in
`evidence/p0-device-method-profile-hardware-20261029-01`. Route2 costs: registry
preparation 622 ms and binding specs 538 ms (inclusive, containing yields), trace
writes 393 ms, terrain rendering 391 ms, loading drawing 168 ms, GC steps 2.5 ms.
Do not sum inclusive costs or label them CPU samples. Leave GC unchanged.
Main `4da7f65` avoids full map copies for a connection Boolean and uses a 24 ms
device loading-work threshold; Simulator stays at 8 ms. Hardware smoke passed in
`evidence/p0-load-slices-hardware-20261029-01`: **2,851 ms** worst map load,
**19 ms** battle start, **3.47 / 4.85 MiB** live/peak, no new crash logs.
All 36 SDK cases, the one review, production compile and 54 protocol checks pass.
The duplicate-validation candidate did not help (2,924 ms) and stays off main.
The old assumption that Viridian tiles were preloaded was wrong after lazy startup.
Root is validating flat, per-tileset PDT atlases next. Regeneration now uses current
source grids and the unchanged qualified formula, without an unmerged Git dependency. Actual phase ratios are in the no-wall run’s
`device-simulator-phase-ratios.json`; they are not one universal CPU factor.
`wip/midgame-integration` remains frozen at 108 maps. Before unfreezing, port the
current P0 code and verify that its 16 MB heap stays close to the 65-map result.
Root audio, cleanup and Safari polish remain paused. No new regions are on main.

## 5. Decisions and history

Keep Blue world/story/dialogue, Gen V rules, 151 species and protected art.
Approved display changes: imported GB tones plus museum/Route2 diagnostics.
Crank, registered A+B, manual Bag sort, reusable TMs and B2W2 Pickup are approved.
Trades require taking held items first but remain parked. No repeated policy or volume questions.
Detailed history: [earlier device reports](progress-history-device-p0-20261029.md),
[loading reports](progress-history-p0-loading-20261029.md).
Accepted summaries: [setup](divemac-baseline-20261026.json), [Brock](brock-acceptance-20261026.json),
[foundations](foundation-acceptance-20261026.json), [Cerulean](cerulean-acceptance-20261028.json),
[Vermilion](vermilion-acceptance-20261028.json).
Prior housekeeping freed 16.13 GB and removed at least 94 clean worktrees; further cleanup is paused.
Journey data stays in `Source/dev`; references regenerate from checksum manifests.
Packages, earned slots and clips remain outside Git. **Local commits await an explicit push request.**
**The full game remains unfinished.**
