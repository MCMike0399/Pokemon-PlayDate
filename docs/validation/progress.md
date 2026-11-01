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

Latest executed B host suite: **1,067 passed**, no errors/failures/skips, 191.410 s.
`evidence/b149-v2-composed-full-host-20261101-02.log` retains the result.
Later operator/reporting changes leave production Source unchanged. Main’s
reviewed in-place build publisher fix and existing regression case are ported
as `15715215`; the updated full host/compile suite has not been rerun.
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
Private recorder preparation now enumerates exact staged map IDs instead of
copying full maps. All 149 maps/752 IDs match the prior actual SDK projection;
combined review finds no issues. Native memory benefit remains unmeasured.

Prepared source work is recorded separately: Self-KO review caught and Root
fixed King’s Rock secondary/RNG loss; spec recheck is clear. Generic INTERIOR
warp reviews are clear. All remain unadopted and require native validation.
[Prepared frontier](prepared-source-frontier-20261101.json).

Next: resolve bounded capture at restored runtime headroom, inspect native motion,
then finish B acceptance/merge. Preserve current hardware proof and earned slots.
Continue real worst-door decomposition/structural latency work; never resume the
exhaustive census. Its 2,832 closed trials remain frozen.
[Census stop](census-stopped-20261101.json), [static ranking](door-static-ranking-20261101.json).

Current native capture preflight passes2.99s,436MiBhost; decoded pixels exact.
Walking and a complete24.05s Fisherman victory are captured independently.
Battle sampling15fps preserves original walltime; no gamepacing claim.
Snorlax/Koga and final60–90s composition remain open; some setup+Save processes
still hit1GiB. OpenClaw has no active computer node; no GUI workaround/settings
change. [Components and exact scope](b149-showcase-components-20261101.json).
Release candidate `evidence/player-packages/5.5b-release-candidate-20261101-01/`
contains normalproductionPDX and ALLTHREE verified originalearnedSave pairs.
User cannotplaynow; nofeedbackwait. Bstillunaccepted; no push.

## Operational boundaries

Exact 16 MiB safety admission: no error, raw slice ≤150 ms and sampled peak ≤9 MiB.
Device live guard: collect near 8 MiB; fail above 6 MiB after GC or 9 MiB hard.
Keep 51 GiB batch admission /50 GiB reserve, ordered locks and one runtime owner.
The concrete capacity block permitted one bounded duplicate-checkout cleanup:
8 completed, clean, main-merged review worktrees reclaimed 3.02 GiB; branches
and evidence remain. Two live process paths were preserved. Measured free
47.13 GiB still fails admission. [Record](closed-review-worktrees-20261101.json).
Storage stays background/exception-only through the existing reviewed queue.
No new storage tooling, broad scans or proof release. No push without a request.
[Earlier detailed ledger](progress-history-before-b-traversal-20261101.md).

Reviewer5 recoverypassclosedafterexternalauthorizedTartcleanup: fresh84.62GiB,
0Playdatearchive/rehearse/releases and0pendingpassjobs. No additionalroots;
ordinarypolicies/guards unchanged, temporaryslotreleased. Runtimeadmission
restored; olderlow-capacity measurements above remain historical.

Reviewed Self-Destruct/Explosion plus King's Rock correction are composed into
private B4470a0c2:74 native battle cases and34 focused host checks pass; existing
harness registration added. One minimal-runner charge-lock dependency refusal
is retained separately. No B/C acceptance or fresh full-suite claim.
[Scope](self-ko-private-b-adoption-20261101.json).

Current private B file-open device profile completes without new logs; keeper
restored. Fuchsia6545ms:133 Lua-visible opens757ms,136 decodes744ms; Route18
3038ms:49 opens231ms/49 decodes254ms. Opens are11.6%/7.6% of those map spans,
so packing is not justified as the main fix. Next attribute field reload, actors
and post-actor traversal capture. [Exact scope](door-io-counts-20261101.json).

Reviewed loading-scope field-index retention is integrated privately: Route18
3038→2610ms(14.1%); Fuchsia6545→5920ms(9.5%). No new logs, keeper restored.
Literal owner-body equality, fresh SDK descriptor/roster exports,31 host and7
native checks pass; exact composed safety52.386ms/8.76MiBpeak is admitted.
Strict live target remains failed; final owner hardware timing and B visual
acceptance remain open. [Integration](loading-field-cache-integration-20261101.json).

Physical activation profile completes six recorded door entries, matching all
route boundaries; no new logs, keeper restored. Fuchsia5879ms, Route175542ms.
Actor descriptors are built three times (2039/2570ms inclusive); capture totals
overlap those times. Empty actor normalization discards one eagerly built
descriptor: next targeted candidate, no gain claimed. Worst-eight and B visual
gates remain. [Attribution](door-activation-attribution-20261101.json).

Chunked checksum is reviewed and adopted privately: title store-read3286→2847ms
(13.36%); whole Save2189→1986ms(9.27%), not a10% whole-wait claim. Existing
persistence18/18 and23 recovery/build host checks pass. Two exact import lists
and the registration list now include Self-KO without weakening original order.
No new device logs; keeper restored. [Adoption](chunked-checksum-adoption-20261101.json).
