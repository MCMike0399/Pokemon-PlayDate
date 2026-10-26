# Shared source-script events (5.2 step 3 candidate)

Prepared on `wip/source-events`, based on main `1339333`. This is not merged or
SDK accepted. Root retains the 5.1 Source freeze and sole Simulator ownership.

`Source/data/sourceEvents.json` declares the existing 59 implemented events:
19 Viridian/authored adapters and 40 Route 2/Forest/Pewter events. No new story
content or previously blocked source events become playable. Stable event IDs,
source text labels, pickup flags and trainer IDs remain unchanged.

`SourceEvents` compiles declarative programs, ordered conditional cases, gifts,
pickups and trainer descriptors into the existing plan shape. The only bespoke
handler is Oak's authored parcel/Pokédex scene in `sourceEventHandlers.lua`.
`SliceEvents` and `PewterEvents` remain compatibility adapters. Neither owns
handlers or story decisions. TrainerEvents obtains shared trainer definitions,
reward transactions and declarative victory effects through SourceEvents.

Planning never consumes a receipt, changes session state, constructs a Pokémon,
or starts a UI. Descriptor/plan tables are detached. EventState still claims
trainer receipts only on explicit controller entry, splits ordinary dialog from
commit-gated receipt pages, owns temporary sprites, freezes actors under its
overlay, and guards callbacks by session/player/zone/epoch/serial/top state.
TrainerEvents still owns encounter tokens, approach, party creation, confirmed
battle resolution, payout, badge transaction and receipt publication. TM34 is
still a separate full-bag retry transaction after Brock's confirmed victory.

## Reusable operations

Programs accept `dialog`, `give-item`, `battle`, `move`, `move-npc`, `set-flag`,
`heal`, `shop`, `warp`, and explicit commit-gated `receipt`. Compatibility plans
retain `trainer` and `confirmed-dialog`. Item and flag operations compile into
one optimistic transaction; they never write while planning. Battle operations
end their program, use the event's own stable trainer ID, and leave post-battle
rewards to return interaction. They cannot combine with pending durable writes.

Programs have at most 16 steps; movement has 1–8 cells; expanded execution has
at most 64 operations; dialog has 1–12 labels and at most 64 pages. Item grants
have 1–99 units and transaction-time Inventory validation remains authoritative.
Flags require explicit booleans. Conditional selection has at most eight levels
and sixteen cases per level. Future content adds data under stable IDs and may
register named text and trainer data resolvers. Existing content adapters retain
their reviewed text/RAM behavior.

NPC movement leases tracked actors from NPCMotion, which owns their source-art
steps, reservations and completed poses. Scripts retain each lease across dialog
and release it on completion, cancellation or failure. The incomplete cell rolls
back; completed cells remain. Explicit stable-ID position metadata extends script
placement while autonomous wandering keeps its original bounds. Read
[scripted-npc.md](scripted-npc.md) when changing these ownership or pose rules.

Warp is terminal. The destination is resolved through WorldDeltas before commit;
loaded NPC occupancy and available unloaded source actor descriptors are checked.
The real DoorWarpSubstate receives the destination only after commit and all
receipt callbacks complete. Failure or abort drops the pending warp. The existing
fade/switch/entry pipeline owns traversal. No existing event uses NPC movement or
warp yet; these are bounded operations for future content, not a new journey.

## Root integration patch (worker did not edit these files)

The candidate works with existing imports because `world/sliceEvents` imports
`game/sourceEvents`. An explicit `import "game/sourceEvents"` immediately before
`import "world/sliceEvents"` is optional for import-order readability.

Replace the body of `KantoWorld.dispatch` with:

```lua
return SourceEvents.dispatch(game,id)
```

In `KantoWorld.tryInteract` and `PewterWorld.tryInteract`, replace the respective
`SliceEvents.has(id)` / `PewterEvents.has(id)` checks with `SourceEvents.has(id)`.
Geometry, interaction queuing, actor facing, authored HomeRest/Daisy/PC seams and
blocked-event diagnostics remain in their existing owners.

