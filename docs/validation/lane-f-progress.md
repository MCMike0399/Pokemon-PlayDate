# Lane F audio

Branch `cursor/lane-f-audio` from `bf92c4fc`. Source of truth is pret/pokered `af519899719f0754965776faac0e836a3b906e6d`. Map, battle, jingle, and cue rows are generated into `Source/audio/events.lua` with file:line citations. Decisions live in `Source/audio/select.lua` and do not touch Playdate or gameplay state.

## What the observer does

`Source/game/kantoAudio.lua` imports events, select, and the engine. It does not import `audio/scores`. The engine loads `audio/score/<name>.lua` on first play and `audio/cries` on the first cry. `tools/measure_boot_budget.py` still uses `POOL_BYTES` 16645684 and `LUA_PEAK_BUDGET_KIB` 14000. SDK 3.1.2 is installed in this VM. A boot-budget run with the lane E hook applied was not measured.

Once lane E imports `game/kantoAudio` and calls `KantoAudio.updateGame(game)` after `machine:handleInput()`, the observer plays:

- Title clock, counted in observer updates because the port does not bounce the logo. `SFX_INTRO_CRASH` on update 20 (`engine/movie/title.asm:159`, after 16+4 bounce frames; `engine/movie/intro.asm:88` is the same score for the unported Gengar slash). `SFX_INTRO_WHOOSH` on update 68 (`engine/movie/title.asm:193`; that sound is not in intro.asm). `Music_TitleScreen` on update 102, which is 68 plus the traced 34-tick whoosh, covering the version scroll, `Delay3`, and `WaitForSoundToFinish`. Leaving attract (`confirm-new`, `confirm-recovery`, `message`, `closed`, or the title root going away) cries `title.idle.species`, the stand-in for `wTitleMonSpecies`.
- The songs.asm theme for all 248 map rows, which covers all 222 installed maps. Authored aliases include `oaks_lab`.
- Battle music from `audio/play_battle_music.asm` `PlayBattleMusic`: gym flag, then wild (opponent below `OPP_ID_OFFSET` 200), then `OPP_RIVAL3` final, then `OPP_LANCE` gym, otherwise trainer. A nil `gymLeaderNo` infers Brock, Misty, Lt. Surge, Erika, Koga, Blaine, and Sabrina. Giovanni infers gym music only in `pokered:VIRIDIAN_GYM`. An explicit 0 stays trainer music.
- Low HP from `GetHPBarLength` plus `GetHealthBarColor`: the player's living mon, red when the 48-pixel bar is under 10. Not a 20% test.
- Center heal: `SFX_HEALING_MACHINE` then `Music_PkmnHealed`.
- Victory music while `battle.outcome` is `"victory"` (`Music_DefeatedWildMon`, `Music_DefeatedTrainer`, or `Music_DefeatedGymLeader`, the last also for the Champion). Caught uses `SFX_CAUGHT_MON`. A level change on `battle.player` uses `SFX_LEVEL_UP`.
- Cries when the battle scene's `introPhase` becomes `"ready"` (wild, including Articuno, Zapdos, Moltres, and Mewtwo) and when `playerShown` or a trainer `enemyShown` changes.
- Pause open `SFX_START_MENU`; other menu opens and cursor moves `SFX_PRESS_AB`. Text advance on A is the same press-AB cue. The title menu does not play the start-menu sound.
- Evolution: `SFX_TINK`, the previous species' cry, `Music_SafariZone`, then `.done`. Success and cancel both stop that bed first. Success cries the new species. Cancel cries `info.from`, which is `wEvoOldSpecies` when `.evolutionCancelled` jumps to `.done`. There is no evolution fanfare.
- Credits and Hall of Fame ceremony beds. The Hall of Fame map song in songs.asm stays Pallet Town; the ceremony is a different cue.
- PC on, enter, withdraw/deposit, and off from `PCState` phase changes.
- Door, ledge (`player.isJumping`), Cut, and Strength boulder from visible state fields.
- Surf and bicycle from `game.lastFieldTravel.mode` and a completed bicycle field-gear result. Both are music (`home/audio.asm` `PlayDefaultMusicCommon`), not sound effects.
- Item, item2, key-item, and badge fanfares when an event is in phase `receipt` and `waiting` is a text label whose script plays `sound_get_item_1`, `sound_get_item_2`, `sound_get_key_item`, or a badge `sound_level_up`. The label map is `KantoEvents.fieldReceipts`.
- `Music_MeetProfOak` when the top dialog's first line is Oak's "Hey! Wait!" stop in Pallet Town (`Story.OAK_STOP`). That is the visible `scripts/PalletTown.asm` event.

`KantoAudio.playCue`, `playJingle`, `playSFX`, `playCry`, `setTraversal`, and `trainerJingle` are the calls the patches use. `playSFX("heal")`, `"menu"`, `"hit"`, `"faint"`, `"arrow_tiles"`, and `"denied"` still resolve, so endgame cues are not no-ops once the global exists.

