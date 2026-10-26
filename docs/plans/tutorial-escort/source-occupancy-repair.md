# Escort source occupancy repair

Base: `6e8cc87ab832127318cdad613eb3ab554cadfdd3`, the latest root revision
explicitly supplied for this follow-up. Branch: `wip/escort-source-occupancy`.

Root's actual `m53-private-sdk-20261026-03` returned 1583 passes and five failures.
All five arrival failures were valid/top `blocked` scenes, retrying `escort-walk`:
guide finished at (12,18), player stopped at (8,14), next down into collision-zero
(8,15), occupied by `pokered:PEWTER_CITY:objects:1`. This is a frozen source
occupant, not a tick-budget or rendering failure. The pinned source object is
actually STAY/NONE (Cooltrainer F), not WALK.

## Source policy and implementation

The already vendored, checksum-pinned `home/overworld.asm`, revision
`af519899719f0754965776faac0e836a3b906e6d`, has `CollisionCheckOnLand::` branch
to `.noCollision` when `wSimulatedJoypadStatesIndex` is nonzero, before either
sprite-collision probe and before tile checks. Host checks independently pin
that instruction ordering and show that every exact player route crosses (8,15).

The repair follows source sprite-overlap policy through an opaque player intent.
It is bound to the actual registered/top escort controller, epoch, session,
player, zone, guide lease and exact source route index/origin/direction. It is
released on exit; overlays, context replacement, changed routes, replay, forged
intent and replaced motion attachments reject it. `Player:tryMove` accepts this
optional intent only for its NPC occupancy check. Ordinary callers retain their
collision behavior. Terrain, directional traversal, eight-frame interpolation,
route endpoints and source movement order remain enforced. The guide's existing
reservations and final-aisle yield remain enforced as a deliberate safety
adaptation; the player cannot overlap that guide. NPCMotion adds only a read-only
`isScriptOwner` query, so validation never advances a cell or reapplies a pose.

Transient player overlap with another frozen sprite is intentional source
behavior. No NPC is moved aside, hidden, teleported, released or settled to clear
the route. Existing midstep actors and both reservation cells stay frozen. No
RNG draw, session write, persistent pose, flag, map, art or save-schema change is
introduced. Runtime visual review should include the overlap at (8,15).

B cancellation restores the existing entry poses and suppresses this coordinate
trigger until the player leaves the entire trigger-cell set. Movement across an
adjacent trigger cell therefore remains possible. Leaving then returning rearms
it; explicit interaction can still start a new escort. Suppression is transient
and bound to the same session/player/zone.

## Checks and root handoff

The five existing native route cases now also verify the unchanged real source
blocker, ordinary collision against it, exact executed direction sequence,
eight updates per player step, source index completion and unchanged complete
NPCMotion snapshot after reset. Five additional native cases cover intent
rejection/stale-session/terrain/cancel/reentry, cancellation-trigger escape,
a different native NPC blocker on the source path, a validated real tick-three
WALK snapshot frozen through the escort, and attachment replacement after the
guide finishes. Existing endpoint, dialogue, reservation, full-session equality,
both RNG streams, blocked/retry and guide reset assertions are preserved.

Executed here: 40 scoped host checks passed (including nine escort source checks);
real SDK harness and production compile-only builds passed. Final build evidence:

- `~/Developer/Pokemon-PlayDate-env/evidence/escort-source-occupancy-build-20261026-02`
- `~/Developer/Pokemon-PlayDate-env/evidence/escort-source-occupancy-production-20261026-02`

No Simulator execution, push or delegation occurred. Native regressions remain
pending. After composing this commit, root can rerun the registered whole suite:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python tools/harness/run.py --recent-interval 60 --scenario tools/harness/scenarios/tutorial-escort.json --output "$POKEMON_ENV/evidence/escort-source-occupancy-sdk-20261026-01"
```

Use a fresh evidence suffix if needed. The scenario invokes the whole registered
SDK contract suite; it does not constitute a natural-input campaign journey.
