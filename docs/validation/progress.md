# Full-game execution ledger

Updated 2026-11-02 UTC. Follow [the goal](../plans/full-game-goal.md).
**Main: 149/222 Simulator-route maps. Device-playable acceptance: 0/222.**
Checkpoint B is merged and accepted. The full Blue campaign, credits and postgame
remain unfinished. C's 171-map preparation remains isolated and inactive.

## Checkpoint 5.5b — accepted

**Simulator-accepted and hardware-safe; device latency targets not yet met.**
Added 41 maps: Tower/Fuji/Flute, both Snorlax routes, Bicycle/Cycling Road,
rods/fishing, Fuchsia/Koga, Safari, Surf and Strength. All three genuine earned
A→B routes and actual two-process restarts pass in their retained source scope.
Later rule and performance fixes have targeted native/review/hardware proofs;
this is not a claimed new full-route replay. The 86.161-second native showcase
and current production package complete the remaining visual/package gate.
[Acceptance and exact hashes](midgame-b-acceptance-20261102.json).

Merged game code: `af9a8938`. Current production Source matches the reviewed B
candidate and packaged build. Main's working maintenance tools, tests and old
proof files were retained when resolving B's unrelated synchronization deletions.
**1,152 host tests pass, no failures/errors/skips; 57 protocol tests pass.**
Literal `make compile` succeeds with SDK 3.1.2; the PDX has 202 game modules and
zero dev modules. All six canonical B save byte strings remain unchanged.
[Chain identities](chain-saves.json). No push is authorized.

Elapsed: 73.075 hours since the first 149-map packet commit (`ce615acf`), about
13.466 added maps/day. This wall time includes staging, tooling, latency work
and waits; it is not pure implementation time.

## Visual and gameplay evidence

The native 400×240 silent showcase is 86.161 seconds at original speed, with
explicit cuts between four genuine earned-save sessions. It includes walking,
a complete three-Pokémon Fisherman victory, Snorlax's wake/encounter/removal,
and Koga's dialogue/intro/first turn. The gym portion is an excerpt and makes
no new Koga-victory claim. Root inspected native and decoded samples, readable
dialogue pages and source sequences. All 1,420 decoded RGBA frames and original
timestamps are preserved; sampled capture gaps remain visible.
[Showcase](b149-showcase-final-20261102.json).

The package contains a main production PDX, three earned save pairs, the clip,
one-line loading instructions and known limits. It has not been installed or
physically timed as an exact normal-production package. User play feedback is
unavailable now and does not block continued work.
[Package and limitations](midgame-b-acceptance-20261102.json).

The prior 2,494 protected images retain exact pixels/alpha/masks. Reviewed
41-map spawn views and 82 overlays remain historical visual proof; current
motion evidence is the showcase. Gen V move fixes, Surf presentation/expiry,
rod gifts and the measured allocation changes retain their individual review
and runtime scopes. Full mechanics fidelity is not inferred from green routes.
Coverage facet levels and every old raw proof hash remain intact.

## Physical observations — targets still open

Current matched Game Corner route: build `e64af0a6f9da4b8081420c87f486967a`,
12 ordinary input batches, no new error/crash logs, keeper restored.

| Phase | Device wall | Target | Result |
| --- | ---: | ---: | --- |
| App start → title accepts A | 13.564 s | ≤10 s | Fails |
| Maximum boot slice | 1.458 s | ≤1 s | Fails |
| Continue | 3.474 s | ≤4 s | Passes this run |
| Save | 1.946 s | ≤2 s | Passes this run |
| Worst sampled entry on this route | 4.477 s, Fuchsia | ≤1.5 s | Fails; worst-eight route incomplete |
| Game Corner entry | 3.960 s | ≤1.5 s | Fails latency; former hard guard absent |
| Battle / cave p95 | Unmeasured on this finite route | ≤1 s / ≤50 ms | Open |

The different historical common route measured battle start at 18 ms and cave
p95 at 88.32 ms; the cave result fails. It is not a current-source rerun.
Sampled Lua peak is 7.83 MiB, below the unchanged 9 MiB guard. End heap of
6.28 MiB is uncollected, not post-GC live proof. Forced diagnostic collections
were absent; ordinary production soft collection remained.
[Current physical report](gamecorner-membership-hardware-20261102.json).

The earlier physical long traversal passed 110 doors across 30 maps and
20 actual wild battles over 87.44 minutes: 136 post-GC samples, maximum
5.151 MiB, raw peak 6.341 MiB and no new logs. It is resource evidence, not a
current latency or every-map claim. The 60+60-minute idle soak and separate
native image point probe remain scoped evidence; native/transient peaks are
not measured by Lua counts.
[Traversal](b149-physical-long-traversal-20261101.json).

