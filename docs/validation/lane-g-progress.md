# Lane G progress

Front end for the Pokémon Blue Playdate port. Source of truth is pret/pokered `af519899719f0754965776faac0e836a3b906e6d`. Art for Red is `gfx/title/player.png` run through `tools/generate_title_art.py` (threshold 128, nearest, scale 1). Output sha256 `f6368b9681aeb6e98660050bb80fd55efd9dcced7fd5281395387a55516d272e`. No other title pin was rewritten.

Frames for the visual decision are composed 400×240 images under `/opt/cursor/artifacts/lane-g/`. The Playdate simulator is not installed here, so those frames are layout proofs, not device captures.

## What landed

- `engine/movie/title.asm` `DrawPlayerCharacter` draws Red. Sprite 10 (column 0, row 2) is the ball. `engine/movie/title2.asm` `TitleScreenAnimateBallIfStarterOut` / `TitleBallYTable` moves that ball. The Squirtle-first TitleMons cycle in `titleIdle.lua` is unchanged, and `TitleIdle.advance` is unchanged.
- `engine/menus/main_menu.asm` `MainMenu`. A press leaves the title. The menu is `CONTINUE` / `NEW GAME` / `OPTION` when a save exists, and `NEW GAME` / `OPTION` when it does not. `DelayFrames` 20 before input. B returns to `DisplayTitleScreen`. `DisplayContinueGameInfo` shows `PLAYER` / `BADGES` / `#DEX` (drawn `POKéDEX`) / `TIME`, then waits 30 frames. A loads the save. B returns to the menu. Recovery rows stay after `OPTION`.
- `constants/player_constants.asm` Blue presets: player `BLUE` / `GARY` / `JOHN`, rival `RED` / `ASH` / `JACK`. `engine/menus/naming_screen.asm` plus `data/text/alphabets.asm`: 7-tile player and rival names, 10-tile nicknames, case row, `ED` submits. Empty player or rival submit stays on the screen. An empty nickname keeps the species name.
- `engine/movie/oak_speech/oak_speech.asm` `OakSpeech` and `oak_speech2.asm` `ChoosePlayerName` / `ChooseRivalName`. Text from `data/text/text_2.asm`. The Nidorina cry seam is `KantoAudio.playCry("nidorina")` when that function exists. The sprite is Nidorino, matching the source.
- `home/start_menu.asm` `DisplayStartMenu` and `engine/menus/draw_start_menu.asm`: `POKéDEX`, `POKéMON`, `ITEM`, the player name, `SAVE`, `OPTION`, `EXIT`. Without the dex the first row is skipped. Dispatch is by index (`TitleIdle.startAction`), so a player named `SAVE` does not collide. `engine/menus/start_sub_menus.asm` `StartMenu_TrainerInfo` shows `NAME/` `MONEY/` `TIME/`. Badge tiles are a count, because `DrawBadges` is tile art this screen does not have.
- `engine/menus/main_menu.asm` `DisplayOptionMenu`: `TEXT SPEED` `FAST` / `MEDIUM` / `SLOW`, `BATTLE ANIMATION` `ON` / `OFF`, `BATTLE STYLE` `SHIFT` / `SET`, `CANCEL`. Left and right do not wrap. A leaves only on `CANCEL`. The approved `CRANK SCROLL` row stays. Text speed still defaults to `FAST` (`docs/plans/approved-qol.md`); pokered `InitOptions` is `MEDIUM`.
- `scripts/NameRatersHouse.asm` dialogue and OT check live in `NameRater`. The house object is not wired. See the nickname patch.
- `engine/movie/intro.asm` `PlayIntro` / `PlayIntroScene` and `engine/movie/splash.asm` `PlayShootingStar`. Copyright is 180 frames and ignores A. Black bars are 64 frames and ignore A. A during the star skips the star and the 40-frame hold. A during the fight leaves the intro. Fight art is the existing Nidorino and Gengar fronts. Intro gfx is 2bpp and is not in the PNG pipeline.
- Title music is `TitleIdle.playMusic` → `KantoAudio.playTitle` when that function exists. Intro music is `IntroMovie.sound` → `KantoAudio.playIntro`. Both are no-ops until lane F adds them.

