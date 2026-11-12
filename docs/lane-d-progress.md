# Lane D progress

Reference: pret/pokered `af519899719f0754965776faac0e836a3b906e6d`, checked out at `/tmp/pokered`.
Base: `d2d05ed8` on `cursor/linux-runtime-seams-fcc0`. Lane A had already generated the 222-map manifest, the league maps, `Source/data/endgame/story.json`, and `Source/game/endgameStory.lua`.

## What lane A had already wired

These play from the generated story, without this lane's scripts:

- Viridian Gym door. Seven badges set `EVENT_VIRIDIAN_GYM_OPEN`. The locked door prints the guard text and steps the player down. The twelve spinner tiles build movement plans. No arrow sound.
- Giovanni's party, payout, Earth Badge, TM27 reward text, and the two Route 22 rival show flags. The eight gym trainers have parties, sight ranges, and defeat flags.
- Route 22's second rival roster, defeat flag, and show flag. Cerulean Routes owned the trigger. The event was a plain trainer, so the approach from `(29, 4)` / `(29, 5)` could not start: talk mode requires the rival to be adjacent, and he stands at `(25, 5)`.
- Route 22 Gate's Boulder Badge check and the one-step push down.
- Route 23's seven guards, their y coordinates, the Earth Badge's `x < 14` test, and the passed flags. The denied and accepted lines read `wNameBuffer`, and the plan never filled it, so the text would assert.
- Victory Road trainers. A boulder landing on a switch opens that switch's collision and, for the 3F hole, toggles the two boulder hide flags. The hole did not warp the player. 2F's map load did not reset the 1F switch. Items and boulders were not events, so talking to them asserted.
- Elite Four parties and the walk-in plans. Lorelei, Bruno, and Agatha treated all four entrance tiles as the autowalk, including the "don't run away" tiles at y=10. After the walk the battle was dispatched in sight mode, and every one of those trainers has sight 0, so the battle starter rejected it. The six-step walk also stops at y=5, three tiles south of the trainer at y=2.
- Lance's hallway walk, lock coordinates, and entrance blocks. The blocks reopened after `EVENT_BEAT_LANCE`. In pokered they stay closed for as long as the lock flag is set. The walk ends at `(6, 11)`, and the battle starts only from `(5, 1)` or `(6, 2)`. The port started a sight battle at the end of the hallway.
- The champion's starter teams and the player walk (up 1, right 1, up 3). The same sight-mode dispatch followed. Oak's four lines, his hidden start (`TOGGLE_CHAMPIONS_ROOM_OAK` begins clear), and the walk into the Hall of Fame were absent.
- Hall of Fame: walk up 5, Oak's line, hide `TOGGLE_CERULEAN_CAVE_GUY`, play the credits, return to the title, do not save. No party record. pokered also saves, resets the Indigo event range through `EVENT_LANCES_ROOM_LOCK_DOOR`, and sets the last blackout map to Pallet Town.
- Indigo Plateau's outdoor warps. The lobby nurse, mart, guide, cooltrainer, and link receptionist were not registered. The mart stock `indigoPlateauLobbyClerkText` was already correct.
- Moltres existed only as a Late Kanto data row (Victory Road 2F, level 50). Nothing started the fight. A static legendary has to stay if the player runs or loses, and hide on a win or a catch. Neither the ghost rule nor the Snorlax rule matches that.

`story.json` is byte-pinned by `tools/tests/test_endgame_story.py`. This lane did not edit it. Extra text lives in `Source/data/endgame/play.json`.

## What this lane filled

