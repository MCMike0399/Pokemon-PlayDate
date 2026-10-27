# Saffron gate guard handoff

Candidate `wip/saffron-gate-guards` starts exactly at private 65-map root
`0b3aa5db6d94798c1ee9d0824030080ad1adf6ea`. No existing Source file, active
manifest/cache, ordinary package/reservation, ledger or protected image changed.
No Simulator, runtime, push or delegation occurred.

Pinned English Blue `af519899719f0754965776faac0e836a3b906e6d` supplies four
object-1 guards: Route5 (1,3 RIGHT), Route6 (6,2 LEFT), Route7 (3,1 DOWN),
Route8 (2,1 DOWN). Runtime adds the manifest's horizontal padding. Automatic
checks use coordinates, **without a facing/direction eligibility condition**:
Route5 (3/4,3), Route6 (3/4,2), Route7 (3,3/4), Route8 (2,3/4). Source automatic
turns are left/right/up/left, with one-cell pushback up/down/left/right.
Every talk pointer uses `SaffronGateGuardText` in Route5Gate.asm, including its
**upward talk pushback on every gate**. Only Route5/6 descriptors/hooks install;
Route7/8 remain declaration-only. Existing unavailable Saffron exits remain
physically blocked even after a drink; this package adds no destination/access.

The source has no YES/NO offer or decline branch. Without a drink, complete
thirsty paragraphs precede guarded movement. `RemoveGuardDrink` chooses Fresh
Water, Soda Pop, then Lemonade. The package uses exactly existing `freshWater`,
`sodaPop`, `lemonade` definitions. One existing `GameSession:transact` guards all
three quantities and false `pokered:wStatusFlags1:BIT_GAVE_SAFFRON_GUARDS_DRINK`,
takes one item and sets that shared bit atomically. Success prose is commit-gated
receipt text. A stale/duplicate transaction cannot charge again; failures never
show success. After the flag, automatic checks stop and talk thanks the player.
Planning/text/draw use no RNG. EventState's existing player/session/zone/epoch
callbacks, NPCMotion interaction restoration and native movement own execution.
There are no initial/decline/empty-bag completion writes. An empty party can talk.
Source timing is normalized to the existing atomic receipt contract; the original
Route6 automatic flag-before-prose and Route5 flag-after-prose difference is not
replicated as a partially durable operation. `sound_get_key_item` remains an
explicit audio gap in metadata; no sound implementation/timing claim is made.

Root integration, before spawning/entering an imported gate:

1. Review/apply `docs/plans/saffron-guards-root.patch` (unapplied here). Its only
   shared seam is `face-player`: validate one of four directions, enqueue it,
   update the settled player's facing/sprite in EventState before prose. It adds
   no coordinate writes, collision exceptions, transport owner or RNG calls.
2. Import `game/saffronGuards` after SourceEvents/GameSession/SourceMaps. Call
   `SaffronGuards.install()` once after the ordinary Vermilion package. Existing
   SourceEvents/SourceActors interaction and explore hooks handle dispatch;
   no event-state subclass, map activation or reservation edit is required.
3. In the harness-only imports, after existing service contract helpers:
   `import "dev/saffronGuardContracts"` and
   `Contracts.register("saffron-guards", SaffronGuardContracts.run)`.

Checks: generator `--check`, patch `git apply --check`, and 21 focused host tests
passed (`test_saffron_guards`, `test_source_events`, `test_vermilion_gifts`). Host
checks inspect pins/data only, including a tampered-source rejection. Regenerate
with `python -m tools.generate_saffron_guards --output <candidate-directory>`.

SDK 3.1.2 compile-only evidence (patch applied only to private copies, new module
and SDK suite explicitly imported/registered):
`~/Developer/Pokemon-PlayDate-env/evidence/saffron-guards-0b3aa5d-compile-20261026-02`.
The prepared SDK suite uses real imported guards/Player/NPCMotion/EventState,
measured Dialog and session transactions: exact paragraphs, each trigger column
and all facings, real counter talk/upward push, real actor turn/cancel restoration,
8-frame push interpolation, overlay/transport/moving suppression, partial-cell
cancellation and retry, stale player/session/zone callbacks, priority items,
atomic stale/duplicate charge rejection, receipt execution and empty-party plan.
It depends on the root's installed real maps/package and facing patch; it has
**not executed**. Root must run/review it and natural input journeys before
acceptance. Future absent gates receive no runtime credit. No visual, device,
process-restart or completed-5.4/5.5 claim is made.
