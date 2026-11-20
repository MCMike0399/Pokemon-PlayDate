# Charmander E4 battle-UI gaps

pret/pokered `af519899719f0754965776faac0e836a3b906e6d`. Three host tests stay red for E. None use `expectedFailure`. `Source/` is unchanged. Two sketches are unapplied (`git apply --check` succeeds).

## Message queue

`tools/tests/test_lane_k_message_queue.py`. A mashed A on `LORELEI: You will lose!` installs `BRUNO is about to use ONIX!` on frame 12, the same press that finishes the dialog confirm.

`home/print_text.asm` `PrintLetterDelay` reveals the line. `home/joypad.asm` `WaitForTextScrollButtonPress` takes one new A for that page. `BattleScene:handleInput` calls `battle:handleInput` on that same A, and `syncMessage` shows the next say before draw.

Sketch: `tools/notes/lane-e-message-queue-confirm.patch`. Remember `messageReady` from before `Dialog:handleInput`, and advance the script only when it was already true. With the sketch applied, the host prints `queue-held`. The existing `test_lane_e_learn_pages.py` still passes.

## Shift YES/NO on a fainted lead

`tools/tests/test_lane_k_shift_slots.py`. SHIFT, Charizard fainted, Weepinbell benched:

- Bruno’s Onix faints with Hitmonchan waiting. The script sends Hitmonchan and ends in `forcedSwitch` (`Choose a POKEMON!`). `shiftChoice` stays nil.
- Lorelei’s Jynx faints with Lapras waiting. Lapras is sent the same way.

`engine/battle/core.asm` `HandleEnemyMonFainted`: a battle mon at 0 HP goes through `ChooseNextMon`, then `ReplaceFaintedEnemyMon`. That second step still prints `_TrainerAboutToUseText` and opens `TWO_OPTION_MENU` when `BIT_BATTLE_SHIFT` is clear, the party has a bench, and the battle is not a link or the first send-out (`data/text/text_2.asm`). `Battle:finishRound` asks only when `self.player:isAlive()` (`Source/battle/battle.lua`). A living lead still gets the question; these two clip slots are the fainted lead. `eligibleForcedReplacements` also rejects a fainted target, so dropping the `isAlive` check alone raises on `#nil`. The question belongs after the player’s replacement is committed and before the next foe is sent. No patch.

## Learn box name

`tools/tests/test_lane_k_learn_name.py`. `LearningState:showAsk` draws `askPages[1]`, which is `CHARIZARD is` / `trying to learn`. The opened box omits `FLARE BLITZ`.

`data/text/text_4.asm` `_TryingToLearnText` puts `wStringBuffer` on the `cont` immediately after `trying to learn`. Sketch: `tools/notes/lane-e-learn-box-name.patch` appends the name on that first page. With the sketch applied, the new test prints `learn-name-shown` and `test_lane_e_learn_pages.py` still passes. The battle box is two rows (`battleText` / `text_boxes.asm`); E should confirm the name is painted, since page 1 can now be three lines.