## Handoff

Apply `tools/notes/lane-e-audio-hooks.patch` and `tools/notes/lane-e-audio-gaps.patch`. The hooks patch adds the main import and `updateGame`, the trainer meet jingle (rivals get `meet_rival` because `PlayTrainerMusic` returns without one), and surf and bicycle `setTraversal`. The gaps patch is the separate call sites: Hall of Fame ceremony bed and per-photo cries, `denied` and `arrow_tiles` (the endgame step and the field spinner), and the Poké Flute cue, which used to sit in the hooks patch. `tools/audio/root-hooks.patch` is the main-file subset; do not apply it as well.

Do not apply `tools/audio/cry-hooks.patch` while `noteCries` remains in the observer. That patch cries at the same iris and send-out moments.

`tools/notes/lane-g-audio-hooks.patch` calls title music and the pause start-menu sound. Title music is idempotent with the observer. The pause call doubles `SFX_START_MENU` if the observer is active. `tools/tests/test_lane_e_audio_hooks.py` and `tools/tests/test_lane_g_audio_hooks.py` are `expectedFailure` until those production lines exist. `git apply --check` passes for all five patches.

## Fidelity ledger for lane E

- Voice 4 uses the SDK noise oscillator, not the NR43 LFSR (`Source/audio/engine.lua`).
- Pulse envelopes use SDK ADSR paced at 64 Hz, not the hardware envelope.
- A jingle replaces the music bed instead of stealing hardware channels; the bed's clock keeps advancing underneath.
- Pitch slides glide. `Audio1_InitPitchSlideVars` stores the step and `Audio1_ApplyPitchSlide` walks it (`audio/engine_1.asm`); a step past the target is not written. The heal channel-1 glide is the audible case. `menu`, `text`, and `start_menu` lengthen sub-frame gates to 3+5 ticks so a 30 FPS observer cannot drop them.
- Badge scripts name `SFX_GET_KEY_ITEM`. The audio2 bank alias (level-up or `SFX_BALL_POOF`) is not reproduced.
- Surf is `Music_Surfing` and the bicycle is `Music_BikeRiding`. Neither is an SFX.
- Evolution's bed is `Music_SafariZone`.
- Articuno, Zapdos, Moltres, and Mewtwo use `Music_WildBattle` because their species ids are below `OPP_ID_OFFSET`. The static `PlayCry` sites are `scripts/SeafoamIslandsB4F.asm`, `scripts/PowerPlant.asm`, `scripts/VictoryRoad2F.asm`, and `scripts/CeruleanCaveB1F.asm`.
- The door cue treats `door.connection` as inside. That is not `PlayMapChangeSound`'s `$0b` tile test.
- `Music_CinnabarMansion` does not share one loop. Channel 1 loops at its `sound_loop 0` label, tick 0, period 9315. Channel 2 loops at tick 864, period 1728. Channel 3 loops at tick 0, period 3888. Channel 4 loops at tick 216, period 216. The joint LCM is 1788480 ticks and is not shipped. At tick 9315 only channel 1 returns to its label.
- Bench level-ups still have no stack field. Item, key-item, badge, and Oak's meet jingle play from the receipt label and the Pallet dialog, as above.

## Tests

Host checks with `POKERED_REFERENCE_DIR=/tmp/pokered`: `tools.tests.test_audio_events`, `tools.tests.test_audio_host`, `tools.audio.test_scores`, `tools.audio.test_cries`, `tools.tests.test_audio_hooks`, `tools.tests.test_boot_budget`, and the two expected-failure lane hook modules. `scores.py --check`, `cries.py --check`, and `events.py --check` reproduce the generated files. Every looped track is checked against its pokered `sound_loop 0` label. Songs whose channels share that label loop there. Songs whose periods meet at an LCM of at most 20000 ticks use one joint window at the latest label. Cinnabar Mansion is the one per-channel score. A first pass that is not note-identical keeps the register repeat, moved back one tick when that holds the downbeat.

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

## Host render

These WAVs are a host render, not a Simulator capture. `tools/audio/host_engine.lua` loads `Source/audio/engine.lua` with a stubbed `playdate.sound` and steps the same score data and channel logic the game uses: parts, jingle-over-bed, SFX priority, and the `70224/4194304` tick. `tools/audio/host_render.py` turns that schedule into PCM. Square, noise, and wavetable oscillators in that script are host stand-ins for the Playdate synth, with the engine's 0.22 master gain. Round 3 held a constant gate. Round 4 renders the shared envelope, slide, and vibrato curve; see the r4 files below. The Simulator is still silent. `setOutputsActive` was not added.

The trainer file plays `Music_MeetMaleTrainer` and then restarts `Music_TrainerBattle`, because a looping jingle replaces the bed. The Center file is `SFX_HEALING_MACHINE` then `Music_PkmnHealed`. The mansion file starts at tick 9000; tick 9315 is about 5.3 seconds in, where channel 1 returns to its label and channels 2–4 do not.

sha256:

