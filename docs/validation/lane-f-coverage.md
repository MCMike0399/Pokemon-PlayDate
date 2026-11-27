# Lane F audio coverage

Pokered `af519899719f0754965776faac0e836a3b906e6d`. Every `music_const` from `constants/music_constants.asm`. The main path is New Game through the Champion, the Hall of Fame, the credits, and the postgame (Cerulean Cave), including the required detours: all eight gyms, the Pokémon Tower, the SS Anne, the Rocket Hideout, Silph Co., the Safari Zone, Cinnabar Mansion, Victory Road, and the Elite Four.

`SFX_STOP_ALL_MUSIC` is `$ff`, not a `music_const`. The SS Anne cue list stops the bed when that command is posted.

Counts, excluding the two unused IDs: **played 185**, **patched 9**, **missing 10**.

## Missing

| Constant | Why it is still silent |
| --- | --- |
| `MUSIC_MUSEUM_GUY` | scripts/PewterMuseum.asm and auto_movement.asm. The museum guy walk is not a ported event. |
| `MUSIC_JIGGLYPUFF_SONG` | scripts/PewterPokecenter.asm. The Jigglypuff song event is not ported. |
| `MUSIC_INTRO_BATTLE` | engine/movie/intro.asm fight intro. The title clock stops at the crash and whoosh; hip, hop and raise are the same unported scene. |
| `SFX_TRADE_MACHINE` | Cable Club trade. The trade machine is not ported. |
| `SFX_INTRO_HIP` | Unported fight intro. Same scene as MUSIC_INTRO_BATTLE. |
| `SFX_INTRO_HOP` | Unported fight intro. |
| `SFX_INTRO_RAISE` | Unported fight intro. |
| `SFX_SLOTS_STOP_WHEEL` | Celadon slots has a service desk and no spin UI. |
| `SFX_SLOTS_REWARD` | Celadon slots has no spin UI. |
| `SFX_SLOTS_NEW_SPIN` | Celadon slots has no spin UI. |

## Recorded in a lane-E patch

The scores exist. `tools/notes/lane-e-audio-gaps.patch` and `tools/notes/lane-e-audio-main-path.patch` are not applied. The matching tests are `expectedFailure` until Lane E applies them. The observer plays a main-path receipt as soon as the field exists.

| Constant | Patch |
| --- | --- |
| `SFX_DENIED` | tools/notes/lane-e-audio-gaps.patch, eventState denied. |
| `SFX_ARROW_TILES` | tools/notes/lane-e-audio-gaps.patch, eventState arrow tiles. |
| `SFX_POKEFLUTE` | tools/notes/lane-e-audio-gaps.patch, Snorlax flute. |
| `SFX_HEAL_HP` | tools/notes/lane-e-audio-main-path.patch. `game.lastItemUse` after a potion, revive, or full restore. |
| `SFX_HEAL_AILMENT` | Same patch. `game.lastItemUse` after a status cure. |
| `SFX_POKEDEX_RATING` | Same patch. `game.lastDexRating` when Oak's "How is your POKéDEX coming?" page opens. The owned count picks the band; 10–39 is this sound. |
| `SFX_POISONED` | Same patch. `game.lastFieldPoison` every fourth completed step while a living party member is poisoned. |
| `SFX_DEX_PAGE_ADDED` | Same patch. `battle.dexPageAdded` when the caught species was not already owned. |
| `SFX_SWAP` | Same patch. `party.swapReceipt` only after two different slots exchange. Cancel does not set it. |

Hall of Fame music is played by the observer when the photo phase starts, so `MUSIC_HALL_OF_FAME` is played. The same patch also calls it from `beginPhotos`.

## Played

