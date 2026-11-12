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
- `scripts/NameRatersHouse.asm` dialogue and OT check live in `NameRater`. Lane E reserves `pokered:NAME_RATERS_HOUSE:objects:1` with a comment and does not install a second handler. Loading that module turns the house on.
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

`Story.promptNickname` is the catch and gift ask. It already runs for the starter. Lane E's adopted catch and gift paths call it after the caught line and the gifts. `NameRater.present` runs the house script, including the party list, the OT check, and the rename keyboard. Lane E reserves `pokered:NAME_RATERS_HOUSE:objects:1` with a comment and does not install a second handler. Loading that module turns the house on. `Story.tryNameRater` still requires that object on the faced tile.

## Round 4

BlueBot approved the intro fight, the title with Red, the player name presets, and the main menu. Four screens that were still wrong are corrected. The logo, the Blue Version line, Red, and the presets were not moved.

The naming grid is `data/text/alphabets.asm`: row 4 is `× ( ) : ; [ ] PK MN` and row 5 is `- ? ! ♂ ♀ / . , ED`. Row 3 keeps its trailing space. `× ; [ ] ♂ ♀` come from `gfx/font/font.png`. `PK`, `MN`, and `ED` are one tile each (`ED` is `gfx/font/ED.png`). The `B delete / A on ED done` line is gone.

`CRANK SCROLL` stays. It sits on the row under the third `options.asm` box. `CANCEL` has the following row to itself, with a blank row between them.

The title copyright is `.tileScreenCopyrightTiles`: `$41,$42,$43,$42,$44,$42,$45,$46`–`$4E`. `$42` is the `'9` tile and is drawn three times, so the row reads `©'95.'96.'98 GAME FREAK inc.` `LoadTitleMonSprite` is `hlcoord 5, 10`, seven tiles, so the picture ends on row 16. The copyright is `hlcoord 2, 17`. Every TitleMon is sampled into that slot and clipped to it. `tools/tests/test_lane_g_front_end.py` checks the grid against the alphabet, parses the copyright sequence from `title.asm`, and checks every TitleMon against the copyright row.

Oak's speech is a white screen. It shows Oak, then Nidorino (slide), then the player, then the rival, then the player again. The text is the pixel font and reads `POKéMON`. The dialog owner is unchanged.

Playdate Simulator 3.1.2, production bundle `source_sha256` `8ca9b2687c421e0d96f3172e36a4fd20f62ba89b7f2d63d29a04f663c5bacc38`. Captures are in `artifacts/lane-g/r4/`: the title, the keyboard, options, each Oak stage, the Continue menu and info box, and the Continue landing in Pallet Town. The Continue file is the bedroom save with `location` set to `pallet_town` `(5, 6)`, `EVENT_BEAT_CHAMPION_RIVAL`, and one Hall of Fame team. The codec still prints `RED`.

The r4 title row listed `$41` through `$4E` once each, so `$42` (the `'9` tile) was drawn once and the years read `©'95.68`. The row is now the `.tileScreenCopyrightTiles` sequence with `$42` three times. `artifacts/lane-g/r5/title.png` is that screen, bundle `36f846d031cafdc10b3f4addfb50754cf0c22664500c244c54eaee3fcce8087d`.

`DrawPlayerCharacter` is `lb de, $60, $5a` on a 5-by-7 grid: GB y 80–135 and x 82–122. The copyright row is y 136, so the feet stop one pixel row above it and the body sits over GAME FREAK. r5 drew that sheet at scale 2 from `(308, 118)`, which crossed the row and covered `inc.` The same 20-by-13 cells now map the OAM box. Sprite 10 still follows `TitleBallYTable`. `artifacts/lane-g/r6/title.png` is that frame, bundle `3701fa64d49b77451857f9b1a493771a5af6d8233875a3399c058df28bb4402f`.

## Round 5

Lane E's `db83fbfd` is on this branch. Codec version 5 stores the chosen names. A version 1–4 save that omits them still loads as `RED` and `BLUE`. An explicit name on an older save is kept. Catch and gift handoffs call `Story.promptNickname`. The yes/no question wraps inside the naming box. The Name Rater house uses the reserved object, and `Story.tryNameRater` still requires that object on the faced tile. `Story.storeNickname` accepts the same 1–10 glyphs as the Pokemon codec, including `×` `♂` `♀`. The continue box reads the saved candidate, so a saved name is not replaced by the live default.

