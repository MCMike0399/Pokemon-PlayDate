# Full-game execution ledger

Updated 2026-11-05 UTC. Follow [the goal](../plans/full-game-goal.md).
**Main: 149/222 Simulator-route maps. Device-playable acceptance: 0/222.**
The full Blue campaign, credits and postgame remain unfinished. C's 171-map
preparation is isolated and inactive. Nothing is pushed without a user request.

## C actor-validation correction — 2026-11-05

The reviewed Macintosh C migration had three defects: hidden saved actor
records skipped structural/value validation, the session retention boundary
could accept arbitrary actor deletion, and the diagnostic could report unequal
actor payloads as equal. They are corrected on the isolated C branch
`pi/c-actor-validation-fix` (correction `6fe0357c`, merged reviewed main
`8306f79b` as `2f5bba22`). Every known saved actor is now fully validated before
a bounded visibility drop; only a removal independently proven hidden by a fresh
source descriptor/flags survives, with survivors value-identical; literal
equality and the proven migration are separate, and raw selected-slot payload/
sequence stay distinct from the canonical state. The preserved Fuji visibility
and elevator fixes are unchanged.

Review of that correction found two receipt holes. The host checker read
`worldMotion.actors` as the actor list, but SessionCodec stores the
envelope there and the list at `worldMotion.actors.actors`, so every
genuine migration was rejected. It now compares that envelope and rejects
a flat list, a zone or revision change, a survivor edit, a bad count, and
an extra field. The dev Save/Continue observation also treated a later
`game.session` encode as the canonical form of the selected slot. A
literal match still skips the second decode. Any other payload is
canonicalized from those bytes, so later play cannot become the receipt.
Host receipt tests cover the nested migration. Native `saffron-guards`
was not re-run. C remains unaccepted and is not merged to main.

Fresh actual SDK 3.1.2 export refreshed both dependency pin maps (only
`domain/gameSession.lua` changed); production compiles. Native
`contracts saffron-guards` passes 110/110, now covering malformed hidden records,
custom-validator deletion/addition/mutation, stale flags, all eleven elevator
floors, both exits and unknown-floor rollback. The post-merge host suite runs
1,157 tests with 40 pre-existing C projection/pin/environment failures and **0
new** versus unmodified `03c1bae4`; regenerating the Cerulean and Vermilion
projections fixed two of the former 42. Main remains B149 and C remains
unaccepted.

Two genuine cabin pilots from the frozen pilot12 marker still trip the unchanged
1 GiB host ceiling during repeated route requests/Saves; both failures are
retained. Bounded probes put Continue near 318 MiB and Silph 1F entry near
547 MiB, so the earlier ~900 MB boot figure is not reproduced. Lua heap stays
near 8 MiB while native `Malloc Small` grows. A trusted-boundary observation
change removed a repeated SaveStore deep validation at the dev boundary and
reduced the measured Saffron-walk peak 701→611 MiB (12.8%) with the owner deep
path unchanged. The harness still selects the deep Save path because
`SaveBuildPolicy` disables owner exports whenever `HarnessBuild` exists; changing
that, the guard or the pool needs an explicit user decision. No more pilot
retries were made. The failed pilot's Silph 1F marker is preserved but rejected
by the strict importer because later transit saves overwrote its archived slots.
[Exact correction evidence and scope](../../tools/integration/checkpoint-c/actor-validation-correction-20261105.json).

## Macintosh work reviewed and safe subset integrated — 2026-11-04

The user explicitly requested reviewing the Macintosh session and pushing what
is safe to main. The fetched C branch is `origin/pi/checkpoint-c-host-preparation`
at `03c1bae4`, six commits beyond the previous C tip `1464d1a2`. At review it was
44 commits ahead of the merge-base; main `ff598ced` was 9 ahead. C171 is not accepted
and is not merged wholesale. Source-backed Fuji visibility, elevator confirmation
and cabin projection are useful progress, but both independent reviews found
validation defects in the actor compatibility migration and diagnostic equality
exception. Those remain isolated and require correction/native qualification.
[Separate Standards and Spec findings](../reviews/macintosh-c-20261104.md).

