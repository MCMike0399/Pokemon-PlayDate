# Full-game execution ledger

Updated 2026-10-30. Follow [the goal](../plans/full-game-goal.md).
**108/222 Simulator-route maps; 0/222 device-playable maps. Current: 5.5b.**
The full campaign remains unfinished. Root exclusively owns Simulator/device.
Main's reviewed coverage and fresh compile/full-host audit pass all **1092 tests**,
no errors/skips (261.205 s). [Audit](main-host-after-tools-20261030.json).
Last authorized push includes `cbd91c96`; subsequent commits are local.

## Accepted on main

5.5a merged in `c946efdf`: 43 East maps, Erika and Silph Scope, for 108 maps.
**Simulator-accepted and hardware-safe; device latency targets not yet met.**
All three earned 5.4 journeys and actual process Save/Continue restarts pass.
Charmander covers Celadon services, Eevee, slots and Abra. Acceptance passed
1,018 host tests without skips. [Acceptance](midgame-a-acceptance-20261029.json),
[chain hashes](chain-saves.json). 5.4 is also Simulator-accepted, not device-playable.
Player package: `evidence/player-packages/5.5a-accepted-20261029-01/`.
Native silent showcase: `evidence/showcase-5.5a-final-20261029-02/`, 89.854 s.
GB tones, protected art, chained saves, schema 4 and approved QoL remain.

## Measured device waits and scaling

Boot means `boot.begin` → `initialize.ready`, when title accepts A.
Early artwork is descriptive. The reviewed Kanto first-use change is merged on
main (`db4e82e7`) and ported privately to B. Combined review: no findings;
40 host/build and 44 native scene cases pass. Descriptors and teams match SDK
exports; heavy records use the existing bounded cache. Full region activation
is incomplete. [Scope](kanto-first-entry-candidate-20261030.json).

| Phase / target | 108 maps | 149 maps |
| --- | ---: | ---: |
| Input-ready title / 10 s | 11.263 s | 12.580 s |
| Longest boot slice / 1 s | 1.267 s | 1.446 s |
| Continue / 4 s | 3.197 s | 3.384 s |
| Save / 2 s | 1.613 s | 1.648 s |
| Longest sampled door / 1.5 s | 3.014 s | 2.974 s |
| Cave walking p95 / 50 ms | 96.97 ms | 101.51 ms |
| Battle start / 1 s | 19 ms | 20 ms |

Builds `025d4978` / `3d62a607` complete the same real-input serial smoke with
unchanged error/crash logs. Last phase: `battle.live.after_gc`; screen not directly
observed; keeper restored. Lua live/peak: 4.02/5.26 and 4.53/5.82 MiB.
Diagnostic title GC: 0.821/0.835 s, included. **Shipped-equivalent timing remains
unmeasured**; no silent subtraction or physical power-on claim.
[Exact reports and per-installer scaling](kanto-first-entry-scaling-20261030.md).
Kanto installer falls 1,119→58 ms at 108 maps and 1,172→34 ms at 149.
Registration is 112/193 ms; provider install 1,141/1,559 ms; title preparation
4,184/4,296 ms. 108 Daycare includes later installers and is not separately
comparable. At 149 maps Hideout aggregate is 768 ms and Celadon services 283 ms.

Remaining structural priorities: census and worst-five physical doors, then cave
step costs; finish first-entry installers. Savings are unmeasured until paired
hardware runs. The title split is rejected: immediate app→walking worsened from
17.321 to 17.936 s despite earlier menu input. Do not resume it without removing
actual work. [Rejected result](two-stage-title-corrected-measurement-20261030.json).

Hardware measurement admission: exact error-free 16 MiB smoke, sampled peak
≤9 MiB and raw Simulator slice ≤150 ms. Device playability additionally needs
worst door ≤1.5 s, walking ≥25 fps without >300 ms non-transition hitches and
battle ≤1 s, then user play-test. All latency targets gate 5.5c; no accepted
checkpoint may regress a phase >10%. The full door census is not yet complete.

## Runtime work and checkpoint B

`t3/midgame-55b-driver` is private at 149 maps: Tower/Fuji/Flute, Snorlax/Cycling
Road, Fuchsia/Safari/Koga, rods, Surf and Strength. All three earned A journeys
and real two-process restarts pass and export `chain/5.5b/<starter>`.
[Candidate and runs](midgame-b-candidate-20261030.json),
[common-build cold loads and six input restarts](midgame-b-common-load-20261030.json).
Canonical slots are unchanged. Charmander covers optional Safari/fishing.

