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

## Blockers

- Chosen names do not survive Continue. The codec still asserts `RED` / `BLUE`.
- Nickname glyphs outside printable ASCII are rejected by `Story.storeNickname`, because `pokemonCodec.lua` rejects them. The keyboard still shows `×` `♂` `♀` `PK` `MN`.
- The rival NPC id stays `BLUE`. Dialogue uses the chosen rival name. The actor lookup does not.
- Intro and copyright graphics that exist only as 2bpp are not in the title PNG pipeline. The fight frame uses the existing fronts.
- `KantoAudio.playTitle` and `playIntro` do not exist yet. The seams no-op.
- There is no Playdate simulator in this environment. The frames are composed.
