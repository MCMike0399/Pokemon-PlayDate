# Full-game execution ledger

Updated 2026-10-29. Follow [the goal](../plans/full-game-goal.md).
Progress: **0/222 maps accepted for device playability; 65/222 route-verified in Simulator. Current checkpoint: 5.5a, frozen for device loading and memory checks.**
Last accepted Simulator milestone, 5.4: **8.70 h**, **96.55 maps/day**; [times](milestone-times.json).
P0 elapsed since the first guarded trace commit: **21.16 h**; hardware pace: **0 maps/day**.
## 1. Accepted game and current main

Simulator-accepted 5.4 gameplay: `1a4a7894aa40125147e8f2d227fd1da6320dd341`.
[Acceptance](vermilion-acceptance-20261028.json), [earned-save hashes](chain-saves.json).
All three starters reached Vermilion, explored Anne, received Cut, beat Surge,
crossed Diglett's Cave and earned Flash, starting from earned Cerulean saves.
Bulbasaur covered optional content; the others covered the critical path.
All passed actual process exit/Continue. These are Simulator results.
**Hardware now boots and loads the earned save; playability is not accepted yet.**
The full hardware smoke passed, but map loads still exceed the revised target.

Current P0 game change on main: `152470a0`. Imported maps use two cache slots.
Startup work yields; map cells use validated packed rows. Field data/art prepares
at map entry. Encounter policy reads retain every commit guard without repeated
slot copying. Original source grids, world/story/rules and protected pixels remain.
The approved GB tones and non-audio QoL remain; no new regions are active.

Simulator preview packages: `evidence/player-packages/5.4-playable-20261028`.
Showcase: `evidence/milestone-5.4-showcase-20261028/PokemonBlue-5.4-showcase.mp4`.
These are not verified device deliveries.
## 2. Current checkpoint and checklist

**108-map hardware smoke passes; loading/playability remains open. 5.5a: frozen.**

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
## 3. Current evidence and blockers

Latest 108-map hardware build `2cb0ecebdb0243c2967dd928aacc4bdf` completed
title, earned 5.4 Continue, save, doors, Cut and a wild Diglett battle. Errorlog
and crashlog remain exact. Lua live/peak **4.00 / 5.61 MiB**; worst door load
**3,040 ms**, battle start **20 ms**. Last `battle.live.after_gc`: **4.24 MiB**.
Skipping Hideout spinner lookup on unrelated maps improves recorded walking to
**30.23 / 26.76 fps** (Route2/cave), from **16.56 / 15.19** with the same recorder.
These windows include settling and diagnostics; they are not physical user play.
The filter passed review and five host checks and stays private. Map loading and
user play remain open. [Exact comparison](device-walking-108-20261029.json).
The device returned to the USB keeper. Original failed timing reports remain.

Flat atlases passed 16 SDK world cases, one review and all **497,664 native
pixels across 486 keys**, compiled-path use, fresh copies and two-slot eviction.
Compile and 54 protocol checks pass. Main’s full host suite passes **963 tests,
no skips** (`evidence/main-aromatherapy-host-20261029-01.log`). Cold per-image files and duplicate-validation
fast paths were rejected after actual device comparisons. No universal guessed
factor blocks deployment; safety is the completed 16 MB route, <=9 MiB sampled
peak, <=150 ms Simulator slices and active crash guards.

The earlier user-play build `2e450cd9` reached its 9 MiB guard after about
100 minutes idle at title. Its exact trace was archived before replacement.
No leak cause is established. Recorder `5899775` reuses one flushed handle and
stops metrics after physical handoff. The exact hardware smoke passes with no
new logs (`evidence/p0-recorder-handle-hardware-20261029-01`); idle benefit is unmeasured.
The user is away; no repeated setup or feedback request. Production excludes
all serial-input and frame-recorder code.

The paired 16 MB heap check now passes on private 108-map `e022538e`:
title **5.614 MiB**, earned Continue **5.776 MiB**, observed phase peak
**6.744 MiB**. The same observer on 65 maps measured **5.014 / 5.088 / 6.002 MiB**.
Evidence: `evidence/p0-checkpoint-a-field-index-heap-20261029-01`.
The 6 MiB title/Continue and 9 MiB peak guards remain unchanged. Existing SDK
content/event and world batches pass **80/80**; one review found no defect.
Field indexes may reload after GC, so journey latency still needs measurement.
These are Simulator results, not hardware validation of the 108-map build.

## 4. Work in flight

Root owns main, Simulator and hardware; the user is away. No setup question or
push. Main remains **65/222 Simulator route-verified; 0/222 hardware accepted**.
The provisional full-latency targets are in the goal: boot/title 10 s, Continue
4 s, Save 2 s, doors 1.5 s, battle start 1 s, cave p95 50 ms; boot slices 1 s.
App-start-to-walking is also reported; physical power-on remains unmeasured.
Save is first, then static loading cadence, trace I/O, JSON/Lua decoding and Route2.

Private 108-map revision `baaf6368` fixed Mansion's blocked stair arrival from
exact Blue code. One native contract and both reviews pass. Charmander then
obtained Eevee and completed a genuine one-coin slot spin. Its prize window
exposed another real interaction bug: signs must win before counter-range NPC
lookup (`home/overworld.asm:1076–1126`). Private `b676f305` fixes both dispatchers;
red/green native evidence and 20 host checks pass; both reviews have no defects.

`evidence/m55a-arrival-restart-resumed-20261029-01` has two complete passes:
Bulbasaur and Squirtle, including real process Continue, with earned slots in
`chain/5.5a/<starter>`. Charmander's real Save includes Scope, drink rewards and
Eevee. No old failed run was promoted. No new journey set starts before the
all-routes host preflight is complete; its first report retains explicit gaps.

Save candidate `4c7cbd65` preserves default dynamic validators while reusing exact
publication parsing/checksums and removing the observer's redundant load. It
passed 17 native fault cases. Review caught a retained-validator alias in optional
inspection caching; root fixed it before another callback, extending the existing
mutation case. The SDK suite failed on the alias, then all 17 passed. Candidate
`5ce731bd` is being prepared for its first device measurement. Production inspect
reuse stays disabled without a proven stable validation epoch. Save <=2 s is unproven.

Static loading `4cd93146` and bounded production trace buffering `8f5d4f5b` passed
one review each; native timing comparisons remain pending, in that order after
Save. The membership and lazy-audio packets stay parked. No new regions or audio
are activated. An unattended two-hour title/overworld soak remains required.
Fresh device reports use phase targets and exclude diagnostic-GC frames from
ordinary walking; historical reports remain exact. Earlier reports are archived.

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
