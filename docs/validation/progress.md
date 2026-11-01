# Full-game execution ledger

Updated 2026-11-01. Follow [the goal](../plans/full-game-goal.md).
**108/222 Simulator-route maps on main; 0/222 device-playable maps. Current: 5.5b.**
The complete Blue campaign, credits and postgame remain unfinished.
Root exclusively owns SDK/device sessions. No push authorized for current work.

## Accepted main and private content

5.5a is merged/pushed: 43 East maps, Erika and Silph Scope, for 108 maps.
**Simulator-accepted and hardware-safe; device latency targets not yet met.**
All three earned 5.4 journeys and actual process restarts passed.
[Acceptance](midgame-a-acceptance-20261029.json), [chain hashes](chain-saves.json).
GB tones, protected art, schema 4, earned saves and approved QoL stay intact.

Private B149 includes Tower/Fuji/Flute, Snorlax, Cycling Road, rods,
Fuchsia/Koga/Safari and Surf/Strength. Three earned A→B journeys and actual
restarts pass. B remains unaccepted pending the current showcase/motion gate.
[Candidate](midgame-b-candidate-20261030.json),
[common loads/restarts](midgame-b-common-load-20261030.json).
C171 remains isolated; no C activation or acceptance. No 5.6 work starts yet.
Current static C audit leaves 22 declared move gaps across 44 ordinary trainers;
Self-Destruct occurs on 13 members and is the next preparation priority.
[Scope](checkpoint-c-current-move-exposure-20261101.json).

## Current B validation

Surf expiry, Reflect/Chip Away, HM battle actions, Haze/Clear Smog and
Rest/Snore/Yawn/Foresight/Revenge are composed privately. Targeted native suites
pass: 33 new move cases, 145 existing regressions and 54 original coverage
assertions. Both gameplay reviews and the measured cache performance review
have no remaining actionable findings. [Move scope](b-earned-moves-composition-20261101.json).

Full current host suite: **1,067 passed**, no errors/failures/skips, 191.410 s.
`evidence/b149-v2-composed-full-host-20261101-02.log` retains the result.
Later edits affect operator preparation/reporting only, not production Source.
Coverage retains 1,512 rows, verification levels and original historical hashes.
All 2,494 protected images, 41 South spawn views and 82 overlays retain their
previous inspected proof. Static views do not establish current motion acceptance.
[Protected art](midgame-b-protected-visuals-20261030.json),
[overlays](midgame-b-full-overlays-20261030.json).

## Physical traversal — passed resource gate

Build `8ecd184c4495408486dac93c4f146f60` completes **110 actual doors, 30 maps,
20 wild battle starts and 136 post-GC entry samples** over 87.44 minutes.
Maximum post-GC Lua heap **5.151 MiB**; sampled raw peak **6.341 MiB**.
No new error/crash logs; exact compiled inventory, console/file receipts,
canonical/private seed bytes and final settled state pass verification.
No hardware Save occurred. Ordinary RUN ended the wild battles; party, items
and money are unchanged. Calibration keeper restored; all runtime owners closed.
[Root review and exact proof](b149-physical-long-traversal-20261101.json).

This closes the long physical resource gate, not B acceptance or playability.
Per-entry diagnostic collections remain explicit; Lua samples exclude native
allocations/unsampled peaks. Existing 2 MiB image point probe is separate evidence.
The earlier 60+60-minute idle soak and Simulator plateaus remain valid.
[Idle](idle-soak-active-20261030.json), [native point probe](native-image-headroom-20261030.json).
Audio stays held until its separate integration/playback verification.

## Device latency and next actions

The shipped-equivalent common route is measured: boot 12.477 s, Continue 3.373 s,
Save 1.607 s, doors 2.961/1.917/1.398 s, battle 18 ms, cave p95 88.32 ms.
Boot slice 1.458 s fails; diagnostic GC was not silently subtracted.
[Comparison](device-shipped-equivalent-20261101.json).

The reviewed versioned cache layout removes flat-directory FAT overhead:
matched Fuchsia entry 14.858→6.576 s (55.7%); all 2,546 record bytes and indexes
are unchanged. Private B keeps this measured improvement. Worst sampled door in
current diagnostic stress is 7.067 s; it is not a shipped-equivalent pacing run.
Boot, worst-door and cave targets remain unmet; latency gates C acceptance.

The first current-source capture preflight stops at the 1 GiB host-memory guard
after 8.59 s; no usable movie. Owned child is gone and UUID Data byte-archived.
Disk is 46.65 GiB, below 51/50 GiB admission/reserve. An external shell check
failed to stop launch; admission now lives inside the recorder and its refusal
before output/SDK is verified. No retry or guard relaxation.
[Retained failure](b149-showcase-preflight-stop-20261101.json).

Next: resolve bounded capture at restored runtime headroom, inspect native motion,
then finish B acceptance/merge. Preserve current hardware proof and earned slots.
Continue real worst-door decomposition/structural latency work; never resume the
exhaustive census. Its 2,832 closed trials remain frozen.
[Census stop](census-stopped-20261101.json), [static ranking](door-static-ranking-20261101.json).

Current normal-production preview and optional earned save are prepared at
`evidence/player-packages/5.5b-reviewed-development-20261101-02/`.
User cannot play-test now; do not wait for feedback. Package limitations are explicit.

## Operational boundaries

Exact 16 MiB safety admission: no error, raw slice ≤150 ms and sampled peak ≤9 MiB.
Device live guard: collect near 8 MiB; fail above 6 MiB after GC or 9 MiB hard.
Keep 51 GiB batch admission /50 GiB reserve, ordered locks and one runtime owner.
Storage stays background/exception-only through the existing reviewed queue.
No new storage tooling, broad scans or proof release. No push without a request.
[Earlier detailed ledger](progress-history-before-b-traversal-20261101.md).