The exact retained Simulator safety route measured a 77.436 ms maximum slice,
8.68 MiB sampled peak, 292 ms map window and 1 ms battle-start marker. Its
finite no-forced-GC profile has no post-GC live value. Diagnostic Simulator
heap is not compared with the device's 6 MiB live guard.

## Next work

1. The qualified door tier candidate is **rejected and unadopted**. Production
   and deep native modes pass14/14 each and the exact safety route passes
   measurement admission (54.148ms / 8.24MiB). Paired hardware cold-entry gains
   are only3.1% Fuchsia,8.4% Route17,7.8% GameCorner; Save regresses11.3%.
   No extra cycle or review is requested for this candidate. Main is unchanged.
   [Exact comparison and retained failures](door-tier-rejected-20261102.json).
2. Narrow terrain queries are merged as`9ba63d68`: current main exactly matches
   the measured Source. Baseline reaches9MiB guard on a real Surf/save route;
   the fix completes9 targetedSDK cases and that physical route at6.12MiB peak,
   4.64–5.04MiB postGC, no newlogs. Combined review has no findings. Fullhost ran1152:1149pass/3stale metadata failures; all resolved in64 targeted
   reruns. Protocol57passes and literal productioncompile pass. Safari/Tower/Hideout/GameCorner live coverage
   and native headroom remain; this route does not establish the full Cmargin.
   [Proof and limitations](terrain-query-memory-adoption-20261102.json). Audio held.
3. Measure title preparation/Continue on all three earned B saves. Host counts
   are 19–21.5 KB payloads with only 3–6 stored Pokémon; no CPU/timing conclusion
   or validation shortcut follows from those sizes.
4. Finish isolated Substitute checks. C host composition is ready on
   `t3/checkpoint-c-host-preparation` at `69658243`: 61 focused checks pass;
   preflight now has four explicit conditions after verified original-path
   ancestry restoration. All three accepted-B imports pass. Activation hooks
   remain unapplied and main stays149.
   C activation needs the memory margin; its acceptance still requires latency
   targets. Later regions, credits and postgame remain ahead.

Keep SDK 3.1.2, the 16 MiB pool, 1 GiB host guard, 31 GiB runtime admission,
30 GiB reserve and ordered ownership locks. Storage remains background and
exception-only. The bounded recovery retained stopped census data remotely,
verified full restore rehearsals and restored runtime admission. Measured free
space rose from 49.06 to 54.65 GiB during that pass; concurrent activity limits
exclusive attribution. The 70 GiB target was not reached or used as a gate for
resuming the game. One separately approved closed B5 retry was also retained
remotely for capture headroom; no current save/package/proof input was released.
[Recovery](capacity-census-retention-complete-20261102.json),
[closed retry](capacity-b5-retention-20261102.json).

[Previous ledger and failed history](progress-history-before-b-acceptance-20261102.md).

## Runtime admission follow-up — 2026-11-02

One stopped superseded census root was remotely verified, fully restore-rehearsed
and released through the existing qualified helper and five fences. Original
864 measured / 1,936 gaps / 2,090 missing outcomes remain unchanged remotely;
closure is not a passing result. Measured free after release was **52.40 GiB**,
restoring the unchanged 51 GiB admission gate. No further archive root is admitted.
[Receipt, exact paths and restoration command](capacity-census04-retention-20261102.json).
Root completed the door cycle and rejected it; the narrow memory fix is adopted
with the separate scope above.
Clean merged worker checkouts were removed without force after status/ancestry/
open-handle checks; branches and proof remain. No memory guard changed.

User disk-headroom override (2026-11-02): reserve30 GiB, new runtime admission31 GiB;
local maintenance30→50 GiB. Historical measurements/guards above retain their
original values. No Simulator/device memory or shared Pi helper guard changed.

Native follow-up: user resolved ScreenSharing/desktop dialogs; startup works.
Nine targeted memory/transaction cases pass in fresh guarded processes. The
499-stepSafari expiry fixture still exceeds1GiB host allocation history; no
current pass is claimed. Its original accepted proof remains. Substitute's
standards finding is fixed (`4160ce96`), spec review has no findings; its remaining
native regressions/presentation/curated54 still gate adoption. No active SDK/USB
owner remains after the measured memory route; verified keeper is restored.
[C ancestry restoration and four conditions](checkpoint-c-restored-ancestry-20261102.json).
