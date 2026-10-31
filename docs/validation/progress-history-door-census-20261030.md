# Historical ledger before the corrected door census

Snapshot; runtime statuses below are historical. See progress.md for current state.

# Full-game execution ledger

Updated 2026-10-30. Follow [the goal](../plans/full-game-goal.md).
**108/222 Simulator-route maps; 0/222 device-playable maps. Current: 5.5b.**
The full campaign remains unfinished. Root alone owns Simulator/device execution.
The last authorized push includes `cbd91c96`; subsequent commits are local.

## Accepted on main

5.5a merged in `c946efdf`: 43 East maps, Erika and Silph Scope, for 108 maps.
**Simulator-accepted and hardware-safe; device latency targets not yet met.**
Three earned 5.4 journeys and actual process Save/Continue restarts pass.
Charmander also covers Celadon services, Eevee, slots and Abra.
[Acceptance](midgame-a-acceptance-20261029.json), [chain hashes](chain-saves.json).
Main passed all 1,018 host tests without skips at acceptance.

Player package: `evidence/player-packages/5.5a-accepted-20261029-01/`.
Native silent showcase: `evidence/showcase-5.5a-final-20261029-02/`, 89.854 seconds.
5.4 remains Simulator-accepted; neither milestone is device-playable yet.
GB tones, protected art, chained saves, schema 4 and approved QoL remain.

## Hardware and memory

The accepted 108-map hardware smoke reaches title, earned Continue, Save, doors,
Cut and battle with unchanged error/crash logs. Screen observation is separate.
Save-tier export and early-title preparation are accepted locally after review:
Save **1.510 s**, Continue **3.335 s**, sampled peak **5.63 MiB**.
[Save acceptance](save-tier-accepted-20261030.json),
[title acceptance](early-title-accepted-20261029.json).

The full 60+60-minute idle soak passes: 120 minute samples, title **4.08 MiB**,
overworld **4.35 MiB**, peak **5.77 MiB**, no soft collections or new logs.
Its maximum raw slice **1.295 s** still misses latency. Keeper restored.
[Idle qualification](idle-soak-active-20261030.json).
Hardware guards remain 6 MiB live after GC / 9 MiB hard; soft GC near 8 MiB.
Simulator diagnostic Lua heaps are not compared to the hardware 6 MiB threshold.

Managed Simulator plateaus pass: 400 real door transitions in one pair, then
30 maps × 5 direct-owner loops. Warm same-map ranges are bounded; these are
supplementary owner tests, not physical or approach-walking journeys.
[Pair](memory-door-plateau-20261030.json), [30-map loop](memory-30map-plateau-20261030.json).
A test-only loaded-game hardware probe allocates and releases eight 256 KiB
requested image payloads (2 MiB total), with no new logs. Native headers, masks,
unsampled peaks and long-session headroom remain outside that point test.
[Native probe](native-image-headroom-20261030.json).
**Audio remains held for 100+ physical doors across 30+ maps and 20 battles.**

## Device latency and boot scaling

Boot is `boot.begin` → `initialize.ready`: the title must accept A.
Early title artwork is descriptive and never scores the 10 s target.
The latest isolated shipped-data candidates give this measured device table:

| Phase / target | 108 maps | 149 maps |
| --- | ---: | ---: |
| Input-ready title / 10 s | 12.340 s | 13.687 s |
| Longest boot slice / 1 s | 1.207 s | 1.448 s |
| Continue / 4 s | 3.224 s | 3.295 s |
| Save / 2 s | 1.526 s | 1.600 s |
| Sampled longest door / 1.5 s | 2.957 s | 2.960 s |
| Cave walking p95 / 50 ms | 97.93 ms | 102.83 ms |
| Battle start / 1 s | 18 ms | 19 ms |

Builds `8e912161` / `09f16f95` complete the same serial smoke without new logs.
108-map Lua live/peak: **4.13/5.37 MiB**; 149-map: **4.57/5.87 MiB**.
Last phase: `battle.live.after_gc`; screens not directly observed; keeper restored.
Boot includes 0.781/0.898 s diagnostic GC. No physical power-on claim.
[Full phase/scaling table](boot-region-scaling-20261030.md),
[exact identities](boot-region-scaling-20261030.json).

Build-time map validation removes global provider rescans. Immutable conflict
checks move to pinned staging. Fresh SDK transform exports produce lightweight
memberships; descriptor bodies load on demand through the bounded cache.
At 149 maps, registration falls **5.363 → 0.171 s** and boot **18.540 → 13.687 s**.
108-map registration is 0.109 s; saved-map title preparation stays 4.232/4.201 s.
Historical `Daycare.install` includes later installers; it is not an isolated cost.
The combined review found staged-byte qualification and missing bounded guards;
root corrected both, plus SDK aliases. The real staging-race regression fails
both mutations before the fix and passes after. Main `8b581613` and private B
`8e188083` now contain the reviewed stack. Rejected story-field deferral stays off.
Main compile, 57 protocol checks, 25 focused checks, 182 native cases and the
qualified guard/publication probe pass; B passes 16 focused/build checks.
[Review and corrections](boot-stack-review-20261030.json).

