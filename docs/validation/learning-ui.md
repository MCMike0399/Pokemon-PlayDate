# Native move-learning overlay

`Source/game/learningState.lua` owns a temporary overlay around the existing `Dialog`, `BattleMenu` and `StateMachine` classes. Pokémon retains ownership of its durable pending choices. The overlay uses the existing system font, monochrome boxes, typewriter narration and directional/A/B input. It does not alter world assets, battle art, maps or the definition of a learning event.

## Root integration hooks

Import `game/learningState` after `Pokemon`, `Dialog`, `BattleMenu` and `State`; register `machine:register("learning", LearningState(game))`. The session owner calls `LearningState.open(game, pokemon, onComplete)` after the destination overworld has been established. It returns false for an empty queue and true for an active/opened session. Reoffering the same active Pokémon does not push a duplicate state; another Pokémon cannot steal an active session.

`BattleState:finish` should change to the appropriate overworld first, then invoke the context/session owner's `offerLearning` wrapper. That owner should also offer learning after other authorized XP grants. It must use the actual party Pokémon object and preserve its unresolved choices across forced transitions and save/reload. The overlay itself does not add a polling global manager or create replacement Pokémon objects.

Normal completion pops the overlay, resumes the world, clears view callbacks, then invokes `onComplete({kind="complete", results=..., pending=0})` once. A forced state exit cancels the presentation callbacks without resolving unchosen moves or invoking the completion callback. Subsequent sessions can resume the Pokémon's pending queue. Guarded callbacks from an earlier visit cannot act after exit/reentry.

Import `dev/learningContracts` and register `Contracts.register("learning", LearningContracts.run)` in the root-owned contract registry. `LearningState:getSnapshot()` provides detached semantic fields: `phase`, `move`, `choice_id`, `selected`, `message_kind`, `dialog_ready`, `remaining`, and `pokemon`. Root diagnostics should include this as `learning` and expose the number of unresolved Pokémon choices as `pokemon.pending_moves` alongside existing move/PP arrays.

## Player flow and cancellation

A free slot learns immediately through `Pokemon:resolveMoveChoice`, then shows the standard learned-move message. The state keeps input ownership until the player acknowledges it. Existing PP remains unchanged; the newly learned move starts at its defined maximum PP.

A full set shows LEARN / KEEP MOVES. LEARN opens the four known moves with current/max PP. Selecting a move opens FORGET MOVE / BACK; no model change occurs until FORGET MOVE is explicitly confirmed. B at confirmation returns to the same highlighted replacement slot; B in the move list returns to the initial prompt. The confirmed action shows separate forgotten/learned narration through the standard Dialog.

KEEP MOVES or B at the initial prompt opens “Stop trying to learn …?” with YES/NO. YES explicitly declines the current event and narrates that result; NO or B returns to the initial prompt. There is no normal “Later” dismissal or hidden decline. Cancel/back does not change moves, PP or pending choices. Each resolved message leads to the next pending event in order, including multiple moves at the same level.

A choice that has become already known is consumed without refilling PP or presenting a spurious replacement prompt. Auto-appending into a free slot is committed before its learned message; a later forced reset is not an undo operation. Unresolved choices remain on the Pokémon if presentation is interrupted.

The overlay saves/restores graphics font and draw offset. Draw is read-only with respect to learning/model/dialog timing. Every phase change and exit explicitly calls the documented [SDK `sprite.addDirtyRect`](https://sdk.play.date/3.1.2/Inside%20Playdate.html#m-graphics.sprite.addDirtyRect) for the400×240 screen, allowing the underlying dirty-sprite world renderer to erase departed menus and dialog boxes immediately.

## Runtime scenarios and evidence

Root fixture support required by these scenarios:

```json
{
  "op": "fixture",
  "options": {
    "intro": "skip",
    "opening": false,
    "zone": "reds_house_2f",
    "seed": 42,
    "player_pokemon": {"species": "charmander", "level": 5},
    "grant_xp": {"to_level": 7}
  }
}
```

`grant_xp` may instead provide an explicit `amount`. After constructing/resetting the player and applying the grant, the root-owned fixture invokes the same session learning owner used after a real battle. The fixture is not a replacement for the input flow: all learning decisions below use actual harness button presses and semantic awaits.

Runtime-owner commands, using fresh output directories:

```sh
python3 tools/harness/run.py --scenario tools/harness/scenarios/learning-free.json --output /private/tmp/pokemon-learning-free-unique
python3 tools/harness/run.py --scenario tools/harness/scenarios/learning-replace.json --output /private/tmp/pokemon-learning-replace-unique
python3 tools/harness/run.py --scenario tools/harness/scenarios/learning-multiple.json --output /private/tmp/pokemon-learning-multiple-unique
```

`learning-free` demonstrates Charmander5→7, native learned Ember narration, correct moves/PP and return to the world. Its `learning-free-before.png` and `learning-free-return.png` capture the same stationary bedroom scene; compare them exactly to verify no menu/dialog residue remains. This room has no changing water/flower tiles, and the fixture repeats the same camera/player state.

`learning-replace` demonstrates a full four-move set, PP-labeled list, B from confirmation, B from replacement, unchanged move/PP assertions before commitment, explicit replacement of Growl with Dragon Rage, both narration pages and native world return. `learning-multiple` demonstrates two same-level Bulbasaur choices, stop-confirmation B/NO paths, explicit decline of Poison Powder, then explicit Sleep Powder replacement. Fourteen400×240 captures are required across the scenarios. Root must inspect the actual images for readable text, selection/focus, no overlap and clean return, and rerun the original three-starter intro/battle regressions after integration.

## Validation status

The new files compile with the installed SDK into `/private/tmp/pokemon-learning-ui-compile.pdx`; `git diff --check` passed. The three scenario JSONs parse and contain bounded semantic awaits plus expected image outputs. No Simulator was launched by this worker.

Twelve `LearningContracts.run()` cases exercise the real SDK/controller/domain classes: empty queue, free-slot learning and visible message ownership, both back paths, explicit replacement/PP cleanup, explicit decline, stop-confirmation NO/B preservation, sequential events, interruption/listener cleanup/stale callbacks across phases and sessions, already-known PP protection, reentrant completion, and read-only drawing/offset restoration. They dispatch actual menu/dialog completion callbacks for lifecycle coverage; they do not claim native button/typewriter timing was tested. Root-owned Simulator execution, captured-image inspection and original-journey regression are pending until recorded by the integrator. Save/load and party-wide scheduling remain the session/persistence owners' responsibility.