- Giovanni is a bespoke script. The win still writes the Earth Badge, the rival show flags, and now also marks gym trainers 0 through 7 defeated, which is pokered's `SetEventRange`. The same conversation gives TM27 when the bag has room. The later advice sets `TOGGLE_VIRIDIAN_GYM_GIOVANNI`, which hides him. The gym guide switches on `EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI`. The Revive ball is a pickup.
- Route 22's second rival is a bespoke scene owned by the Cerulean Routes registration, because that file already claimed the object. The upper trigger walks right 3 and the player faces left. The lower trigger walks all four rights onto the player's tile, the rival faces up, and the player faces down. The battle starts from the script.
- Route 23 plans set `wNameBuffer` to `EARTHBADGE`, `VOLCANOBADGE`, `MARSHBADGE`, `SOULBADGE`, `RAINBOWBADGE`, `THUNDERBADGE`, or `CASCADEBADGE`. The Victory Road gate sign is registered. Entering Route 23 still resets the 2F and 3F switches and the boulder toggles.
- Victory Road items are pickups (TM43, Rare Candy, TM17, Full Heal, TM05, Guard Spec., Max Revive, TM47). Boulders say "This requires STRENGTH to move!" Strength pushing is unchanged. Entering 2F, and entering the Indigo lobby, clears `EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH`. Standing on the 3F hole at `(23, 15)` warps to Victory Road 2F `(22, 16)` unless that switch flag is set.
- Moltres is a catchable static encounter. `EVENT_BEAT_MOLTRES` is set on a win, a catch, or a run, and left clear on a loss. `EndTrainerBattle` hides the sprite unless the battle was lost. The cry line is the dialogue "Gyaoo!".
- The Indigo lobby nurse heals with the standard Center lines and a checkpoint on Indigo Plateau `(9, 6)` facing down. The clerk opens `indigoPlateauLobbyClerkText`. The guide and the cooltrainer use their source lines. The link receptionist says the Cable Club welcome and the "we have to save" line. Linking itself is not implemented.
- Entering Lorelei's room sets `EVENT_STARTED_ELITE_4`. Entering the lobby after that clears the Indigo flags from Lorelei's trainer through `EVENT_LANCES_ROOM_LOCK_DOOR`, and clears the started flag. `EVENT_BEAT_CHAMPION_RIVAL` is outside that range and is kept.
- Lorelei, Bruno, and Agatha autowalk only from the door tiles (y=11) and only once. y=10, and either tile after the autowalk flag is set, prints "don't run away" and steps the player up. The walk is exactly six steps up. Sight is 0, so the walk does not start the battle. The player talks to the trainer afterward.
- Lance's hallway walk is unchanged and does not start the battle. The lock still closes when the player reaches `(5, 11)` or `(6, 11)`, and the entrance blocks stay closed while `EVENT_LANCES_ROOM_LOCK_DOOR` is set. Standing on `(5, 1)` or `(6, 2)` starts the battle. The win also sets `EVENT_BEAT_LANCE`.
- After the champion win, the receipt plays his defeated line, the prize money, his after-battle line, then Oak's four lines. Oak's congratulations use the player's starter as `wNameBuffer` (`CHARMANDER`, `SQUIRTLE`, or `BULBASAUR`). The script then warps to the Hall of Fame door. Round 1 left Oak hidden. Round 2 adds his walk; see Visual decisions.
- The Hall of Fame plan walks up, hides the Cerulean Cave guard, records the party, resets the Indigo range, sets the Pallet blackout, saves, plays the photo sequence, then the credits, and returns to the title.

## Lane A patch

`docs/lane-d-patches/session-codec-hall-of-fame.patch`

`SessionCodec` rejects an unknown `hallOfFame` field. The in-memory record cannot be saved, and this lane does not edit the codec. `tools/tests/test_lane_d_endgame.py` marks `test_save_schema_keeps_a_hall_of_fame_record` as an expected failure until that allowlist entry exists. The same save also needs the Indigo reset and Pallet as the last blackout map; there is no blackout-map field to write.

`Source/domain/sourceEncounters.lua` did get a small addition (the Moltres definition and `SourceEncounters.completed`). Ghost and Snorlax completion are unchanged: an unidentified ghost completes only on victory, and a Snorlax fight completes on every result except a loss. `Source/main.lua` appends `EndgameStory.actorMetadata` in the same place as the other story visibility rules. `Source/game/ceruleanRoutes.lua` only changes the second Route 22 rival, which that file already special-cased as belonging to this campaign.

## Visual decisions

BlueBot, under Miguel's Nov 11 standing autonomy. Each one matches pret/pokered `af519899`. Graphics go through the Bayer 31.25% / 68.75% shade map and the shared `Shade` patterns. No new art.

