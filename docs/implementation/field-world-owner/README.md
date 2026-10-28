# Prepared 5.4 field world owner seam

Branch: `wip/field-world-owner`. Exact parent:
`6a137379a7e8b85a7bc8a65eec7c563f58bed756`.
This is separate preparation. Root's accepted 5.2 and frozen private 5.3 runtime
at `c6882b6` are untouched. No Simulator, runtime, device, push, delegation,
main activation, protected art, maps, geometry, coverage or ledger edits.

## Owners and lifecycle

`FieldWorld` is a policy adapter over `WorldDeltas` and `GameSession`, not another
state owner. `FieldWorld.commit(game, expectedRuntimeWorld, snapshot)` checks the
runtime guard, uses native `WorldDeltas.apply` and its rollback, then the existing
atomic `captureTraversal` owner. Rejected terrain/views, location, checkpoints,
actors or field data leave the session unchanged and restore runtime terrain and
registry/cache bookkeeping. It never assigns player/NPC coordinates or replaces
the session, bag or party. Actor/player reconstruction remains with the existing
overworld/context/transport owners.

The narrow, opt-in `OverworldState.enter` hook resets the departing map on a
real map entry, explicit reload, or respawn. It runs before the old view is
removed. Ordinary no-entry battle returns and menu/dialog overlays retain Cut.
`opts.fieldReloadReason` accepts `map`, `reload`, `escape`, or `blackout`.
`opts.fieldRestore=true` is reserved for existing transport rollback; it prevents
that rebuild from masquerading as a new departure.

`GameSaves.continueGame` prepares only its detached candidate before the existing
atomic `installSession` publication. All installed supported Cut maps reset on
Continue. The projection removes only complete exact pinned replacements and
preserves unrelated deltas. New Game already supplies an empty world.

`resolvePlayerLocation` is a separate optional dependency. Its fallback is the
original strict location resolver, preserving existing callers. Only the player
location uses it: checkpoints and actor surfaces still use strict validators.
The allowance proves the entire restored source block, exact source revision,
map dimensions/name, source grid keys, generated changed endpoint, slice policy,
bounds, facing and binding status. It accepts the player on the restored tree
without changing ANY collision cell or candidate tile. The existing Player
movement checks the destination, so stepping off works and stepping back onto
the blocked tree fails. No Player or WorldMotionData change was needed.

## Explicit save field and adapter

SessionCodec emits **version 2** with one new required top-level field:

```json
{"fieldWorld":{"version":1,"mapPalOffset":0}}
```

Only offsets `0` and `6` are supported; unknown nested fields, versions and values
are rejected. Schema 1 records remain decodable and migrate deterministically to
`{version=1,mapPalOffset=0}`. A schema 1 envelope containing the new field is
rejected. This migration never guesses historical Flash use or rolls RNG.
Existing Pokémon encoding and legacy item-storage/world-motion migrations stay
in place. The inner schema is `field-world.schema.json`.

GameSession owns this field and a process-local context epoch. Constructors,
decode, successful traversal capture, successful Flash CAS, and explicit scene
invalidation allocate a new epoch without RNG. Epochs are not save fields.
Reads return defensive values and do not initialize, capture traversal or draw.

Root installs `game.fieldDarkness=FieldWorld.darknessAdapter()`:

```lua
adapter:read(game)
-- nil when absent/ineligible, otherwise defensive
-- {zone_id, source_revision, offset, epoch}
adapter:clear(game, expectedInput)
-- Exact tuple CAS: offset6 -> 0; false for stale/changed/light contexts.
```

Eligibility requires one of the packet's two declared Rock Tunnel IDs AND an
installed provider descriptor at the pinned revision by default. An explicit
`darknessAdapter(resolveDescriptor)` can instead consume declared source-map
metadata (`id`, pinned `revision`) for the future 5.5 owner. It still accepts
only the two source dark IDs. The extra SDK case uses this declared boundary
with the real session/codec and no geometry or SDK stand-in. Neither map is installed
here. No map name heuristic, geometry, circular light renderer, offset inference,
RulesRNG consumption or alternate darkness flag is introduced. The future 5.5
renderer reads the session-backed adapter without writing it.

`transitionOffset` implements the pinned source policy for legal loader warps:
outside entry into 1F sets6; internal 1F/B1F transitions and same-map reload retain
the offset; Flash clears to0; Save/Continue retains; leaving, Escape Rope and
blackout clear. New Game initializes0. An outside entry directly into B1F rejects.
Legal source warp/connection validation remains with the existing map loader.

## Unapplied root integration

Apply the original `field-cut-flash/root-api.patch` first, then this packet's
`root-integration.patch`, adapting context to the composed root. Both were applied
only in a private compile stage. The second patch adds the new import, the
player-only resolver dependency, FieldWorld/darkness adapters, explicit blackout
and escape reasons, and retained traversal rollback in the Escape Rope owner.
The escape patch is necessary: a failed transport must restore the session's
world/location/actors/offset as well as its existing native runtime checkpoint.
A rollback rebuild uses `fieldRestore=true`.