## Ledger proposal for lane E

Replace the Title row. Keep the Title idle row's timing claims (`HOLD` 200, Squirtle first, out then ball then in). The ball is no longer drawn in the vacated mon slot.

| Area | Pokered behavior | Port behavior | Evidence |
| --- | --- | --- | --- |
| Title | `engine/movie/title.asm` `DisplayTitleScreen` draws the logo, the version, and `DrawPlayerCharacter` (`gfx/title/player.png`, OAM `$5a,$60`). `engine/movie/title2.asm` `TitleScreenAnimateBallIfStarterOut` bounces sprite 10 through `TitleBallYTable` (`$71`–`$6c` from rest `$74`) while a starter is out. A press leaves the title. | Red is `Source/images/title/player.png` from the pinned threshold. Sprite 10 is erased from the sheet and redrawn at the table Y. The Squirtle-first cycle is unchanged. A opens the separate main menu. | `tools/tests/test_lane_g_front_end.py`, `tools/tests/test_title_idle.py`, frames `title-before.png` / `title-after.png` / `title-after-bounce.png` |
| Main menu | `engine/menus/main_menu.asm` `MainMenu`. With a save: `CONTINUE`, `NEW GAME`, `OPTION`. Without: `NEW GAME`, `OPTION`. `DelayFrames` 20. B returns to the title. `DisplayContinueGameInfo` prints `PLAYER` / `BADGES` / `#DEX` / `TIME` (`PrintNumBadges`, `PrintNumOwnedMons`, `PrintPlayTime` as `hours:minutes`). `DelayFrames` 30. A loads. B returns to the menu. | Same labels and delays. The dex label is `POKéDEX`. Eight gym flags are counted. Hours are three digits and minutes two, matching `PrintPlayTime`. Recovery rows stay after `OPTION`. | `tools/tests/lane_g_host.lua`, frames `main-menu-after.png` / `continue-after.png` |
| Oak speech and naming | `engine/movie/oak_speech/oak_speech.asm` `OakSpeech`. Blue presets in `constants/player_constants.asm`. `engine/menus/naming_screen.asm`: 7 tiles for people, 10 for a Pokémon, `ED` submits, an empty person name retries, an empty nickname keeps the species name. | The speech uses the chosen names. Presets and the keyboard match. Names are remembered on the session for this process. They are not in the save until the names patch lands, so Continue still shows `RED` / `BLUE`. | `tools/tests/lane_g_host.lua`, frames `naming-before.png` / `naming-after-presets.png` / `naming-after-keyboard.png` |
| Start menu and options | `home/start_menu.asm` `DisplayStartMenu`. `engine/menus/draw_start_menu.asm` order with the dex: `POKéDEX`, `POKéMON`, `ITEM`, `wPlayerName`, `SAVE`, `OPTION`, `EXIT`. `engine/menus/start_sub_menus.asm` `TrainerInfo_NameMoneyTimeText`. `DisplayOptionMenu` boxes, plus the approved `CRANK SCROLL` row. Text speed default stays `FAST`. | Same order, labels, and option boxes. The trainer card prints the badge count in place of `DrawBadges`. | `tools/tests/lane_g_host.lua`, frames `start-menu-before.png` / `start-menu-after.png` / `options-before.png` / `options-after.png` |
| Intro | `engine/movie/intro.asm` `PlayIntro`. Copyright 180, bars 64, star skippable, fight skippable. | Same skip rules. Fight uses existing fronts. Intro 2bpp tiles are not generated. | `tools/tests/lane_g_host.lua`, frames `intro-after-copyright.png` / `intro-after-fight.png` |

## Handoff patches

Apply `tools/notes/lane-e-names.patch` first, then `tools/notes/lane-e-nicknames.patch`.