- `artifacts/lane-f/r3/title.wav` `e08a4129cdf0e05d89a0189cc216d54712f09778a5a53166162d085156d6eccb`
- `artifacts/lane-f/r3/route1.wav` `85c6828237d126d8b389ae59a0f2c315b0ed588c20a4083733e02827984973cd`
- `artifacts/lane-f/r3/trainer.wav` `527357228daeacef31ebf842f74c226284caceab4a1d99c7988ec36fd876b51e`
- `artifacts/lane-f/r3/heal.wav` `aeb510c2cbfe43d92223ecbe761ecb7e57d6c5791b1ad8adf08e79348bba77a3`
- `artifacts/lane-f/r3/champion.wav` `3fd31da124daf3928b5b15a4b5b574c40cecf1ab6d77a45f2b49b3bdf26fdafe`
- `artifacts/lane-f/r3/mansion.wav` `8933de6562a80e6166d4ce76fd94b0e06e283167d367ce1a5db340ac7d902fb6`

## Host render, round 4

These two files are a host render, not a Simulator capture, and they are not committed. `Source/audio/shape.lua` is the one ADSR, envelope-gain, pitch-slide, and vibrato implementation. `Source/audio/engine.lua` calls it for `setADSR` and for `setLegato` pitch updates. `tools/audio/host_engine.lua` does not keep a second copy: it plays through that engine and samples `KantoShape.gain` for the amplitude. Pitch slides are `Audio1_InitPitchSlideVars` plus `Audio1_ApplyPitchSlide` from `audio/engine_1.asm`. Vibrato is `Audio1_ApplyMusicAffects` `.vibrato`. The heal channel-1 line falls from the clamped attack (16000 Hz) through the intermediate periods instead of sitting on the target.

The trainer jingle-to-bed cut was checked and left alone. `ticksFor(3.5)` is 209 source ticks, and the trainer bed's first note is at 3.4992 s. That is the tick grid, about 0.8 ms under 3.5 s. The 3.478 s mark from the reference pass is a template-match offset of about 22 ms, not an off-by-one in this scheduler.

sha256:

- `artifacts/lane-f/r4/title.wav` `beb5bde4bd2afbd62bfa6e4c8820da371025523d5327dd22d9454f89220d5cf5`
- `artifacts/lane-f/r4/heal.wav` `9872ebb08e685cd89d98aba2ec4278b717d003fe70187a9a21f3c8dea2a94030`

## Sound gaps

The observer now plays the title crash, whoosh, and attract cry, the cancelled-evolution cry, and the item, item2, key-item, badge, and Oak meet cues when those events are on the stack.

These still need a lane E call site. They are one unapplied patch, `tools/notes/lane-e-audio-gaps.patch`, and `test_hall_flute_arrow_and_denied_call_sites` is `expectedFailure` until it is applied:

- Hall of Fame ceremony bed at `EndgameStory.beginPhotos`, and `KantoAudio.playCry` for each party photo. The player photo has no cry. The observer also starts the ceremony bed when it sees phase `hall-photo`, which still waits on the main import.
- Poké Flute in `SnorlaxStory.useFlute`.
- `arrow_tiles` for the field spinner in `EventState`, and `denied` or `arrow_tiles` on an endgame story step.
- The fidelity ledger above still stands: voice 4 is the SDK noise oscillator, envelopes are ADSR, a looping jingle replaces the audible bed, pitch slides use `Audio1_ApplyPitchSlide`, the door cue uses `door.connection`, and Surf and the bicycle are music.

## New cues

| Cue | Pokered label |
| --- | --- |
| Intro crash | `SFX_INTRO_CRASH` (`audio3:SFX_Intro_Crash`). `engine/movie/title.asm:159`. `engine/movie/intro.asm:88` is the same score for the unported Gengar slash. |
| Intro whoosh | `SFX_INTRO_WHOOSH` (`audio3:SFX_Intro_Whoosh`), `engine/movie/title.asm:193`. |
| Title-mon cry | `PlayCry` of `wTitleMonSpecies`, `engine/movie/title.asm:241`. |
| Cancelled-evolution cry | `PlayCry` of `wEvoOldSpecies`. `.evolutionCancelled` loads that species and jumps to `.done`, which does `SFX_STOP_ALL_MUSIC` then `PlayCry` (`engine/movie/evolution.asm:89` and `:70`). |
| Item fanfare | `SFX_GET_ITEM_1` (`home/text.asm`, script opcode `sound_get_item_1`). |
| Second item fanfare | `SFX_GET_ITEM_2` (`sound_get_item_2`). |
| Key-item fanfare | `SFX_GET_KEY_ITEM` (`sound_get_key_item`). |
| Badge fanfare | `SFX_GET_KEY_ITEM`. Gym scripts write `sound_level_up`, an alias of `sound_get_item_1`; the fanfare that plays is the key-item score. |
| Meet Oak | `MUSIC_MEET_PROF_OAK` (`scripts/PalletTown.asm`). |
