# Full-game execution ledger

Updated 2026-10-30. Follow [the goal](../plans/full-game-goal.md).
Progress: **108/222 Simulator-route maps; 0/222 device-playable maps. Current: 5.5b.**
5.5a: **33.83 h / 30.51 maps/day**, including device P0 and waits.
Main was pushed at the user’s request on 2026-10-30, including work through
`cbd91c96` and this push record. Later work requires another request.
The full game remains unfinished.

## Accepted on main

Checkpoint **5.5a** merged in `c946efdf`: Routes 9/10, Rock Tunnel, Lavender,
Celadon, Erika, Game Corner, Rocket Hideout and Silph Scope. It adds 43 maps.
Status: **Simulator-accepted and hardware-safe; device latency targets not yet met**.
[Acceptance](midgame-a-acceptance-20261029.json), [chain hashes](chain-saves.json),
[elapsed-time basis](milestone-times.json).

Three journeys pass from earned 5.4 saves, with actual process Continue/Save
restarts. Charmander covers Celadon services, Eevee, a real slot spin and Abra.
Original earned files are unchanged.
[Journey identities](midgame-a-journey-candidates-20261029.json),
[common-build checks](midgame-a-common-load-20261029.json).
Merged main compiles and passes all **1,018 host tests without skips**.

Player package outside Git: `evidence/player-packages/5.5a-accepted-20261029-01/`.
It contains the production PDX, three earned save pairs and one-line Simulator
loading instructions. Its production Source exactly matches the qualified build.
Native silent showcase: `evidence/showcase-5.5a-final-20261029-02/`, 89.854 seconds
at original speed, with full Erika/Rocket battles. This is not device pacing proof.

5.4 remains accepted for Simulator gameplay. The 108-map hardware smoke now
exercises its earned Continue/Route 2/Cut/battle/save surface too. Device latency
still prevents playable-on-device status. Earlier packages and clips remain retained.

## Hardware result and idle safety

Build `3793be9f` passes hardware title, earned Continue, Save, doors, Cut and
battle with unchanged logs; sampled live/peak **4.02/5.52 MiB**. Serial/state
proof is retained; the screen was not directly observed. Its 16 MiB Simulator
route reports **5.80/6.96 MiB** live/peak and a 124.576 ms maximum raw slice.
Native allocations and unsampled peaks remain outside scope.

The earlier 30+30-minute `eda0ce22` soak passes with flat **3.45/4.02 MiB**
heap and unchanged logs. Its clock-validator failure and separate corrected
revalidation remain in [the idle record](device-idle-qualification-20261029.json).
The older two-hour failure was collectible backlog, not a proved retained leak.

Timer removal queues now reuse their existing tables. Production collects at a
safe point near 8 MiB, rejects over 6 MiB after GC, and retains a hard 9 MiB guard.
The full **60+60-minute** soak passes on build `11f5e226`, using the accepted A
Bulbasaur save: 120 minute samples, title **4.08 MiB**, overworld **4.35 MiB**,
zero soft collections and **5.77 MiB** observed peak. Exact PDX, save bytes,
logs and post-assertion witness pass collection; the keeper is restored.
Maximum raw slice **1.295 s** still misses the latency target. Incremental
comparison remains pending. [Evidence](idle-soak-active-20261030.json).

## Device latency budget

Boot ends when the title accepts A (`initialize.ready`), not at early artwork.
Both builds fail its 10 s target. [Scaling](boot-input-ready-scaling-20261030.json).
Contributor spans are inclusive, not exclusive CPU. Expected savings are aims.