Playdate Simulator 3.1.2, production bundle `source_sha256` `f695f58096595da10ffc3b0cb915c526d43b211e66e35ea04225022103775a50`. Captures are in `artifacts/lane-g/r7/`: `nickname-gift.png` (the starter ask), `nickname-catch.png` (the wild ask after Gotcha), `name-rater.png`, `name-rater-yes.png`, `name-rater-rate.png`, `name-rater-keyboard.png`, and `continue-box.png` (`PLAYER` `GARY`).

## Round 6

BlueBot approved the Continue box. The Name Rater words stay `_NameRatersHouseNameRaterGiveItANiceNameText`. The box was the system font. Every dialog box is pokered's two-line, 18-tile box: `MESSAGE_BOX` at `hlcoord 0, 12`, text on rows 14 and 16, and `▼` at column 18 of row 16. Breaks follow `text` / `line` / `cont` / `para`. `dialog.lua` is lane E, so this is `tools/notes/lane-e-dialog-font.patch`. `tools/tests/test_lane_e_dialog_font.py` checks that the patch applies. The assertion that the box already uses `GbFont` is an expected failure until lane E lands it. After applying it, lane E runs `python3 tools/visual/compare.py <reviewed-baseline> <candidate> --protected-preservation` and updates baselines only for dialog-box pixels. The overworld, battle messages, and Oak's speech share these glyphs.

The nickname ask matches `AskName`. `_DoYouWantToNicknameText` prints in the dialog box over the current scene: the battle after a catch, the overworld for a gift. The YES/NO menu is `TWO_OPTION_MENU` at `hlcoord 14, 7`, 4 by 3, cursor column 15, YES on row 8 and NO on row 10. Only YES opens the naming screen. The full-screen ask and its `SQUIRTLE NICKNAME?` title are gone.

`tools/integration/kanto-first-entry/qualified/provenance.json` and `tools/references/content-transforms-149/provenance.json` are restored to the copies lane E regenerates. A production build of this commit fails the transform-dependency check until that regeneration. The scratch build below kept the matching hashes so the simulator could run.

The r8 dialog frames were rendered with the patch applied on a scratch tree. That bundle's `source_sha256` is `b4d2fd7e2cf2298494c8b3005c968f7432e4878e1ae720719d6ea93b00b736b8` and includes the patch, so it will not match this commit. Playdate Simulator 3.1.2. Frames are in `artifacts/lane-g/r8/`: `nickname-gift.png` (the lab, the last question page, and YES/NO), `nickname-catch.png` (the battle after Gotcha, the same question, and YES/NO), `name-rater-rate.png` (`SQUIRTLE, is it?` / `That is a decent` with `▼`), and `overworld-dialog.png` (the house greeting).

## Round 7

BlueBot approved the overworld dialog, the gift scene, and the YES/NO box at column 14, row 7. `_DoYouWantToNicknameText` ends on `done`, and `DoneText` does not place `▼`. `PromptText`, `Paragraph`, and `_ContText` do. The arrow is drawn for `prompt`, `para`, and `cont`. `cont` stays because the approved house greeting (`Hello, hello!` / `I am the official`) closes on `cont`. `done` and a page with no recorded ending draw none. The nickname question's second page is `done`, so the YES/NO menu has no arrow under it. The first page still blinks `▼`.

The rule lives in the dialog patch. `tools/tests/test_lane_e_dialog_font.py` applies that patch on a throwaway worktree and checks the nickname recipe (`cont` then `done`), one `prompt` page (`Which POKEMON` / `should I look at?`), and one `para` page (`That is a decent` / `nickname!`). The unpatched `dialog.lua` still fails the tile-font assertion, and that assertion now also requires `Dialog.showsArrow`.

A newly caught species follows `item_effects.asm`: the owned flag is read before recruit, `ItemUseBallText06` prints, `ShowPokedexData` opens that species, and A returns to the battle before `AskName`. The empty enemy side after Gotcha stays. The player's back sprite and the HUD above the message box match a pre-throw frame from the same fight, pixel for pixel. A dialog over the battle was leaving the overworld camera offset applied, which slid the field off the top; the field is drawn from the origin again.