In `PewterWorld.trySight`, replace only the successful push with:

```lua
SourceEvents.dispatch(game,id,{mode="sight"});return true
```

Register the new SDK suite next to the existing event contracts in main.lua
(or in the root's later harness-only dev import overlay):

```lua
import "dev/sourceEventContracts"
Contracts.register("source-events",SourceEventContracts.run)
```

Coordinate these few lines with the map-pipeline worker; do not cherry-pick over
that worker's world-module edits. Existing map binding calls can keep using the
compatibility adapters.

## Validation and acceptance

Host tests validate the JSON registry, source event identities, original text,
trainer labels/rosters, pickups, Brock effects and Mart movement. They never
execute translated Lua or replace SDK interfaces. The frozen baseline planners
in `dev/sourceEventBaseline.lua` are identifier-renamed originals from `1339333`,
used only as SDK regression oracles. They are not production dispatch fallback.
The new SDK suite compares every plan field, including absent versus empty
fields, across flags, capacity, item quantities, defeated state, receipts and
sight/talk observations. It also checks observation immutability, descriptor
isolation, reusable transaction compilation and bounded-operation rejection.
Two additional existing event-UI contracts exercise real sprite movement,
incomplete-cell rollback, real transaction/receipt warp deferral, stale callback
cancellation and handoff to the actual DoorWarpSubstate.

Root should apply the integration lines, then run from the integrated checkout:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python -m unittest tools.tests.test_source_events -v
python tools/harness/run.py --build-only --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/source-events-root-build-UNIQUE" snapshot
make test-harness
python tools/harness/run.py contracts catalog --output "$HOME/Developer/Pokemon-PlayDate-env/evidence/source-events-root-sdk-UNIQUE"
python tools/visual/compare.py docs/validation/catalog-pewter "$HOME/Developer/Pokemon-PlayDate-env/evidence/source-events-root-sdk-UNIQUE/frames" --protected-preservation --report "$HOME/Developer/Pokemon-PlayDate-env/evidence/source-events-root-sdk-UNIQUE/comparison.json"
```

Run the full host suite with that fresh compile bundle as PARCEL_BUNDLE_SOURCE,
following host-tests.md. Root must review/regenerate the current coverage matrix
fingerprint for the integrated Source; the frozen matrix correctly rejects this
candidate tree. Compare the resulting catalog to `docs/validation/catalog-pewter`
in protected-preservation mode. Existing event/trainer/receipt/healing/provider
contracts must pass along with the new `source-events` suite. Rerun the existing
parcel, trainer approach/return, full-bag TM retry and healing journeys as the
root's native integration checks; fixtures supplement the natural 5.1 gate.

The worker launched no Simulator and makes no runtime, image-preservation,
device or milestone-acceptance claim. Main.lua, kantoWorld.lua, pewterWorld.lua,
map importers, domain/session, battle code, protected art and the ledger are
untouched by this candidate.

Worker checks on 2026-10-26: all eight new host tests passed; all seventeen
source-event plus Viridian-generator tests passed after the final code changes.
The broader host run passed 546 tests with zero skips, excluding exactly
`test_coverage_matrix.CurrentMatrixTests.test_complete_source_indices_without_completion_promotion`
because the root-owned matrix snapshot is frozen. The first broad run also
reported a missing worktree-local B2W2 cache; `PinnedSources(fetch=True).all()`
verified/populated it before the successful rerun. No failure was relabeled as
acceptance. Logs: `~/Developer/Pokemon-PlayDate-env/evidence/source-events-host.log`.
Final compile-only bundle: `evidence/source-events-compile-final`; separate
compile-only copy with the new SDK suite explicitly registered in its main.lua:
`evidence/source-events-contract-compile`. Both are under the same durable
environment directory. No SDK contracts were executed by the worker.