1. Spinners. `gfx/overworld/spinners.png` replaces gym VRAM `$3c,$3d,$4c,$4d` with spinner tiles 1, 3, 0, 2 on odd remaining steps, which is `GymSpinnerArrows`. The player's facing cycles down, left, up, right. The plan plays `SFX_ARROW_TILES` (`arrow_tiles`) when the spin starts.
2. Badge gates. Route 22 Gate plays `SFX_DENIED` between the two refusal lines. Each Route 23 guard plays it after the refusal line and before the step down.
3. Exclamation bubble. Pokered does not show the bubble for the scripted Elite Four, Champion, or Giovanni battles, so this lane does not add one. The champion and the Route 22 rival start in script mode, because those battles are not adjacent checks.
4. Giovanni. After the post-battle advice, `GBFadeOutToBlack` (4 palettes, 8 frames each), hide `TOGGLE_VIRIDIAN_GYM_GIOVANNI` at black, `Delay3`, then `GBFadeInFromBlack`.
5. Moltres. The battle text and `KantoAudio.playCry("moltres")` start together. The cry data is already in the cry pipeline.
6. Oak. After the champion win he is shown at `(3, 7)`, walks up 5 to `(3, 2)`, faces the player and the rival through the three Oak lines, walks up 2 onto the hall warp, and hides. The player follow is `WalkToHallOfFame_RLEMovement` (up 4, left 1). The third up lands on the warp at `(4, 0)`, which is where the hall warp fires. `championsOakMayCrossWarp` grants those two cells, including the padded column at x = 5, and `plan.simulated` walks through the rival.
7. Hall of Fame. `AnimateHallOfFame`: 100 frames, then each party Pokémon (front and back, name, level, both types, cry, "HALL OF FAME", 80 + 180 frames, fade to white in 24 frames), then Red from the checked-in overworld grid, then the existing credits player. `RedPicFront` is not in the battle PNG set, so the player card uses `SpriteFactory.grids.red`.
8. Victory Road and the doors. A boulder on a switch paints cavern block 29 or 21, then the collision opens. Lorelei and Bruno paint gym block `$24` closed and `$5` open. Agatha paints cemetery `$3b` closed and `$0e` open. Lance paints dojo `$72/$73` closed and `$31/$32` open. `setTile` runs before `setBlock`, so the script collision stays in charge.
9. Sprites. `SPRITE_LORELEI`, `SPRITE_BRUNO`, `SPRITE_AGATHA`, `SPRITE_LANCE`, and `SPRITE_OAK` install from `Source/data/zEndgame/sprites.json` through `SpriteFactory.makeSprite` at phase `(0, 0)`. Giovanni and Blue were already mapped. The five trainer pics already match the approved battle-art threshold, scale 2. They were not redrawn.

## Lane A patches, round 2

- `docs/lane-d-patches/arrow-denied-sfx.patch` adds `arrow_tiles` and `denied` to the synth. Playback is a `pcall` until then.
- `docs/lane-d-patches/oak-scripted-movement.patch` lets Oak cross the two Champion warps and lets `plan.simulated` walk through the rival, matching `CollisionCheckOnLand`.
- `docs/lane-d-patches/endgame-sprite-install.patch` calls `EndgameStory.prepareArt()` before `CeruleanContent.install`. The resolver copies its functions at install, so the wrap has to be earlier.
- `docs/lane-d-patches/cemetery-door-tile.patch` adds `pokered:CEMETERY:cell:07-08-17-18`. Until it is in the tile cache, Agatha's closed door is drawn from that same grid in `Source/data/endgame/visual.json`.

The round 1 save patch is applied. The Hall of Fame plan now records the party, resets the Indigo flags through `EVENT_LANCES_ROOM_LOCK_DOOR`, sets the Pallet Town blackout, and saves before the credits. `SessionCodec.VERSION` stays 4.

Review against af519899 kept the six-step Elite Four walk and script engagement, the Route 22 three-right and four-right approaches, and a Moltres run as a completed battle. Oak's warp cells are listed once `SourceActors.championsOakMayCrossWarp` is present, including the padded column at x = 5. `plan.simulated` skips sprite and tile collision and still refuses a step off the map.

Two Hall of Fame card details still disagree with pokered. `PrintMonType` erases `TYPE2/` when both types match, and this card still prints `TYPE2/` for Pikachu (`ELECTRIC`/`ELECTRIC`). Per-mon cards draw that species' front and back, which matches `HoFShowMonOrPlayer`. The player card draws the overworld sprite. pokered uses `RedPicFront` and `RedPicBack` there.

## Tests

`tools/tests/test_lane_d_endgame.py` covers the round 1 story checks plus the spinner sound and facing, both denied cues, talk mode with no bubble, Giovanni's fade counts, Oak's five-up walk and the hall follow, the Hall of Fame photo order and timing, Moltres's cry request, and the switch and door cell ids.

The six lane A gaps now pass at their cause: the Hall of Fame save field, the two SFX scores, Oak's warp transit, the simulated follow, the sprite install call, and Agatha's cemetery cell.

Before and after frames for the spinner, Giovanni's fade, Oak's walk, the Hall of Fame photo, and the switch and door blocks are in `/opt/cursor/artifacts/lane-d/frames/`. They are headless Bayer renders of the same grids. This environment has no Playdate SDK, so they are not simulator captures.

`tools/tests/test_endgame_story.py` still matches the pinned story and the credits length. `test_cerulean_routes`, `test_late_kanto_story`, `test_tower_story`, and `test_source_events` passed after round 1. Darwin-only and Playdate-simulator tests were not run.