The r9 frames were rendered with the patch applied on a scratch tree. That bundle's `source_sha256` is `743b277c49d93f0a191b4979f203eb63471f3dc7c3d75be9752f78c60aab0180` and includes the patch plus the matching transform hashes, so it will not match this commit. A production build of this commit still fails the transform-dependency check until lane E regenerates those hashes. Playdate Simulator 3.1.2. Frames are in `artifacts/lane-g/r9/`: `nickname-gift.png`, `nickname-catch.png`, `pre-throw.png`, `post-pokedex.png`, and `pokedex-rattata.png` (the new entry that returns to the battle).

## Round 8

BlueBot's Zapdos clip switched box styles. `A wild ZAPDOS appeared!` and the typing `Go! SQUIRTLE!` use the tile border and the pixel font. Once the page settles, `Go! SQUIRTLE!` and `What will SQUIRTLE do?` fall through to the thin rectangle and the system font. The dialog patch, applied on `origin/cursor/lane-e-integration` at `2ded4b6a`, did not cover that. Typing called `messageDialog:draw` only while the page was still active. The finished line used `_wrapped` with the system font, and the menu used `gfx.getSystemFont()`.

The patch now sends the typing page and the settled page through `BattleScene:drawDialog`, which calls `Dialog:draw`. The command frame uses that same dialog for `What will` / `NAME do?` and a `GbFont` tile box for `FIGHT` / `BAG` / `POKEMON` / `RUN`. The name is redrawn at 2× in the gutter so `SQUIRTLE do?` stays whole, and the menu labels are the same tiles at 13px so `POKEMON` and `RUN` both fit inside the border. The hunk starts after `local boxY = 180` and leaves the `gfx.setFont(gfx.getSystemFont())` lines, so lane H's `lane-e-battle-text-flicker.patch` still applies before or after it. `tools/tests/test_lane_e_dialog_font.py` checks that the patched typing call and the settled call both go through `drawDialog`. The unpatched `battleScene.lua` still fails that assertion.

`gfx/font/font.png` char `$E7` and `Source/images/title/font/font.png` tile `0x67` are the same 8×8 pixels, 20 ink pixels. The charmap already points `!` at `$E7`. The thick mark is the 20×13 nearest-neighbor scale of that tile. The glyph and the charmap are unchanged.

The r10 frames were rendered on a scratch tree of `e93bc416`. The before set applies the dialog font and leaves `battleScene.lua` unpatched, so the style swap is visible. The after set includes the battle hunk. That bundle's `source_sha256` is `3641207b8a9879759e15d4728941b589ae6f48b12b053cff34540d6482a38f44` and includes the patch, so it will not match this commit. A production build of this commit still fails the transform-dependency check until lane E regenerates those hashes. Playdate Simulator 3.1.2. The fixture is Squirtle L5 against Zapdos L50. Frames are in `artifacts/lane-g/r10/`: `before-appeared.png`, `before-typing.png`, `before-go-full.png`, `before-go-settled.png`, `before-menu.png`, `after-appeared.png`, `after-typing.png`, `after-go-full.png`, `after-go-settled.png`, and `after-menu.png`.

## Round 9

BlueBot approved the shared renderer and did not approve the 20×13 scale. Every `GbFont` blit is now an integer 2× of the 8×8 tile, 16×16, nearest neighbor. `!` stays charmap `$E7` (tile `0x67`, 20 ink pixels). The glyph is unchanged; only the scale changed, so the mark keeps the `$E7` shape. Eighteen glyphs are 288px. Pokered's two text rows keep the blank tile between them (`data/text_boxes.asm` `MESSAGE_BOX` is `0, 12` through `19, 17`; text is `bccoord 1, 14` and `hlcoord 1, 16`). That blank row stays 16px in the narration box, because 6×16 = 96 fits on the screen.

The narration box is `x=0, y=144, w=320, h=96`. Text is `(16, 176)` and `(16, 208)`. The gap is `y=192–208`. `▼` is `(288, 208)` for `prompt`, `para`, and `cont`.