Main component `598f64d2` ports only bounded named-contract dispatch and suite-aware
catalog/field evidence classification. Default aggregate order/common cases remain;
unknown suite rejection occurs before RNG-mutating tests. Production B runtime,
data, art, save owners and qualification pins are unchanged; main stays 149 maps.
The helper/acknowledgement hunk is not independently portable because main has no
matching JourneyHistory owner, so it remains on C. The coverage review preserves
all 1,512 rows/facets/proof hashes and prior snapshot history; only current Source
identification advances for the two development Lua changes.

Fresh validation: **1,171/1,171 full host tests pass**, no errors/skips; 32 targeted
checks and 4 coverage checks pass. A guarded thin API probe passes 21 selected and
22 aggregate cases (the 20 original common cases execute twice plus dispatch
sentinels), including unknown-suite/RNG preservation. This is not a full harness
or C journey pass. The ordinary full-contract B probe exceeded 1 GiB and remains
a retained failure; it is a different profile from the B/C journey comparison.
[Exact component scope](main-named-contracts-20261104.json),
[final host result](main-named-contracts-host-20261104.json).

The latest genuine C frontier is pilot12's stopped Silph elevator Save at (7,1,right),
floor 1, marker 22047333..., only saffron-guard-entry complete. It is on Macintosh;
the new prompt/scenario binds those exact slots and ancestry instead of older
record16. No DiveMac Playdate USB port was present at review; hardware work needs
the device reconnected. Source/host work continues independently. No guard, pool,
trust fence or acceptance threshold changes.
[Current continuation prompt](../handoffs/continuation-after-macintosh-review-20261104.md).

The earlier takeover details below remain historical and are superseded above
where the branch tip, frontier, local setup or next action has advanced.

## Macintosh takeover — 2026-11-04

The user requested pushing current accepted main and a complete handover to
Macintosh. Accepted game/validation tip `75eca5d9` and the reviewed cold-archive
allowlist commit `96b53554` were fast-forward pushed. This handover adds no game
Source changes and does not adopt C or the selected-slot/Telekinesis candidates.
[Takeover prompt and exact frontier](../handoffs/macintosh-20261104.md).

Main remains B149 accepted with the existing label. Isolated C is at `1464d1a2`.
Its last Squirtle attempt completed a genuine Saffron guard-entry Save, then
failed at the unchanged64-Clear cap while routing around a source-confirmed
Saffron actor-visibility bug. No complete C journey or new hardware result is
claimed. Reviewer steer8's30-door production-GC route remains unexecuted.
The November4 process audit found no live SDK/journey/device/archive operation.

Both requested superseded Brock failure roots are now archived, fully rehearsed
and locally released; exact receipts and restoration references are in the
handover. Their logical total is8.46GiB, not an isolated free-space delta.
Actual DiveMac free space at the audit was about95GiB. No current earned input
or positive acceptance proof was discarded. Macintosh receives a private all-ref
bundle and dirty-work snapshots separately; raw external evidence stays on
DiveMac/Pi until exact-path hydration is required. The outgoing agent starts no
new campaign during the ownership transfer. All prior scope/latency limits below
continue to apply.

The user then requested an independent handover challenge. One Sol/medium advisor
found two P2 portability gaps and one P3 persistence clarification, no standards
findings. Root supplied the missing pinned reference/cache/environment setup,
an exact188-file frozen seed-dependency closure, and a new scenario bound to
latest C record16. An isolated recovery drill on Macintosh recovers all selected
branch tips and passes the unchanged strict importer for all three starters,
including Squirtle's exact Saffron slots. Goal/task state is explicitly not
transferred; the prompt supplies a fresh local goal instruction. No gameplay
Source changed or runtime started. Runtime/desktop/hardware and C acceptance
remain separate pending gates.
[Review findings, resolutions and actual drill](../handoffs/macintosh-readiness-review-20261104.json).

## What a player can do

Checkpoint B is accepted and merged: Tower/Fuji/Flute, both Snorlax routes,
Bicycle/Cycling Road, rods/fishing, Fuchsia/Koga, Safari, Surf and Strength.
**Simulator-accepted and hardware-safe; device latency targets not yet met.**
All three genuine A→B routes and two-process restarts passed in their retained
source scope. Later fixes have targeted proofs, not a new whole-route replay.
[Acceptance and original hashes](midgame-b-acceptance-20261102.json).