| Phase / target | Measured | Main contributors | Structural candidate |
|---|---:|---|---|
| Input-ready title / 10 s | 18.729 s at 108 maps; 24.945 s at 149 | registration 2.527/6.063 s; provider 5.034/6.974 s; title preparation 4.213/4.233 s | build-time shipped validation, then lazy region registration; unmeasured |
| A → walking / 4 s | 3.307 s | store 2.29 s; decode 1.41 s; gate view 1.13 s | retain fully checked title preparation; aim to hide 2–4 s |
| Save / 2 s | 1.510 s | deep validators; copies/encoding; slot I/O | sealed production owner export, checksum/readback; hardware comparison running |
| Longest door / 1.5 s | 3.002 s | Zone 0.799 s; bindings 0.443 s; view 0.419 s | spare-slot prefetch; decode/padding candidate hides only part of this |
| Cave p95 / 50 ms | 96.96 ms | encounter prepare/resolve and allocation/GC | prepared policies and synchronous scratch; safety route passed, gain unmeasured |

Other doors: 1.885/1.419 s. Battle start: **20 ms**. App start → walking:
**22.566 s** after early-title preparation; physical power-on is unmeasured. Boot/Continue/Save/door regressions
against the previous 108-map trace run are **3.38/9.04/5.04/1.87%**, all below 10%.
These results do not meet playability targets. Targets must pass before 5.5c.

After a 16 MiB safety smoke, measure performance candidates on hardware first;
review only gains of at least 10%. Do not use the guessed 35.11 factor.
Untrusted disk bytes keep full load validation. Production validated-owner exports
use checksum/readback; harness/dev/public paths retain deep validation.

## Work in flight

Root owns Simulator/device and integration. The input-ready boot metric now
fails at 18.729/24.945 s for 108/149 maps. An isolated map-validation candidate
moves checks to build time; eight targeted checks pass at each count. Paired
profiles pass the exact 16 MiB safety route. Hardware boot improves **19.9%** at
108 maps and **22.4%** at 149 maps (25.086→19.455 s); 10 s still fails. The
bundle-read fence passes deliberate Data-shadow regressions and refined hardware.
The candidate remains isolated. [Measured scope](shipped-map-boot-measurement-20261030.json).
Immutable-conflict staging cuts registration 13.3%; on-demand region records
then cut it **5.363→0.171 s** and boot **18.540→13.687 s (26.2%)**. All remain
isolated for review. Full first-entry activation and 10 s boot remain open.
[Latest measured scope](region-declaration-boot-measurement-20261030.json).
Save-tier export is accepted locally after its single review. The exact 108-map
composition passes 96 native cases and hardware: **Save 1.510 s / Continue 3.335 s**,
5.63 MiB peak, no new logs. [Acceptance](save-tier-accepted-20261030.json).
[Paired result](device-save-tier-measurement-20261029.json). Completed hardware comparisons covered isolated
early-title. Nearby-door prefetch was rejected at only 6.63% door improvement;
it stays off main. Generated registration was rejected after
boot/door regressed to 26.886/5.978 s; it stays off main. All passed safety;
39 title recovery/bridge and 64 source-event SDK cases also pass.
Early-title preparation is accepted locally after its single review: 39 merged
native cases, five artifact cases and compilation pass. Artwork appears in 2.5 s;
full initialization is 18.546 s (+6.8%). [Evidence](early-title-accepted-20261029.json).
No unmeasured candidate is on main. [Save candidate](device-save-tier-candidate-20261029.json).

Hold lazy audio until memory plateaus and native headroom are qualified. Then add
town/route/battle music and all 151 cries,
moderate gain 0.22, followed by native loading, heap and listening checks.
Audio candidate `d4dfcc39` passes 76 host checks and the 108-map native route
(7.24 MiB sampled peak). SDK system volume reads 0; the incomplete capture is
silent and not accepted. Current-main refresh `bd842e4b` compiles, passes 76
host checks and reproduces scores/cries; fresh runtime/listening remains pending.
[Evidence](audio-108-runtime-candidate-20261029.json).

5.5b remains private on `t3/midgame-55b-driver`: **149 maps**, starting from
unchanged accepted A saves. Scope: Tower/Fuji/Flute, Snorlax/Cycling Road,
Fuchsia/Safari/Koga, Surf/Strength. Ten owner SDK cases, Chip Away, both gameplay
reviews and 59 focused host checks pass. Geometry is conditional on live actors.