All 2,494 protected images match. All 41 South spawn viewports and selected
real-input Bike/Surf/rod/Safari BALL frames reviewed. All 82 full-map actor/event
overlays inspected; no obvious rendering defect found. Static output does not
prove live visibility or triggers. [Overlay scope](midgame-b-full-overlays-20261030.json).
Long physical traversal and checkpoint showcase remain. The showcase recipe now
uses a verified genuine pre-Koga Bulbasaur Save; host import/ancestry checks pass,
but capture is unrun. [Showcase preparation](midgame-b-showcase-preparation-20261030.json). The corrected-B normal
production bundle and refreshed private long-route packet compile, with identical
production Source and verified immutable earned slots; neither is runtime-admitted.
[Production preparation](midgame-b-production-preparation-20261030.json),
[long-route preparation](midgame-b-long-traversal-preparation-20261030.json). [Protected](midgame-b-protected-visuals-20261030.json),
[static scope](midgame-b-new-visuals-20261030.json),
[field motion](midgame-b-field-motion-20261030.json),
[Safari presentation](midgame-b-safari-presentation-20261030.json).
Safari correction recheck: Standards 0; Spec found held input bypassing expiry
after Surf completion. Native regressions reproduce it; the shared input-phase
guard passes boarding and ordinary Surf variants, plus existing normal Surf.
43 targeted host checks pass; independent Standards/Spec fix rechecks both
report no findings. B e71e3301 binds coverage to the reviewed correction with
all rows/facets unchanged. Fresh compile/full-host run now passes all 1058
tests, no errors/skips (287.809 s). Prior B0bc results remain historical. [Evidence](safari-expiry-input-20261030.json).
C/Saffron/Silph/Sabrina/Dojo/Fly remain isolated; B is not accepted yet.

Census qualification: eight measured real-input trials, two deliberate geometry
gaps; earned bytes unchanged. [Qualification](door-census-qualification-20261030.json).
First full exec 6850 is terminal: 26 trials then Game Corner's 9 MiB Simulator
Lua guard. Fresh process reproduces it. Private loading-suspension collection
allows both isolated Game Corner trials; production and hard guard unchanged.
Extra GC is explicit and excludes hardware admission/production pacing claims.
[Memory scope](door-census-memory-20261030.json). Corrected monolithic exec12747/PID58418 is terminal: 866 rows, 292 measured/
574 gaps; 4,024 trials unrun. It stalled in native Lua full GC with a reported
61.3 GB host footprint. Root reaped only that owned child; partial evidence is
retained. This is not a device crash or proven game leak.
[Host stop](door-census-host-stop-20261030.json). Continue unreported pairs in
fresh groups ≤64, with 1 GiB host footprint / 60 s no-row-progress ceilings.
Compare production manifests before combining; no full census claim.
Guarded one-session and incremental-GC controls also hit the host ceiling; both
changes rejected. Panic documents retained malloc history, consistent with the
host growth. Clear/off confirmation is pending; no pool or gate changed.
User chose to retain 16 MiB and enable Accessibility for Clear automation.
Trust is still false at last probe; no profiler-off path is authorized. Host
helper compiles and seven rejection checks pass. The private case-boundary pause/
ack hook compiles with SDK3.1.2 and 16 host checks pass; actual AX labels/reclamation
remain unverified. [Helper scope](malloc-history-helper-20261030.json).
[Controls and limits](door-census-history-retention-20261030.json). Old paged-run
timings do not establish a worst-door ranking. No SDK process remains running.
B coverage was reviewed against current owners, inventories and historical blobs,
then published privately in B0bc2e5fe. Fresh compile-only build and all **1,058
host tests pass**, no errors/skips (412.325 s). Three projection failures required
only dependency hashes, with Cerulean regenerated before Vermilion. No accepted
journey evidence was relabelled. [Audit](midgame-b-host-audit-20261030.json).
Provisional per-phase active ratios are fitted from the same exact build's three
Simulator/device doors, for census ranking only. Residual waits and private GC
are not multiplied. [Calibration scope](door-phase-ratios-20261030.json).

Reviewed Reflect/Chip Away composition is adopted into private B565bfdfb only.
Producer14→15 history is preserved;34 SDK executions across33 names and both
review axes pass. Coverage retains all1512 rows; fresh compile/full host passes
**1059 tests**, no errors/skips (284.633 s), on the identical Source/harness tree.
Old unrun B production/traversal/census/showcase packets are stale and require
fresh staging. B acceptance remains open. [Adoption](reflect-private-b-adoption-20261030.json).

## Memory, audio and storage

60+60-minute hardware idle soak passes: 120 samples, title 4.08 MiB, overworld
4.35 MiB, peak 5.77 MiB; no soft GC/new logs. Raw slice 1.295 s misses latency.
[Idle qualification](idle-soak-active-20261030.json). Guards: 6 MiB live after GC,
9 MiB hard, soft GC near 8 MiB. Simulator diagnostic heap is not hardware live heap.
Managed Simulator 400-door pair and 30-map × five-loop plateaus are bounded:
[pair](memory-door-plateau-20261030.json), [loop](memory-30map-plateau-20261030.json).
Hardware allocates/releases eight 256 KiB requested image payloads (2 MiB), no new
logs. This point test excludes native headers/masks and long-session headroom.
[Native probe](native-image-headroom-20261030.json). **Audio held for 100+ physical
doors across 30+ maps and 20 battles.** The long-journey native `drawFaded` OOM
is not universally closed by short tests; bounded gift text saves 675.84 KiB.

Automatic cleanup uses **50 GiB minimum / 70 GiB target** every 30 minutes.
About 116 GiB free at last check; no cleanup claimed this turn. Retain chain saves,
packages, acceptance references and latest passes/failures. No more compression
or production planner tooling. [Storage audit](archive-sharing-20261030.json).
[Previous ledger and history](progress-history-door-census-20261030.md).
