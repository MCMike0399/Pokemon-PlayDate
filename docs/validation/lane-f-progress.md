# Lane F audio

Branch `cursor/lane-f-audio` from `bf92c4fc`. Source of truth is pret/pokered `af519899719f0754965776faac0e836a3b906e6d`. Map, battle, jingle, and cue rows are generated into `Source/audio/events.lua` with file:line citations. Decisions live in `Source/audio/select.lua` and do not touch Playdate or gameplay state.

## What the observer does

`Source/game/kantoAudio.lua` imports events, select, and the engine. It does not import `audio/scores`. The engine loads `audio/score/<name>.lua` on first play and `audio/cries` on the first cry. `tools/measure_boot_budget.py` still uses `POOL_BYTES` 16645684 and `LUA_PEAK_BUDGET_KIB` 14000. A Simulator boot with the hook applied was not measured: this VM has no Playdate SDK.

Once lane E imports `game/kantoAudio` and calls `KantoAudio.updateGame(game)` after `machine:handleInput()`, the observer plays:

- Title bed `Music_TitleScreen` (`engine/movie/title.asm`) instead of stopping.
- The songs.asm theme for all 248 map rows, which covers all 222 installed maps. Authored aliases include `oaks_lab`.
- Battle music from `audio/play_battle_music.asm` `PlayBattleMusic`: gym flag, then wild (opponent below `OPP_ID_OFFSET` 200), then `OPP_RIVAL3` final, then `OPP_LANCE` gym, otherwise trainer. A nil `gymLeaderNo` infers Brock, Misty, Lt. Surge, Erika, Koga, Blaine, and Sabrina. Giovanni infers gym music only in `pokered:VIRIDIAN_GYM`. An explicit 0 stays trainer music.
- Low HP from `GetHPBarLength` plus `GetHealthBarColor`: the player's living mon, red when the 48-pixel bar is under 10. Not a 20% test.
- Center heal: `SFX_HEALING_MACHINE` then `Music_PkmnHealed`.
- Victory music while `battle.outcome` is `"victory"` (`Music_DefeatedWildMon`, `Music_DefeatedTrainer`, or `Music_DefeatedGymLeader`, the last also for the Champion). Caught uses `SFX_CAUGHT_MON`. A level change on `battle.player` uses `SFX_LEVEL_UP`.
- Cries when the battle scene's `introPhase` becomes `"ready"` (wild, including Articuno, Zapdos, Moltres, and Mewtwo) and when `playerShown` or a trainer `enemyShown` changes.
- Pause open `SFX_START_MENU`; other menu opens and cursor moves `SFX_PRESS_AB`. Text advance on A is the same press-AB cue. The title menu does not play the start-menu sound.
- Evolution: `SFX_TINK`, the previous species' cry, `Music_SafariZone`, then the new species' cry (`engine/movie/evolution.asm`). There is no evolution fanfare.
- Credits and Hall of Fame ceremony beds. The Hall of Fame map song in songs.asm stays Pallet Town; the ceremony is a different cue.
- PC on, enter, withdraw/deposit, and off from `PCState` phase changes.
- Door, ledge (`player.isJumping`), Cut, and Strength boulder from visible state fields.
- Surf and bicycle from `game.lastFieldTravel.mode` and a completed bicycle field-gear result. Both are music (`home/audio.asm` `PlayDefaultMusicCommon`), not sound effects.

`KantoAudio.playCue`, `playJingle`, `playSFX`, `playCry`, `setTraversal`, and `trainerJingle` are the calls the patches use. `playSFX("heal")`, `"menu"`, `"hit"`, `"faint"`, `"arrow_tiles"`, and `"denied"` still resolve, so endgame cues are not no-ops once the global exists.

## Handoff

Apply `tools/notes/lane-e-audio-hooks.patch` only. It adds the main import and `updateGame`, the trainer meet jingle (rivals get `meet_rival` because `PlayTrainerMusic` returns without one), surf and bicycle `setTraversal`, and the Poké Flute cue. `tools/audio/root-hooks.patch` is the main-file subset; do not apply it as well.

Do not apply `tools/audio/cry-hooks.patch` while `noteCries` remains in the observer. That patch cries at the same iris and send-out moments.

`tools/notes/lane-g-audio-hooks.patch` calls title music and the pause start-menu sound. Title music is idempotent with the observer. The pause call doubles `SFX_START_MENU` if the observer is active. `tools/tests/test_lane_e_audio_hooks.py` and `tools/tests/test_lane_g_audio_hooks.py` are `expectedFailure` until those production lines exist. `git apply --check` passes for all four patches.

## Fidelity ledger for lane E

- Voice 4 uses the SDK noise oscillator, not the NR43 LFSR (`Source/audio/engine.lua`).
- Pulse envelopes use SDK ADSR paced at 64 Hz, not the hardware envelope.
- A jingle replaces the music bed instead of stealing hardware channels; the bed's clock keeps advancing underneath.
- Pitch slides snap to the target note. `menu`, `text`, and `start_menu` lengthen sub-frame gates to 3+5 ticks so a 30 FPS observer cannot drop them.
- Badge scripts name `SFX_GET_KEY_ITEM`. The audio2 bank alias (level-up or `SFX_BALL_POOF`) is not reproduced.
- Surf is `Music_Surfing` and the bicycle is `Music_BikeRiding`. Neither is an SFX.
- Evolution's bed is `Music_SafariZone`.
- Articuno, Zapdos, Moltres, and Mewtwo use `Music_WildBattle` because their species ids are below `OPP_ID_OFFSET`. The static `PlayCry` sites are `scripts/SeafoamIslandsB4F.asm`, `scripts/PowerPlant.asm`, `scripts/VictoryRoad2F.asm`, and `scripts/CeruleanCaveB1F.asm`.
- The door cue treats `door.connection` as inside. That is not `PlayMapChangeSound`'s `$0b` tile test.
- `Music_CinnabarMansion` channel periods are 9315, 1728, 3888, and 648 ticks. Their joint loop is tick 1788480 and is not shipped. The score loops at tick 9315, so channels other than channel 1 seam.
- Bench level-ups and item, key-item, and badge fanfares are not visible on the stack. `playCue("item")`, `playCue("item2")`, `playCue("key_item")`, and `playCue("badge")` are the calls. Oak's `MUSIC_MEET_PROF_OAK` is `playCue("meet_oak")` and is not started by the trainer-jingle hook.

## Tests

Host checks with `POKERED_REFERENCE_DIR=/tmp/pokered`: `tools.tests.test_audio_events`, `tools.audio.test_scores`, `tools.audio.test_cries`, `tools.tests.test_audio_hooks`, `tools.tests.test_boot_budget`, and the two expected-failure lane hook modules. `scores.py --check`, `cries.py --check`, and `events.py --check` reproduce the generated files. Loop points were compared with `ScoreTrace` except the three chirp adaptations, the hand-built low-HP alarm, and the mansion seam above.

## Simulator clip

No clip was recorded. `pdc` is not installed and `PLAYDATE_SDK_PATH` is empty, and no earned-save path was available. Nothing was teleported or edited to invent one.
