# Ledger before checkpoint 5.5a acceptance

# Full-game execution ledger

Updated 2026-10-29. Follow [the goal](../plans/full-game-goal.md).
Progress: **65/222 Simulator-route maps; 0/222 device-playable maps. Current: 5.5a.**
5.4: **8.70 h / 96.55 maps/day**. 5.5a elapsed: **31.57 h / 0 accepted maps/day**.
P0 elapsed: **25.33 h**. Commit locally; do not push.

## Accepted scope and current candidate

Main's Simulator-accepted 5.4 gameplay is `1a4a7894`.
[Acceptance](vermilion-acceptance-20261028.json), [chain hashes](chain-saves.json),
[elapsed-time basis](milestone-times.json). Three starters reached Surge, Cut,
Diglett's Cave and Flash from earned Cerulean saves. This is not device playability.
The 108-map private 5.5a build boots and passes its earned-save hardware smoke.
It fits the same current-map memory budget as 65 maps. No new region is on main.

All three natural 5.5a journeys pass Erika, Hideout and Silph Scope, with actual
process Save/Continue. Charmander covers optional Celadon services, Eevee, a real
slot spin and Abra; the other starters use the critical path.
[Journey hashes](midgame-a-journey-candidates-20261029.json).
All three also pass actual-input Continue/Save, exit, Continue/Save on one PDX.
Original earned files remain unchanged. [Common-build evidence](midgame-a-common-load-20261029.json).
The synchronized candidate passes all 1,018 host tests, with no skips.

Candidate production PDX and three earned save pairs, outside Git:
`evidence/player-packages/5.5a-synchronized-20261029-01` (not accepted/delivered).
[Acceptance checklist](midgame-a-acceptance-pending-20261029.json).
Native silent showcase: `evidence/showcase-5.5a-final-20261029-02/` (89.854 s,
original speed; complete Erika and Rocket battles, evolution and departure).
Prior 5.4 package: `evidence/player-packages/5.4-playable-20261028`.
Prior clip: `evidence/milestone-5.4-showcase-20261028/PokemonBlue-5.4-showcase.mp4`.

## Immediate blocker: idle collection

The two-hour hardware soak **FAILED**, build `c87b9ee8`, after 60 title minutes
and 15 overworld minutes. The software guard saw **9217.205 KiB** after 75/120
samples; last named phase was Continue.end. No new error/crash log appeared.
[Exact failure](device-idle-soak-failure-20261029.json). Queued measurements stopped.
Root verified its PDX, slots and logs, closed the terminal failure and restored
the awake keeper. No acceptance was claimed.

Simulator frame-count diagnosis reaches 8.5 MiB then falls to **5.09 MiB** after
full collection. Growth is collectible; a retained leak is not established.
Removing the game’s explicit per-frame step alone had no effect. SDK timer
queue reuse now stops growth at matched Simulator frame counts. Soft/live/hard
checks pass; the full 16 MiB route passes at 29 ms / 6.20 MiB peak. The repaired 30+30
generational qualification **passes**: title 3.45 MiB and overworld 4.02 MiB stay
flat, with zero soft collections and no new error/crash logs. The first collector
hit an observer-clock check; raw files and its failure remain unchanged. Separate
[explicit revalidation](device-idle-qualification-20261029.json) verifies all 60
samples, installed bytes and post-check witness. The 108-map smoke is running.
Incremental comparison and the full two-hour soak remain pending.
Next: soft 8 MiB collection at a safe point; reject >6 MiB after GC or the hard
limit. Preserve a 9 MiB hard guard. Qualify 30+30 minutes, then two hours overnight.
Find the retained 1.10 s slice before calling the startup work closed.

## One-page device latency budget

Measured totals below are the latest paired 108-map trace-policy run. Contributor
figures are inclusive spans from retained traces; older method profiles are
labelled and must not be added as exclusive CPU. Savings are design targets,
not measured claims. [Save evidence](device-save-latency-20261029.json).

| Phase / target | Measured | Top three contributors | Structural change / expected saving |
|---|---:|---|---|
| Boot → title / 10 s | 15.636 s | title inspect 3.326 s; registration 2.15 s (older); imports about 1.1 s | minimal title first, finish work in background; generate pure registration data; aim to hide/remove 3–5 s |
| A → walking / 4 s | Continue 6.922 s | store load 2.29 s; decode 1.41 s; gate view 1.13 s (older profile) | validate disk once, preload saved map while title idles, install prepared result; aim to remove/hide 2–4 s |
| Save / 2 s | 5.759 s | five deep validator calls; payload copies/encoding; slot IO/readback (current exclusive split unavailable) | production trusted-owner export plus checksum/readback; aim to remove 3–4 s |
| Route2 door / 1.5 s | 2.947 s | Zone 0.799 s; bindings 0.443 s; view 0.419 s (older profile) | prepare destination in spare cache during approach, fade only installs; aim to hide 1–2 s |
| Cave p95 / 50 ms | 97.68 ms | encounter prepare, encounter resolve, timer/GC churn; exclusive device split pending | prepare policy on entry, allocation-free completion; aim to remove 40–60 ms |

