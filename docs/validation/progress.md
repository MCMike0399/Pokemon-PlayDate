# Full-game execution ledger

Updated 2026-10-29. Follow [the goal](../plans/full-game-goal.md).
Progress: **0/222 maps accepted for device playability; 65/222 route-verified in Simulator. Current checkpoint: 5.5a, frozen for device loading and memory checks.**
Last accepted Simulator milestone, 5.4: **8.70 h**, **96.55 maps/day**; [times](milestone-times.json).
P0 elapsed since the first guarded trace commit: **19.82 h**; hardware pace: **0 maps/day**.
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

Root owns main, Simulator and hardware. The user cannot access the Playdate
right now and asked to keep progressing. No repeated setup or feedback request.
Unattended device measurements return to the USB keeper before Simulator work.
The 5 s crash guard remains below the 10 s watchdog.

Private checkpoint A has 108 maps (accepted 65 plus 43 East), current P0 fixes,
regenerated caches and flat atlases. Main remains at 65 maps. Three chained
journeys use hash-verified partial Saves and actual Continue; no completed travel
is replayed or save state invented. Current set:
`evidence/m55a-lift-projection-resumed-20261029-01`; next revision `06ee7f4f`.
All three obtained Silph Scope, then failed the planner route from the B1F lift.
Fixed B2F spinner exit `81b9d95c` and a real post-Scope Save are integrated.
Running: `evidence/m55a-fixed-hideout-exit-resumed-20261029-01`, revision `06ee7f4f`.
Squirtle obtained rooftop Ice Beam, beat Erika and saved; no grinding or save
edits. One Aromatherapy gap appeared; its Gen V party cure now passes on main and privately.
Medicine and Revives spend real money and turns. No journey is accepted yet.

The SDK file encoder is on main (`09154f9e`); 54 protocol checks and one review
pass. It passed the earlier native JSON abort points. Longer travel then exposed
Lua memory pressure during battle return. Private journey mode now releases
completed replies and collects its diagnostic allocations before the next input;
it cannot establish production memory or pacing. Three real saved boundaries
avoid replaying completed travel. The completed logs rank one Aromatherapy hit; the other two starters had none.

Private `20c8c5b` restores six missing generated field-map records; accepted map
records remain exact. Native 108-map memory and content results above remain
separate from this restoration. Full host rerun: **1001 tests, 1000 passed, one
stale coverage fingerprint, no skips**. The inventory snapshot is now refreshed
privately (`808ec87`), retaining every row/evidence facet; its four checks pass.
Hardware loading and user play still block milestone acceptance, not Simulator
preparation. Sparse WorldView `79e42dc1` was rejected after hardware (3,199 vs 3,234 ms;
no material gain). Continue shortcut `f0774168` was rejected before runtime:
it removed validation required by candidate-bound owners. Both checks stay.
Pose metadata `6334e989` passed review, eight native cases and the safety smoke,
but was rejected after hardware: 3,046 vs 3,040 ms, no material gain. Root audio,
cleanup and Safari polish remain paused. Nothing pushed.
Private `wip/checkpoint-a-erika` restores the Gym’s source Cut data and uses the
outside (35,32) and inside (5,7) trees. 55 host checks, generator and compile pass;
All starters beat Erika; Charmander received the badge/TM21 and 2,871 payout.
The city tree correctly returned on leaving the Gym; the driver now cuts it
again before returning to the Center. Full journeys and Hideout remain unaccepted.
The preceding 108-map fade build also passed the 16 MB production probe:
**5.615 MiB title / 5.778 MiB Continue / 6.793 MiB phase peak**. Its real-input
smoke peaked at **7.294 MiB**, max slice **45.40 ms**; hardware unmeasured.
Battle HUDs now appear with each presented Pokémon (`178b7f6f`): ten native
cases, frame inspection and independent review passed. Visible HUD pixels, rules
and timing remain unchanged; this is separate from campaign acceptance.
Evidence: `evidence/p0-checkpoint-a-current-p0-resources-20261029-01` and
`evidence/p0-checkpoint-a-current-p0-smoke-20261029-01`.

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