B game code merged as `af9a8938`. Current main adds the reviewed catalogue-query
memory fix `9ba63d68`; historical B acceptance and package retain their original
build identities. The production code matches the measured memory candidate;
only a generated development-fixture dependency hash changed afterward.
Substitute is integrated as`056fe922`:299native executions, six rendering cases,
a native component motion clip and physicalgame smoke pass in their stated scope.
[Substitute proof and limits](substitute-component-adoption-20261102.json).
The six canonical B slot byte strings are unchanged. [Chain identities](chain-saves.json).

The B merge passed 1,152 host tests and 57 protocol tests. After the memory merge,
1,152 host tests ran: 1,149 passed and three stale metadata checks failed. The
projection changed only its reviewed terrain-owner hash; all 64 targeted
metadata checks then passed. Protocol checks pass 57/57 and literal production
`make compile` passes with SDK 3.1.2. No second full-suite run is claimed.

Current main after Save inspection reuse and metadata reconciliation passes the
full **1,169/1,169 host suite**. The earlier six failures were projection digests,
accepted-code preservation pins and the current Source coverage snapshot; their
failed run is retained. Semantic projections, protected assets and all original
coverage proof hashes remain unchanged. No new campaign or hardware acceptance
is inferred. [Exact host result](main-host-after-save-20261102.json).

B acceptance took 73.075 elapsed hours from the first 149-map packet: about
13.466 added maps/day, including tooling, latency work and waits.

## Visual and package evidence

The native 400×240 silent showcase is 86.161 seconds at original speed, with
four explicit cuts: walking, a complete three-Pokémon Fisherman victory,
Snorlax's wake/encounter/removal, and Koga's dialogue/intro/first turn. Koga is
an excerpt, not a new full-victory claim. Root inspected native/decoded samples
and source sequences; all 1,420 decoded frames and timestamps are preserved.
[Showcase](b149-showcase-final-20261102.json).

The historical accepted package contains a production PDX, three earned save
pairs, clip, one-line instructions and known limits. It predates the memory fix
and was not physically timed as an exact normal-production package. User play
feedback is unavailable now and does not block work. The current production PDX
is at `evidence/main-terrain-query-production-20261102-01/PokemonBlue.pdx` outside Git.

The 2,494 protected images retain their accepted pixels/alpha/masks. Existing
41-map spawn views and 82 overlays remain historical visual proof. No full
mechanics fidelity is inferred from green routes or unchanged art.

## Current memory fix and physical observation

`SourceMaps.terrain` returns detached metadata. Field travel stops retaining a
whole catalogue; Vermilion membership uses `hasTile`. Primitive validation and
rollback remain. The fixture lookup follows active record scopes deliberately.
Actual SDK exports preserve transformed values and prior provenance. Nine
selected native cases pass: query isolation, Surf, Fly, rollback, Save/Continue
and Vermilion scene transactions. Combined review has no actionable findings.
[Adoption, exact reports and limitations](terrain-query-memory-adoption-20261102.json).

The accepted baseline reaches the 9 MiB Simulator guard at `Save.publish.end`
on the earned Surf/save route. It was not admitted to hardware. The candidate
completes the same route, including the actual surfing save at Fuchsia `(31,21)`
with 15 Surf PP and a natural Old Rod battle. Safety: 50.176 ms maximum slice,
8.53 MiB sampled Lua peak, 16 MiB pool, no runtime error. The strict Simulator
live-heap budget still fails; this is measurement admission only.

Physical build `ef35f457052b46dcbf9fffa8be447e6c`: no new logs, sampled Lua peak
**6.12 MiB**, post-GC samples **4.64–5.04 MiB**. Keeper inventory was verified and
run acknowledged; its screen was not directly observed. No paired device saving
is claimed because the baseline cannot safely run this route.

| Phase | Device wall | Target | Scope/result |
| --- | ---: | ---: | --- |
| App start → title accepts A | 13.191 s | ≤10 s | Fails; includes 0.876 s diagnostic GC |
| Maximum boot slice | 1.451 s | ≤1 s | Fails |
| Continue | 3.279 s | ≤4 s | Passes this run |
| Save in Center | 1.820 s | ≤2 s | Passes this run |
| Save while Surfing | 3.317 s | ≤2 s | Fails; no paired regression established |
| Fuchsia entry | 4.478 s | ≤1.5 s | Fails |
| Good Rod house / Fuchsia return | 1.664 / 2.435 s | ≤1.5 s | Fail |
| Fishing battle start | 22 ms | ≤1 s | Passes this run |
| Cave walking p95 | Unmeasured | ≤50 ms | Open |