| Constant | How |
| --- | --- |
| `MUSIC_PALLET_TOWN` | Observer or map bed. |
| `MUSIC_POKECENTER` | Observer or map bed. |
| `MUSIC_GYM` | Observer or map bed. |
| `MUSIC_CITIES1` | Observer or map bed. |
| `MUSIC_CITIES2` | Observer or map bed. |
| `MUSIC_CELADON` | Observer or map bed. |
| `MUSIC_CINNABAR` | Observer or map bed. |
| `MUSIC_VERMILION` | Observer or map bed. |
| `MUSIC_LAVENDER` | Observer or map bed. |
| `MUSIC_SS_ANNE` | Observer or map bed. |
| `MUSIC_MEET_PROF_OAK` | Observer or map bed. |
| `MUSIC_MEET_RIVAL` | Observer or map bed. |
| `MUSIC_SAFARI_ZONE` | Observer or map bed. |
| `MUSIC_PKMN_HEALED` | Observer or map bed. |
| `MUSIC_ROUTES1` | Observer or map bed. |
| `MUSIC_ROUTES2` | Observer or map bed. |
| `MUSIC_ROUTES3` | Observer or map bed. |
| `MUSIC_ROUTES4` | Observer or map bed. |
| `MUSIC_INDIGO_PLATEAU` | Observer or map bed. |
| `MUSIC_GYM_LEADER_BATTLE` | Observer or map bed. |
| `MUSIC_TRAINER_BATTLE` | Observer or map bed. |
| `MUSIC_WILD_BATTLE` | Observer or map bed. |
| `MUSIC_FINAL_BATTLE` | Observer or map bed. |
| `MUSIC_DEFEATED_TRAINER` | Observer or map bed. |
| `MUSIC_DEFEATED_WILD_MON` | Observer or map bed. |
| `MUSIC_DEFEATED_GYM_LEADER` | Observer or map bed. |
| `MUSIC_TITLE_SCREEN` | Observer or map bed. |
| `MUSIC_CREDITS` | Observer or map bed. |
| `MUSIC_HALL_OF_FAME` | Observer or map bed. |
| `MUSIC_OAKS_LAB` | Observer or map bed. |
| `MUSIC_BIKE_RIDING` | Observer or map bed. |
| `MUSIC_SURFING` | Observer or map bed. |
| `MUSIC_GAME_CORNER` | Observer or map bed. |
| `MUSIC_DUNGEON1` | Observer or map bed. |
| `MUSIC_DUNGEON2` | Observer or map bed. |
| `MUSIC_DUNGEON3` | Observer or map bed. |
| `MUSIC_CINNABAR_MANSION` | Observer or map bed. |
| `MUSIC_POKEMON_TOWER` | Observer or map bed. |
| `MUSIC_SILPH_CO` | Observer or map bed. |
| `MUSIC_MEET_EVIL_TRAINER` | Observer or map bed. |
| `MUSIC_MEET_FEMALE_TRAINER` | Observer or map bed. |
| `MUSIC_MEET_MALE_TRAINER` | Observer or map bed. |
| `SFX_NOISE_INSTRUMENT01` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT02` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT03` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT04` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT05` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT06` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT07` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT08` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT09` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT10` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT11` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT12` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT13` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT14` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT15` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT16` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT17` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT18` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_NOISE_INSTRUMENT19` | Noise-channel instrument inside the song scores, not a separate cue. |
| `SFX_CRY_00` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_01` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_02` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_03` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_04` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_05` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_06` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_07` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_08` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_09` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_0A` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_0B` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_0C` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_0D` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_0E` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_0F` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_10` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_11` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_12` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_13` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_14` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_15` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_16` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_17` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_18` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_19` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_1A` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_1B` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_1C` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_1D` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_1E` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_1F` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_20` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_21` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_22` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_23` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_24` | KantoCries plays this program when a species that uses it cries. |
| `SFX_CRY_25` | KantoCries plays this program when a species that uses it cries. |
| `SFX_GET_ITEM_2` | Observer or map bed. |
| `SFX_TINK` | Observer or map bed. |
| `SFX_START_MENU` | Observer or map bed. |
| `SFX_PRESS_AB` | Observer or map bed. |
| `SFX_GET_ITEM_1` | Observer or map bed. |
| `SFX_GET_KEY_ITEM` | Observer or map bed. |
| `SFX_TURN_ON_PC` | Observer or map bed. |
| `SFX_TURN_OFF_PC` | Observer or map bed. |
| `SFX_ENTER_PC` | Observer or map bed. |
| `SFX_HEALING_MACHINE` | Observer or map bed. |
| `SFX_TELEPORT_EXIT_1` | Observer or map bed. |
| `SFX_TELEPORT_ENTER_1` | Observer or map bed. |
| `SFX_TELEPORT_EXIT_2` | Observer or map bed. |
| `SFX_LEDGE` | Observer or map bed. |
| `SFX_TELEPORT_ENTER_2` | Observer or map bed. |
| `SFX_FLY` | Observer or map bed. |
| `SFX_PUSH_BOULDER` | Observer or map bed. |
| `SFX_SS_ANNE_HORN` | Observer or map bed. |
| `SFX_WITHDRAW_DEPOSIT` | Observer or map bed. |
| `SFX_CUT` | Observer or map bed. |
| `SFX_GO_INSIDE` | Observer or map bed. |
| `SFX_PURCHASE` | Mart buy result on the shop state. Poké Mart only; a sale does not play it. |
| `SFX_SAVE` | PC box change result, and `game.lastSave` once the menu-save patch is applied. |
| `SFX_SAFARI_ZONE_PA` | Safari game-over announcement. Elevator rides use `game.lastElevator` from the same patch. |
| `SFX_SWITCH` | Vermilion trash success, the Game Corner poster, and Bill's initiated page. |
| `SFX_SHRINK` | Bill's cell-separator phase. Oak's intro shrink is not a drawn scene. |
| `SFX_COLLISION` | Observer or map bed. |
| `SFX_GO_OUTSIDE` | Observer or map bed. |
| `SFX_LEVEL_UP` | Observer or map bed. |
| `SFX_BALL_TOSS` | Observer or map bed. |
| `SFX_BALL_POOF` | Observer or map bed. |
| `SFX_FAINT_THUD` | Observer or map bed. |
| `SFX_RUN` | Observer or map bed. |
| `SFX_CAUGHT_MON` | Observer or map bed. |
| `SFX_PECK` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_FAINT_FALL` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_09` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_POUND` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_0B` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_0C` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_0D` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_0E` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_0F` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_DAMAGE` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_NOT_VERY_EFFECTIVE` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_12` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_13` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_14` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_VINE_WHIP` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_17` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_18` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_19` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_SUPER_EFFECTIVE` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_1B` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_1C` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_DOUBLESLAP` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_1E` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_HORN_DRILL` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_20` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_21` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_22` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_23` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_24` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_25` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_26` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_27` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_28` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_29` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_2A` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_2B` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_2C` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_PSYBEAM` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_2E` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_2F` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_PSYCHIC_M` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_31` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_32` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_33` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_34` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_35` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_BATTLE_36` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_TRAINER_APPEARED` | data/moves/sfx.asm row, pitched through KantoMoveSfx. |
| `SFX_INTRO_LUNGE` | Observer or map bed. |
| `SFX_INTRO_CRASH` | Observer or map bed. |
| `SFX_INTRO_WHOOSH` | Observer or map bed. |
| `SFX_SHOOTING_STAR` | Observer or map bed. |

## Not on the main path

| Constant | Why it is excluded |
| --- | --- |
| `SFX_59` | Defined and never called on the main path. |
| `SFX_BATTLE_16` | Defined and never called on the main path. |

## This pass

- `SFX_FLY` plays when a field Fly fade starts (`LeaveMapAnim`) and again when the arrival receipt is posted (`EnterMapAnim`). The battle move Fly is a different sound: `SFX_NOT_VERY_EFFECTIVE` with that row's pitch and tempo, through `KantoMoveSfx`.
- `SFX_BALL_TOSS` plays when the capture phase changes to throw. Absorb and breakout stay `SFX_BALL_POOF`.
- `SFX_RUN` plays once when a battle outcome is `run`.
- `SFX_COLLISION` plays on a new terrain or NPC block, and waits out the sound before it can play again. Pokered skips a restart while `SFX_COLLISION` is the current sound.
- `SFX_SS_ANNE_HORN` plays from `vermilionShip.cues`. The same list stops the bed on `SFX_STOP_ALL_MUSIC` and starts `MUSIC_SURFING`.
- `SFX_SWAP` plays only from `party.swapReceipt`, which the lane-E patch sets after a real exchange. Leaving the swap phase on cancel does not play it.
- `SFX_PURCHASE` plays when a shop result is a successful buy.
- `SFX_SAVE` plays when a PC box change reports `saved`, and when `game.lastSave.ok` is set by the menu-save patch.
- `SFX_HEAL_HP` and `SFX_HEAL_AILMENT` play from `game.lastItemUse`. Potions, revives, and full restores are the HP sound. Status cures are the ailment sound.
- `SFX_DEX_PAGE_ADDED` plays when `battle.dexPageAdded` is set for a species that was not owned.
- `SFX_POISONED` plays from `game.lastFieldPoison`.
- `SFX_POKEDEX_RATING` plays from `game.lastDexRating` when the owned count is 10–39. The other bands use the denied, item, caught, level-up, and key-item cues.
- `SFX_SWITCH` plays when the event page is the first Vermilion trash success, the Game Corner poster, or Bill's initiated text.
- `SFX_SHRINK` plays when the event phase is the cell separator.
- `SFX_SAFARI_ZONE_PA` stops the bed and plays on the Safari game-over announcement, and on `game.lastElevator`.
- Every `data/moves/sfx.asm` row plays when `battle.currentMoveKey` changes. Agility, Kinesis, Transform, and Dizzy Punch reuse the pitched faint-fall scores. A hit, faint, or trainer fall that lands in the same update is queued behind the move row.

