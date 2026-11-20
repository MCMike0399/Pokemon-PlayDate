# Lane K patch preverify

Tip: `6e4bc90fe6c9c72a23f8249ff453babc777193aa`.
`origin/main` and `origin/cursor/lane-e-integration` are that commit.
Host checks: `git apply --check`, then the module under `tools/tests/`. E has not moved past `6e4bc90f`. The later suite record is `docs/validation/lane-k-suite-6e4bc90f.md`.
`Source/` was not left patched. `MallocPoolSize` stays 16645684.

## Hand to E

Apply in this order. The files do not overlap, so a later patch does not depend on an earlier one. Order keeps the Miguel visual pair together, then the battle-scene stencil, then the two fidelity gaps.

| Order | Patch | Apply | Live test until E lands it |
| --- | --- | --- | --- |
| 1 | `tools/notes/lane-e-gym-terrain-tones.patch` | clean | `tools/tests/test_lane_e_gym_terrain.py` |
| 2 | `tools/notes/lane-e-flower-tile-03.patch` | clean | `tools/tests/test_lane_e_flower_tile.py` |
| 3 | `tools/notes/lane-e-battle-text-flicker.patch` | clean | `tools/tests/test_lane_e_battle_text_flicker.py` |
| 4 | `tools/notes/lane-e-viridian-sight.patch` | clean | `tools/tests/test_lane_e_fidelity.py` (`test_viridian_trainers_are_not_talk_only`) |
| 5 | `tools/notes/lane-e-money-yen.patch` | clean | `tools/tests/test_lane_e_fidelity.py` (`test_trainer_card_and_payday_use_yen`) |
| 6 | `tools/notes/lane-e-message-queue.patch` | clean | `tools/tests/test_lane_e_message_queue.py` |
| 7 | `tools/notes/lane-e-possessive.patch` | clean | `tools/tests/test_lane_e_possessive.py` |
| 8 | `tools/notes/lane-e-shift-hold.patch` | clean | `tools/tests/test_lane_e_shift_hold.py` |

Each live assertion is `@unittest.expectedFailure` and fails on this tip. The same modules assert `git apply --check` and the patched temp tree. Remove the expected failure when the patch lands.

1. Gym terrain tones. `Source/data/terrainToneOverrides.json` plus the atlas generator. Tileset `GYM` only, schema 1, `approved-by-miguel-2026-11-19`. `tones is None` stays the qualified Bayer formula. The patch does not mention `shade.lua` or `Shade.LIGHT`.
2. Flower tile `$03`. `tools/generate_kanto_maps.py` replaces that cell with `gfx/tilesets/flower/flower1.png` when `settings[4]` is `TILEANIM_WATER_FLOWER`. `home/vcopy.asm` `UpdateMovingBgTiles` `.flower`; flower1 is the resting phase.
3. Battle text flicker. Distinct from the GB-font snap. `BattleScene:draw` still sets the iris stencil and clears it after `drawBattleField`, so the message box is clipped for the first frames. The patch clears the clip and the stencil inside `drawBattleField` immediately before `local boxY = 180`.
4. Viridian sight. `EndgameStory.trainerRow` sets `talk_only = true` for every endgame trainer. `SourceActors.trySight` and `TrainerEvents` skip `talk_only`, so the Viridian Gym ranges in `story.json` (4/4/4/2/3/4/3/4) never fire. The patch sets `talk_only = (row.sight or 0) == 0`. Giovanni and the Elite Four stay talk-only because their sight is 0. The arrow-tile spinner is already on this tip and is not part of the patch.
5. Money yen. Two strings the earlier yen patch did not cover. The trainer card draws `MONEY/$` in `PauseState:draw`; `engine/menus/start_sub_menus.asm` `TrainerInfo_NameMoneyTimeText` uses the charmap money sign. Pay Day says `Coins scattered everywhere!` and credits the coins with no pickup page; `data/text/text_2.asm` `_PickUpPayDayMoneyText` is `<PLAYER> picked up` / `¥@` / the BCD total / `!`, once, on a win. The patch draws the card figure with `GbFont.drawMoneyLine` and says that page before the victory message. Do not re-apply `lane-e-yen-glyph.patch`.
6. Message queue. From lane I `51e1efc4`. `Dialog:handleInput` and `BattleScriptPhase:handleInput` still turn the page when A is held. `home/print_text.asm` `PrintLetterDelay` only shortens the letter wait while A is held. `home/joypad2.asm` `WaitForTextScrollButtonPress` requires `hJoyPressed`, a new edge. The live probe advances EXP, stat, Skull Bash, and recoil lines on a held A. The patched tree prints them and leaves the page up.
7. Possessive ligature. From the same lane I commit. `constants/charmap.asm` maps `'d` `$bb`, `'l` `$bc`, `'s` `$bd`, `'t` `$be`, `'v` `$bf`, `'r` `$e4`, `'m` `$e5`. The live font draws the apostrophe and the letter as two cells (`CHARIZARD' s`). The patch teaches `TitleIdle.nextTile` and uses it in `GbFont.drawString`, `GbFont.drawTight`, and `Dialog` wrap/clip. `CHARIZARD's` is 10 tiles.
8. Shift hold. From the same commit. The shift question is already its own page (`lane-e-shift-prompt.patch` is landed). YES/NO still accepts input on the same frame the question appears, including the A that dismissed "about to use". The patch waits until the question has finished printing and 10 frames have passed.

