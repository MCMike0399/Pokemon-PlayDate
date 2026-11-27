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

## Credits path, Nov 19

Elite Four battle music was already the pokered choice: Lorelei, Bruno, and Agatha are trainer battles (`defeated_trainer` on a win), Lance is gym-leader battle music, and the champion (`OPP_RIVAL3`) is `Music_FinalBattle` with the gym-leader victory bed. Their room songs were already the `songs.asm` rows: Lorelei `Music_Gym`, Bruno `Music_Dungeon1`, Agatha `Music_PokemonTower`, Lance and the champion `Music_IndigoPlateau`. The Hall of Fame map bed is `Music_PalletTown`. `AnimateHallOfFame` replaces it with `Music_HallOfFame`, and `HallOfFamePC` then plays `Music_Credits`. The observer starts those two when it sees phase `hall-photo` and `credits`. Party cries are `EndgameStory.playCry` of each photo's species. The player photo and the credits roll have no cry. Pokered's dex-rating fanfare does not play during the Hall of Fame (`EVENT_HALL_OF_FAME_DEX_RATING` returns before `PlayPokedexRatingSfx`).

New scores, traced with the channel pointers from `audio/alternate_tempo.asm`:

| Cue | What it covers |
| --- | --- |
| `faint_fall` | `SFX_FAINT_FALL` (`audio2:SFX_Faint_Fall`). `FaintEnemyPokemon` plays it, waits, then `SFX_FAINT_THUD` (`engine/battle/core.asm`). Trainer and champion enemy faints, including the Elite Four. A wild win does not play it. |
| `cities1_oak` | `Music_Cities1AlternateTempo`. Channel 1 is tempo 232 into `Music_Cities1_Ch1.body`; the other channels stay on the Cities1 header. Oak's arrival in the champion room. |
| `meet_rival_slow` | `Music_RivalAlternateTempo`. Channel 1 is tempo 100. The second Route 22 rival, while that object walks in. |
| `meet_rival_league` | `Music_RivalAlternateStartAndTempo`. Channels 1–3 use the alternate start, and channel 1 then uses the slower start. The "That loosened me up!" page after that rival. |
| `meet_rival_start` | `Music_RivalAlternateStart` (`audio/alternate_tempo.asm`). Channels 1–3 use the alternate start at tempo 112, then the normal MeetRival loop. The visible exit line in Oak's Lab ("Smell you later!", the exact "Gramps!" arrival, and "Leave it"), the first Route 22 battle ("I heard"), Cerulean ("BILL"), Pokémon Tower 2F ("How's your"), SS Anne 2F ("CUT"), and Silph Co 7F ("good luck"). Pokered starts the song as the rival walks out, after the text; the port starts it when that line is on screen. |
| `faint_fall_agility` | `SFX_FAINT_FALL` with pitch `$20` and tempo `$c0` (`data/moves/sfx.asm` AGILITY). `GetMoveSound` writes those bytes before the animation. |
| `faint_fall_kinesis` | Same header, pitch `$18`, tempo `$20`. |
| `faint_fall_transform` | Same header, pitch `$ff`, tempo `$ff`. |
| `faint_fall_dizzy_punch` | Same header, pitch `$ff`, tempo `$04`. |
| `shooting_star` | `SFX_SHOOTING_STAR` (`engine/movie/splash.asm`, from `PlayShootingStar`). The fight intro is not a drawn state, so this plays on title-clock frame 1, before the crash at frame 20. |
| `intro_lunge` | `SFX_INTRO_LUNGE` (`engine/movie/intro.asm`, the nidorino lunge). Title-clock frame 10, still before the crash. |
| `teleport_exit_1` | `SFX_TELEPORT_EXIT_1`. Warp-pad leave (`LeaveMapAnim` while standing on a pad). A source warp with `preserveFacing` and no `connection` is the visible stand-in. |
| `teleport_enter_1` | `SFX_TELEPORT_ENTER_1`. The arrival spin after that leave, and after an escape. |
| `teleport_exit_2` | `SFX_TELEPORT_EXIT_2`. Escape-rope leave, before `EXIT_1`. Dig and the field Teleport move set the same bits in pokered; the port only records the escape rope on `lastFieldItem`. |
| `teleport_enter_2` | `SFX_TELEPORT_ENTER_2`. Follows enter 1. A dungeon warp in pokered skips it; that bit is not on the door, so the port plays it. |
| `ball_poof` | `SFX_BALL_POOF` (`DoPoofSpecialEffects` when the poof counter is 5). Capture `absorb` and a failed `breakout`. |

