# Full-game execution ledger

Updated 2026-10-29. Follow [the goal](../plans/full-game-goal.md).
Progress: **0/222 maps accepted for device playability; 65/222 route-verified in Simulator. Current checkpoint: 5.5a, frozen for device loading and memory checks.**
Last accepted Simulator milestone, 5.4: **8.70 h**, **96.55 maps/day**; [times](milestone-times.json).
P0 elapsed since the first guarded trace commit: **15.89 h**; hardware pace: **0 maps/day**.

## 1. Accepted game and current main

Simulator-accepted 5.4 gameplay: `1a4a7894aa40125147e8f2d227fd1da6320dd341`.
[Acceptance](vermilion-acceptance-20261028.json), [earned-save hashes](chain-saves.json).
All three starters reached Vermilion, explored Anne, received Cut, beat Surge,
crossed Diglett's Cave and earned Flash, starting from earned Cerulean saves.
Bulbasaur covered optional content; the others covered the critical path.
All passed actual process exit/Continue. These are Simulator results.
**Hardware now boots and loads the earned save; playability is not accepted yet.**
The full hardware smoke passed, but map loads still exceed the revised target.

Current P0 game change on main: `b4ef728`. Imported maps use two cache slots.
Startup work yields; map cells use validated packed rows. Field data/art prepares
at map entry. Encounter policy reads retain every commit guard without repeated
slot copying. Original source grids, world/story/rules and protected pixels remain.
The approved GB tones and non-audio QoL remain; no new regions are active.

Simulator preview packages: `evidence/player-packages/5.4-playable-20261028`.
Showcase: `evidence/milestone-5.4-showcase-20261028/PokemonBlue-5.4-showcase.mp4`.
These are not verified device deliveries.

## 2. Current checkpoint and checklist

**P0 hardware loading and 108-map memory: in progress. Checkpoint 5.5a: frozen.**

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

Main's game Source at `b4ef728` completed the hardware smoke: title, earned
Continue, verified save, doors, Cut and wild battle, with no new error/crash logs.
Latest measured build: `b295f7aebf024c1fbf2a6da618ff5ce3`,
`evidence/p0-flat-atlas-hardware-20261029-01`. Live/peak Lua **3.48 / 4.85 MiB**;
worst map load **2,662 ms**, battle start **19 ms**. Loading remains above ~1.5 s.
Sampled walking on the earlier same-route smoke was typically 33 ms per frame,
with no non-transition hitch over 300 ms. Source grids and protected pixels stay exact.

Flat atlases passed 16 SDK world cases, one review and all **497,664 native
pixels across 486 keys**, compiled-path use, fresh copies and two-slot eviction.
Compile and 54 protocol checks pass. Cold per-image files and duplicate-validation
fast paths were rejected after actual device comparisons. No universal guessed
factor blocks deployment; safety is the completed 16 MB route, <=9 MiB sampled
peak, <=150 ms Simulator slices and active crash guards.

The user's guarded build `2e450cd96ab54b5f875037322671c917` passed the full hardware
smoke and is now at title with physical controls restored. Handoff:
`evidence/p0-user-play-handoff-20261029-01/handoff.json`.
User feedback was requested once. **Do not send device inputs or reinstall while
the user is trying it.** This is a guarded test build, not a production release.
The one-way test-only `manual` command restores SDK buttons and refuses later
serial inputs; production contains no test module or command handler.

The paired 16 MB heap check now passes on private 108-map `e022538e`:
title **5.614 MiB**, earned Continue **5.776 MiB**, observed phase peak
**6.744 MiB**. The same observer on 65 maps measured **5.014 / 5.088 / 6.002 MiB**.
Evidence: `evidence/p0-checkpoint-a-field-index-heap-20261029-01`.
The 6 MiB title/Continue and 9 MiB peak guards remain unchanged. Existing SDK
content/event and world batches pass **80/80**; one review found no defect.
Field indexes may reload after GC, so journey latency still needs measurement.
These are Simulator results, not hardware validation of the 108-map build.

## 4. Work in flight

Root owns main, Simulator and hardware. The user cannot access the Playdate
right now and asked to keep progressing. No repeated setup or feedback request.
The guarded physical build stays available; no device inputs or reinstall during
this Simulator work. The 5 s crash guard remains below the 10 s watchdog.

Private checkpoint A has 108 maps (accepted 65 plus 43 East), current P0 fixes,
regenerated caches and flat atlases. Main remains at 65 maps; the original frozen
branch is preserved. Three chained 5.5a journeys are running on private
`9510e51`, with Charmander covering optional content and the other two the
critical path. Failures do not abort later starters. Evidence:
`evidence/m55a-small-harness-journeys-20261029-01`.
The UTF-8 repair preserves all 1,882 decoded records. The next set stopped in
early travel with 11–13.5 MiB of tooling-heavy Lua heap. Journey builds now
exclude every contract and catalog exporter, including their compiled modules.
The six remaining development modules retain input, snapshots and captures.
Full contract builds remain unchanged; 42 existing host checks and SDK
compilation pass. The smaller profile is also on main (`85c188f8`).

Private door-fade candidate `b51e4831` starts destination work during the fade.
One review and compilation pass. Its exact 16 MB smoke saves and traverses doors
without a runtime error (peak 6.58 MiB, maximum slice 27.74 ms). The old timed
input script walks farther through the quicker transitions and misses its final
battle; fixed door waypoints and visual inspection remain necessary. It is not
on main and has no hardware measurement. Evidence:
`evidence/p0-door-fade-smoke-20261029-01`.
Hardware loading and user play still block milestone acceptance, not Simulator
preparation. Root audio, cleanup and Safari polish remain paused. Nothing pushed.

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