`host-boundary.patch` is separate and unapplied. It extends only the Cerulean
host boundary schema validator for canonical version2, retaining archived v1
validation. It rejects missing/extra/invalid field data. No driver was edited.
Root should update hard-coded test expectations of SessionCodec1 and the older
field packet's contract that intentionally EXPECTS the blocked-endpoint failure.
That limitation is now the success case in the new suite. The returned integration
patch also uses the optional player resolver in the original field terrain
commit's PLAYER preflight. Its checkpoint preflight stays strict; no existing
field intent/state implementation was edited in this branch.

Add `tools/field-world/sdk_imports.lua` to the private harness overlay, after the
original packet imports. Do not add dev modules to production imports. No
existing Scene, field-move state/intent, party/battle UI, dev import driver or
baseline was changed by this branch.

## Composition with Anne/Surge and daycare

Inspected read-only from `4c851502d89a4faa1e37fabf93a16e27c4dbfc3e`:
`tools/patches/vermilion-story-root-api.patch`, SHA-256
`1a6ff9edd519910db7f4da612e405f832083cf2d958e07f82ef1596047de4ef0`.
It was NOT applied. Root reports gifts at `acaa8e2` and readability at `e27a807`;
this branch does not contain those compositions.

- Its Thunder badge addition is independent; retain it alongside Boulder/Cascade.
- Both packets append owner APIs to GameSession. Merge both append blocks; retain
  this packet's fieldWorld initialization, codec restoration and traversal field.
- Its `transactScene` calls lexical `location(deps, scene.location, candidate)`.
  Pass `true` for that PLAYER location so source scenes can run while the player
  stands on a restored Cut tree. Keep its checkpoint call strict.
- After a successful scene commit, call `self:invalidateFieldWorldContext()`.
  Keep its existing scene epoch/world RNG guard as well. This invalidates retained
  darkness tuples even if the scene leaves the player on the same map/coordinate.
  Failed scene transactions must preserve offset and field epoch. Scene writes
  should retain fieldWorld unless they explicitly invoke a legal map lifecycle.
- Its DoorWarp refusal must happen before onLeave or FieldWorld entry. A blocked
  Anne exit must not reset a tree or clear darkness. Its extra `door` argument to
  onLeave remains intact; our hook is in OverworldState.enter, not DoorWarp.
- A scene that deliberately reloads/warps uses the lifecycle reason; a menu or
  battle return does not. Existing transport rollback must use fieldRestore.
- Daycare's returned owner patch must preserve the optional player resolver and
  fieldWorld owner. If it adds another persisted field, root must compose a
  single coherent envelope/version migration rather than independently assigning
  a conflicting version2. No daycare file or patch was changed here.

## Verification and remaining acceptance

Environment was sourced. Eleven focused host checks pass: eight existing field
pin/generator checks and three new primary/schema checks. The host boundary test
applies the RETURNED patch to a temporary driver copy and evaluates only its
Python envelope schema; no Lua emulation or fake SDK is used.

Production and composed private **SDK 3.1.2 compilation pass**. Durable stages:
`~/Developer/Pokemon-PlayDate-env/preparation/field-world-owner/final/production`
and `final/sdk-prepared`; `final/verification.json` records fingerprints and
compile-only status.
Compilation is not execution. Reproduce with a NEW output directory:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 -m unittest tools.tests.test_field_move_data tools.tests.test_field_world_data -v
python3 tools/field-world/compile_prepared.py --output "$HOME/Developer/Pokemon-PlayDate-env/preparation/field-world-owner/NEW-RUN"
```

Thirteen new real-SDK cases are prepared: under-tree reset and actual Player step
off/reentry rejection; codec Continue reset with unchanged position/unrelated
delta; real GameSaves disk save/Continue; native-view and session rejection
rollback; menu/battle-lifecycle retention and real reload; New Game; all other
blocked Route2 locations strict; stale runtime guard; Flash offset codec/Continue
and one-shot epoch CAS with unchanged RNG; declared future-map adapter read/clear, replacement-session
and floor CAS with schema roundtrip; declared Rock Tunnel transition
policy; v1 migration and invalid data. They use production owners and native SDK
objects. The Rock Tunnel cases exercise the declared transition policy and saved
offset owner, not installed Rock Tunnel geometry or a rendered darkness effect.

Root must execute these cases, inspect the field effect, and accept real native
map/transport/Save/Continue journeys on the composed source. Real Flash adapter
use on installed dark maps, renderer behavior, process restarts, native device
acceptance, full suites and protected-pixel checks remain pending root.

## Routine policy and fidelity recommendation

Use the packet's pinned pokered source for field lifecycle and palette state;
keep the already selected B2W2 battle rules and data untouched. No permission is
needed for this reversible owner preparation. Suggested root fidelity rows:

1. Preserve the original restored-tree player coordinate on reload/Continue;
   allow standing only at exact generated Cut endpoints, with normal collision
   on the next destination. This is a narrow codec accommodation, not teleport
   or persistent Cut.
2. Old schema1 saves lack palette provenance; migrate to light0 without inferred
   Flash history. New schema2 saves preserve original wMapPalOffset semantics.

The previous packet's bounded animation commit timing and meaningful-Flash guard
remain its own recommendations. This branch does not edit the fidelity ledger or
claim acceptance of them.