Battle start is **14 ms**, already below 1 s. App-start → walk-ready is **24.476 s**;
physical power-on is unmeasured. Latest Lua live/peak: **3.95/5.45 MiB**.
Trace: `evidence/p0-buffered-trace-hardware-20261029-01`.
65-map paired Simulator title/Continue/peak: **5.014/5.088/6.002 MiB**;
108-map: **5.614/5.776/6.744 MiB**. Evidence:
`evidence/p0-checkpoint-a-field-index-heap-20261029-01`. Fresh 65/108 timing
comparison remains required. Cost growing with installed world size is fixed first.

## Rules for the next changes

Production device export is tiered: full validation once for untrusted disk bytes;
validated owner exports use checksums and exact readback. Harness/dev/contracts
retain deep validators. Two slots and full load validation remain. Earlier strict
repeat-validation rules are superseded by the latest user steer.

After the 16 MiB safety route, measure on hardware first. Review only phase gains
of at least 10%; discard the rest after one measurement. No guessed 35.11 factor.
Safety is guards active, no runtime error, <=9 MiB sampled peak, <=150 ms raw
Simulator slices. Performance targets do not block measurement.

The isolated early-title candidate passes its 16 MiB smoke (41.3 ms raw slice,
7.00 MiB peak) and 39 existing recovery/archive/session bridge SDK cases.
Hardware timing remains unmeasured; it is not merged.
Door prefetch and generated registration also pass isolated safety routes:
54.2 ms / 6.99 MiB and 36.3 ms / 6.89 MiB peak, respectively. Both remain
unmerged pending hardware comparisons; no speed gain is claimed.

The old title-summary shortcut was rejected because it removed constructor and
fresh dependency checks. Rework load/export structurally under the new tiered
policy; do not quietly relabel the rejected shortcut as accepted.
JSON/Lua hardware benchmark: indexes were slower as Lua; keep JSON indexes.
[Exact decode results](device-decode-benchmark-20261029.json).
[Save allocation candidate](device-save-inventory-candidate-20261029.json) and
[walking profiler](device-step-profile-candidate-20261029.json) remain unmeasured
on hardware. Do not add more machinery around old micro-optimizations.

## 5.5 acceptance and parallel work

Once the soak passes, merge 5.5a after the 108-map hardware smoke has no new logs
and fits the memory guards. Label **Simulator-accepted and hardware-safe;
device latency targets not yet met**. Do not call it playable on device yet.
Then activate prepared lazy audio. Targets must pass before 5.5c acceptance;
no checkpoint may regress any phase by more than 10%.

Next checkpoints: 5.5b Tower/Fuji/Flute/Snorlax/Fuchsia/Safari/Koga/Surf/Strength;
5.5c Saffron/Silph/Sabrina/Dojo/Fly. Each has three earned saves on main and one
optional starter. Workers may prepare 5.5b host repairs: two unreachable points
and six explicit field/actor gaps. Root owns Simulator/device time.
Prepared 5.5b host preflight now passes 1,569 checks with zero geometry findings.
Its field/actor results remain conditional static projections, not runtime acceptance.
[Save-tier candidate](device-save-tier-candidate-20261029.json): 95 native cases
and the production-profile safety route pass; hardware measurement remains next.

## Storage and housekeeping

Freed **110.48 GiB (118.63 GB)**; now **160.02 GiB free**.
Removed 83 clean integrated/rejected worktrees and 82 branches,
plus 648 superseded evidence directories. COW-deduplicated 58 identical
archived files with SHA256 verification; all retained paths/bytes remain intact.
[Audit](storage-cleanup-20261029.json). Automatic 150 GiB maintenance runs every 30 minutes.
Keep chain saves, packages, committed validation references and latest passing
journey/device builds. Journey frames retain failures/checkpoints only.

## Decisions and history

Blue world/story/dialogue, Gen V rules, 151 species; protected art stays exact.
GB imported tones, four approved QoL controls and Pickup remain. Trades require
Take first but trades/guards stay parked. No repeated policy/volume question.
Detailed [earlier device reports](progress-history-device-p0-20261029.md),
[loading history](progress-history-p0-loading-20261029.md).
Nothing pushed. **The full game remains unfinished.**