This profile retains default diagnostic full collections and normal soft GC.
Shipped-equivalent timing is unmeasured; do not silently subtract GC. Lua counts
exclude native/transient allocations. The route covers Fuchsia and its rod house,
not all heavy B maps or C's working margin.

The earlier physical long traversal passed 110 doors, 30 maps and 20 wild battles
over 87.44 minutes: 136 post-GC samples, maximum 5.151 MiB, raw peak 6.341 MiB,
no new logs. It is scoped historical resource proof, not current latency.
[Traversal](b149-physical-long-traversal-20261101.json). Idle soak and native image
point probes retain their separate scope.

## Next work and open gates

1. Current physical memory samples now cover Game Corner and Hideout B1F–B4F,
   about 5 MiB collected live with 6.13 MiB sampled peak. Safari Center, East,
   North and West now measure 5.03–5.08 MiB post-GC with the same 6.13 MiB peak;
   seven natural encounters use ordinary RUN. Tower 1F–7F now measures
   4.77–4.84 MiB post-GC, with 6.11 MiB sampled peak and six actual encounters.
   Tower uses the genuine earlier post-Fuji Save, not a fabricated late-B save.
   [Tower samples](tower-memory-20261102.json).
   [Safari samples and retained failures](safari-memory-20261102.json). The current fishing-battle point probe holds eight requested 256 KiB
   native images on hardware, then releases them; allocation plus two collections
   takes 1.243 s. This diagnostic-GC route is not the full C margin.
   [Native point probe](native-headroom-current149-20261102.json).
   Spinner query merge `1860b3c0` reduces ordinary B3 active p95 from 148 to
   39 ms in one hardware comparison; 61 native checks and 24 merged host checks
   pass, with no review findings. Three roughly two-second hitches remain.
   [Scoped adoption](spinner-query-adoption-20261102.json). Audio remains held.
   [Heavy-map samples and hitch scope](heavy-b-memory-20261102.json).
2. Substitute is adopted. The composed host suite ran1,169tests with four
   metadata/art-reference failures;110targeted branch checks and120merged checks
   pass after correction.57protocol checks and productioncompile pass. Current
   shared-owner evidence is rebound only where unchanged assertions reran;
   HelpingHand/Dig stay stale, and no full-mechanics completion is inferred.
3. C's isolated candidate is now wired and SDK-qualified at `5ae77a61` in
   `t3/checkpoint-c-host-preparation`. Main stays 149 maps; candidate has 171.
   Source-derived metadata handles two inert Silph declarations and 13 scripted
   elevator IDs without changing B's 510 classifications. Actual thin SDK export
   preserves Kanto/East/South values and produces Saffron's 30 transformed events
   and 45 trainers; sampled host peak is 194 MiB. Qualified production compile
   passes. Native floor/elevator checks, earned journeys and C's own hardware,
   memory, latency and visual gates remain open. The guarded full-harness export
   stopped at 1 GiB and was replaced, not continued. B memory no longer blocks C
   activation, per reviewer steer 7. Existing earned boundaries remain strict.
   [C ancestry proof](checkpoint-c-restored-ancestry-20261102.json).
4. Controlled four-Save measurement separates ordinal from the earlier mixed
   comparison: Center #1/#2 take 1.947/2.867 s; Fuchsia Surf #1/#2 take
   2.288/3.529 s. Inspection rises 361→1,334 ms and 375→1,600 ms; writes/readbacks
   are nearly flat. Whole-phase marks are private, not a production change.
   Cross-map still combines map, travel and mode; no isolated Surf effect claimed.
   [Actual attribution](save-four-point-attribution-20261102.json).
   A SAVE-only inspection-proof candidate now measures repeated Center Save
   2.867→2.020 s and repeated Surf Save 3.529→2.426 s, 29.5/31.3% faster.
   First Saves are 2.5/3.5% slower. Public loads retain deep validation; 23
   selected native persistence cases pass. Both exact safety routes admit device
   measurement; hardware peak is about 6.14 MiB with unchanged system logs.
   Adopted as `1ffd6fa7` after one combined review with zero findings. All 47
   selected merged host/build checks and production compilation pass; the three
   changed Source files equal the measured candidate. Surf still misses 2 s.
   [Measured candidate and scope](save-inspection-reuse-measured-20261102.json).