All three now have verified real Saves with Koga, Surf, Strength and Bicycle.
Thirteenth-set Charmander hit a `drawFaded` OOM under the 16 MiB Simulator pool;
Bulbasaur and Squirtle stopped after a Route 17 trainer because their held brake
needed physical rearming. The brake correction passes 68 targeted host checks
and compilation; all 1,039 host tests pass. The fourteenth set is running,
including a full-history Charmander replay. It passed the old OOM point, then
stopped at a held-B learning guard; the other two continue frozen.

Both gift-cache variants pass 40 native cases. Bounded text loading removes
**675.84 KiB** of retained heap and is installed only in private B. A separate
71-map Simulator diagnostic completes at **6.90–7.96 MiB** post-GC. These are not
device heap values. Plateau tests and native headroom remain open; the original
OOM remains unresolved. [Measured scope](m55b-memory-diagnostics-20261030.json).
The latest three Bicycle Saves pass the original ancestry/slot/producer checks.
All three earned B routes and actual restarts pass and export final chains.
All three also pass common-build cold load and two real-input Continue/Save
processes on one PDX, preserving canonical slots. [Scope](midgame-b-common-load-20261030.json).
All 2,494 protected images match exactly. New B presentation, physical long
traversal and scoped reviews remain; B stays private. [Visual scope](midgame-b-protected-visuals-20261030.json).

The earlier 149-map hardware smoke completed title/Continue/Save/doors/Cut/battle
with unchanged logs and **4.49/6.20 MiB live/peak**. Continue: 3.55 s; longest
door: 3.01 s; cave p95: 101.85 ms. Save's 6.64 s used the diagnostic deep policy;
current production profiling remains pending. Keeper restored; latency unaccepted.
Physical **6 MiB live / 9 MiB peak** guards stay unchanged. Short-route hardware
proof does not establish long-route or final B acceptance.
A streaming-observer 200-round-trip door test plateaus after warm-up: city/Center
heap ranges 0.09/0.36 KiB, fixed sprites/registry. This is managed Simulator heap;
The 30-map loop5x also plateaus: largest cycle2→5 same-map increase0.09KiB.
A test-only loaded-game probe allocates 8/8 native images (2 MiB requested payload)
on the device, releases them and leaves no new logs. Long device traversal remains
open. [Pair](memory-door-plateau-20261030.json), [30-map](memory-30map-plateau-20261030.json), [native scope](native-image-headroom-20261030.json).
[Current evidence](midgame-b-candidate-20261030.json), [history](progress-history-midgame-b-20261030.md).

5.5c follows with Saffron/Silph/Sabrina/Dojo/Fly. Trades/guards remain parked.

## Storage, decisions and history

Initial audited cleanup freed 110.48 GiB; later worktree, COW and compile cleanup
is retained in [history](progress-history-midgame-b-20261030.md) and the
[cleanup audit](storage-cleanup-20261029.json). Automatic maintenance uses a
50 GiB minimum / 70 GiB target every 30 minutes, per the user’s 2026-10-30
update; ownership locks stay enforced.

Native APFS compression recovered an observed **14.31 GiB (15.36 GB)** without
removing referenced evidence. All **178 files / 35.42 GB of logical trace bytes**
passed full post-write SHA256 checks. Paths, readable bytes and public metadata
are preserved. That pass stopped at the open-path guard. Automatic compression is
integrated in `6abf11ec`; its 49 checks pass, but later unattended recovery is
unmeasured by that earlier audit. The latest pass recovered an observed
**9.92 GiB**, leaving about **125 GiB free**, above the new 50 GiB limit. [Audit](archive-sharing-20261030.json).

Blue world/story/dialogue, Gen V rules, 151 species; protected art stays exact.
Approved GB imported tones, four QoL controls and Pickup remain.
[Prior ledger](progress-history-5.5a-acceptance-20261029.md),
[device history](progress-history-device-p0-20261029.md),
[loading history](progress-history-p0-loading-20261029.md).