Orders 6 and 7 both edit `dialog.lua`. Either order applies: the other hunk lands with a small offset. Order 8 edits `battleScene.lua` only. All three also apply after the queued flicker and money-yen patches. Nine focused tests: 6 passed, 3 expected failures on the live tree.

## Already on this tip

These patches fail `git apply --check` because the change is in the tree. Do not re-apply them.

| Patch | First failing hunk |
| --- | --- |
| `lane-e-blackout.patch` | `Source/battle/battle.lua:1765`, `Source/game/battleState.lua:143` |
| `lane-e-player-back-scale.patch` | `Source/battle/battleScene.lua:1059` |
| `lane-e-nurse-audio.patch` | `Source/game/kantoAudio.lua:176` |
| `lane-e-hp-drain-menu.patch` | `Source/battle/battleScene.lua:667` |
| `lane-e-battle-font.patch` | `Source/battle/battleScene.lua:415`, `Source/ui/dialog.lua:216` |
| `lane-e-trainer-pic.patch` | `Source/game/endgameStory.lua:1204` |
| `lane-e-yen-glyph.patch` | `Source/data/endgame/play.json:462`, `Source/data/endgame/story.json:4543`, `Source/game/celadonServicesController.lua:551` |
| `lane-e-shift-prompt.patch` | `Source/battle/battle.lua:250`, `Source/battle/battleScene.lua:653` |
| `lane-e-battle-message.patch` | `Source/ui/dialog.lua:13` |

Send-out text box. Lane I still blits `_wrapped("battle-message")` with the system font inside the heavy box. This tip already calls `messageDialog:draw(true)` for that page, including the send-out line. `tools/tests/test_lane_e_sendout_textbox.py` passes and there is no send-out patch. The iris stencil above is the remaining battle-text gap.

## npc-trades

Closed. This branch and `main` are the same commit, so there is no head-only diff. The ledger on this commit (`docs/validation/progress.md`) records device suite `npc-trades` at 68 passed / 1 failed, the name `main` `bf92c4fc` already failed: `full party all 240 PC slots, source append order and survivor active identity`. `pewterProviderContracts` is 29 passed / 2 failed, the same two names. No npc-trades patch. This VM has no Playdate SDK, so that device score was not re-run here. The comparison is the shared SHA plus that ledger.