Text cries, from `home/text.asm` `TextCommand_SOUND`. `sound_cry_dewgong` is unused and is not played.

| Cry | When |
| --- | --- |
| `nidorina` | `TX_SOUND_CRY_NIDORINA`, between oak speech text 2A and 2B. The opening dialog's "For some people," line, while the title is still up. |
| `pidgeot` | `sound_cry_pidgeot` after `_SaffronCityPidgeotText`. A Saffron line that starts with `PIDGEOT:`. |

The full constant sweep is `docs/validation/lane-f-coverage.md`. Of the constants pokered defines, 185 are played, 9 are in an unapplied lane-E patch, and 10 are still missing. `SFX_59` and `SFX_BATTLE_16` are unused and are not in those counts.

A mart buy, a PC box save, the Safari game-over announcement, the Vermilion trash switch, the Game Corner poster, Bill's initiated page, and Bill's cell separator are visible, so those sounds play from the observer. `SFX_SWAP` plays only from `party.swapReceipt`. Cancel no longer plays it. Medicine, the pause-menu save, a new dex page, the field poison tick, Oak's dex rating, and an elevator ride set a receipt in `tools/notes/lane-e-audio-main-path.patch`. The observer plays each receipt once that field exists.

Still missing:

- Hall of Fame cries and the flute, spinner, and denied cues still need the lane E import. `tools/notes/lane-e-audio-gaps.patch` and `tools/notes/lane-e-audio-main-path.patch` are unapplied. The coverage-matrix fingerprint is `tools/notes/lane-e-coverage-fingerprint.patch` (`aee32b591b3202898ab28d254ee376750c0ea6a58793735a495dde4f24016e27`). This lane does not rewrite that snapshot.
- Field Dig and field Teleport are not a ported command, so they do not set `lastFieldItem`. The escape rope uses their pokered sound sequence.
- The fight intro is still not drawn. `MUSIC_INTRO_BATTLE`, `SFX_INTRO_HIP`, `SFX_INTRO_HOP`, and `SFX_INTRO_RAISE` stay silent with it. Museum Guy, Jigglypuff's song, the slot machine, the trade machine, and Oak's intro shrink are the other sites left out of this pass.

## Done-path receipts

Simulator on a scratch worktree of `origin/cursor/lane-e-integration` at `79fbcba560e34945a130d7e1788ab44be5aa8d77`, with this branch's `Source/audio` and `Source/game/kantoAudio.lua` checked out on top. Lane E already imports `game/kantoAudio`. Playdate SDK 3.1.2. `MallocPoolSize` stayed `16645684`. Pokered is `af519899719f0754965776faac0e836a3b906e6d`. The harness was `tools/harness/run.py` with fixture saves and real A presses. A scratch logger wrote each `KantoSynth` call to `runtime-data/audio-receipts.txt`. That logger is not on this branch.