- `lane-e-names.patch`: `GameSession:setPlayerName` / `setRivalName` (1–7 printable ASCII), `title()` returns the stored names, the codec stops requiring `RED` / `BLUE`, and `<PLAYER>` / `<RIVAL>` fall back to `Story` when the caller did not pass a value. `purchaseGiftPokemon` also returns `mon`, which the nickname patch reads. Old saves that still say `RED` / `BLUE` remain valid.
- `lane-e-nicknames.patch`: after the caught line, `BattleState` calls `Story.promptNickname`. Lapras, the gym gift, Eevee, Magikarp, and the fossil handover do the same. `sourceEventHandlers.lua` documents `pokered:NAME_RATERS_HOUSE:objects:1`. `NameRater` in `namingState.lua` is the dialogue. The house scene still has to push it. `main.lua` does not need an edit: `TitleState:init` registers `NamingState`, and the intro plays as a title phase.

`tools/tests/test_lane_e_names.py` and `tools/tests/test_lane_e_nicknames.py` check that the patches apply. The assertions that the codec and the catch ask for names are `expectedFailure` until lane E lands them.

## Round 2

`DisplayContinueGameInfo` is `hlcoord 4, 7`, `b = 8`, `c = 14`. The four `PlaceString` rows are 9, 11, 13, and 15. `TitleIdle.continueCells` places each label and value inside that border. The host test rejects a row that crosses it. The main menu is `hlcoord 0, 0` on the same 20px by 13px map, with `▶` in column 1. The start menu is `hlcoord 10, 0` with the cursor in column `$0b`. Options use `▷` on the current choice and `▶` on the active row (`PlaceUnfilledArrowMenuCursor` / `PlaceMenuCursor`).

Names go through `Story.readName`. Oak's speech, the naming screen, and the continue box all use `Story.playerName` / `Story.rivalName`. Lane E's codec change is the `title()` return. No second read was added.

The 8×8 font is `gfx/font/font.png` and `font_extra.png`, thresholded into `Source/images/title/font/`. Box corners are the font_extra tiles. `BattleMenu` in `ui/menu.lua` is still a 1px rect and a `>` cursor. That file is lane E's. `tools/notes/lane-e-menu-font.patch` switches it to the battle font, the dialog frame, and `▶`. The title, start menu, options, naming screen, and the loading line do not wait on that patch.

Blue's intro front is `gfx/intro/blue_jigglypuff_*.png` (`FightIntroFrontMon` under `_BLUE`). Gengar is composed from `gfx/intro/gengar.png` and `gengar_1/2/3.tilemap`, not a 56px crop. The Red Nidorino sheets are pinned in the same manifest and are not drawn. The battle fronts are no longer the intro stand-in. The tilemap wave is still the static first frame.

The continue-box capture is a Playdate Simulator 3.1.2 frame, `simulator-continue.png`.

## Round 3

`PlayIntroScene` writes `ldpal a, SHADE_BLACK, SHADE_DARK, SHADE_LIGHT, SHADE_WHITE` to `rBGP`, `rOBP0` and `rOBP1`. That is `0xE4`: color 0 white, color 1 the approved LIGHT Bayer, color 2 the approved DARK Bayer, color 3 black. `RunPaletteCommand` returns when `wOnSGB` is 0, so `SET_PAL_NIDORINO_INTRO` does not change those registers. `IntroClearScreen` writes tile 0, the blank color-0 tile, so the field is white. `IntroPlaceBlackTiles` writes tile 1, the solid color-3 bar, four rows at the top and at row 14.

Gengar is `gfx/intro/gengar.png` in column order, then `tools/gfx --remove-duplicates --preserve=0x19,0x76`. `gengar_1/2/3.tilemap` are placed at `hlcoord 13, 7`, 7 by 7. The fight no longer crops the first 56px of the sheet. Jigglypuff stays the three picture sheets (`IF DEF(_BLUE)`), dithered with the same palette. `hSCX` is still the static first frame. Animating the scroll is pending.