Composed B hardware `1d983974`: boot **13.711 s**, raw boot slice **1.444 s**,
Continue **3.339 s**, Save **1.559 s**, sampled longest door **2.978 s**, cave
p95 **99.91 ms**, battle **19 ms**, Lua live/peak **4.57/5.87 MiB**. No new logs;
last `battle.live.after_gc`, keeper restored, screen not directly observed.
Forced title GC is 0.858 s. **Shipped-equivalent timing is not yet measured**;
no subtraction or implied 10-second pass. The longest slice includes the provider
compact decode/profile preparation; it is not isolated decode timing.
[Composed phases and installer attribution](boot-stack-composed-20261030.json).
Full first-entry activation and current-map scaling remain open. The reviewed
Kanto first-use port has its own 149-map SDK export and 40 passing host/build
checks. The 149-map hardware comparison completed without new logs; keeper restored.
Kanto installer falls 1,172 → 34 ms; boot 13.711 → 12.580 s. Continue 3.384 s,
Save 1.648 s, sampled longest door 2.974 s, cave p95 101.51 ms, raw boot
slice 1.446 s; Lua live/peak 4.53/5.82 MiB. Diagnostic title GC is 0.835 s.
[108/149 installer comparison](kanto-first-entry-scaling-20261030.md).

Hardware admission is exact 16 MiB smoke, no error, sampled peak ≤9 MiB and
raw Simulator slice ≤150 ms. The new 108-map proof reports 65.066 ms / 7.05 MiB.
Historical guessed-factor failures remain retained; safety-only admission passes.
Latency targets gate 5.5c. No accepted checkpoint may regress a phase over 10%.
Two-stage title is isolated on `wip/two-stage-title-108-20261030-01`.
Checksum/header preview opens the menu; the same full load continues in bounded
slices. Early Continue finishes that record, and cancellation unwinds its loader
scope. Initial hardware split regressed immediate walking and Save, so it is
rejected. Cache handoff and duplicate checkpoint work are corrected; 103 save/
session and 42 title/recovery SDK cases pass. Corrected hardware Save is 1.597 s,
but app → walking is 17.936 s versus baseline 17.321 s; the split stays off main. [Candidate](two-stage-title-candidate-20261030.json).
Kanto first-use data is merged in `db4e82e7`, after a clean combined review.
40 merged host/build checks and 44 native scene cases pass; 13 descriptors and
two teams match the SDK export. Hardware installer is 58 ms and boot 11.263 s. [Scope](kanto-first-entry-candidate-20261030.json).
Door census qualification: eight measured input trials and two deliberate solid
boundary gaps; no runtime failure, earned bytes unchanged. Full census launched
once in exec 6850: terminal, 26 measured trials before Game Corner hit the
Simulator 9 MiB Lua guard. A fresh process reproduced it. Private observer
collections at loading suspensions permit both Game Corner trials without
changing production or its guard. [Memory scope](door-census-memory-20261030.json).
The corrected full census is pending; no worst-door result is claimed.
[Qualification](door-census-qualification-20261030.json).
Then per-installer first-entry activation, all-door/worst-five measurements,
cave steps, and the remaining B traversal/visual gates. Superseded queued
journey failure notifications are already handled; do not rerun them.
Rejected terrain, sparse-view, pose, registration and decode-only prefetch trials
stay off main. No more evidence compression tooling.

## Checkpoint 5.5b: private, journeys complete

`t3/midgame-55b-driver` has 149 maps: Tower/Fuji/Flute, Snorlax/Cycling Road,
Fuchsia/Safari/Koga, rods/fishing, Surf and Strength. All three earned A journeys
and real two-process restarts now pass and export `chain/5.5b/<starter>`.
Charmander includes optional Safari and fishing; earlier failures remain history.
[Candidate and exact runs](midgame-b-candidate-20261030.json).

All three B saves also pass common-build cold load and six stopped real-input
Continue/Save processes; canonical earned slots remain unchanged.
[Common-build checks](midgame-b-common-load-20261030.json).
Both gift-cache variants pass 40 native cases; bounded text saves 675.84 KiB.
The original long-journey native `drawFaded` OOM is not universally closed by
short tests. Physical long traversal and scoped reviews remain before acceptance.

All **2,494 protected images** match exactly. South exports 484 native images
across 41 maps; all 41 native spawn viewports inspected. Bike, Surf and Safari BALL frames have supplemental input review; full-map
actor/event overlays and long physical traversal remain.
[Protected](midgame-b-protected-visuals-20261030.json),
[new static scope](midgame-b-new-visuals-20261030.json).
5.5b stays private. C/Saffron/Silph/Sabrina/Dojo/Fly remain isolated preparation.

## Storage and history

Automatic maintenance uses **50 GiB minimum / 70 GiB target** every 30 minutes,
per the user. Ownership locks and retention rules remain. About 116 GiB is free
at this update; no cleanup was needed or claimed in this turn.
Prior audited recovery includes 110.48 GiB initial cleanup, 14.31 GiB native
compression and a later 9.92 GiB pass; see retained audits rather than summing
incomparable snapshots. [Storage audit](archive-sharing-20261030.json).

[Previous ledger](progress-history-boot-scaling-20261030.md),
[B history](progress-history-midgame-b-20261030.md),
[A acceptance history](progress-history-5.5a-acceptance-20261029.md).
