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
- Moltres existed only as a Late Kanto data row (Victory Road 2F, level 50). Nothing started the fight. `EndTrainerBattle` sets `EVENT_BEAT_MOLTRES` and hides the sprite unless `wIsInBattle` is `LOST_BATTLE`. A win, a catch, and a run all hide it. A loss leaves it.

`story.json` is byte-pinned by `tools/tests/test_endgame_story.py`. This lane did not edit it. Extra text lives in `Source/data/endgame/play.json`.

## What this lane filled

- Giovanni is a bespoke script. The win still writes the Earth Badge, the rival show flags, and now also marks gym trainers 0 through 7 defeated, which is pokered's `SetEventRange`. The same conversation gives TM27 when the bag has room. The later advice sets `TOGGLE_VIRIDIAN_GYM_GIOVANNI`, which hides him. The gym guide switches on `EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI`. The Revive ball is a pickup.
- Route 22's second rival is a bespoke scene owned by the Cerulean Routes registration, because that file already claimed the object. The upper trigger `(29, 4)` walks right 3. The lower trigger `(29, 5)` walks right 4, onto the player's tile, which is a declared script overlap. The rival then faces the way `Route22Rival1StartBattleScript` does, and the map script starts the battle without an adjacency check.
- Route 23 plans set `wNameBuffer` to `EARTHBADGE`, `VOLCANOBADGE`, `MARSHBADGE`, `SOULBADGE`, `RAINBOWBADGE`, `THUNDERBADGE`, or `CASCADEBADGE`. The Victory Road gate sign is registered. Entering Route 23 still resets the 2F and 3F switches and the boulder toggles.
- Victory Road items are pickups (TM43, Rare Candy, TM17, Full Heal, TM05, Guard Spec., Max Revive, TM47). Boulders say "This requires STRENGTH to move!" Strength pushing is unchanged. Entering 2F, and entering the Indigo lobby, clears `EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH`. Standing on the 3F hole at `(23, 15)` warps to Victory Road 2F `(22, 16)` unless that switch flag is set.
- Moltres is a catchable static encounter. `EVENT_BEAT_MOLTRES` is set on a win, a catch, or a run, and left clear on a loss, matching `EndTrainerBattle`. The cry line is the dialogue "Gyaoo!". The sprite hides through the actor rule.
- The Indigo lobby nurse heals with the standard Center lines and a checkpoint on Indigo Plateau `(9, 6)` facing down. The clerk opens `indigoPlateauLobbyClerkText`. The guide and the cooltrainer use their source lines. The link receptionist says the Cable Club welcome and the "we have to save" line. Linking itself is not implemented.
- Entering Lorelei's room sets `EVENT_STARTED_ELITE_4`. Entering the lobby after that clears the Indigo flags from Lorelei's trainer through `EVENT_LANCES_ROOM_LOCK_DOOR`, and clears the started flag. `EVENT_BEAT_CHAMPION_RIVAL` is outside that range and is kept.
- Lorelei, Bruno, and Agatha autowalk only from the door tiles (y=11) and only once. The walk is the six source steps and does not start the battle. Sight is 0, so the player talks once they are next to the trainer. y=10, and either tile after the autowalk flag is set, prints "don't run away" and steps the player up.
- Lance's hallway walk is unchanged and does not start the battle. The lock still closes when the player reaches `(5, 11)` or `(6, 11)`, and the entrance blocks stay closed while `EVENT_LANCES_ROOM_LOCK_DOOR` is set. Standing on `(5, 1)` or `(6, 2)` starts the battle. The win also sets `EVENT_BEAT_LANCE`.
- After the champion win, the receipt plays his defeated line, the prize money, and his after-battle line. Oak is shown, walks up five from the Lance warp, speaks his four lines, walks up two onto the Hall of Fame warp, and hides. The player follows onto that warp. Oak's congratulations use the player's starter as `wNameBuffer` (`CHARMANDER`, `SQUIRTLE`, or `BULBASAUR`). The champion battle itself starts from the script after the entrance walk, including when the player is not cardinally adjacent.
- The Hall of Fame plan walks up, hides the Cerulean Cave guard, records the party (species, level, and name), clears the Indigo flags through `EVENT_LANCES_ROOM_LOCK_DOOR`, sets the blackout checkpoint to Pallet Town `(3, 17)` facing up, saves, plays the credits, and returns to the title. `EVENT_BEAT_CHAMPION_RIVAL` is outside that range and is kept. The record is a versioned list of up to 50 teams. The 51st drops the oldest.

## Lane A patch

`docs/lane-d-patches/session-codec-hall-of-fame.patch`

The allowlist entry is applied. `HallOfFame.normalize` accepts the record, older saves migrate to an empty list, and `GameSession:recordHallOfFame` appends the team before the Hall of Fame save boundary writes the file. Pallet is stored as the session checkpoint, which is the blackout destination this save schema already has.

`Source/domain/sourceEncounters.lua` did get a small addition (the Moltres definition and `SourceEncounters.completed`). Ghost and Snorlax completion are unchanged: an unidentified ghost completes only on victory, and a Snorlax fight completes on every result except a loss. `Source/main.lua` appends `EndgameStory.actorMetadata` in the same place as the other story visibility rules. `Source/game/ceruleanRoutes.lua` only changes the second Route 22 rival, which that file already special-cased as belonging to this campaign.

## Open visual questions

Not chosen here:

- Spinner floor tiles and `SFX_ARROW_TILES`. The arrow plan turns the player through the down, left, up, right cycle while the tile pushes them. `gfx/overworld/spinners.2bpp` is not installed, and `SourceAudio` does not play the cue. The gap is recorded on the event. The facing cycle is not a substitute for the tile animation.
- `SFX_DENIED` when a badge gate refuses the player.
- The exclamation bubble. Sight-mode trainers already show one. These rival and Elite Four battles start from a script, in talk mode, so the bubble does not appear.
- Giovanni's fade before he disappears. The flag hide removes him on the advice conversation.
- Moltres's cry. The line is shown. Playback stays with the unimplemented `SourceAudio` owner.
- Oak's first line still waits until he has finished the five-step walk. pokered prints it while he is moving. Dialogue here blocks the script.
- The Hall of Fame machine's photo sequence. This lane plays the credits player lane A already built.
- The switch and door block tiles (Victory Road tiles 29 and 21, and the Elite Four door blocks). Collision changes; the art does not.
- Any Elite Four or Giovanni sprite that the runtime still has marked as needing a mapping.

## Tests

`tools/tests/test_lane_d_endgame.py` covers the badge names, Route 23 RAM, the don't-run tiles, the six-step Elite Four walk, Lance's hallway, the hole warp, Giovanni's TM and hide, the Route 22 approach, Oak's seven-step walk, the Hall of Fame record and save, and Moltres outcomes against the ghost and Snorlax rules. The save-schema test is no longer an expected failure.

`tools/tests/test_endgame_story.py` still matches the pinned story and the credits length. `test_cerulean_routes`, `test_late_kanto_story`, `test_tower_story`, and `test_source_events` passed after these edits.

`test_endgame_story` imports `PIL`. It was not installed; `pip install pillow` made that test runnable. The generator also expects pokered at `/home/ubuntu/Developer/Pokemon-PlayDate-env/pokered`. That path is a symlink to the checkout at `/tmp/pokered`. Darwin-only and Playdate-simulator tests were not run; this environment is Linux and has no Playdate SDK.
