# Full-game execution ledger

Updated 2026-11-02 UTC. Follow [the goal](../plans/full-game-goal.md).
**Main:108/222 Simulator-route maps. Private B:149. C:171 isolated. Device-playable acceptance:0/222.**
The complete Blue campaign, credits and postgame remain unfinished. Root owns
SDK/device sessions; no push is authorized for this work.

## Accepted main and private frontier

5.5a is merged/pushed:43 East maps, Erika and Silph Scope, for108 maps.
Label: **Simulator-accepted and hardware-safe; device latency targets not yet met.**
Three earned routes and actual process restarts passed.
[Acceptance](midgame-a-acceptance-20261029.json), [chain identities](chain-saves.json).

Private B149 covers Tower/Fuji/Flute, Snorlax, Cycling Road, rods,
Fuchsia/Koga/Safari and Surf/Strength. Its retained three-starter earned A→B
journeys/restarts pass; later rule/performance changes have scoped native and
hardware evidence, not a claimed new campaign rerun. B remains **unaccepted**
pending Snorlax/Koga captures, final60–90s motion showcase and release review.
[Candidate](midgame-b-candidate-20261030.json), [restarts](midgame-b-common-load-20261030.json).
C171 stays isolated/inactive; no C acceptance or5.6 work. Latency gates C acceptance.

## Current private-B implementation and validation

Adopted allocation composition:`f0edc15c`. It avoids unrelated gym descriptor
projections and uses a SourceMaps boolean query instead of copying the entire
world catalogue four times for four Hideout cells. All callbacks, validation,
cell/world outputs, transactions, RNG, rollback and defensive getters remain.
Combined review: **Standards0 / Spec0**. Merged Source is byte-exact to the
native/hardware candidate. **Full host:1072/1072, zero errors/skips,177.676s.**
The initial stale-snapshot failure is retained; the snapshot-only refresh keeps
all1512 coverage rows, levels, inventories and original evidence hashes.
[Host/review](gamecorner-membership-full-host-20261102.json),
[native cases](gamecorner-membership-root-native-20261102.json),
[physical proof](gamecorner-membership-hardware-20261102.json).

Metadata:6native cases across1262IDs. Membership:6original cases across11short
processes, covering all18effect/world combinations with original assertions.
The minimal guarded projection failed on catalogue copy3; it now completes
with0catalogue copies. No guard/GC policy or art/data/map change.
[Expected-red diagnosis](hideout-catalogue-minimal-red-20261102.json).

GenV HM battle actions, Haze/ClearSmog, Rest/Snore/Yawn/Foresight/Revenge,
Reflect/ChipAway and Self-Destruct/Explosion are composed privately, with their
retained native/review scopes. Source gaps remain explicit; green routes never
meant full mechanics fidelity. [Move scope](b-earned-moves-composition-20261101.json),
[Self-KO](self-ko-private-b-adoption-20261101.json).
Protected art/static views retain their earlier proof; allocation changes do
not alter rendering. Static images do not establish current motion acceptance.
[Art](midgame-b-protected-visuals-20261030.json), [overlays](midgame-b-full-overlays-20261030.json).

## Current physical results and limits

Latest finite route, build`e64af0a6f9da4b8081420c87f486967a`, uses an earned
Charmander B save and12ordinary input batches. It reaches GameCorner(15,17)
settled; the prior9MiB guard failure is resolved on this matched replay.
No new error/crash logs. Keeper restored; all runtime owners closed.

| Phase | Latest device wall | Target | Result |
| --- | ---: | ---: | --- |
| App start→title accepts A |13.564s|≤10s|Fail|
| Boot maximum slice |1.458s|≤1s|Fail|
| Continue |3.474s|≤4s|Pass this run|
| Save |1.946s|≤2s|Pass this run|
| Worst sampled door on this route |4.477s Fuchsia|≤1.5s|Fail; worst-eight incomplete|
| GameCorner entry |3.960s|≤1.5s|Fail latency; former hard guard absent|
| Battle/cave p95 |Unmeasured here|≤1s /≤50ms|Open|

Sampled Lua peak7.83MiB stays below9MiB. Endheap6.28MiB is **uncollected**, not
post-GC live proof. Marks remain but forced diagnostic collections are absent;
production soft collection is unchanged. Native/transient peaks are unmeasured.
The different historical common route measured battle18ms and cave p9588.32ms;
that cave result fails and is not a current-source rerun.
[Phase report](gamecorner-membership-hardware-20261102.json),
[common shipped-equivalent route](device-shipped-equivalent-20261101.json).