5. Matched hardware observations now cover all three canonical B saves, with
   identical code/SDK/compiler and only private build identity differing:
   selected envelopes 21,533/22,650/24,316 bytes; title preparation
   4.589/4.687/4.981 s; input-ready boot 13.325/13.548/13.774 s;
   Continue 3.293/3.360/3.463 s. Store inspection takes 2.419/2.482/2.635 s.
   Default title diagnostic GC is 0.876/0.899/0.968 s; shipped-equivalent timing
   remains unmeasured. Party, PC and flags vary together, so PC causality is not
   isolated. All three exceed boot/slice targets; Continue meets 4 s.
   [Three-save phases and exact proof](boot-three-earned-saves-20261102.json).
   Fix structural door/boot/cave costs. Deferred `import()` splitting is closed:
   SDK 3.1.2 prohibits imports outside PDZ loading; no candidate was created. Do not
   restart the census. The user explicitly allows the existing guarded history
   helper for ordinary C journeys. Its archive-fence correction passes host
   checks, but native qualification remains open: opening the profiler window
   itself can cross the unchanged 1 GiB host guard before Clear. A reviewed
   ready-title pause now proves actual Clear and 67 ordinary requests through
   Route 15, but stops at the unchanged 64-Clear limit: the cleared UI footprint
   exceeds the 512 MiB trigger. Closing the window did not release headroom and
   is rejected. The user approved changing only the soft Clear trigger to
   736 MiB; 36 focused host checks pass and a fresh single-Squirtle pilot is
   running. The 1 GiB hard stop, 16 MiB pool, 64-Clear/131-call caps and other
   limits remain unchanged. No complete C journey is inferred from the earlier
   short qualification.

Compact SMC1 terrain-row consumption is also rejected after native correctness
passes but no whole-phase hardware gain: Fuchsia 4.451→4.507 s, memory unchanged.
Four map cases, one WorldView rollback and nine activation cases pass; no review
or adoption follows. [Measured rejection](packed-terrain-rejected-20261102.json).

The six-set atlas enablement candidate is rejected after matched hardware.
Game Corner load was 3.889→3.933 s; B3 load 1.886→1.907 s, with three >1 s
frames still present. Tower's best floor improvement was 3.0%. Native pixels
passed all 727 keys/20 tables, but no target met the 10% performance rule.
No review, adoption or additional proof work is requested for this candidate.
[Measured rejection](atlas-enable-rejected-20261102.json).

The door-tier candidate remains rejected: primary cold-entry gains were only
3.1% Fuchsia, 8.4% Route17 and 7.8% GameCorner, with Save 11.3% slower. Its
qualified native modes passed 14/14 each, but no further cycle/review is requested.
[Rejected measurement](door-tier-rejected-20261102.json).

The 499-step Safari expiry fixture currently exceeds the 1 GiB host allocation
history limit; no fresh pass is claimed. Its original accepted proof remains.
Other targeted tests ran in fresh processes with their assertions intact. User
resolved desktop dialogs and opened Screen Sharing; native startup works again.
Paired DiveMac-node desktop observation is verified; gateway status alone is not
node availability. No unrelated applications were killed.

## Operating decisions

User disk policy: **30 GiB reserve / 31 GiB new-runtime admission**. Local
maintenance runs at 30→50 GiB. Keep the SDK 3.1.2 pool at 16 MiB, host limit at
1 GiB, Lua guards at 6/8/9 MiB, and ordered ownership locks. All runtime/USB
readers are closed after both measured routes; verified keeper is restored.
Storage is background, exception-only. No current/earned input is discarded.
[Verified census retention](capacity-census04-retention-20261102.json),
[earlier recovery](capacity-census-retention-complete-20261102.json).

Coverage retains all 1,512 rows, facets and historical proof hashes. The current
snapshot was reviewed separately; no fidelity or acceptance level was promoted.
[Previous ledger/history](progress-history-before-b-acceptance-20261102.md).
