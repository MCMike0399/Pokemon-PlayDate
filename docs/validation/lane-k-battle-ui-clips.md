# Charmander E4 battle-UI gaps

pret/pokered `af519899719f0754965776faac0e836a3b906e6d`. The message queue landed in `603aac90`. The learn-box sketch stays unapplied. The shift tests stay red. None use `expectedFailure`. Lane K does not edit `Source/`.

## Message queue

`tools/tests/test_lane_k_message_queue.py`. A mashed A on `LORELEI: You will lose!` installs `BRUNO is about to use ONIX!` on frame 12, the same press that finishes the dialog confirm.

`home/print_text.asm` `PrintLetterDelay` reveals the line. `home/joypad.asm` `WaitForTextScrollButtonPress` takes one new A for that page. `BattleScene:handleInput` calls `battle:handleInput` on that same A, and `syncMessage` shows the next say before draw.

Sketch: `tools/notes/lane-e-message-queue-confirm.patch`. Remember `messageReady` from before `Dialog:handleInput`, and advance the script only when it was already true. With the sketch applied, the host prints `queue-held`. The existing `test_lane_e_learn_pages.py` still passes.

## Shift YES/NO on a fainted lead

`tools/tests/test_lane_k_shift_slots.py`. SHIFT, Charizard fainted, Weepinbell benched:

- Bruno’s Onix faints with Hitmonchan waiting. The script sends Hitmonchan and ends in `forcedSwitch` (`Choose a POKEMON!`). `shiftChoice` stays nil.
- Lorelei’s Jynx faints with Lapras waiting. Lapras is sent the same way.

`engine/battle/core.asm` `HandleEnemyMonFainted`: a battle mon at 0 HP goes through `ChooseNextMon`, then `ReplaceFaintedEnemyMon`. `ChooseNextMon` loads that mon and calls `SendOutMon` while the fainted foe is still active. `ReplaceFaintedEnemyMon` then prints `_TrainerAboutToUseText` and opens `TWO_OPTION_MENU` when `BIT_BATTLE_SHIFT` is clear, the party has a bench, and the battle is not a link or the first send-out (`data/text/text_2.asm`). `Battle:finishRound` asks only when `self.player:isAlive()` (`Source/battle/battle.lua`). A living lead still gets the question; these two clip slots are the fainted lead. `eligibleForcedReplacements` also rejects a fainted target, so dropping the `isAlive` check alone raises on `#nil`.

`test_question_follows_the_player_replacement` requires `eligibleForcedReplacements` to return the bench for that fainted lead, then commits Weepinbell through `Battle:chooseParty`, then requires the YES/NO while Onix or Jynx is still the active foe. The current function returns `inactive-target`. The current script sends Hitmonchan or Lapras first. After Weepinbell is sent, that foe is already active and `shiftChoice` is still nil. Asking while Charizard is fainted also fails this test. No patch.

## Learn box name

`tools/tests/test_lane_k_learn_name.py` asserts the pokered multi-page contract. `_TryingToLearnText` puts `wStringBuffer` on the `cont` after `trying to learn`, so `FLARE BLITZ` is on the following page while YES/NO is still closed. The test does not require the name on page 1.

`LearningState:draw` paints through `battleText`, and that box stops after two rows. `tools/notes/lane-e-learn-box-name.patch` adds the name as a third line of page 1, so the painter drops it. Do not apply that sketch as-is. E chooses: keep this multi-page contract, or widen the box.
