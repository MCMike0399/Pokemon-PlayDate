# Lane F audio

Branch `cursor/lane-f-audio` from `bf92c4fc`. Source of truth is pret/pokered `af519899719f0754965776faac0e836a3b906e6d`. Map, battle, jingle, and cue rows are generated into `Source/audio/events.lua` with file:line citations. Decisions live in `Source/audio/select.lua` and do not touch Playdate or gameplay state.

## What the observer does

`Source/game/kantoAudio.lua` imports events, select, and the engine. It does not import `audio/scores`. The engine loads `audio/score/<name>.lua` on first play and `audio/cries` on the first cry. `tools/measure_boot_budget.py` still uses `POOL_BYTES` 16645684 and `LUA_PEAK_BUDGET_KIB` 14000. SDK 3.1.2 is installed in this VM. A boot-budget run with the lane E hook applied was not measured.

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
- `Music_CinnabarMansion` does not share one loop. Channel 1 loops at its `sound_loop 0` label, tick 0, period 9315. Channel 2 loops at tick 864, period 1728. Channel 3 loops at tick 0, period 3888. Channel 4 loops at tick 216, period 216. The joint LCM is 1788480 ticks and is not shipped. At tick 9315 only channel 1 returns to its label.
- Bench level-ups and item, key-item, and badge fanfares are not visible on the stack. `playCue("item")`, `playCue("item2")`, `playCue("key_item")`, and `playCue("badge")` are the calls. Oak's `MUSIC_MEET_PROF_OAK` is `playCue("meet_oak")` and is not started by the trainer-jingle hook.

## Tests

Host checks with `POKERED_REFERENCE_DIR=/tmp/pokered`: `tools.tests.test_audio_events`, `tools.audio.test_scores`, `tools.audio.test_cries`, `tools.tests.test_audio_hooks`, `tools.tests.test_boot_budget`, and the two expected-failure lane hook modules. `scores.py --check`, `cries.py --check`, and `events.py --check` reproduce the generated files. Every looped track is checked against its pokered `sound_loop 0` label. Songs whose channels share that label loop there. Songs whose periods meet at an LCM of at most 20000 ticks use one joint window at the latest label. Cinnabar Mansion is the one per-channel score. A first pass that is not note-identical keeps the register repeat, moved back one tick when that holds the downbeat.

## Simulator clip

Playdate SDK 3.1.2 ran under Xvfb `:99`. Audio was recorded with `ffmpeg -f pulse -i pd.monitor` from a PulseAudio null sink named `pd`. A `paplay` tone on that sink peaked at 21128, so the monitor is live. Every Simulator capture peaked at 0, including a square wave at amplitude 1 whose `playNote` returned true while `playdate.sound.getCurrentTime` advanced. The bezel control under the crank is labeled Volume and draws a speaker with a slash. Clicks, the wheel, and a drag left that slash in place. `setOutputsActive` was not called, and no production file was edited to chase the recording.

The pictures are a throwaway pdx that plays the real engine: title, Route 1, the male trainer jingle then the trainer bed, the Center heal (`SFX_HEALING_MACHINE` then `Music_PkmnHealed`), and Champion (`Music_FinalBattle`). The Simulator rejects `import()` after the pdx has loaded (`import() called outside of pdz loading` from `KantoSynth.music`), so the throwaway preloaded those scores. The production engine still imports on first play. There is no earned save and nothing was teleported.

The files are video only. sha256:

- `artifacts/lane-f/r2/sequence.mp4` `188cb88294d7ffe114c40eaab4cd696752352d48fef9b94d78b67882ff48eb65` covers the whole sequence.
- `artifacts/lane-f/r2/title.mp4` `c8d388e5753e812df0a31a487f3ecd7f4b533f3d43f23b49d7263e16a63f3e37`
- `artifacts/lane-f/r2/route1.mp4` `5e3407c8d2f5535dfee68f0bc5f4900c29943fbd6f8d6ba91589fd2ef3fde71d`
- `artifacts/lane-f/r2/trainer.mp4` `6d6fb038e3ed6906fa0c02111b9ce2dbd039074911a304b4abfc19a5f157ffa5` is the jingle, then the trainer bed.
- `artifacts/lane-f/r2/center-heal.mp4` `b2e6765a880241cf534d2916faddb32c84f7bf97a97c2cee7651b064bb543775`
- `artifacts/lane-f/r2/champion.mp4` `91ad50905f2f3001c3eb19b655dce463b31a656fb4d14349e2eca1eab7b04e83`
- `artifacts/lane-f/r2/kanto-cues.mp4` `df3eb59c911c796aa127284dfb498da7e435f6be98abfa1182f8f0182ce0a493` is the full take, which holds on Champion after the sequence.

## Sound gaps

These pokered sounds still have no playback from the running game. Scores that exist are named so a later hook can call them.

- Title attract (`engine/movie/title.asm`): `SFX_INTRO_CRASH` at line 160 and `SFX_INTRO_WHOOSH` at line 194 are not in the generated catalog. Leaving the attract mode plays `PlayCry` of `wTitleMonSpecies` at line 241. The observer starts `Music_TitleScreen` only.
- Evolution (`engine/movie/evolution.asm`): the observer plays `SFX_TINK`, the previous species' cry, `Music_SafariZone`, and on `result.kind == "complete"` the new species' cry. Cancel stores the old species and falls through `.done`, which stops the bed and cries that species. The observer does not cry on cancel.
- Hall of Fame: `EndgameStory.hallPhotos` sets `cry = mon.species` on each party photo and leaves the player photo without one. `updatePhotos` calls `EndgameStory.playCry` when the photo reaches `show`. That returns false until `KantoAudio` is imported. The ceremony bed is the observer cue on stack phase `hall-photo`, which waits on the same import.
- No field caller: `item`, `item2`, `key_item`, and `badge` (`home/text.asm` get-item fanfares), and `meet_oak` (`scripts/PalletTown.asm`, `MUSIC_MEET_PROF_OAK`). `playCue` is the API. The Poké Flute score exists; `SnorlaxStory` does not play it. That hook is the unapplied `tools/notes/lane-e-audio-hooks.patch`.
- `arrow_tiles` and `denied` are named in `Source/data/endgame/visual.json`. The story step plays them through `EndgameStory.playCue`, which returns false until `KantoAudio` is imported. The field observer does not watch gym spinners.
- The fidelity ledger above still stands: voice 4 is the SDK noise oscillator, envelopes are ADSR, a looping jingle replaces the audible bed, pitch slides snap, the door cue uses `door.connection`, and Surf and the bicycle are music.
