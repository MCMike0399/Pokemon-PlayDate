# Earlier-region scene candidate

Branch: `wip/tutorial-escort`. Exact `66b9d99` was merged first in `9a28a4f`.
The merge retained that foundation's production-overlay capture-policy behavior;
its five capture-policy host tests passed. No scene change edits an existing file.
This is bounded 5.3 preparation, not campaign activation or milestone acceptance.

`Source/game/tutorialEscort.lua` owns an actual native Lua overlay state, keyed by
source object IDs. It uses real DialogState callbacks, a guarded YES/NO menu,
ordinary Player movement and opaque NPCMotion leases. New source recipes and
art grids live in `Source/data/tutorialEscort/scenes.json`. All durable state
continues to belong to GameSession. The scene never commits a quest/reward,
checkpoint, traversal snapshot, Pokémon, money, inventory, Pokédex or RNG change.

The old-man gate is source `EVENT_GOT_POKEDEX`, not possession of the parcel or
an independent tutorial-completed flag. Sleepy object 5 is visible before that
flag, awake object 7 afterwards (existing map bindings already implement those
predicates). The coordinate trigger is `(19,9)` before the flag; it shows private
property text and walks the player down one cell. Girl object 4 retains both
source dialogue branches. YES to “Are you in a hurry?” refuses the demonstration;
NO (including B at that menu) starts it. Repeating the tutorial is allowed.

`TutorialDemo` is an explicitly isolated presentation model. It takes no game,
session, player Pokémon or RNG reference. It shows exactly source level-5 Weedle,
the original old-man back art, simulated ITEM selection, the source 50-ball display,
and a deterministic successful catch through existing CaptureAnimation. This is
not an ordinary Capture transaction: source `item_effects.asm` jumps straight to
`.captured` for OLD_MAN, skips awarding the Pokémon/Pokédex and skips consuming a
player ball. The demo does not instantiate a combat Pokémon, save the player's
name into encounter data, or reproduce the MissingNo memory bug. Gen V gameplay
rules remain unchanged. The capture presentation uses the existing three-shake
successful noncritical receipt. Command delays are converted from 60 to 30 Hz;
the displayed bag has a bounded 30-tick pause rather than source menu key synthesis.

The guide uses source object `pokered:PEWTER_CITY:objects:5`. Source trigger cells
are `(35,17)`, `(36,17)`, `(37,18)`, `(37,19)` while Brock is undefeated; direct
interaction from `(34,16)` is also implemented. The generator derives all five
player prefixes, the reverse-consumed player RLE, forward NPC RLE and five-right
NPC departure directly from the pinned ASM. Endpoints are player `(10,18)` and
guide `(12,18)`, facing left. Source hide/reset/show is executed by NPCMotion's
saved lease pose. No scene assigns NPC coordinates. Source's noted screen-X
misalignment bug is not reproduced.

Two explicit occupancy adaptations need root review: the player yields before
the final two right steps until the guide clears their shared aisle; script pause
bytes consume one native update each. The source otherwise ignores occupancy.
A blocked scene stops and offers A retry / B cancellation. Cancellation restores
the player's scene-entry transient pose and the guide's saved lease pose in the
same context, including partial interpolation. New-context exits never reposition
a replacement player/session/zone. Context replacement or reattachment invalidates
callbacks/leases; incomplete steps roll back through NPCMotion on release. If a
saved actor home has become occupied, the reset refuses it and preserves the last
completed legal pose. Runtime context replacement remains the caller's rebuild
responsibility, as in the foundation. No durable scene phase or save schema is added.

## Root integration (patch files only; not applied in this branch)

1. Apply `npc-motion.patch`: add saved lease pose, guarded facing and reset methods.
   Reset is allowed during owner exit after stack removal, but requires the same
   live session, player, zone, attachment token and owner epoch. Saved origin
   occupancy/collision are checked. Start/update/facing still require top ownership.
2. Apply `arrival-transit.patch`: exactly this guide may lease-transit `(16,18)`,
   the arrival mat below the Gym. Existing geometry remains protected. The actual
   Gym warp `(16,17)`, every other actor and autonomous wandering remain excluded.
   This is necessary to execute the source five-right departure with reservations.
3. Apply `registration.patch`: import/register the state, intercept these bespoke
   source interactions and trigger checks, supply script positions, add diagnostics
   and register the SDK contracts in the harness-only overlay.

The registration patch is deliberately unapplied. The shared source event JSON,
map manifest, existing data outputs, ordinary battle/domain code, campaign and
ledger are unchanged. Root may fold these hooks into its eventual bespoke-source
handler seam rather than use the exact dispatch insertion. Imports require
EventState, EventText, CaptureAnimation, TileFactory and SpriteFactory first.
The source actor metadata must be supplied before attaching NPCMotion.

## Checks and pending acceptance

- Seven new host tests pass: pinned bytes, deterministic output, mutation rejection,
  independent source route transcription/endpoints, script catch exception, direct
  art pixel transcription and stable IDs/conditions. No host Lua emulation is used.
- Scoped source/event/motion host suite: 52 passed, no skips.
- `make test-harness`: 54 passed, no skips. Mock failure messages are expected tests.
- SDK production and explicitly registered contract builds compile in private stages.
  See `~/Developer/Pokemon-PlayDate-env/evidence/tutorial-escort-build-20261026-02`.
  These are compile results only; no Simulator was launched and no native Lua ran.
- Twelve SDK witnesses are provided, unexecuted. They cover YES/NO, source gates,
  full session-codec equality before/after the demo, both RNG streams, stale callbacks,
  overlays/new context, five route entries/endpoints/reset, source eight-frame art,
  reservations, cancellation/reentry, blocked retry, attachment epochs and the exact
  arrival-only transit policy. Fixtures are explicitly supplementary, not journeys.

After 5.2 acceptance, root must run the real SDK contracts, inspect new source art
at native size and in motion, and execute real-input before/after-parcel, both
hurry choices, repeat/abort, blocked retry and escort-trigger cases. Also exercise
Continue and boundary/overlay interruption with the integrated journey driver.
`tools/harness/scenarios/tutorial-escort.json` runs contracts after integration; it
is not a natural-input acceptance scenario. No fixture result is natural proof.
