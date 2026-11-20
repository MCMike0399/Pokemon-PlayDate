# Lane K fidelity sweep on 3ddb9667

Tip: `3ddb966765346a899188860b116161de27c03ffd`. `Source/` is `2e7863ff`. Reference: pret/pokered `af519899719f0754965776faac0e836a3b906e6d` at `/tmp/pokemon-host/pokered`.

## Pass

| Item | Where | pokered |
| --- | --- | --- |
| Blackout text | `Battle:_resolveFaintCheckpoint` says `<PLAYER> is out of useable POKéMON!` and `<PLAYER> blacked out!`. The lab rival is the exception. | `text/text_2.asm` `_PlayerBlackedOutText2` |
| Blackout respawn | `BattleState:finish` heals and `GameContext:returnToCheckpoint()`. A blackout returns before a lost script, so the Route 22 rival victory line does not resume. | `scripts/Route22.asm` jumps away on `LOST_BATTLE` |
| Bruno wipe is the last heal, not the PC door | The Indigo lobby nurse stores checkpoint `pokered:INDIGO_PLATEAU` `(9, 6)` facing down. That is the outdoor fly warp, not the lobby PC door. `SetLastBlackoutMap` writes `wLastMap` at heal time, and the lobby’s previous map is the plateau. A wipe in Bruno’s room uses that stored checkpoint. | `engine/events/set_blackout_map.asm`. `data/maps/special_warps.asm` `fly_warp INDIGO_PLATEAU, 9, 6`. `engine/events/pokecenter.asm` calls `SetLastBlackoutMap` |
| Shift YES/NO | `Will <PLAYER>\nchange POKéMON?` and `shiftMenu:show({"YES", "NO"})`. | `text/text_1.asm` then `TWO_OPTION_MENU` |
| Nurse YES/NO | `EventState` shows `{"YES","NO"}`. | `scripts/Pokecenter.asm` |
| Viridian spinners | `EndgameStory` returns `spin = true` for the gym arrow script. | `scripts/ViridianGym.asm` |
| Viridian line of sight | `talk_only = (row.sight or 0) == 0`. Sight greater than 0 is no longer talk-only. | `scripts/ViridianGym.asm` object movement |
| Elite Four and Champion pics | `class_source` values are `OPP_LORELEI`, `OPP_BRUNO`, `OPP_AGATHA`, `OPP_LANCE`, and champion `OPP_RIVAL3`. `LORELEI.png`, `BRUNO.png`, `AGATHA.png`, `LANCE.png`, and `RIVAL3.png` are under `Source/images/title/trainers/`. | `constants/trainer_constants.asm` |
| Yen | Pay Day says `picked up\n¥`. The trainer card draws `¥` through `GbFont.drawMoneyLine`. Marts, daycare, and services use the same glyph. | Charmap money sign `$f0`. `text/text_2.asm` `_PickUpPayDayMoneyText` |

## Fail

No new fidelity gap in this sweep. The sight and yen gaps from the `6e4bc90f` note are in the tree now.