Playdate Simulator 3.1.2, production bundle `source_sha256` `a8b0b1566576a1c860688adbb56fc4aadb44ab559a1f0ce2bea68796f25b1032`. Captures are in `artifacts/lane-g/r3/`: `title.png`, `title-bounce.png` (sprite 10 off the hand), `main-menu.png`, `oak-speech.png`, `naming-player-presets.png`, `naming-player-keyboard.png`, `naming-rival-presets.png`, `naming-rival-keyboard.png`, `start-menu.png`, `options.png`, `intro-fight.png`. `intro-fight.png` is the raised Gengar on a white field with black letterbox bars. The boot reached the title and the bedroom with no memory-guard abort. The simulator log did not print a heap figure. This machine had no earned save, so the Continue box is not in the set. The main menu is NEW GAME and OPTION.

`Story.promptNickname` is the catch and gift ask. It already runs for the starter. Lane E's patch calls it after the caught line and the gifts. `NameRater.present` runs the house script, including the party list, the OT check, and the rename keyboard. `Story.tryNameRater` calls it only after the patch installs `SourceEventHandlers["pokered:NAME_RATERS_HOUSE:objects:1"]`.

## Round 4

BlueBot approved the intro fight, the title with Red, the player name presets, and the main menu. Four screens that were still wrong are corrected. The logo, the Blue Version line, Red, and the presets were not moved.

The naming grid is `data/text/alphabets.asm`: row 4 is `× ( ) : ; [ ] PK MN` and row 5 is `- ? ! ♂ ♀ / . , ED`. Row 3 keeps its trailing space. `× ; [ ] ♂ ♀` come from `gfx/font/font.png`. `PK`, `MN`, and `ED` are one tile each (`ED` is `gfx/font/ED.png`). The `B delete / A on ED done` line is gone.

`CRANK SCROLL` stays. It sits on the row under the third `options.asm` box. `CANCEL` has the following row to itself, with a blank row between them.

The title copyright is `.tileScreenCopyrightTiles`: `$41,$42,$43,$42,$44,$42,$45,$46`–`$4E`. `$42` is the `'9` tile and is drawn three times, so the row reads `©'95.'96.'98 GAME FREAK inc.` `LoadTitleMonSprite` is `hlcoord 5, 10`, seven tiles, so the picture ends on row 16. The copyright is `hlcoord 2, 17`. Every TitleMon is sampled into that slot and clipped to it. `tools/tests/test_lane_g_front_end.py` checks the grid against the alphabet, parses the copyright sequence from `title.asm`, and checks every TitleMon against the copyright row.

Oak's speech is a white screen. It shows Oak, then Nidorino (slide), then the player, then the rival, then the player again. The text is the pixel font and reads `POKéMON`. The dialog owner is unchanged.

Playdate Simulator 3.1.2, production bundle `source_sha256` `8ca9b2687c421e0d96f3172e36a4fd20f62ba89b7f2d63d29a04f663c5bacc38`. Captures are in `artifacts/lane-g/r4/`: the title, the keyboard, options, each Oak stage, the Continue menu and info box, and the Continue landing in Pallet Town. The Continue file is the bedroom save with `location` set to `pallet_town` `(5, 6)`, `EVENT_BEAT_CHAMPION_RIVAL`, and one Hall of Fame team. The codec still prints `RED`.

The r4 title row listed `$41` through `$4E` once each, so `$42` (the `'9` tile) was drawn once and the years read `©'95.68`. The row is now the `.tileScreenCopyrightTiles` sequence with `$42` three times. `artifacts/lane-g/r5/title.png` is that screen, bundle `36f846d031cafdc10b3f4addfb50754cf0c22664500c244c54eaee3fcce8087d`.

## Blockers

- Chosen names do not survive Continue. The codec still asserts `RED` / `BLUE`.
- Nickname glyphs outside printable ASCII are rejected by `Story.storeNickname`, because `pokemonCodec.lua` rejects them. The keyboard still shows `×` `♂` `♀` `PK` `MN`.
- The rival NPC id stays `BLUE`. Dialogue uses the chosen rival name. The actor lookup does not.
- The intro tilemap scroll (`hSCX` in `IntroMoveMon`) is still the static first frame. The three Gengar poses are in place.
- `TitleState:update` calls `KantoAudio.playCue("title")` while the title state is open. The start-menu sound stays on lane F's observer. Intro music is still unwired.
- Continue now has a Pallet Town capture. The player name on that box is still `RED` until the names patch lands.
