# Lane K fidelity sweep

Pinned reference: pret/pokered `af519899719f0754965776faac0e836a3b906e6d`.
Tree: `6e4bc90fe6c9c72a23f8249ff453babc777193aa`.
There is no pokered checkout on this VM. Labels below are the ones already cited in this tree, checked against the current Lua and JSON.

Host module: `tools/tests/test_lane_e_fidelity.py`.
Five landed checks pass. Two gap checks are `expectedFailure` until E applies the patches named below.

## Pass

| Item | Where it already is | Label |
| --- | --- | --- |
| Blackout page and warp | `Battle:_resolveFaintCheckpoint` prints `is out of useable POKéMON!` and `blacked out!`, then `BattleState` calls `returnToCheckpoint`. `intro.stage == "rival_fight"` keeps the lab line and does not black out. A lost script returns before `descriptor.lost` when the battle blacked out, which is the Route 22 rival wipe. | `text/text_2.asm` `_PlayerBlackedOutText2`. `scripts/Route22.asm` `Route22Rival2AfterBattleScript` returns on `LOST_BATTLE`. |
| Shift YES/NO | `Will <PLAYER> change POKéMON?` and `shiftMenu:show({"YES", "NO"})`. | `text/text_1.asm` `_TrainerAboutToUseText`, then `TWO_OPTION_MENU`. |
| Nurse YES/NO | `EventState:heal` shows `{"YES","NO"}`. | `scripts/Pokecenter.asm` nurse prompt, `TWO_OPTION_MENU`. |
| Viridian Gym spinners | `EndgameStory.check` dispatches `pokered:VIRIDIAN_GYM:script:arrow` to `EndgameStory.arrow`. `visual.json` has the spinner cells and `SFX_ARROW_TILES`. | `scripts/ViridianGym.asm` arrow tiles. |
| Elite Four and Champion pics | `story.json` `class_source` is `OPP_LORELEI`, `OPP_BRUNO`, `OPP_AGATHA`, `OPP_LANCE`, and champion `OPP_RIVAL3`. PNGs exist under `Source/images/title/trainers/` and `drawTrainer` loads that path. | `constants/trainer_constants.asm`. |
| Prize, mart, daycare, and service yen | Prize text contains `<PLAYER> got ¥@`. The mart uses `GbFont.drawMoneyRight("¥"`. Daycare and the Kanto service windows draw the figure with `GbFont` yen. The PC storage screen does not draw a balance. `TitleIdle` maps `¥` to `$f0`. | `data/text/text_2.asm` `_MoneyForWinningText`. Charmap money sign `$f0`. |

## Fail

| Item | Live behavior | Patch |
| --- | --- | --- |
| Viridian Gym trainer line of sight | `trainerRow` sets `talk_only = true` for every endgame row. `SourceActors.trySight` returns before sight, and `TrainerEvents` reports `trainer-has-no-sight` when `talk_only` is set. Viridian Gym objects 2–9 have sight 4/4/4/2/3/4/3/4. Giovanni (objects:1) has no sight. Elite Four entries have sight 0. Victory Road shares `trainerRow`, so a positive sight there is the same gap. | `tools/notes/lane-e-viridian-sight.patch` sets `talk_only = (row.sight or 0) == 0`. `scripts/ViridianGym.asm`. |
| Trainer-card money | `PauseState:draw` prints `MONEY/$` with the system font. | `tools/notes/lane-e-money-yen.patch`. `engine/menus/start_sub_menus.asm` `TrainerInfo_NameMoneyTimeText`. |
| Pay Day pickup | The hit says `Coins scattered everywhere!` and adds `5 * level` to `payDayCoins`. `BattleState:finish` credits that total on a win and never shows it. | Same patch. On a win, before the victory message, say `<PLAYER> picked up` / `¥<coins>!`. `data/text/text_2.asm` `_PickUpPayDayMoneyText`. The scatter line is `text_3.asm`. |
