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

1. Freshly qualify the isolated door tier candidate (accepted-main port `85f464eb`, Root hook `bd5a119f`); execute its
   existing native selections and exact 16 MiB safety route. Measure Fuchsia,
   Route 17 and Game Corner on hardware, retaining only a ≥10% phase gain and
   one combined performance review. Do not restart the census.
2. Measure heavy-map post-GC live heap and native headroom. Qualify the small
   Vermilion membership and detached field-terrain candidates; both remain
   unadopted. Keep about 7.5 MiB working peak before C activation, with the
   existing guards unchanged. Audio stays held for its own listening checks.
3. Measure title preparation/Continue on all three earned B saves. Host counts
   are 19–21.5 KB payloads with only 3–6 stored Pokémon; no CPU/timing conclusion
   or validation shortcut follows from those sizes.
4. Finish isolated Substitute checks. C host composition is ready on
   `t3/checkpoint-c-host-preparation` at `69658243`: 61 focused checks pass;
   preflight has six explicit conditions, including two archived ancestry
   inputs. Activation hooks remain unapplied and main stays149.
   C activation needs the memory margin; its acceptance still requires latency
   targets. Later regions, credits and postgame remain ahead.

Keep SDK 3.1.2, the 16 MiB pool, 1 GiB host guard, 51 GiB runtime admission,
50 GiB reserve and ordered ownership locks. Storage remains background and
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
restoring the unchanged 51 GiB admission gate. No further root is admitted.
[Receipt, exact paths and restoration command](capacity-census04-retention-20261102.json).
Root resumed the isolated door candidate's real SDK export. Door hook integration
passes 13 focused host checks; terrain-query composition passes18. Both remain
unadopted until their native, physical and review gates pass.