| Check | Trigger | Track or SFX | Evidence | Pokered |
| --- | --- | --- | --- | --- |
| Champion battle | `pokered:CHAMPIONS_ROOM:objects:1` after the rival intro. Battle info `class=OPP_RIVAL3 wild=false zone=pokered:CHAMPIONS_ROOM`. | music `final` (`Source/audio/score/final.lua`, `audio2:Music_FinalBattle`). Match. | Session `4e8060388d41487b8dfb2d2299242979`, `/tmp/done-audio/champion6`. Receipt `AUDIO music final`. Battle file `AUDIO battle class=OPP_RIVAL3 wild=false zone=pokered:CHAMPIONS_ROOM`. Snapshot root `battle`, message `PIDGEOT used WING ATTACK!`. | `audio/play_battle_music.asm:19` `cp OPP_RIVAL3`, `:29` `ld a, MUSIC_FINAL_BATTLE`. Score `audio/music/finalbattle.asm:1` `Music_FinalBattle_Ch1`. |
| Hall of Fame | Entered `kanto_hall_of_fame`. Oak `pokered:HALL_OF_FAME:objects:1`, phase `hall-photo`. | music `hall_of_fame` (`audio3:Music_HallOfFame`), then cry `charmander` for the party species. The receipt notes the bed twice because `EndgameStory.beginPhotos` and the observer both call `playCue`; the engine keeps the same bed. Match. | Session `f341d00e95b74bb09829b746e5707916`, `/tmp/done-audio/hall1`, outcome ok. | `engine/movie/hall_of_fame.asm:37` `MUSIC_HALL_OF_FAME`. Score `audio/music/halloffame.asm:1` `Music_HallOfFame_Ch1`. Cry `engine/movie/hall_of_fame.asm:178` `jp PlayCry`. |
| Credits | Same Hall session, after the photos. Final snapshot `event.phase` `credits`, id `pokered:HALL_OF_FAME:objects:1`. | music `credits` (`audio3:Music_Credits`). Match. | Same hall1 receipt, `AUDIO music credits`. | `engine/movie/credits.asm:27` `ld a, MUSIC_CREDITS`. Score `audio/music/credits.asm:1` `Music_Credits_Ch1`. |
| Low-HP alarm | Wild Onix against Charmander at 1/18 HP. The bar is red, then the mon faints. | alarm `true`, then alarm `false` when HP hit 0. Score `alarm` is `audio2:low-health` (`Music_DoLowHealthAlarm`). Match. | Session `4bacd704f01549589bf4f4adb50addf4`, `/tmp/done-audio/lowhp1`. Message `CHARMANDER fainted!`. | `engine/battle/core.asm:1860` `cp HP_BAR_RED`, `:1871` `.setLowHealthAlarm`, clear on faint at `:1863`. Score `audio/low_health_alarm.asm:1` `Music_DoLowHealthAlarm`. |
| Player faint | Same battle. Charmander fainted after Onix's Bind. | `sfx faint` (`audio2:SFX_Faint_Thud`). The earlier `cry charmander` is the send-out, before `sfx move_bind`. No cry at the faint. Gap. | lowhp1: `AUDIO sfx move_bind`, `AUDIO alarm false`, `AUDIO sfx faint`. | `engine/battle/core.asm:1041` `ld a, [wBattleMonSpecies]`, `:1042` `call PlayCry`. Enemy fall and thud stay `:782` and `:788`. |

The champion battle then stopped: `game/kantoAudio.lua:267: attempt to index a nil value (global 'KantoMoveSfx')`. `pdc` does not compile `import "audio/moveSfx"` from inside `moveScore`. The champion bundle's `main.pdz` contains the path and not the `KantoMoveSfx` table. The low-HP run used a scratch file-scope import so the move could finish. That import is `tools/notes/lane-e-audio-movesfx-import.patch`. The alarm line itself is before the move lookup.

`tools/notes/lane-e-audio-player-faint-cry.patch` cries `battle.player.species` after the move row, and leaves the enemy fall and thud alone. Applied only on the scratch tree, the same battle cried Charmander. Session `f04554bdfca24936b41e1ed113331035`, `/tmp/done-audio/lowhp2`: `AUDIO sfx move_bind`, `AUDIO alarm false`, `AUDIO cry charmander`, message `CHARMANDER fainted!`. The patch is not applied on this branch.

Both tests are plain failures. No skip and no expectedFailure.

- `LaneEAudioFidelityTests.test_player_faint_plays_the_battle_mon_cry` fails until `lane-e-audio-player-faint-cry.patch`.
- `LaneEAudioFidelityTests.test_move_sfx_table_is_imported_at_file_scope` fails until `lane-e-audio-movesfx-import.patch`.

Together, before either patch: `FAILED (failures=2)`. After both: `OK`. After reversing both: `FAILED (failures=2)`.

## Memory fit against lane E `85512254`

`MallocPoolSize` stayed `16645684`. Score records are 32-byte little-endian rows in `Source/audio/score/<name>.bin`. The lua file is only the header (`ticks`, `loop`, `count`, waves, file offset). `KantoPacked` reads that slice on first play and `KantoSynth.unloadAll` drops it, along with the map table, receipt labels, move-SFX table, and decoder. Those four load through `playdate.file.run`, not an import, so they are not part of the main chunk. Cry catalogs are built for one cry and released. Playback is the same packed layout the host tests unpack.