## Long-session resource evidence

Earlier exact build`8ecd184c` passed110actual doors/30maps/20wild battles over
87.44min,136post-GC samples,max5.151MiB,raw6.341MiB,no newlogs. This closes its
stated physical resource scope, not current latency, every map or B acceptance.
[Traversal](b149-physical-long-traversal-20261101.json).
60+60min idle and Simulator plateaus remain retained; the separate2MiB native
image point probe excludes long-session/unsampled native peaks.
[Idle](idle-soak-active-20261030.json), [headroom](native-image-headroom-20261030.json).
Audio remains held for its separate integration/listening checks.

## Capture, package and isolated mechanics

Walking and a complete24.05s Fisherman victory are captured; native short
preflights pass with exact decoded pixels. Snorlax/Koga and final composition
remain open. The unchanged1GiB host guard stops longer setup/Save paths.
DiveMac desktop observation and native foreground/menu actions are verified;
Clear History/reclamation remains unqualified. A tiny GUI-only check returned
a truncated1000-element AX tree, not proof that the control is absent.
[Components](b149-showcase-components-20261101.json),
[capture limits](b149-desktop-capture-limits-20261102.json).
Outside-Git player package02 retains all three earned pairs and known limits;
its production build predates allocation changes. Repackage on acceptance.
User cannot play now; do not wait for feedback.

Substitute epoch19 and source-derived doll art are isolated on
`t3/gen-v-substitute` at716a062f. New24rule+8seam cases and6presentation cases
are compiled, not executed on that candidate. Old67passes apply only to its
prior owner-seam version. No Substitute adoption or C activation. Trick/Recycle
and other unsupported producers remain gaps. The historical C exposure audit
predates Self-KO; refresh it before C activation instead of presenting its old
count as current. [Historical audit](checkpoint-c-current-move-exposure-20261101.json).

## Next actions and operating boundaries

1. Port the reviewed shared allocation fix to main108 without B content,
   qualifying its own copied Source and real SDK outputs.
2. Complete remaining ranked physical destinations and structural door/cave work;
   preserve paired evidence and≥10%performance review rule. Never resume the census.
3. Finish genuine Snorlax/Koga segments and real-speed showcase; update the player
   package, accept/merge B only after its remaining gates, then ask once about push.
4. Execute/review isolated Substitute and later C integration; C acceptance still
   requires latency targets. Do not change source trainers/moves/AI to hide gaps.

Keep exact16MiB safety: no error,observed slice≤150ms,sampled peak≤9MiB.
Keep6MiB post-GC live/8MiB soft/9MiB hard policy,51GiB runtime admission/50GiB
reserve,ordered locks and one runtime owner. Storage is background/exception-only;
no new tooling, broad scans or proof release. Capacity recovery is historical,
not an active blocker. Never push without a new user request.

[Complete prior ledger, including failed history](progress-history-before-allocation-adoption-20261102.md).

Current B Snorlax component completes from a genuine adjacent earnedSave:
16.56s/native400x240/originalwalltime, silent15fps; firstdecodedRGBAexact and
first/quarter/mid/finalsourceframesinspected. No MallocLog/Clear/AX operation.
Source-fixed waypoints avoid an optionaltrainer through ordinarymovement;
earnedflags/resources remain. [Component/ancestry/limits](b149-snorlax-component-20261102.json).
Koga andfinal60–90s composition remain. Capture-onlywindowclosed requirement
retains16MiBpool/allguards; failed1GiBapproachesretained, noslot reconstruction.

Current-build walking9.715s and complete Fisherman24.045s companions exported;
Root inspected source sheets and decoded-first equality. Genuine post-Snorlax
Bulbasaur Save now retained at Route12(10,61), Soul absent. A longer next
approach hit unchanged1GiB host guard during Save and produced no marker;
shorter ordinary travel is in progress. Koga/composition/acceptance stay open.
[Current components and Save identity](b149-current-capture-progress-20261102.json).

Ordinary southern route now has verified genuine Saves through Route12(10,91),
including the actual Rocker victory. The next JR encounter reached Save but
failed final codec observation at unchanged1GiB host guard; no checkpoint was
reconstructed. All owned processes closed. Koga/final showcase remain open.
