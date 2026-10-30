# Full-game execution ledger

Updated 2026-10-29. Follow [the goal](../plans/full-game-goal.md).
Progress: **0/222 maps accepted for device playability; 65/222 route-verified in Simulator. Current checkpoint: 5.5a, frozen for device loading and memory checks.**
Last accepted Simulator milestone, 5.4: **8.70 h**, **96.55 maps/day**; [times](milestone-times.json).
P0 elapsed since the first guarded trace commit: **21.80 h**; hardware pace: **0 maps/day**.
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

Latest 108-map Save-only build `d6e78c1253664f05b28e05f339a5f683` completed
the earned-save hardware smoke with exact error/crash logs. Save measured
**6.528 s**, versus **9.193 s** on its matched baseline; the 2 s target stays open.
Boot/title **18.447 s**, Continue **7.929 s**, Route2 door **3.082 s**, battle
**19 ms**, cave walking p95 **97.26 ms**. App-start/walk-ready proxy **28.351 s**;
physical power-on is unmeasured. Lua live/peak **4.01 / 5.65 MiB**; last battle
phase **4.24 MiB**. [Exact phase results](device-save-latency-20261029.json).
The original hook filter improved mean walking to 30.23/26.76 fps; cave p95
still fails. Old reports remain exact; fresh reports separate diagnostic GC.

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

The paired 16 MB heap check passes on private 108-map `e022538e`: title/Continue
**5.614/5.776 MiB**, peak **6.744 MiB**, versus 65-map **5.014/5.088/6.002 MiB**.
Evidence: `evidence/p0-checkpoint-a-field-index-heap-20261029-01`; 80 SDK cases
and one review pass. These are Simulator results; hardware pacing remains open.

## 4. Work in flight

Root owns Simulator and hardware; the user is away. No setup question or push.
Main remains **65/222 Simulator route-verified; 0/222 hardware accepted**.
The provisional full-latency targets are in the goal: boot/title 10 s, Continue
4 s, Save 2 s, doors 1.5 s, battle start 1 s, cave p95 50 ms; boot slices 1 s.
App-start-to-walking is also reported; physical power-on remains unmeasured.
Save parsing, static loading cadence and trace buffering are measured and retained.
JSON/Lua decoding is measured; startup registration and the Route2 outlier are next.

Private 108-map revision `baaf6368` fixed Mansion's blocked stair arrival from
exact Blue code. One native contract and both reviews pass. Charmander then
obtained Eevee and completed a genuine one-coin slot spin. Its prize window
exposed another real interaction bug: signs must win before counter-range NPC
lookup (`home/overworld.asm:1076–1126`). Private `b676f305` fixes both dispatchers;
red/green native evidence and 20 host checks pass; both reviews have no defects.

All three private 5.5a journeys pass actual process Save/Continue. Bulbasaur and
Squirtle cover the critical path; Charmander also completed drink rewards,
Eevee, a genuine slot spin and the Abra prize. [Hashes and exact build scopes](midgame-a-journey-candidates-20261029.json).
Earned slots are outside Git in `chain/5.5a/<starter>`. All three also pass
[exact cold-load session equality on one build](midgame-a-common-load-20261029.json).
This calls GameSaves directly, adding no natural-input or device claim. Final
input Continue, latency, soak, delivery and user play remain; no acceptance claimed.
Current-checkout preflight: 1,566 checks, no unexplained 5.5a geometry blockers.
Inactive 5.5b keeps two unreachable points and six explicit field/actor gaps.

Save parsing reuse is on main (`7291113e`), with dynamic validators preserved.
Review caught an optional-cache alias; the extended existing SDK case failed,
then passed after the fix. All 17 persistence cases pass on main. Production
inspect reuse remains disabled without a stable validation epoch; Save still exceeds 2 s.

Static loading is on main (`ad037673`): five native presentation cases pass
privately and on main. Its device cycle reduced boot/title 18.447→15.681 s,
Continue 7.929→7.057 s and Save 6.528→5.891 s, with unchanged logs. Targets stay
open. Trace buffering `8f5d4f5b` passed review; its separate device cycle completed; all provisional latency targets except battle
and one cave door remain open. The membership and lazy-audio packets stay parked. No new regions or audio
are activated. The unattended two-hour title/overworld soak is running on build `c87b9ee8`.
Launch: `evidence/private-soak-hardware-launch-20261029-01`. Its exact fresh
16 MB short proof passes at 33 ms / 6.21 MiB, including a retained post-check
witness (`evidence/private-soak-postcheck-short-20261029-01`). Hardware completion
is unverified; the device reservation protects the attempt. The root collector is
scheduled for launch +125 minutes and will retain failures or restore the keeper
after verified collection (`evidence/private-soak-collection-schedule-20261029-01.json`).
Fresh device reports use phase targets and exclude diagnostic-GC frames from
ordinary walking; historical reports remain exact. Earlier reports are archived.

The device decode benchmark completed 24 calls and 12 typed comparisons. Route2
JSON/Lua medians were 79.63/46.91 ms; Vermilion index 86.37/94.80 ms and
midgame index 112.98/121.38 ms. Keep JSON indexes: Lua was slower for both.
[Exact results and hashes](device-decode-benchmark-20261029.json).
This does not explain the 2.15 s registration span. Candidate `a318caec` reuses
transient fields, reducing loader calls 2,274→6, and adds cooperative yields.
Review, compile, 35 host checks and 182 targeted SDK cases pass; the exact
16 MB input smoke passes at 42.04 ms maximum raw slice and 7.01 MiB sampled
peak. Hardware comparison waits until the soak releases the device; no speedup claimed.

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