Checked on a scratch of `855122548deed18b53e4390870a7a6f47041a4d2` plus this audio tree and lane K's batch, in K's order. The six `LaneEAudioFidelityTests` passed after those patches. They are not applied on this branch.

| Check | Result |
| --- | --- |
| `test_live_viridian_switch_stays_under_budget` | Pass. Fuchsia `zone.end` 13471.9 KiB, peak 13583.6. Session output `/tmp/lane-f-switch7`. |
| `test_cerulean_cave_warp_stays_under_budget` | Pass. Same run, 36.7s for both tests. |
| `individual-stats-v1` | 17 passed, 0 failed. Heap 12944.9 KiB. `/tmp/lane-f-stats`. |
| `field-travel` | 2 passed, 1 failed. The failure is `expired Surf takes input before held traversal`: `pd_readcompressed inflate failed, out of memory`. `/tmp/lane-f-field`. |
| Clean tip `85512254`, same contract | 2 passed, 1 failed, the same Surf inflate. `/tmp/lane-e-field`. Fuchsia `zone.end` there is 13310.4; this tree is 13391.5. |

Resident Lua heap, same fixture (Viridian idle, then a wild Rattata, then the Hall of Fame), before the packed bins and after:

| Scene | Before (fat note tables) | After |
| --- | --- | --- |
| Viridian idle `zone.end` | 13456.3 | 13319.5 |
| Viridian idle `actors.end` | 13300.1 | 13163.3 |
| Battle `battle.start.end` | 13493.5 | 13133.1 |
| Hall `zone.end` | 13273.0 | 13005.9 |
| Hall `actors.end` | 13318.7 | 13051.6 |

The Hall row is the map. `hall_of_fame` still plays only from the ceremony, not from zone entry.

## Fidelity sweep against pokered `af519899`

Lane E's tip for the Simulator receipts is `4bac3bdff34ee3a23f7d2d6b7d2cd0b5a2081ffe`. The audio tree on that scratch is this branch. Champion, Hall of Fame, and credits playback are out of this sweep.

`POKERED_REFERENCE_DIR=/tmp/pokered python3 -m unittest tools.tests.test_audio_fidelity_sweep tools.tests.test_audio_events` ran 19 tests and passed. The sweep parses `data/maps/songs.asm` and `constants/music_constants.asm`, and compares every map with `Source/audio/eventMaps.lua`. It parses `data/trainers/encounter_types.asm` and every `trainer_const`, then asks `KantoEvents.trainerJingle` for gym leader 0 and 1. Rivals stay silent. Evil and female classes use those lists. Every other class uses the male jingle. A non-zero `wGymLeaderNo` stays silent, which is `PlayTrainerMusic` returning before the lists. Bike and surf replace the map bed with `MUSIC_BIKE_RIDING` and `MUSIC_SURFING` (`home/audio.asm`). Walking restores the map song.

The cue rows match the pokered token that plays them: heal (`MUSIC_PKMN_HEALED` after `SFX_HEALING_MACHINE`), item (`SFX_GET_ITEM_1`), key item and badge (`SFX_GET_KEY_ITEM`), evolution (`SFX_TINK` then `MUSIC_SAFARI_ZONE`), caught (`SFX_CAUGHT_MON`), level up (`SFX_LEVEL_UP`), the four PC sounds, door (`SFX_GO_INSIDE` / `SFX_GO_OUTSIDE`), ledge (`SFX_LEDGE`), bump (`SFX_COLLISION`), and the menu sounds (`SFX_START_MENU`, `SFX_PRESS_AB`). Badge scripts name the key-item opcode. The item-fanfare change is already `tools/notes/lane-e-audio-badge-item.patch` with `LaneEAudioFidelityTests.test_boulder_and_earth_badges_play_the_item_fanfare`. No new gap turned up, so this sweep adds no patch.

Simulator receipts are the music name `KantoAudio` requested on a real zone change. The logger and the `switchzone` / `traverse` commands lived only on the scratch. Sessions:

| Transition | Requested bed | Session |
| --- | --- | --- |
| Viridian, then Pewter | `cities1`, then `cities1` | `ee39a17c81cc4693a18429a11f93a4aa` |
| Route 1 | `route1` | same |
| Pewter Gym, and later Cinnabar Gym | `gym` | same, and `e1cfe80346484dc288859975e5a86897` |
| Mt. Moon | `dungeon3` | `ee39a17c` |
| Cerulean Cave | `dungeon1` | same |
| Pokémon Tower | `tower` | `5d4cb5d921844212a6f727515cf79a94` |
| Silph Co. 1F and 11F | `silph`, then `silph` | same |
| Safari Zone center and east | `safari`, then `safari` | `b0809f24905d4105b3c4592cfe63fc88` |
| Fuchsia | `cities2` | `e1cfe803` |
| Surf, then bike, then walk | `surfing`, `bicycle`, `cities2` | same |
| Celadon, then Vermilion | `celadon`, `vermilion` | same |

Rock Tunnel is `dungeon3` in the table, the same bed Mt. Moon played. The longer tours ran out of memory while inflating a later map. Those crashes are the scratch logger loading every score, not a wrong song. The finished Fuchsia tour is session `e1cfe803`.

## Budget against main `61a70ffe`

`MallocPoolSize` stayed `16645684`. Main is `61a70ffe972f75a812282a08129d209e3152b4fc`. The audio tree had not landed there, so this branch merges that tip. A rebase would rewrite the pushed commits.

Clean `61a70ffe` passes field-travel 3/3. The first audio measurement failed the expired Surf inflate (`pd_readcompressed`, `fieldTravelContracts.lua:367`) at 2 passed / 1 failed. `KantoAudio.updateGame` was reloading the full map table every frame, and that string table stayed live through the Safari stay. The device now reads `Source/audio/eventMaps.bin`, keeps the one score name, and drops the table. The lua file remains the host table. The same contracts then match clean main.

| Check | Clean `61a70ffe` | Audio tree |
| --- | --- | --- |
| `individual-stats-v1` | 17/17, heap 12934.3 KiB | 17/17, heap 12933.6 KiB |
| Viridian `zone.end` | 13186.4 | 13250.6 |
| Lavender `zone.end` | 13070.2 | 13070.3 |
| Fuchsia `zone.end` | 13568.3 | 13467.7 |
| Cerulean Cave 1F `zone.end` | 13216.0 | 13264.9 |
| City switch and cave warp | both pass | both pass |
| `field-travel` | 3/3, heap 12798.0 KiB | 3/3, heap 12810.4 KiB |

## Indigo Plateau and Elite Four

Same pokered pin, `af519899`. Champion, Hall of Fame, and credits playback are still out of this sweep. `POKERED_REFERENCE_DIR=/tmp/pokered python3 -m unittest tools.tests.test_audio_fidelity_sweep tools.tests.test_audio_events` ran 21 tests and passed. No row disagreed, so this sweep adds no patch.

`data/maps/songs.asm` beds, also asserted by name:

| Map | Bed |
| --- | --- |
| Indigo Plateau | `indigo` (`MUSIC_INDIGO_PLATEAU`) |
| Indigo Plateau lobby | `indigo` |
| Route 23, the outside approach | `indigo` |
| Lorelei's room | `gym` |
| Bruno's room | `dungeon1` |
| Agatha's room | `tower` |
| Lance's room | `indigo` |

Lorelei, Bruno, Agatha, and Lance are in neither encounter list, so the meet jingle is `meet_male`. A non-zero gym flag is silent. `PlayBattleMusic` uses `MUSIC_TRAINER_BATTLE` for Lorelei, Bruno, and Agatha, and `MUSIC_GYM_LEADER_BATTLE` for Lance.

`data/trainers/parties.asm` parties, each cry triple checked against `data/pokemon/cries.asm` and `KantoCrySpecies`:

| Trainer | Party |
| --- | --- |
| Lorelei | Dewgong, Cloyster, Slowbro, Jynx, Lapras |
| Bruno | Onix, Hitmonchan, Hitmonlee, Onix, Machamp |
| Agatha | Gengar, Golbat, Haunter, Arbok, Gengar |
| Lance | Gyarados, Dragonair, Dragonair, Aerodactyl, Dragonite |

The repeated Onix, Gengar, and Dragonair are the same cry rows. Send-out still cries `scene.enemyShown.species` through that table.