`BATTLE_MENU_TEMPLATE` is `text_box_text` at `data/text_boxes.asm:31`: columns `8, 12` through `19, 17`, text at `10, 14`. `BattleMenuText` is `FIGHT <PK><MN>` / `ITEM  RUN`. `DisplayBattleMenu` (`engine/battle/core.asm`) restores the screen and draws that template over the right of the message box. The port's words are `FIGHT` / `BAG` / `POKEMON` / `RUN`, and `POKEMON RUN` is 11 tiles, so the split moves to `x=208` so the cursor, the shared border, and those 11 tiles fit. The menu box is `x=208, y=144, w=192, h=96`. Labels start at `(224, 176)` and `(224, 208)`; `BAG` and `RUN` start at `x=352` and the last glyph ends at `x=400`. The left box is `x=0, y=144, w=224, h=96`, which is the border plus 12 tiles. `What will` / `SQUIRTLE do?` is drawn there by `Dialog:draw`. There is no 13px size and no second redraw of the name. The prompt still goes through `drawDialog`.

AskName keeps YES/NO at column 14, row 7 (`x=224, y=112, w=96, h=80`, bottom `y=192`). The question uses the compact box (`y=176, h=64`, gap 0, text at `y=192` and `y=208`) so the first line starts where YES/NO ends. Overworld and battle narration stay on the full 96px box.

The HP and level panels are `tools/notes/lane-e-battle-hud.patch`. `DrawHPBar` (`home/pokemon.asm`) writes `$71` (HP), `$62` (left cap), six middle tiles, and `$6d` for the battle right cap. `PrintLevel` writes `<LV>` (`$6E`). `LoadHudTilePatterns` copies `gfx/battle/battle_hud_1.1bpp` onto vChars2 `$6d`, which is the right cap and the Lv tile that is actually shown. The sheet is `Source/images/battle/hud.png`. Enemy `ZAPDOS` Lv50 is `x=8, y=8, w=160, h=32`. Player `SQUIRTLE` Lv5 and `19/19` is `x=216, y=96, w=176, h=48`, ending on the message box. A status replaces the level. The hunk stays above `gfx.setFont(gfx.getSystemFont())` and does not touch the message hunk, so it applies before or after `lane-e-dialog-font.patch` and before or after `lane-e-battle-text-flicker.patch`. `tools/tests/test_lane_e_battle_hud.py` expects the unpatched battle scene to fail.

The circle in r10 `after-go-settled.png` at about `(47, 77)` is the send-out ball, not the poof and not a stray tile. `BattleScene:drawPresentation` draws the ball while `frame < 10`. At frame 5, `t=0.5`, the player ball starts at `x=0` and lands on `(95, 112)` with a hop of 35, so it is at `(47.5, 77)`. `updateVisualEvent` clears `playerShown` for the send-out, which is why Squirtle is absent. Pokered `SendOutMon` (`engine/battle/core.asm`) prints the line, draws the HUDs, plays `POOF_ANIM`, then `AnimateSendingOutMon`, which writes the ball tile (`$4c`) and grows the mon. The rays after frame 9 are this port's stand-in for that poof and grow. The captured frame is still on the ball arc.

The r11 frames were rendered on a scratch tree of `dbfdc00e` with both patches applied. That bundle's `source_sha256` is `2730d2bd50fc0c2b5c6e780ba36668550e741fb5dc9f8797a017f005a0efce7e` and includes the patches, so it will not match this commit. Playdate Simulator 3.1.2. The fixture is Squirtle L5 against Zapdos L50. Frames are in `artifacts/lane-g/r11/`: `appeared.png`, `typing.png`, `go-full.png`, `go-settled.png`, `menu.png`, `hud.png`, and `overworld-dialog.png`.

## Blockers

- The rival NPC id stays `BLUE`. Dialogue uses the chosen rival name. The actor lookup does not.
- The intro tilemap scroll (`hSCX` in `IntroMoveMon`) is still the static first frame. The three Gengar poses are in place.
- `TitleState:update` calls `KantoAudio.playCue("title")` while the title state is open. The start-menu sound stays on lane F's observer. Intro music is still unwired.
