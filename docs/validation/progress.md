# Full-game execution ledger

## 2026-11-12 Lane A stops

Lane E now owns the shared engine, `main`, and the pending handoffs, including lane B's STAY-actor patch. This commit is only on `cursor/linux-runtime-seams-fcc0`. `main` was not moved.

Unfinished: the revised patch at `75118c76` was not applied as written. It would mark every non-`WALK` object stationary, including the 135 `STAY, NONE` NPCs that still turn. `SourceActors.wanders` in this commit is the narrower rule, and `WorldMotionData.normalize` still rejects a stationary `delay`. The full suite was still running and is not recorded as green. Boot was not measured again. No LCD clip. `main` stays at `bf92c4fc607115b135297b89e7c92aeb80b2ed12`.

## 2026-11-12 Fixed-facing STAY objects are not wanderers

Lane B pushed `75118c76` with a revised `tools/notes/lane-a-cinnabar-trainer-delay.patch`. It no longer rewrites saves. It sets `random` only when `event.movement=="WALK"`, and still excludes trainers, items and boulders. `WorldMotionData.normalize` is untouched.

That diagnosis is right for Cinnabar Gym. `data/maps/objects/CinnabarGym.asm` gives Blaine, the seven Super Nerds and the guide `STAY, DOWN`. `STAY` is `$FF`. `CanWalkOntoTile` rejects it before `MAPX`/`MAPY` change, and a fixed facing ignores the random byte, so those nine never leave the tile or turn. The verbatim line is broader than that. `STAY, NONE` is used by 135 ordinary NPCs, and `TryWalking` writes their new facing before the step is rejected. Marking every non-`WALK` object stationary would freeze those turns.

`SourceActors.wanders` keeps `WALK`, and `STAY` with `NONE` or `ANY_DIR`, random. Fixed `DOWN`/`UP`/`LEFT`/`RIGHT` is not. A saved `delay` on a stationary actor is still rejected. The coverage snapshot is `6ea501a7fc159b8b42b18ec88f1cc692364fe1a84cfa0b88c687e5885eb55931`. The previous snapshot is nested. No row was relabeled.

## 2026-11-12 The Cinnabar delay patch stays unapplied

Lane B's `tools/notes/lane-a-cinnabar-trainer-delay.patch` is on their agent, not on `origin/cursor/lane-b-south-loop` (`d33d853a`). It teaches `WorldMotionData.normalize` to copy a saved actor and, when `phase` is `delay` and `spec.random` is false, store `static` with both delay fields cleared. The paired test expects that settle and currently marks it an expected failure until the shared file changes.

That is not the pokered gym. `data/maps/objects/CinnabarGym.asm` at `af519899` gives Blaine, the seven Super Nerds, and the guide `STAY`. They do not take a wander delay. `EVENT_2A7` is set in `home/overworld.asm` after a Cinnabar Gym battle and cleared at the start of `CinnabarGymSetMapAndTiles`. No other instruction in that tree reads the flag. The patch never mentions it.

The rewrite also keeps the saved coordinates. A `STAY` object that had already wandered would remain off its `object_event` tile. It applies to every non-random actor, not only sequence 119. `normalize` still rejects a `delay` record unless `spec.random` is set. Shared battle code was not changed.

## 2026-11-12 The session accepts all eight badges

`GameSession:hasBadge` knew boulder, cascade, thunder, rainbow, and soul. Sabrina's victory already writes `BADGE_MARSH`, and the Route 23 guards name marsh, volcano, and earth. Those three names now resolve to the same quest flags. The Kanto and content-transform pins were regenerated with the SDK export because they hash `domain/gameSession.lua`. The only structural change in the Kanto export, besides `build_id`, is the order of two `required_trainers` ids. East, South, and Saffron packets match the previous packets. The Vermilion journey projection was regenerated with its generator for the same reason.

The coverage snapshot is `883c5cc5419290a3fd05b6b4af7eaf922a5ec2381bc37aca1fd482e59c88cb7b`. The previous snapshot is nested. No row was relabeled.

Session `2ab8117478cc4d5e8eac082502e1c9ab` reached `title.visible` at 1001 ms and `initialize.ready` at 5887 ms. The title phase was `menu`. Sampled peak 13316.104 KiB. `tools/measure_boot_budget.py` passed. `MallocPoolSize` stayed `16645684`. The heartbeat was quiescent at 6023 ms.

`python3 -m unittest discover -s tools/tests` ran 1296 tests: OK, 11 skipped.

## 2026-11-12 The nine installed-map trades are registered

`NPCTrades.install` was still the parked line after `Daycare.install`. The trade payloads, the Take-before-offer rule, and `MidgameServicesState` (the one event executor, subclass of `NPCTradeState`) were already in the tree. The Cerulean trade house is installed, and the ledger says to register `pokered:CERULEAN_TRADE_HOUSE:objects:2`. That call registers every trade whose map is already in `sourceMaps.json`, including the gambler. Object 1 stays the granny's ordinary dialogue. A selected Pokémon that holds an item is still rejected until Take. The Fuchsia Gym floor row already records Miguel's 2026-11-11 option (a): keep the dense Bayer floor, no floor change. Lane B's latest coast commit did not add a shared-code Blaine patch.

Cerulean and Vermilion journey projections hash `main.lua`, so both were regenerated with their generators after the install call. The coverage snapshot is `7ce440e218429133795280a9ed4b36c817a199b5d750617938ed0723cd09812a`. The previous snapshot is nested. No row was relabeled.

Session `0d21f4ae8a414aa1932aa2a3d48953b2` reached `title.visible` at 1027 ms and `initialize.ready` at 5836 ms. `NPCTrades.install` was 4594–4599 ms. Sampled peak 13316.968 KiB. `tools/measure_boot_budget.py` passed. The heartbeat was quiescent at 5972 ms. The LCD clip is `/opt/cursor/artifacts/hourly/20261112T123235Z-npc-trades.mp4`, about 8.3 seconds, 400×240, sha256 `c54a0f94d5d3bb435cda38fd488b0f40e24d48e112a85f4dcb18a911d3d6fe9e`. It starts on the loading screen and ends on NEW GAME / OPTIONS. No Simulator chrome.

`python3 -m unittest discover -s tools/tests` ran 1296 tests: OK, 11 skipped.

## 2026-11-12 The title menu was waiting on midgame map copies

The 20261112T104318Z clip stayed on the logo, Blue Version, Squirtle, and "Preparing adventure...". `initialize.ready` for session `c289f88170bf42e0a58bdb0ae89c9e4b` was 22758 ms, after that fixed 22 s grab. The heartbeat was quiescent at 22861 ms. Init had not hung. `title.visible` was 972 ms. `MidgameCatalogExporter.register` ran from 1802 ms to 21514 ms. That build id starts at `e6d4105b`, and `e6d4105b` still calls `SourceMaps.definition` for every midgame map. The copy includes grids and collision. The 093817Z boot on `93d58071` had the same stall: register 1979–20264 ms, ready 21479 ms. Its 22 s clip ended on the menu only because ready landed inside the window.

Registration now reads each map's object sprite ids from the decoded record and drops that record. It does not copy the definition. `MallocPoolSize` stays `16645684`. The 14000 KiB boot budget is unchanged. The LCD capture waits for `initialize.ready` and fails if the mark is absent after 90 s.

Session `9f0192b5c3e74f689da7c516fc50c94c` reached `title.visible` at 1032 ms and `initialize.ready` at 5482 ms. `MidgameCatalogExporter.register` was 1854–4171 ms. Sampled peak 13312.873 KiB. `tools/measure_boot_budget.py` passed. The heartbeat was quiescent at 5617 ms. The LCD clip is `/opt/cursor/artifacts/hourly/20261112T112118Z-boot-to-title.mp4`, 8.1 seconds, 400×240, sha256 `3fb739c0c325a782712005e873a9a9c7084ea88c3005fac940a2f6dd22422f4d`. It starts on the loading screen and ends on NEW GAME / OPTIONS. No Simulator chrome.

The coverage snapshot is `e1553b69c3126b4ecc6bf0b7a7ea8837f4cee86691829643277b7f588f2f72a7`. The previous snapshot is nested. No row was relabeled.

`python3 -m unittest discover -s tools/tests` ran 1296 tests: OK, 11 skipped.

## 2026-11-12 Declining a move after Articuno does not reopen it

Lane B's note was a hunch: after beating Articuno (level 50, Seafoam Islands B4F), declining the move-learn prompt seemed to reopen it, and the win never saved. Pokered `engine/pokemon/learn_move.asm` returns to AbandonLearning when the player says NO to `_TryingToLearnText`. YES on `_AbandonLearningText` ("Abandon learning" plus the move name and "?") prints `_DidNotLearnText` and ends that move.

The production battle path already does that. `battleLearningContracts` now drives it with buttons against an Articuno of level 50 and a full moveset. NO opens the abandon prompt. YES consumes that choice, shows "did not learn", and does not offer the same choice again. After every queued move is declined, the phase is `ended` / `victory`, and `battleEnd` emits. The old moves stay. SDK 3.1.2 session `451780dad7d74b03bd2943616f4ca6ea` ran that suite: 21 passed, 0 failed, in 23828 ms. No battle-code change. The prompt was not looping, so nothing was patched to skip it.

The coverage snapshot is `9024843d18093c682f3cf3bbda909202062a074b2520508a05405aade7f23b5c`. The previous snapshot is nested. No row was relabeled. Cerulean and Vermilion journey `--check` still passed.

`python3 -m unittest discover -s tools/tests` ran 1291 tests: OK, 11 skipped.

Session `c289f88170bf42e0a58bdb0ae89c9e4b` reached `title.visible` at 972 ms and `initialize.ready` at 22758 ms. Sampled peak 13463.020 KiB. `tools/measure_boot_budget.py` passed. `MallocPoolSize` stayed `16645684`. The LCD clip is `/opt/cursor/artifacts/hourly/20261112T104318Z-boot-to-title.mp4`, 22 seconds, 400×240, sha256 `e8f0dcc17fc12f1696d1ac398263294e2277ee7b747e52b08c6570f57dd6fccf`. It opens on the loading screen and holds the title while the harness is already on "Preparing adventure...". The logo, Blue Version, and Squirtle are on that screen. No Simulator chrome.

## 2026-11-12 Town Map is the only registered key item

The four approved quality-of-life rows were still marked in progress. The behaviors are in the game. `BagState.canRegister` had begun offering the Bicycle, the rods, and the Itemfinder once `FieldGearState` or `HiddenItems` was loaded. `docs/plans/approved-qol.md` registers Town Map only. Those other items keep their Bag USE actions and stay unregistered. The ledger now says that, and it does not claim a native input witness.

SDK 3.1.2 session `68d24a1a9ee44bd987c8b96b6d1c1cd0` ran `contracts approved-qol`. The report was 24 passed and 0 failed, including the crank, Town Map registration, bag sort, and reusable TM cases. FieldGearState was loaded, and the Bicycle stayed unregistered.

The coverage snapshot is `7cc1d14dd038402530989807908095146093ff5be68c5edcd339bef6bca3e48f`. The previous snapshot is nested. No row was relabeled. Vermilion's journey projection was regenerated; the only hash that moved is `game/bagState.lua`. Cerulean's `--check` still passed.

`python3 -m unittest discover -s tools/tests` ran 1291 tests: OK, 11 skipped.

Session `3e7e15bd67ea4044adb2d4e27b887b4b` reached `title.visible` at 1105 ms and `initialize.ready` at 21479 ms. Sampled peak 13456.679 KiB. `tools/measure_boot_budget.py` passed. `MallocPoolSize` stayed `16645684`. The LCD clip is `/opt/cursor/artifacts/hourly/20261112T093817Z-boot-to-title.mp4`, 22 seconds, 400×240, sha256 `03f11e118813caf2dab63376b793c0ce74ab05d4a97dae04a9e61c766ac6f6f9`. It starts on the loading screen and ends on NEW GAME / OPTIONS. No Simulator chrome.

## 2026-11-12 The suite is green and boot still reaches the title

`python3 -m unittest discover -s tools/tests` ran 1291 tests: OK, 11 skipped. The skips are the same ones as the previous run. The Brock fixtures ran. They stage committed Source when `PARCEL_BUNDLE_SOURCE` is unset.

The coverage snapshot source pin is `f15de7828cb5c4e758e96ec477965246a7dbb1cc34ce7bb3c6a2c3d5f9da0e34`. Row verifications and evidence were not relabeled. `tools/check_coverage_matrix.py` passed. Cerulean and Vermilion journey projections were regenerated with their generators. `--check` passed twice. They change when the hashed inputs change (`sessionCodec.lua`, `main.lua`, `gameSession.lua`, and the other listed sources). The generators are deterministic for a fixed Source.

Vermilion `provenance.json` came back because `387bf5e0` changed `tools/generate_source_map_cache.py`, which the preparation pins under `shared_generators`. The historical `63267b0` proposal bytes did not change. The file now records that generator as `162e918413ce0578ac7f05f997096a27282a9ae57a2d8bd2303645760cf293b5`.

Thrash was declared at epoch 6 in `63c41f12`. `89905295` was not a merge. It moved Thrash, Outrage, Low Kick, Hyper Beam, Giga Impact, Flame Wheel, and Flare Blitz to epoch 19 so the epoch-18 snapshot would invert. That made an epoch-14 projection call Thrash future, and it inferred Whirlwind's epoch-13 edge onto a pre-v13 row. Those fields are back at epoch 6. Sunny Day and Hail stay at epoch 7. The raw epoch-18 snapshot predates the fields, so it does not invert; a projection that includes the declared fields does, and the original 424-row hash is unchanged. Whirlwind and Roar are pokered `SWITCH_AND_TELEPORT_EFFECT` (`$1C`, `SwitchAndTeleportEffect`). The Gen V producer is the existing epoch-13 `ForceSwitchEffect(DEFENDER)`.

`IsSurfingAllowed` in `engine/overworld/field_move_messages.asm` lines 21-50 denies Surf only on `SEAFOAM_ISLANDS_B4F` at x=7, y=11, and only while `EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE` and `EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE` are not both set. `dbmapcoord 7, 11` stores y then x. `CheckBothEventsSet` sets Z when both flags are set, and that path returns with Surf still allowed. `GameContext:fieldTravelRestrictions` now calls `CoastStory.currentTooFast`. The wiring commit is `264d302a0640f6387c5084198b3ecc71c15713b1`.

SDK 3.1.2 session `9e09f1e38ac840259de8dbbf5f9098f4` on `2e7a7fbe` reached `title.visible` at 987 ms and `initialize.ready` at 22759 ms. Sampled peak 13482.593 KiB. `tools/measure_boot_budget.py` passed. `MallocPoolSize` stayed `16645684`. This note does not change Source.

## 2026-11-12 Play time is on the session, and the suite is still not green

Lane D round 5 (`046bf608` on `d87c387c`) is on this branch. Red's card follows `HoFDisplayPlayerStats`: the name box at `hlcoord 5, 0`, the stats box at `0, 4`, play time, money with the yen sign, and three 120-frame pages. `text_decimal` left-aligns the counts, so `Seen:20` matches the source. The Hall of Fame box stays inside the party loop. Oak's plan order matches `ChampionsRoom.asm`. `ShowObject` runs when the five-step walk starts, in the same script as `MoveSprite`. `CheckAndResetEventA` clears `EVENT_HALL_OF_FAME_DEX_RATING` after the paragraph is chosen.

Play time is `wPlayTimeHours`, `wPlayTimeMinutes`, `wPlayTimeSeconds`, and `wPlayTimeFrames` on the v4 save. A save that predates the field loads as a zero clock. `TrackPlayTime` rolls 60 frames into a second and stops when the hour becomes 255. Counting starts when the overworld is entered and stops on the title. Red's card reads that clock. SDK 3.1.2 session `0ab4ac7130bc433aafe865da9cb11e5c` refreshed the transform pins after `gameSession.lua` changed. The parsed East, South, Saffron, and Kanto packets match the previous export aside from the build id and Lua key order.

`python3 -m unittest discover -s tools/tests` ran 1288 tests: 4 failures, 14 errors, 11 skipped. The failures are the coverage-matrix source pin, the Cerulean observation projection, and the Vermilion acquisition and journey projections. The errors are the unset `PARCEL_BUNDLE_SOURCE` Brock fixtures, Cerulean `provenance.json` drift, and the move-producer checks for `thrash` and `whirlwind`. `main` stays at `7a31867a`.

## 2026-11-12 Full boot reaches the title inside the 16 MiB pool

Clip `20261112T061946Z-boot-memory-stop.mp4` opens on the error screen. The whole 45 seconds is `Game stopped safely`, then `error.not enough memory`, then `not enough memory` again. The title is not in that file. The earlier note said content registration passes the title. That described a boot trace, not the clip: the recorder started after the stop, so the frames before the crash were missed. Recordings now start before the simulator opens. The trace for build `8b9da209` does mark `title.visible` at 2163 ms and `error.not enough memory` at 3446 ms, with a sampled Lua peak of 13792 KiB. `MallocPoolSize` stayed `16645684`.

The full harness profile is what exhausts the pool. Region-story imports, including the lane B and lane D modules, move the Lua heap from 12850 KiB to 12928 KiB. They are not the stop. After `CeruleanContent.installSigns`, `VermilionCatalogExporter.register` and `MidgameCatalogExporter.register` called `SourceMaps.compact()`, which deep-copies the map catalogue. That copy does not fit beside the running boot. The thin journey profile never registers those exporters and boots at about 8 MiB. The error screen drew the trace phase `error.not enough memory` and the same message again without the prefix.

The exporters now keep tile membership as booleans on the shared catalogue. Vermilion's presentation bitmaps are warmed when a catalog is written, not during registration. Startup collects once the Lua heap is already at 12 MiB. The pool was not raised. The error screen prints the stop once. `tools/measure_boot_budget.py` fails a trace that misses `title.visible` or `initialize.ready`, records an error, or samples a Lua peak above 14000 KiB.

SDK 3.1.2 session `1f3d0a3b47b449e3940d6d5068dc886d` reached `title.visible` at 1069 ms and `initialize.ready` at 23083 ms. Sampled peak 13484.934 KiB. The budget check passed. Clip `20261112T070934Z-boot-to-title.mp4` is 28.2 seconds of the 400x240 LCD, from the loading screen (`AuthoredMaps.initialize`) through the Blue title menu (`NEW GAME` / `OPTIONS`). The crop has no Simulator chrome and no developer eList dialog. sha256 `be1f80038669765b556ee8438af23927075e95d187cdeeed7fef7ed40585bfca`.

The same boot was measured again on `25979aff` with `MallocPoolSize` still `16645684`. Session `9e37aef4e5fd4822b284fb5ac3859651` reached `title.visible` and `initialize.ready`, sampled peak 13439.801 KiB, and `tools/measure_boot_budget.py` passed. The error screen still prints the stop once. Clip `20261112T074301Z-boot-to-title.mp4` is 25.5 seconds of the 400x240 LCD: `AuthoredMaps.initialize`, then `Preparing adventure...`, then the Blue menu (`NEW GAME` / `OPTIONS`). sha256 `287aac1f7f554e43f8c59dcb6606191ae5282fda3240d5c00eb50646a071945b`.

`python3 -m unittest discover -s tools/tests` on this tree ran 1286 tests: 6 failures, 14 errors, 11 skipped. The weather-id freeze and the Hall of Fame import expectation are updated with that boot. The remaining failures are the coverage-matrix source pin, the Cerulean and Vermilion journey projections, and Cerulean `provenance.json` drift. The errors are the unset `PARCEL_BUNDLE_SOURCE` Brock fixtures and the move-producer epoch checks for `thrash` and `whirlwind`. `main` stays at `7a31867a`.

Lane B can rebase on `58287e35`. The bundle `20261112T070934Z-lane-b-rebase.bundle` requires `origin/main` `7a31867a` and its sha256 is `c3bf18879df2ef87192e515172daa7d4e07e9e380b9ebbe7132863ba16ec1c4a`. The earlier bundle `20261112T061946Z-lane-b-rebase.bundle` stops at `8b9da209`. The earlier full-suite log failed its source setup because `POKERED_REFERENCE_DIR` was unset.

## 2026-11-12 The transform pins match the thin SDK export

SDK 3.1.2 session `/opt/cursor/artifacts/transform-pin-sdk-20261112-05` used the thin journey profile. The full harness catalog walk still exhausts the 16 MiB pool, so that profile was not used and the pool was not raised. Parsed East, South, and Saffron records match the stored export bytes. `domain/gameSession.lua` now includes the safari readers, `world/sourceMaps.lua` honors a water-tile warp arrival, and `game/silphStory.lua` no longer rebuilds the rival pair on a standing frame. The content pin is the opaque-white overworld sprite rehash. The Kanto packet's only semantic change is Route 22 object 2: the second rival is the source trainer, with the source text and the three source flags, instead of a bespoke stub. `Source/lib/shade.lua` and the gym floor were not edited.

## 2026-11-10 The remaining maps, the credits roll, and the source legendaries

Pokered `af519899719f0754965776faac0e836a3b906e6d` has 248 `map_const` entries. The 205-map manifest was missing 43 constants. Twenty-two are unused 0×0 maps (`UNUSED_MAP_0B` through `UNUSED_MAP_F4`) and were not given invented layouts. Three constants are header aliases of maps that were already installed: `CERULEAN_TRASHED_HOUSE_COPY`, `UNDERGROUND_PATH_ROUTE_6_COPY`, and `CINNABAR_MART_COPY`. `UNDERGROUND_PATH_ROUTE_7_COPY` declares the same constant as the installed Underground Path Route 7 header, so it is not a second map. Diglett's Cave, Rock Tunnel, Route 2, the forest, and both forest gates were already in the manifest.

The other 17 constants are installed from source: Pallet Town, Red's house, Blue's house, Oak's Lab, the Viridian school and nickname houses, the Pewter Nidoran and speech houses, the Cerulean trade and badge houses, the Power Plant, Cerulean Cave 1F, 2F and B1F, the Trade Center, and the Colosseum. `Source/data/sourceMaps.json` now has 222 maps. The shared cache and cell bins were rebuilt. Door census for that inventory is 802 warps, 78 connections, 2362 boundary cells, 238 last-map exits, 28 scripted warps, and 0 surface-blocked warps. The authored Pallet Town, Red's house and Oak's Lab stay the playable early zones. The source copies are the decoded maps.

The credits player follows `engine/movie/credits.asm`. The Hall of Fame PC waits 100 frames and then 128. Each fade is 4 palette steps of 5 frames. A mon frame holds, then scrolls 7 tiles and 20 more. Holds are 90, 110, 120, 140 and 16 frames for the five commands. The roll opens on `#MON` / `BLUE VERSION STAFF` with Venusaur and ends on `CRED_THE_END`. The Hall of Fame walk and Oak's text still hide the Cerulean Cave guard. The credits step then returns to the title. That return does not write a save and does not set a badge. The cave guard starts visible on the tile south of warp `pokered:CERULEAN_CITY:warps:7`. The cave opens only after `TOGGLE_CERULEAN_CAVE_GUY`.

Moltres is Victory Road 2F object 6 at (11, 5), level 50. Zapdos is Power Plant object 9 at (4, 9), level 50. Articuno is Seafoam Islands B4F object 3 at (6, 1), level 50. Mewtwo is Cerulean Cave B1F object 1 at (27, 13), level 70. None of those species is in the wild table of its map. Both Snorlax scripts write `SNORLAX` and level 30 to `wCurEnemyLevel` after the Poké Flute sets the fight flag. The flute request uses that species and level. Route 12 and Route 16 wild tables do not contain Snorlax.

No campaign save was written and no badge was set. Real play still waits on lane B's Volcano Badge. Fossil revival stays a plan. `Source/lib/shade.lua` and the gym floor were not edited. `MallocPoolSize=16645684` and the 1 GiB guard stayed on.

Seafoam B3F warps 6 and 7 land on B4F foot tile $14. That water arrival now binds, and map entry sets the surf state. Solid and blocked arrivals stay rejected. The fix is the commit immediately before this checkpoint.

## 2026-11-10 The league is generated and waiting on the Volcano Badge

Fourteen maps were regenerated from pokered `af519899719f0754965776faac0e836a3b906e6d` and installed on the 191-map coast manifest. `Source/data/sourceMaps.json` now has 205 maps: Viridian Gym, Route 22 Gate, Route 23, Victory Road 1F–3F, Indigo Plateau, its lobby, Lorelei, Bruno, Agatha, Lance, the Champion's room, and the Hall of Fame. The shared cache and cell bins were rebuilt. The Viridian City gym door is the source warp at (32, 7). Route 22's north connection is Route 23. The gate script sets the outdoor map from the player's y: south of y 4 returns to Route 22, and the north doors return to Route 23 warps 1 and 2. The guard at (4, 2) and (5, 2) still requires the Boulder Badge.

`Source/data/endgame/story.json` is the generated story. Viridian Gym opens only when the badge mask is 127, every badge except Earth, which includes the Volcano Badge. Giovanni is `pokered:VIRIDIAN_GYM:objects:1`, roster 3, TM27, and his ace is Rhydon at level 50. The second Route 22 rival uses the second starter table. A Charmander player faces Blastoise at level 53. Route 23 checks Earth, Volcano, Marsh, Soul, Rainbow, Thunder, then Cascade. Victory Road's four switches and the 3F hole are the source coordinates. The Elite Four aces are Lapras 56, Machamp 58, Gengar 60, and Dragonite 62. The champion's ace follows the player's starter: Blastoise, Venusaur, or Charizard. The credit sequence opens on `#MON` / `BLUE VERSION STAFF` with Venusaur and ends on `gfx/credits/the_end.2bpp`. Oak in the Hall of Fame is the source trigger. The frames are data the runtime can read. There is no credits movie player in this checkpoint.

No campaign save was written and no badge was set. Real play waits until lane B's Volcano Badge is earned. Lane B had not asked for more coast content. The coast maps were already in the manifest. PowerPlant and CeruleanCaveB1F stay uninstalled. Fossil revival stays a plan. `Source/lib/shade.lua` and the gym floor were not edited. `MallocPoolSize=16645684` and the 1 GiB guard stayed on.

## 2026-11-10 Silph president gave the Master Ball

Continued from the Copycat save with real steps. Copycat's stairs return to 1F, and the door exits to Saffron (7, 6). Silph's door is (18, 21) and lands on 1F (10, 17). The elevator panel is source (3, 1). 3F was already the unlocked floor (`EVENT_SILPH_CO_3_UNLOCKED_DOOR2`), and its warp (11, 11) lands on 7F (5, 3). 7F's warp (5, 7) lands on 11F (3, 2), the side of the floor that reaches the president. The 11F elevator itself lands on the other side. The tile (5, 5) is the inert warp into his room; stepping on it stays on 11F. The president stands at (7, 5) facing down, and the tile south of him is a wall. Standing at (6, 5) facing right received the Master Ball. `EVENT_GOT_MASTER_BALL` is set. The bag holds one `masterBall` and still holds one `tm31`. There is no Poké Doll. Money is still 68008. No battle and no blackout. VmHWM stayed at 344712 KiB. `MallocPoolSize=16645684` and the 1 GiB guard stayed on. `Source/lib/shade.lua` and the gym floor were not edited.

Evidence is `linux-silph-11f-masterball-20261110-01`. Slot B is sequence 138, sha256 `32527e03287f6deb3ecc56da406068d19263e1a23871dbe851d651ad4ca9f339`, at Silph Co. 11F (6, 5) facing right. Slot A is still the Copycat file, sequence 137, sha256 `66aec9e7ddc710cc7d53efc5900addbdff763fe1d1c9027538f6cbc4cb492e3a`. The Copycat, doll, Mr. Psychic, Dojo, and Giovanni files are unchanged.

Pokered opens Viridian Gym only when every badge except Earth is set, which includes the Volcano Badge. That badge stays with lane B. `ViridianGym` is still one of the missing late-Kanto maps, so this save does not walk in. Cinnabar, Seafoam, and the Mansion stay with lane B.

## 2026-11-10 Poké Doll from Celadon Mart 4F, then Copycat's TM31

Continued from the Mr. Psychic save with real steps. No item was injected. Spearow flew from Saffron to Celadon and landed at (41, 10). The department store door is (8, 13). 1F's elevator warp is (1, 1). The elevator panel is source (3, 0); standing at (3, 1) facing up opened the floor list 1F through 5F. 4F's clerk is source (5, 7), behind the counter. Standing at (5, 5) facing down bought one Poké Doll, the first item in pokered's `CeladonMart4FClerkText` mart. The price is 1000. Money went from 69008 to 68008 and the bag went from 17 slots to 18. The elevator returned to 1F and the exit landed on Celadon (8, 14). No battle and no blackout. VmHWM stayed at 316564 KiB.

Evidence of the doll, still in the bag, is `linux-celadon-pokedoll-20261110-01`. Slot B is sequence 136, sha256 `6dc860d2dace35f0e05768e5cf9f4b2c5adf577cde7dd847188a6bd4e0e46833`, at Celadon (8, 14) facing down. Slot A is still the Mr. Psychic file, sequence 135, sha256 `f42b3070976efc4186cfa21ae9ac950f5d7942a6c16f703d7cdc5f395b219c42`.

From that save, Spearow flew back to Saffron (9, 30). Copycat's door is (7, 5). The stairs from 1F land on 2F source (7, 1). Copycat walks, so the four tiles around her spawn did not reach her. She was at source (6, 1). Standing at source (6, 2) facing up played her script. `EVENT_GOT_TM31` is set, the Poké Doll is gone, and the bag holds one `tm31` in 18 slots. Money is still 68008. No battle and no blackout. VmHWM stayed at 315388 KiB. `MallocPoolSize=16645684` and the 1 GiB guard stayed on. `Source/lib/shade.lua` and the gym floor were not edited.

Evidence is `linux-saffron-tm31-20261110-01`. Slot A is sequence 137, sha256 `66aec9e7ddc710cc7d53efc5900addbdff763fe1d1c9027538f6cbc4cb492e3a`, in Copycat's room. The save stores grid (8, 2) facing up; the house padding is 2, so that is source (6, 2). Slot B is still the Celadon doll file, sequence 136. Spearow still knows Fly. The Mr. Psychic, doll, Dojo, and Giovanni files are unchanged. Cinnabar, Seafoam, and the Mansion stay with lane B.

## 2026-11-10 Mr. Psychic gave TM29

Continued from the Fly arrival with real steps. Saffron (9, 30) reaches Mr. Psychic's door at (29, 29) in 23 open tiles. The house warp lands on source (2, 7). The fishing guru stands at source (5, 3) facing left. Standing at source (5, 4) facing up received TM29. `EVENT_GOT_TM29` is set and the bag holds one `tm29`. No battle and no blackout. VmHWM stayed at 302628 KiB. `MallocPoolSize=16645684` and the 1 GiB guard stayed on. `Source/lib/shade.lua` and the gym floor were not edited.

Evidence is `linux-saffron-tm29-20261110-01`. Slot A is sequence 135, sha256 `f42b3070976efc4186cfa21ae9ac950f5d7942a6c16f703d7cdc5f395b219c42`, in Mr. Psychic's house. The save stores grid (7, 4) facing up; the house padding is 2, so that is source (5, 4). Slot B is still the Fly file, sequence 134, sha256 `8aea990c9dfc83e8b865395bde6598b7c07102e83d4cb16f29cf12366f875ba6`. Spearow still knows Fly.

The Fly arrival, the HM02 save, and the Dojo save are unchanged. Copycat is the next Saffron gap. `CopycatsHouse2FCopycatText` is still unbound. Pokered gives TM31 only when a Poké Doll is in the bag, then removes the doll. This party has no Poké Doll. Cinnabar, Seafoam, and the Mansion stay with lane B.

## 2026-11-10 HM02 and Fly to Saffron

Surf, the faint slide, the YES/NO shift prompt, and the single-box Intimidate line are already in `86816e8f`. Nothing from that batch was still open. `Source/lib/shade.lua` and the gym floor were not edited.

Continued from the Dojo save with real steps. Cut from Route 16 (34, 10) facing up opened the tree at (34, 9). The north gate door (24, 4) lands in Route 16 Gate 1F source (7, 2). The north room's west door (0, 2) exits to Route 16 (17, 4). The Fly house door is (7, 5). The brunette girl gave HM02. One Doduo battle, no blackout. Leaving Route 16 restored the tree, which matches pokered `LoadTileBlockMap`: a cut is not saved. The return from (34, 8) was blocked until Cut was used again, facing down. That second cut stayed open long enough to walk south onto the cycling road and edge right into Celadon (0, 18).

Evidence of the gift, still on the north side of the restored tree, is `linux-route16-fly-20261110-01`. Slot A is sequence 133, sha256 `e3144dae71023a427cd86097ae9d2f15a3de485ab025381b861340195b6e6ff5`, at Route 16 (34, 8) facing down. Slot B is sha256 `1f4a3abcd2124343f3add2d2ac136196a6bccf70a67c7382078f3c65c092533f`.

From that save, Celadon's Center stored Rattata and withdrew Spearow. HM02 replaced Growl. Spearow used Fly outdoors. The destination list was Cerulean, Lavender, Vermilion, Celadon, Fuchsia, and Saffron. YES confirmed Saffron. Arrival is Saffron (9, 30) facing down. Evidence is `linux-route16-fly-saffron-20261110-01`. Slot B is sequence 134, sha256 `8aea990c9dfc83e8b865395bde6598b7c07102e83d4cb16f29cf12366f875ba6`. Slot A is still the Route 16 file. The return had no wild battle and no blackout. VmHWM stayed at 337936 KiB. `MallocPoolSize=16645684` and the 1 GiB guard stayed on.

The Dojo save is unchanged. Slot A is `0e893b6be25f3e1b5751241ff92d5990a77d5b8af124c4d6690580c3bc058268`. Slot B is `48231ad03ad6f29d2272edd75036b8053664fa64705b01f993fbcd94bd84120f`. The Giovanni, Marsh Badge, Lapras, and rival files are unchanged. `EVENT_GOT_TM29` is still clear. Mr. Psychic's door is Saffron (29, 29).

## 2026-11-10 Route 19 and the coast maps are in the shared manifest

The 171-map inventory now has the 20 coast maps regenerated from pokered
`af519899719f0754965776faac0e836a3b906e6d` by `tools/generate_lane_b_coast.py`.
They are `Route19`, `Route20`, `Route21`, the five Seafoam floors, Cinnabar
Island, its Center, Mart, Gym, Lab and three lab rooms, and the four Mansion
floors. `Source/data/sourceMaps.json` is still the only runtime inventory:
191 maps. `tools/generate_source_map_cache.py --check` rebuilt the shared
compact cache and cell bins. Fuchsia's south connection targets `ROUTE_19`,
and Route 19's north connection targets `FUCHSIA_CITY`.

Route 19 and Route 20 water is SeaRoutes: rate 5, ten Tentacool, weights
51/51/39/25/25/25/13/13/11/3. `Zone._readEncounterMapPolicy` projects that
table through `WaterEncounters`. A zero water byte stays disabled. Coast
event sidecars stay out of the content cache. `Source/lib/shade.lua` and the
gym floor were not edited.

## 2026-11-10 The Fly house path does not meet the Celadon entrance

Continued from the Dojo save with real steps. Saffron (0, 10) is an edge door to Route 7 (19, 2). The Route 7 gate's east door is (18, 9), landing at source (5, 3). Its west door is source (0, 3), landing at Route 7 (11, 10). Route 7 (0, 2) is an edge door to Celadon (49, 10). Celadon (0, 18) is an edge door to Route 16 (39, 10). Snorlax's tile was empty. The south-east gate door (24, 10) landed at Route 16 Gate 1F source (7, 8). No wild battle and no blackout. VmHWM stayed at 226256 KiB. `MallocPoolSize=16645684` and the 1 GiB guard stayed on.

That south room does not connect to the north room. The north door, source (0, 2), is the one that exits onto the Fly house path. The imported collision matches the pinned blocks: a cell is open when the bottom-left tile of its quadrant is a passable tileset id. On Route 16 the house door (7, 5) is on a north path, x=1 through 17, y=2 through 8. The east half of that path is x=24 through 35. The gate's north doors are the only link between the halves. Neither half touches the cycling road at y=10 or the map edge. The Celadon entrance is only (39, 10). HM02 was not received. No map generator was run, and the collision grid was not edited.

The Dojo save is unchanged. Slot A is `0e893b6be25f3e1b5751241ff92d5990a77d5b8af124c4d6690580c3bc058268`. Slot B is `48231ad03ad6f29d2272edd75036b8053664fa64705b01f993fbcd94bd84120f`.

## 2026-11-10 Marsh Badge, the Fighting Dojo, and the Route 7 edge

Lane A stays on `cursor/linux-runtime-seams-fcc0`. `0721a2b2` is that HEAD and includes `61ea7445` and `86816e8f`. Surf, the faint slide, the YES/NO shift prompt, and the single-box Intimidate line are already in `86816e8f`. Nothing from that batch was still open.

Continue used the earned Giovanni save. Sabrina was won on attempt 1. Evidence is `linux-saffron-marsh-badge-20261110-01`. Slot B is sequence 130, sha256 `48231ad03ad6f29d2272edd75036b8053664fa64705b01f993fbcd94bd84120f`, at Saffron Gym (9, 9) facing up. Slot A is still the Giovanni file, sha256 `2093432634b6313b0d5645cf6c747ed29b3f81239cfeed5ccdf73b67ed9bcbec`. `BADGE_MARSH` and `EVENT_BEAT_SABRINA` are set. Blastoise was Lv50 with 103/155 HP.

The gym exit is the bottom-row edge door. The party healed to full at the Saffron Pokécenter. The Dojo's four blackbelts fell to Surf. The Karate Master started on stepping onto source (4, 3), grid (5, 3). His party was Hitmonlee then Hitmonchan, both Lv37. That was one master fight and no blackout. Skull Bash charged and hit, and the shift prompt was declined with B. Hitmonlee came from the left ball and went to box storage because the party was full. `EVENT_GOT_HITMONCHAN` stays clear. Evidence is `linux-fighting-dojo-20261110-01`. Slot A is sequence 131, sha256 `0e893b6be25f3e1b5751241ff92d5990a77d5b8af124c4d6690580c3bc058268`, in the Dojo at grid (5, 2) facing up. Slot B is still the badge file. Blastoise is Lv51 with 144 HP.

Saffron (0, 10) facing left is an edge door onto Route 7 (19, 2). The Saffron drink flag was already set. HM02 is not received. The next walk is the Route 7 gate, Celadon, and the Route 16 Fly house. Route 16 Snorlax is already beaten, so that one-tile road is open.

Clip `20261110T051809Z-saffron-sabrina.mp4` is 90 seconds, 400x240, the Dojo battle. VmHWM stayed at 231960 KiB. `MallocPoolSize=16645684` and the 1 GiB guard stayed on.

## 2026-11-10 Move select, level-up stats, learn move, and é

Clip `20261110T031342Z` (`battle-flow-fidelity`). Five fixes, each with a contract. Pokered is `af519899719f0754965776faac0e836a3b906e6d`.

The back sprite stays missing on move select because `252dd911` plants the feet on the slot bottom and the type box at y=96 covers that ink. `MoveSelectionMenu` (`engine/battle/core.asm`) and `PrintMenuItem` share row 12: the move box is `hlcoord 4,12` `b=4` `c=14` with `[4,12]='─'` and `[10,12]='┘'`, then the type box is `hlcoord 0,8` `b=3` `c=9`. `TextBoxBorder` (`home/text.asm`) is the box. The Playdate boxes now share one pixel row, the left gutter below that row is cleared (the stray lines were the platform at y=161 and y=168), and the player picture is redrawn above the type box after the white fill. The foot anchor itself is unchanged.

Level-up stats show SP. ATK and SP. DEF, not SPECIAL. `docs/plans/full-game-goal.md` (the source-of-truth table) makes battle rules, base stats, and the physical/special split Gen V. `calcDamage` in `Source/battle/battle.lua` already uses `spa` when `move.category == "special"` and `spd` on the defender. Pokered `PrintStatsBox` (`.LevelUpStatsBox` / `.StatsText` in `engine/pokemon/status_screen.asm`) prints one SPECIAL. Copying that line would hide special defense, so the box lists ATTACK, DEFENSE, SP. ATK, SP. DEF, and SPEED. The single SPECIAL line is not kept.

Learning Bubble no longer clears to a white "MOVE LEARNING" page. `LearnMove` (`engine/pokemon/learn_move.asm`) prints `_LearnedMove1Text` (`data/text/text_4.asm`) in the text box over the saved screen. A full set uses `_TryingToLearnText` (YES continues, NO abandons), `_WhichMoveToForgetText` with the `hlcoord 4,7` list, `_AbandonLearningText`, `_DidNotLearnText`, and `_HMCantDeleteText`. The session still asks before it writes the forgotten slot. The phase indexes are the same.

The shift line's é is the pokered glyph. `constants/charmap.asm` maps `é` to `$ba`, and the pinned rows in `sourceText.json` are that glyph from `gfx/font/font.png`. Battle text now draws through `SourceTextFont` instead of the system font's missing-glyph box.

The matching full-frame back-sprite shots are already in the artifacts: `player-back-sprite-before-full.png` and `player-back-sprite-after-full.png`. This batch does not move the foot line, so those frames still match the anchor.

## 2026-11-10 The Bayer shade file is the 946c4b00 blob

`test_preexisting_input_art_and_old_manifest_entries_are_unchanged` compared
`Source/lib/shade.lua` with `c6882b69`. That baseline is the 12.5%/50%
patterns. The only later edit is `946c4b00` ("Use the approved Bayer shades
for every Shade caller"). HEAD still matches that blob, sha256
`3626b148542cdd797f59369cbbefae38182fb5310f07465b04cc6b8ccd338877`.

The test now reads `tools/references/shade-bayer-approval.json`. It checks
the baseline hash, the approved commit hash, that `946c4b00` is the only
commit between them, that nothing after that commit touches the file, and
that the working bytes are the approved blob. A new edit still fails.

Pinning that file exposed the next miss: `Source/world/spritefactory.lua`.
Its startup wrapper is still the reviewed normalization. The extra body is
the opaque-white paint landed in `61ea7445`.
`tools/references/spritefactory-opaque-white.json` pins that file's sha256
`844fe1a562b1eb90407195133dd2b0001a40e05a3c7a4a3a60714b031d964a10` and the
three snippets. The test reverses those snippets, then runs the same
startup oracle against `c6882b69`. Any other edit still fails.

The same approval also rewrote the two shade-code comments at the top of
`Source/world/tilefactory.lua`. Those two lines are in the shade record.
The test puts the `c6882b69` wording back, then compares that header. The
image-table cache hash and the tile definitions are unchanged.
`test_original_map_inputs_authored_pallet_and_renderers_are_unchanged` uses
the same record. `895a874` has the same pre-Bayer shade bytes. Its pewter
and viridian sprite sheets are checked with `same_except_opaque_white`.

## 2026-11-10 Imported overworld OBJ color 1 is opaque white

Lane C `ea3f9d69` (bundle `0a8f381015796b346a3b5c83c5573c17d581e1a03bbc6b809e460b40178664cd`,
base `17b00af0`) is Miguel's option A. Pokered shade 170 is sprite code `w`:
solid white, and not a flood-fill hole. Shade 255 stays `.`. Shade 85 stays
Bayer `2`. The floor Bayer patterns are unchanged.

The code hunks are in `spritefactory.lua` (it paints `w`), `ceruleanContent.lua`
(BLUE's walk still collapses `w`, then `1`, to `.`), the faithful sprite map,
and the tests that accept that remap. Sprite JSON was still the base bytes, so
each 16-cell frame row was remapped in place. Those files match lane C's
bytes. `generate_content_cache.py` rebuilt `Source/data/contentCache`.
`generate_overworld_sprites.py --check` is clean and still covers only rival,
oak, mom, and daisy.

A 400×240 simulator frame of the Fuchsia Pokécenter nurse is
`/opt/cursor/artifacts/npc-sprite-fix-fuchsia.png`. The uniform and hat are
solid white. The floor dither around them is still the Bayer pattern.
`player.lua` and `sourceActors.lua` were not edited.

## 2026-11-10 Coast maps stay a sidecar until one manifest promotion

Lane B's Routes 19–21, Seafoam, Cinnabar, and Mansion decode is not a second
runtime. `Source/data/sourceMaps.json` is the only inventory (171 maps, pin
`af519899719f0754965776faac0e836a3b906e6d`). `SourceMaps.connection` returns
nil when `nameForID("pokered:" .. target)` misses (`sourceMaps.lua`).
`FuchsiaCity.json` already records south to `ROUTE_19` (offset 5 blocks,
entry adjustment -10). West to Route 18 and east to Route 15 resolve.
South does not, because Route 19 is not in the catalogue.

Adoption is a promotion of their checked JSON into that catalogue, not a
sidecar loader:

1. Add one `source` manifest entry per coast map: id, key, path, padding,
   size, spawn, and `source_sha256` of the sidecar bytes. Keep their path
   if the file moves into this tree unchanged.
2. Rebuild the shared compact cache and `sourceMapCells` bins with
   `tools/generate_source_map_cache.py`. `--check` must see the new grids.
   No parallel manifest.
3. Fuchsia south then uses the existing offset math. Route 19's north
   connection has to be in that map's own JSON or the walk back stays nil.
   Do not invent a Pallet-style seam.
4. Land water projection in the same change as Route 19/20. A nonzero
   `rate_byte` still hits `unbound-water-encounter-policy` in
   `Zone._readEncounterMapPolicy`. Surfing those maps before the projection
   fail-closes. The SeaRoutes table is rate 5, ten Tentacool, weights
   51/51/39/25/25/25/13/13/11/3 (`data/wild/maps/SeaRoutes.asm`, pointed at
   by `data/wild/grass_water.asm`). A zero byte stays disabled.
5. Map scripts and events stay Lane B's. Installing JSON does not bind
   them. Bayer floor shading stays. Sprite masks stay Lane C's.
6. Host checks that freeze 171, including the content-cache drift tests and
   `docs/validation/coverage-current.md`, move in that same commit.

The earlier note that Route 19/20 seam cells are collision 1 is about
`PewterWorld` and `KantoWorld`, not this importer. Recheck the decoded
water cells at promotion. Imported surf uses `FieldTravel.surfSurface` and
the decoded collision.

Lane B's water patch is not in this checkout. `cursor/lane-b-south-loop` at
`0cc8ef2b` and `docs/validation/lane-a-water-encounters.patch` were not
delivered as a bundle. Do not land `Zone._readEncounterMapPolicy` from a
transcript. When the bundle arrives, the review is: import
`game/waterEncounters` before `world/zone` in `main.lua`, replace the
nonzero-rate assert with `WaterEncounters.project`, and run
`tools/tests/test_lane_b_searoutes.py` against the pinned SeaRoutes bytes.
Sabrina, the Fighting Dojo, and Fly are still the next walk from the
Giovanni save. This note does not start them.

## 2026-11-10 Silph Lapras, the 11F door, and Giovanni

Continue used a copy of the earned 7F rival save. That folder was not written.
Lapras was received at Silph 7F (2, 5), facing the worker: `BIT_GOT_LAPRAS`,
level 15, sent to box 0 because the party was full. The game was saved before
the warp. Evidence is `linux-silph-7f-lapras-save-20261110-01`. Slot B is
sequence 128, sha256
`4f56b20009ea9ef2f8c88a2e13f978f17204218fb27e5e7fcc9e34f6dc435506`. Slot A is
still the rival file, sha256
`ab17c2c49f261a116836230a84b94d1139aa5c78695393d08320b93c19cfceb7`.

The 11F walk crossed the Rocket at (3, 16). Cubone, Drowzee, and Marowak fell.
The card-key door in front of (6, 14) stays solid until
`EVENT_SILPH_CO_11_UNLOCKED_DOOR`. Facing up there and pressing A opened it.
The step onto (6, 13) is Giovanni's trigger. One earlier approach reached
(6, 14) and stopped on that locked door. It never started Giovanni, so it is
not an attempt.

Giovanni attempt 1 won under the same frozen policy as the rival. No second
attempt. The party was Nidorino 37, Kangaskhan 35, Rhyhorn 37, Nidoqueen 41.
Blastoise fainted against Nidoqueen, was revived, and finished her.
`EVENT_BEAT_SILPH_CO_GIOVANNI` is set. Evidence is
`linux-silph-11f-giovanni-save-20261110-01`. Slot A is sequence 129, sha256
`2093432634b6313b0d5645cf6c747ed29b3f81239cfeed5ccdf73b67ed9bcbec`, at 11F
(6, 13) facing up. The rival save and the Lapras save still match the hashes
above. Blastoise is Lv49 with 28 HP. The bench is fainted or unevolved.
Lapras remains in box 0.

Opening the malloc log with Alt-L during boot kept VmHWM at 238968 KiB through
the Giovanni save. `MallocPoolSize=16645684` and the 1 GiB guard stayed on.
Clip `20261110T020912Z-silph-lapras-giovanni.mp4` is 90 seconds, 400x240, LCD
only. Sabrina, the Fighting Dojo, and Fly are the next walk from this save.

## 2026-11-10 Linux sim malloc-log artifact

The climbing VmHWM is the Simulator malloc-history log, not the Lua heap.
`MallocPoolSize=16645684` and the 1 GiB host guard stayed on. Nothing was raised
or turned off. The same fixture battle, Metapod Lv7 versus Metapod Lv7 using
Harden, ran eight turns. Both sides stayed at 24/24 HP. Lua is
`collectgarbage("count")`. Pool is the Malloc Log footer "Heap Used", which is
the 16 MiB pool high water and does not reset when the history is cleared.

A left the history alone. B clicked Clear Malloc History after every harness
command through `tools/harness/linux_malloc_history.py` (xdotool on the wx
Malloc Log; the control is the unlabeled icon left of "Automatically Refresh").

| Turn | A VmHWM KiB | A Lua KiB | B VmHWM KiB | B RSS KiB | B Lua KiB | B pool | B items |
| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| boot | 489244 | 7254.9 | 493036 | 493036 | 7253.6 | 8.38 MB | 5 |
| 1 | 517844 | 7412.1 | 494096 | 494096 | 7413.4 | 9.45 MB | 5 |
| 2 | 529012 | 7449.6 | 494096 | 494096 | 7448.0 | 9.45 MB | 5 |
| 3 | 541120 | 7451.2 | 494096 | 494096 | 7448.5 | 9.45 MB | 5 |
| 4 | 555036 | 7452.2 | 494096 | 494096 | 7449.1 | 9.45 MB | 5 |
| 5 | 556144 | 7454.6 | 494096 | 494096 | 7450.3 | 9.45 MB | 7 |
| 6 | 571712 | 7455.5 | 494096 | 494096 | 7450.7 | 9.45 MB | 6 |
| 7 | 572788 | 7456.3 | 494096 | 494096 | 7451.2 | 9.45 MB | 6 |
| 8 | 590220 | 7458.7 | 494096 | 494096 | 7453.1 | 9.45 MB | 6 |
| settled | 610132 | 7459.6 | 494100 | 494100 | 7455.1 | 9.45 MB | 5 |

A climbed 120888 KiB from boot to settled (489244 to 610132). B rose 1060 KiB
on the first command and then stayed at 494096 KiB through turn 8; settled is
494100 KiB. RSS on B matched VmHWM, so it did not climb either. Lua stayed
inside 7.09–7.29 MiB on both arms. A's pool footer was not refreshed, so its
item count stayed at the boot reading of 74641 and is not a live count. B's
footer was read after each clear: the pool moved from 8.38 MB to 9.45 MB when
the battle started and then held, and the history item count stayed at 5–7.
A later open of the same log without clearing still showed about 74634 items
and 8.38 MB while that process's VmHWM crept from 761848 to 793036 KiB, which
is the same direction as A. One uncleared launch was stopped by the 1 GiB
guard at 1096323072 bytes before its first command sample. That is the guard
working, not a limit change.

No battle-text bisect. B is flat and A climbs.

## 2026-11-09 Silph 7F battle path: Agility side, damage text, text box, party

Clip `20261109T214145Z-silph-7f-rival-battle.mp4`. The foe's Agility was
drawn on the defender. pokered `GetSubanimationTransform1` keeps a user
animation on the mover and mirrors it on the foe's turn;
`GetSubanimationTransform2` aims a foe animation at the other battler.
Agility (target id 7) now anchors on the user for both sides. A player's
damaging move still anchors on the foe. `tools/tests/test_battle_path.py`
checks all four.

Blue and Gen V do not print damage totals. The "took N damage!" line is
behind `debugDamageNumbers`, off unless a contract sets it. The HP bar
still drains. The substitute line is the source sentence, with no number.
Effectiveness and critical-hit lines are unchanged.

The clip's last stretch stays on that box because the harness mash
returned and no further A was sent. A waiting say advances on A once
`messageTimer` is past 10 frames. The same host check presses A and the
next source line appears. It is not a softlock.

After the faint, SHIFT still opens on CHANGE, matching the source YES
default. A on the active mon returns `already-active` and "BLASTOISE is
already out!", then waits for a separate button before another choice.
A fainted mon is rejected. B cancels and the foe is sent. A living bench
mon switches in. Mashing A on the lead stays in the party menu, which is
the source loop. The rival is still not defeated. Checkpoint C is not
earned. Standing and battle VmHWM growth is unchanged from the section
below.

## 2026-11-09 Silph 7F rival battle started

Continue from the earned opened-3F-door save, copied in, same hashes.
The stair path landed on Silph 7F (5, 3). Two steps left opened the rival
at (3, 3) and the battle started. No host kill on that walk.

`20261109T214145Z-silph-7f-rival-battle.mp4` is 28.0 seconds, 400x240, 840
frames of the LCD only. It shows "BLUE sent out PIDGEOT!" and then
Blastoise using Strength. That process peaked at VmHWM 667054080. Lua heap
during the clip was 8444 KiB. The earned adventure files were not rewritten.

A second process from the same save reached the same battle. Pidgeot
fainted. Blastoise went from Lv47 125/146 to Lv48 128/149. The stack then
stayed `battle>party` while A was mashed, and VmHWM climbed from about
649 MB to 760 MB with no further battle text. That process was stopped
before the 900 MB ceiling. The rival is not defeated. This is not
checkpoint C.

## 2026-11-09 hidden items and the Itemfinder

The 54 pinned hidden-item rows are imported from `hidden_events.asm` and
`hidden_item_coords.asm`. Facing the tile and pressing A grants the item
once. The Itemfinder uses the source window: item Y in (player Y - 5,
player Y + 4] and item X in (player X - 5, player X + 5], low side clamped
at 0. The 12 hidden coin rows were already owned by the Celadon service,
including the source 40-coin credit of 20 and the shadowed last slot.
`coverage-current.md` now says this checkout installs 171 source maps.
Accepted Simulator maps remain 149/222 through checkpoint B.

## 2026-11-09 Low Kick, Pay Day, Taunt, sun, and hail

Low Kick power follows the target's hectogram weight: 20, 40, 60, 80, 100,
or 120. Pay Day adds five coins times the user's level and the player
collects them on a win. Taunt lasts three residual ticks and blocks status
moves. Sunny Day and Hail are field weather for five turns. Sun boosts Fire
and weakens Water. Hail chips non-Ice Pokémon for 1/16 max HP. Host check
`tools/tests/low_kick_payday_taunt_weather_host.lua` passes. Snowscape stays
rejected.

## 2026-11-09 recharge, rampage, and freeze thaw

Hyper Beam and Giga Impact set a recharge receipt when the hit leaves the
target alive. The next action says the user must recharge, spends no PP,
and refuses a new move choice. A KO does not set the receipt. Thrash and
Outrage use the Petal Dance rampage lock: two or three turns, then
confusion. Freeze still thaws on a 1-in-5 roll. Flame Wheel and Flare
Blitz thaw the user and still run. A damaging Fire move that hits a
frozen target thaws that target. Host check
`tools/tests/recharge_rampage_freeze_host.lua` passes.

## 2026-11-09 approved battle frame

The approved 400×240 frame (Squirtle Lv5 19/19 vs wild Pidgey Lv3, platforms on) is SHA-256 `d02e55fa472c37c3dc687cf3c65387b1c80e4d6a99e348d60fd82ec37828315a`. It is pixel-identical to the PlaydateSimulator 3.1.2 captures of the threshold-128 PNGs (`2a` and `3a`, 0 changed pixels). It differs from the dithered style option `2b` by 1625 pixels. Scaled into the 80px slots, commit `b3ce7a01` misses 777 sprite blacks and adds 772. The threshold sprites miss 0 and add 0. Production is `threshold()` again, committed as `251c12dc`. `b3ce7a01`'s Bayer battle art is superseded for battles. `tools/generate_battle_art.py --check` reports 302/302 exact against the pinned archive. Shade Bayer remains the map and character mapping. The platforms stay.

## 2026-11-09 Blue title idle

The title menu still lists Continue, New Game, and Options, and its cursor
does not blink. The species slot starts on Squirtle and follows the Blue
`TitleMons` cycle: 200 frames, scroll out, the starter ball bounce, then a
different species scrolls in. The last device measurement of app start to
title accepting A remains 13.191 s. This idle starts only after the menu
phase, and it replaces the one Blastoise decode with the one Squirtle
decode. It does not add a save inspect. A Simulator retiming of that device
miss was not run.

`20261109T214800Z-blue-title-idle.mp4` is 24.0 seconds and 720 frames of
the 400x240 LCD. Squirtle holds, scrolls out of the right-hand slot, the
Poké Ball shows, and later Blue title species scroll in. The menu cursor
stays on CONTINUE. After the clip, A opened Silph Co. 3F at (18, 8).
That process peaked at VmHWM 400617472. The earned adventure files were
not rewritten.

## 2026-11-09 Silph host memory and the 7F rival

Same-process Linux PlaydateSimulator 3.1.2, animations on, earned 3F door
save copied in before launch. Lua `heap_kib` stayed near 7.8–8.8 MB while
VmHWM grew, so the growth is the native allocator, not a live Lua heap.

Standing on 3F at (18, 8) for about 40 seconds after Continue is not flat.
Continue settled at VmHWM 398299136 with heap 8103 KiB. Two later steps of
about 16 MB, roughly 24 seconds apart, left the summary at VmHWM 433614848
and heap 7807 KiB. Between those steps the rise is about 100–200 KB per
2 seconds. A 25-step walk from (18, 8) to (1, 16) peaked at VmHWM 466268160
with heap 7987 KiB, under 1 GiB.

Continue from that same save then took the 3F stair at (11, 11) to Silph
7F (5, 3) at VmHWM 532975616 and heap 8307 KiB, and `move left 2` opened
the rival dialog at (3, 3). Summary: root `dialog`, stack
`overworld>event>dialog`, zone `pokered:SILPH_CO_7F`, heap 8168 KiB,
VmHWM 565895168. No host kill and no 900 MiB ceiling trip.

The standing path no longer copies a trainer `definition()` or a full
`getIntro()` every frame. `sightProfile` caches only id, map, range,
talk-only, and the lab flag. Sight checks stay outside the facing cone.
Cerulean `initialize` runs once per session. The camera skips a matching
`setDrawOffset`, idle sprites skip a matching `setImage`, and imported
floors skip the authored water and flower dirty marks. Those cuts slowed
the earlier continuous climb. They did not remove the ~16 MB arena step,
so the flat-after-settle bar is still open.

`20261109T210700Z-silph-7f-rival.mp4` is 36.0 seconds, 400x240, 1080 frames
of the LCD only. Continue walks the 3F hall, warps to 7F, and shows the
rival line "I guess TEAM ROCKET slowed you down! Not that I care!"
Thirty-five of thirty-six one-second samples differ. That process peaked
at VmHWM 649617408 and was stopped. The earned adventure files were not
rewritten. No battle, and no default art change.

## 2026-11-09 style packet (Miguel 1b / 2b / 3a)

Approved from the style-option screens: Bayer LIGHT 31.25% / DARK 68.75%
everywhere, including Pallet and interiors; battle PNGs redrawn from the
pinned four-shade sources through those Shade patterns; battle ground
platforms kept. Native-size checks are the 32×32 Bayer fills (320 and 704
black pixels) and nearest-neighbor views of the redrawn sprites. A new
Simulator motion pass was not started. The previous overworld probe had
already crossed 1 GiB VmHWM (1200940 kB) and was killed; another long
walking process would repeat that leak. `tools/generate_battle_art.py
--check` reports 302/302 exact. Map-generator tests pass except the
pre-existing `/private/tmp` directory assumption on this Linux host.

Host-memory phases from that probe, same process, VmHWM bytes: title stayed
near 298 MB. Standing after Continue moved from about 298 MB to about 460 MB
in 20 seconds, with the floor load as the large step. Walking continued from
about 468 MB to 529 MB. The abandoned process then reached about 1.15 GiB.
Ordinary overworld time grows the Linux simulator footprint. That remains
the blocker for Card Key and later long journeys. The probe was not repeated.

## 2026-11-09 hourly clips and Gen V Dig

`20261109T183245Z-silph-5f-card-key.mp4` is 22.0s and 330 frames of the
400x240 title. The frames are not one stored picture. TitleState draws a
static Blastoise and a static menu cursor, so the title does not cycle
Pokémon or blink the way Pokémon Blue's title demo does. The same harness
build still accepts menu input: a Down press moved the cursor from NEW GAME
to OPTIONS. Hardware keys do nothing in that build because the harness
replaces the button queries.

`20261109T175100Z-title-and-silph-continue.mp4` is a 39.2s desktop recording.
It opens on a Silph interior under the Simulator "Heads up!" dialog, the
Simulator window disappears between 4.6s and 4.7s with no crash dialog, and
the desktop remains until the recording's two-second end card. The entry
runner had already stopped at 17:50:08 on its action bound and terminates
the Simulator during cleanup. The 1 GiB card-door Simulator log starts at
17:53:52, after this file. No Simulator log records a segfault. It is not
treated as a game crash, and the old note was wrong.

`20261109T190243Z-silph-3f-walk.mp4` is 36.0s of the 400x240 LCD only.
Continue from the earned 3F door save walks the 3F hall and returns to
(18, 8). Thirty-two of thirty-six one-second samples differ. The manual
process climbed to VmHWM 1059057664 and was stopped. The earned
adventure files in the door-save evidence were not rewritten.

Style comparisons remain screenshot-only in
`/opt/cursor/artifacts/style-options/` with `captions.txt`. No default art
changed.

Gen V Dig is a two-turn underground move. The first turn says it burrowed
and spends one PP. The locked second turn is the 80-power hit. Earthquake
and Magnitude double final damage against that target. Other moves miss
unless No Guard is up. Flying-type and Levitate immunity still apply.
The reviewed Solar Beam, Skull Bash, and Fly charge function was not edited.
Host check `tools/tests/dig_host.lua` passes.

## 2026-11-09 Card Key earned under the host ceiling

The failed pickup at `43e31ff6` did not attempt the ball. Continue on 5F
`(9, 14)` had Blastoise at 134/146 and Surf at 10/15, so
`party_is_restored()` was false. `heal_here` walked 5F to 3F to 2F to 1F
to Saffron, and packet 5.5c Saved every 16 cells (four Save cycles). Lua
`heap_kib` stayed between 7719 and 8039. That fresh process was killed at
VmHWM 1074339840.

`3bd1752c` takes the 9F pad and the ball before any heal. Evidence
`linux-silph-card-key-20261109-02`, partial
`5070abaa2bd1e72fd03766470bd4b96076d3b7758edbd6ce4f381532d3bb35eb`.
Trace zones are 5F, 9F, 5F. Rocket `pokered:SILPH_CO_5F:objects:2` paid 990.
`pokered:SILPH_CO_5F:objects:8` is the Card Key. Live slot B is sequence
124 at 5F `(20, 16)` facing right, with `cardKey` 1, money 52117, and Surf
9. Slot A remains sequence 123, the previous pad generation.

The new guard curve has 103 samples over 25.6 seconds. VmRSS never fell.
Final VmHWM and VmRSS were both 917110784, 156663040 bytes under 1 GiB.
The host retains images for the life of the process. A restart is what
clears the peak. The isolated Transform branch still has no diff to review.

The door resume from that save, `linux-silph-card-door-20261109-02`,
loaded 5F, 9F, the elevator and 3F, then a 3F trainer. VmRSS never fell.
It crossed 997404672 at 56.9s and was killed at 1078272000. Lua stayed
near 8 MiB. No newer save was written. The route now saves on the 3F
landing, before that battle, and a Card Key resume inside Silph does not
walk out to heal.

Hourly clip `/opt/cursor/artifacts/hourly/20261109T183245Z-silph-5f-card-key.mp4`
is 22 seconds of the 400x240 LCD, title only, with no Simulator dialog.
`ShowElist=0` is now in the Linux Simulator ini beside `ShowPerfWarning=0`.
Style comparisons remain screenshot-only in
`/opt/cursor/artifacts/style-options/` with `captions.txt`. No default art
changed.

`fa6b861e` saves on the 3F elevator cell before the trainer.
`linux-silph-3f-landing-20261109-01`, partial
`b8f37f2346d314ac3b07ec11b23c9a06d1c5f31113964def7dde1750f7d70a19`.
Live slot A is sequence 125 at 3F `(20, 0)` facing down, still holding
the Card Key, money 52117. Trace is 5F, 9F, 5F, elevator, 3F. VmRSS never
fell. Peak VmHWM 845139968, 228601856 bytes under 1 GiB.

The next process from that landing won Rocket
`pokered:SILPH_CO_3F:objects:2` (840) and opened
`EVENT_SILPH_CO_3_UNLOCKED_DOOR2`, then died loading 7F at VmHWM
1074098176. RSS still never fell. `b4ee9a61` saves on the opened door.
`linux-silph-3f-door-save-20261109-01`, partial
`31df0692be795c1b957bb309708a9bd1424730c33a1ffb8fcc88e2ca500ea02c`.
Live slot B is sequence 126 at 3F `(18, 8)` facing left, door open,
Card Key held, money 52957. Peak VmHWM 846131200.

`linux-silph-7f-20261109-01` resumed that door and reached 7F. The rival
intro `m55c-silph_co_7f-source-trainer-0-intro` started, no battle result
was committed, and the process was killed at VmHWM 1074069504. RSS did not
fall. Do not repeat that 7F walk in one process that also retained 3F.

## 2026-11-09 surveys: Seafoam entry and exposed move gaps

[Seafoam slice plan](bc-eaffd220-a2c4-545f-9ae4-2ffdb30985bc) and
[Exposed move gap survey](bc-98d70612-5448-503c-89aa-db2a3f9792ce) are
read-only. Neither installed maps nor changed battle code.

The first late-Kanto walk is not Seafoam B4F. `Route19`, `Route20`, and
`SeafoamIslands1F` are absent from `Source/data/sourceMaps.json`. Fuchsia's
south edge already aims at Route 19. Surf across the Route 19/20 seam is
still rejected because the origin and arrival cells are collision 1, in
`PewterWorld` and `KantoWorld`. Water encounters on those routes assert
`water.rate_byte == 0` and then fail closed. B4F currents stay out of that
packet. This does not start until checkpoint C is actually playable.

Reachable fail-closed moves, in the survey's order: Dig (TM28 and Fuchsia
Sandslash), Fury Cutter (Sandshrew line), Fake Out (Meowth), Mirror Move
(Spearow and Fearow), Transform (wild Ditto on Routes 13–15). `moveSupport.lua`
still gaps all five. Implementing Dig as a one-turn 80-power hit, or Fake Out
without a first-turn check, would be the wrong Gen V behavior. Hyper Beam and
Low Kick stay on the list but are less forced by current parties. A Transform
candidate is isolated on `cursor/gen5-transform-fcc0` and is not integrated.

The pad-resume Card Key process at `43e31ff6` still died at Linux VmHWM
1074339840 without `cardKey`. The skip flag was absent and the partial
location was Silph 1F. That run is not pickup proof and is not rerun as-is.

## 2026-11-09 Silph pad and confirmed mechanics gaps

The Card Key walk in one Simulator lifetime still dies on the host ceiling.
At `e27a514c` the earned resume reached Silph 5F `(9,16)` after the 9F pad
and was killed at Linux VmHWM 1076424704 bytes. Lua heap was 8256 KiB. No
Card Key. That probe is not rerun.

`5aa95bd4` saved the earned 5F elevator exit `(20,0)` and stopped on the
action bound under the ceiling (VmHWM 838070272). Marker
`8554019638797c0157a174fa76e751f92cce6155a6a71bcfff1b6766044d5998`, ancestry
`2204733359…`. `453a2703` then walked the Card Key approach and saved the
pad `(9,14)` down on `pokered:SILPH_CO_5F`. Marker
`4655fb13b1c976117eac8e8d8854365e61ebbec6dd7d92461a2721dcec8a04d7`,
failed-exited `-9`, VmHWM 938696704, Lua 8160 KiB. The next owned process
resumes that pad for the 9F warp and the pickup. This is not Card Key proof.

Confirmed against this checkout, not yet fixed. `moveSupport.lua` still gaps
Transform (`:141`; Route 13 grass includes level-25 Ditto), Low Kick (`:67`;
`pokemon.lua` has no species weight), Hyper Beam (`:63`) and Giga Impact
(`:347`), Thrash (`:38`) and Outrage (`:186`), Pay Day (`:9`), Fake Out
(`:224`), Taunt (`:237`), Sunny Day (`:215`) and Hail (`:230`). Freeze thaw
in `battle.lua` is only the 1-in-5 roll (`:1035-1046`); Flame Wheel is
ordinary damage. `BattleEffects:setWeather` accepts only sandstorm and
rain (`effects.lua:633`).

`sourceEvents.lua:554` accepts `hidden_events` IDs. pret has 54 hidden item
rows and 12 hidden coin rows. The only `HiddenItems` descriptors in the tree
are two unbound Viridian Forest rows. Routes 10 and 12 have none installed.
Itemfinder remains `effect = "unsupported"`. `coverage-current.md` still
describes the historical B matrix (149 installed, 108 accepted through
5.5a). Current install is 171. That header is not acceptance. Multi-hit code
is 35/35/15/15 (`battle.lua:1368`); the old 1/3, 1/3, 1/6, 1/6 sentence in
`CLAUDE.md` was wrong and is corrected. Dither density, undithered battle
art, battle platforms and contradictory style lines stay unchanged pending
Miguel's decision.

Lead is grok-4.7 with fast mode and high effort, not the literal
`grok-4.7-build-fast` name. Workers use `grok-4.7`. The Task tool has no
reasoning-effort field.

## 2026-11-09 Linux resume

Main `7a31867a` is the merged continuation. 171 source maps are installed.
Simulator campaign acceptance is still the historical 149/222 through
checkpoint B. C is wired and unaccepted. Device-playable acceptance is 0/222.
`LateKantoStory` still only reads its plan. Fossil revival is durable and
unactivated. NPC trades stay parked. Audible playback is still open.

The earned bundle hash
`7484be40784e0bf0973798664fe5da2c46856a0fcc6fc60733ced1846f1e9a95`
imports on this main through `import_chain_save` and
`POKEMON_EVIDENCE_MIRROR`. Squirtle matches the elevator marker
`2204733359…` with only `saffron-guard-entry`. Bulbasaur and Charmander
match their accepted-B slots.

Linux SDK 3.1.2 runs. Locks live in `/tmp`. No USB bus is present in this
VM, so device acceptance is blocked outside the checkout. The historical
smoke scenario now stops on the title menu, which is the current new-game
front. The short Squirtle Silph probe at `17d1afa5` reached
`kanto_silph_co_1f` `(8,11)` down, stage `done`, Card Key absent, Lua heap
7745 KiB, and stopped on the semantic action bound. That run did not record
VmHWM. It is not a 1 GiB failure and not Card Key proof.

## 2026-11-08 current timing build installed

Build `6a009335fd584b77ab67aa5c1fd0cd5a`, source `c1383c63`, PDX `66d5b81688381d349793a938b3cbe2e75904df8477e63e8126010ad1fe7bf017` is the installed DeviceSmoke. Cycle `ok: true`, boot and playability not accepted. It replaced rejected PDX `49ced8e6…`. Same elevator route: Continue 2633 ms, door 3948 ms, Save 3379 ms, battle 24 ms, peak 6272.67 KiB. Post-GC live heap is null. Error and crash logs unchanged. The data disk stayed mounted. This is not the Card Key route.

## 2026-11-08 fossil service stays isolated

Commit `5cf04d6c` adds `FossilRevival` on top of `c1383c63`. It is not imported, and the lab maps stay uninstalled. The host driver stubs the session: it does not call `GameSession:transact` or `GameSession:recruit`. The chosen fossil is a weak table on the live session object, so a Continue would not restore `wFossilItem`. It stays off `main`.

## 2026-11-08 packed-row door candidate not adopted

Commit `108448e3` on top of `c1383c63` reads packed zone rows without the native `gsub` and `unpack` passes. A host Lua 5.4 test says the Silph maps match the dense path and the previous constructor, and `fromMapDefinition` allocation falls from 1234 KiB to 1166 KiB, about 5.5 percent, with a rough host timing of about 6 percent. That is not 10 percent of the 3929 ms door wall. The packed constructor handoff kept the native checks on purpose. The commit stays off `main`. No device run was started for it.

## 2026-11-08 Card Key seam is already wired

No commit. `pokered:SILPH_CO_5F:objects:8` is the content-cache pickup of `cardKey`, flag `PICKUP:pokered:SILPH_CO_5F:objects:8`. Interaction goes through `SourceActors.interact`, `SourceEvents.dispatch`, and the pickup plan, which sets that flag and adds one Card Key. Each Silph door is a bespoke event. `SilphStory.plan` returns the fail text when the quantity is 0 and `already-complete` when the door flag is set. `SilphStoryWorld.unlock` requires the faced door and `cardKey` quantity above 0, then `commitWorld` sets the door flag and leaves the quantity unchanged. The next earned step is to play that pickup and one door from the elevator save. `route_c_silph` is the existing leg, inside the long journey that the 1 GiB host stop already blocks when run whole. A longer device route is not covered by the elevator smoke admission.

Current-source timing build `6a009335fd584b77ab67aa5c1fd0cd5a` at `c1383c63` passed the 16 MiB route on peak 8.62 MiB and raw slice 86 ms. Post-GC live heap is null. The device copy was not started: the tool permission request failed before the command ran. The installed PDX is still rejected build `6f2afa26`.

## 2026-11-08 door candidate rejected

Build `6f2afa2621e04574b681471d341fd704`, source `d2d30ffb`, PDX `49ced8e69479738d27c52bf13bb460fcd59edf10c2ecdebe47e1c0736798434f`. Cycle `ok: true`, boot and playability not accepted. Same Squirtle route, unchanged error and crash logs. Door wall 3967 ms versus baseline `072ca581` at 3929 ms, 38 ms slower, not a 10 percent gain. Save 3408 ms, Continue 2637 ms, battle 22 ms, peak 6272.406 KiB. Post-GC live heap is null. The copy reduction is reverted on `main` by `95b0fad8`. The experiment remains at `d2d30ffb` and `469277cd`. The device still has this candidate PDX installed. The prior timing PDX `6f306e33…` was archived and was not restored.

## 2026-11-08 host baseline on b98c14b4

Discover of `tools/tests` with the env venv and pinned pokered: 1204 tests, 4 failures, 2 errors, 0 skips. The two errors are a missing worktree B2W2 cache. With `POKEMON_ENV` set to `~/Developer/Pokemon-PlayDate-env`, `test_runtime_move_coverage` and `test_substitute_generation` pass, 14 tests. The four failures stay red on purpose. The coverage-matrix fingerprint still records snapshot `598f64d2`. `player.lua` still differs from `fd4561b4` because `75d90990` changed field-travel mode. `sessionCodec.lua` still differs from `1ffd6fa7` because later commits added validation reuse and `relieveHeap`. Refreshing those hashes would relabel the old proofs. No commit came from that check.

## 2026-11-08 timing build, forced collect off

Build `072ca58128c34bc7bc5a678734c544d4`, PDX `6f306e33405c0653ad3d03f53164980231a5b8624a14685b48b2d4ad6d8203a8`. Cycle `ok: true`. `boot_accepted: false`. `device_gate_passed: false`. Same Squirtle route: Continue, Silph elevator to 2F, Save, Rocket sent out Golbat. Error and crash logs unchanged. No diagnostic full-GC windows. Soft collections only. Official `heap_live_bytes` is null. There is no post-GC `after_gc` sample. The uncollected probe heaps are separate and are not a 6 MiB live result: title 6269.655 KiB, Continue 5352.738 KiB, door 6116.572 KiB, Save 5898.279 KiB, battle 5818.854 KiB. Peak 6270.214 KiB. Walls: title 13143 ms, boot slice 1681 ms, Continue 2636 ms, Save 3385 ms, door 3929 ms, battle 23 ms. Longest slice 1888.641 ms. Compared with diagnostic build `634097fd`, the walls moved by tens of milliseconds. Turning the forced collection off did not close title, boot slice, Save, or door. The previous DeviceSmoke `9b086e4d…` was archived and was not restored. This build is what the device has installed.

## 2026-11-08 Save and door attribution

On the diagnostic-GC build `634097fd`, Save was 3434 ms and the Silph elevator door was 3990 ms. The 604–825 ms full collections sit outside those walls. Save capture is 1337 ms and publish is 2097 ms, including an 859 ms readback tail. The door’s largest marked cost is packed-row expansion plus the view array, 1078 ms. The unmarked 1362 ms gap is `SilphStoryWorld.reconcile` and `SourceActors.refresh`. A Save proof-reuse hook could touch about 10% of the Save wall and would not move the door. It is unmeasured, so it stays unapplied. The 10% hardware bar still applies before any adoption.

## 2026-11-08 device smoke, not acceptance

Build `634097fdcea6464f8c9769b14384570d`, source `ab2792f7`, PDX `9b086e4decad7ab028860c72647c928a529355e7011f2bba7293dac682caca55`. Cycle `ok: true`. `boot_accepted: false`. `device_gate_passed: false`. Diagnostic full collections were on. Earned Squirtle Continue, Silph elevator to 2F, Save, and a Rocket battle happened. Error and crash logs were unchanged. Walls: title 13239 ms, boot slice 1675 ms, Continue 2633 ms, Save 3434 ms, door 3990 ms, battle start 24 ms. Heap peak 6270.05 KiB. Separate diagnostic GC windows were 604–825 ms and are not shipped frame time.

Durable copy: `~/Developer/Pokemon-PlayDate-env/evidence/main-c171-device-smoke-20261108-634097fd` with `RECEIPT.json`. Tree hashes: build `9d5d025c37cf5afc1c27ec20af5c3432e28c9371cf8a92e8712796ab49b1e49e`, simulator smoke 3 `4ebe06b2146c61c2b90d858a1820f1347229655738180feb677fd47280394da5`, device cycle `177328df29647c865b5d951a4dff5d07dd7ddd23a1e557218f4257cd8dd7b269`. Identities inside the run were not rewritten.

After the cycle the data disk stayed mounted and there was no serial reader. `DeviceSmoke.pdx` on the device is this build. `PokemonPoC.pdx` is still present. The previous DeviceSmoke tree `426835278bf879df` was archived and was not restored. Lock files named dead PIDs; the flock was not held.

Local `main` is `ab2792f7`, four commits ahead of `6e98024`, not pushed.

Updated 2026-11-06 UTC. Follow [the goal](../plans/full-game-goal.md).
**Main: 149/222 Simulator-route maps. Device-playable acceptance: 0/222.**
The full Blue campaign, credits and postgame remain unfinished. C's 171-map
preparation is on main and still unaccepted. The user asked to stop and push
this progress. It combines `cursor/c-linux-continuation-4fcf` (`2a58f532`) and
`cursor/save-catalog-reuse-4fcf` (`4682c9cd`), branched from `4b93ff24`
(`origin/pi/c-actor-validation-fix`). The handover is
[c-session-stop-20261105.md](../handoffs/c-session-stop-20261105.md).

## Accepted continuation merged to main — 2026-11-06

`cursor/c-linux-continuation-4fcf` is an ancestor of
`cursor/save-catalog-reuse-4fcf`, so one merge carries both. Rejected
experiments stay reverted, including door-fade reuse, the skipped journey
collect, and the earlier copy and imagetable cuts recorded below. The
map-definition cache and save-catalog reuse stay. `route_c_silph` still does
not fit under 1 GiB. No cabin was launched for this push.

## Per-command collection and cached door fades do not cut the street — 2026-11-06

VmHWM does not fall because the simulator malloc log keeps every record. A
prior same-host histogram put the live heap at about 4.99 million 24-byte
`strdup`s and 6.60 million 40-byte log nodes; `fordblks` stayed near 3 MiB.
Lua at the street pause stays near 8.5 MiB because those tables are freed.
The log is not. Pool `MallocPoolSize=16645684` and the 1 GiB stop stayed on.
No preload.

On the committed street pair the Center door itself is about +2 MiB. The
next observe plus the step to `(8, 30)` is still about +41 MiB. One
`doorWarp` update spends about 400 ms in fade yields; that wait is not the
+41 MiB. `drawFaded` for the 7/8 and 1/2 patterns was built once per door
and then blitted (`street-fade-1`). Landmarks matched cut 2 within 1.5 MiB
(pause 902924 vs 902424 KiB, peak 1046700 vs 1047904). Reverted.

Dropping `collectgarbage("collect")` after every journey command
(`street-nogc-1`) left the door-to-street step at +41 MiB and raised the
Center pause from 640832 to 677968 KiB. Reverted. Checksums, the second
payload decode, snapshot cadence, owner export, and the 6/8/9 vs 11 MiB
guards are unchanged.

`route_c_silph` still does not fit under 1 GiB. No cabin was launched.

## Saffron street re-decode is smaller; the Silph route still does not fit — 2026-11-06

The 997 vs 1041 MiB spread was the same street Save, sampled on either side of one heap extension. It was not a divergent walk. On this tree the matched pair agrees within 1 MiB at every landmark. Source `9323a2029ebe40cfb183f1d1f52f210758fa22782ffa14470cc59838c8023dbc`, pool `MallocPoolSize=16645684`, no preload. The previous street run on the imagetable experiment is `street-reuse-1` (source `36cd529874271809`).

Leaving the Center used to decode `runtime-SaffronCity.json` and the city's content chunks again, because the load scope drops those tables and the chunk cache held eight. The padded runtime definition for the two most recent maps is now kept, and the chunk cache holds ninety-six. Explore frames read the intro stage and the travel mode without copying those records. Checksums, the second payload decode, owner export, snapshot cadence, the 16 MiB pool, and the 1 GiB stop are unchanged. Lua at the street pause was 8501 KiB, under both 9 and 11, so the 11 MiB recovery did not collect.

| Landmark | reuse | cut 1 | cut 2 |
| --- | --- | --- | --- |
| Center `(3,7)` in | 714620 (697.9) | 641804 (626.8) | 640832 (625.8) |
| Center `(3,7)` out | 940776 (918.7) | 853736 (833.7) | 852636 (832.7) |
| City door `(9,30)` | 944032 (921.9) | 855228 (835.2) | 854780 (834.7) |
| Street `(8,30)` | 1001136 (977.7) | 897360 (876.3) | 896756 (875.7) |
| Pause `(3,28)` | 1010924 (987.2) | 903152 (882.0) | 902424 (881.3) |
| Peak | 1065252 (1040.3) | 1047216 (1022.7) | 1047904 (1023.3) |

KiB, with MiB in parentheses. Sessions: reuse `d596ee7ced834c8ba31140bef98b672f`; cut 1 `9d07cd61df124d73a0be9057e2c8b4fe`; cut 2 `fc1d3e8722db4019a34361c86c21221a`. All three stopped on the 1 GiB guard. The door-to-`(8,30)` step is still about 41 MiB (was 56). The pause is 105 MiB under the previous run, and that Save now returns. The probe then walks back toward Silph and opens another pause; that continuation is what reaches 1023 MiB.

`route_c_silph` after this heal still has the mart, the Silph floors, the rival, Giovanni, the president, and another heal. The measured continuation already spends the margin before re-entering Silph. The route does not fit under 1 GiB. No cabin was launched.

Isolated grass-cut on this source, `max_frames` 18000: 35 passed, 0 failed, exit ok, session `6018aabcbeef4cef9444a1c03206c75f`. Live heap at return was 13212 KiB, under the 16 MiB pool and under the previous 13783 KiB peak. One pass, not a new two-pass claim.

## 11 MiB recovery stays above the 6/8/9 MiB guards — 2026-11-06

`SessionCodec.relieveHeap` runs only at the start of `encode`, `decode`, and
`validate`. It is not on the frame path. The threshold is 11 MiB of Lua
(`11 * 1024` KiB), strictly above the three admission limits in `BootTrace`:

- 6 MiB is the post-collection live cap on hardware (`title.live`,
  `Continue.live`, and after the soft collect).
- 8 MiB is the soft collect (`collectMemoryIfNeeded`), and it runs only after
  `checkGuard` has already sampled the heap.
- 9 MiB is the hard sample. `checkGuard` errors when `heap >= 9 * 1024` KiB.
  It runs from `BootTrace.mark`, `GameBootstrap.yieldIfDue`, and both ends of
  `GameBootstrap.runFrame`. The private door-census collect calls `checkGuard`
  before it collects.

`BootTrace.memoryBudgetEnabled()` is true for a device-test build and for any
process where the harness is off. On that path `relieveHeap` returns
immediately, so it cannot collect a sample away before the 9 MiB guard sees
it, and it does not change the 6 or 8 MiB thresholds. Private harness journeys
leave the budget off. They sit under 9 MiB, so the 11 MiB threshold does not
collect and does not change snapshot cadence (full party, bag, flags, and
Pokédex on command completion and every 30 frames). Releasing retained
diagnostic views only makes the next snapshot rebuild them.

While `proofDepth > 0` (a Save, recovery, or replacement is still proving its
readbacks) the recovery keeps the validation proof and the decoded slot
records. Dropping them would force `_decodeUncached` to decode the payload a
second time. Checksums, that second payload decode, owner export,
`SaveBuildPolicy`, the 16 MiB pool (`MallocPoolSize=16645684`), and the 1 GiB
Linux VmHWM stop are unchanged.

## Hiding the tilemap does not cut the Saffron climb — 2026-11-06

The extended probe still dies on `pokered:SAFFRON_CITY` `(3, 28)` with Card Key
0. Three checks on this tree (`fe4333c6`) missed, and were removed:

- `Party._primitive` during the Silph 1F south walk is about 28 keys and 4
  calls a frame. That is not the climb.
- Freezing `Camera:follow` / `Camera:apply` for ticks 374–460, and separately
  hiding the live tilemap sprite for those ticks, left the Silph-entry peak at
  439004 and 439184 KiB against 439464 KiB with both left on.
- Hiding the live tilemap after tick 30 for the whole extended probe
  (confirmed: Silph 1F drew only RED and one NPC) tracked the previous
  heal-layout run within about 1 MiB at the same landmarks and still stopped
  at 1050072 KiB. The sampler killed that simulator; session
  `82923a4f496d481983443d90b9e88869`. The matched heal-layout run peaked at
  1021240 KiB.

A garbage-collector pause on twelve frames at Saffron `(13, 22)` measured
2.88 KiB of Lua in `machine:update` while walking, 0 in draw, and about 36 KiB
in the harness snapshot on a command boundary. Draw is not the per-frame Lua
cost. The retained Linux climb is still the simulator malloc log (40-byte
node, `strdup`, and a 32-byte-stride `realloc`) enabled with the 16 MiB pool.
No cabin was launched. Grass-cut was not re-run; the two passes above still
stand. The persistence payload cap stays not green.

## Grass-cut holds, Center heal no longer copies the map every frame — 2026-11-06

Publication proofs are kept only while a Save, recovery, or replacement is
validating its readbacks, then released. Above 11 MiB of Lua heap, decoded
publication records and retained diagnostic views are dropped and the pool is
collected. Each grass-cut scene does that before it builds the next Route 6
view. The machine-geometry check still reads the map definition; a zone that
already passed is not deep-copied again on every heal frame. Checksums, the
second payload decode, owner export, the 16 MiB pool, and the 1 GiB stop are
unchanged.

Isolated grass-cut, `max_frames` 18000, final source
`8cc7ad913152ae280b3a43760a83813ad81c0d58ffe4eee5830eb5aa121a95c3`:

| Run | Result | Session |
| --- | --- | --- |
| 1 | 35 passed, 0 failed, exit 0 | `7bb7a11425d3430db1d904331f845251` |
| 2 | 35 passed, 0 failed, exit 0 | `4021f58dc60d435dbfcbd19b9c71cb48` |

Healing-composition on the same source: 26 passed, 0 failed, exit 0, session
`ba01680b870c4698b98ffa643b8e1114`. The persistence payload cap was not re-run
and is not green.

The same extended Saffron probe, pool `MallocPoolSize=16645684`, no preload,
still stops on the 1 GiB guard. Both runs leave the Center and stop in
`pokered:SAFFRON_CITY` at `(3, 28)` up, pause open, Card Key quantity 0.

| Run | Sampled VmHWM | Session | Stop |
| --- | --- | --- | --- |
| previous heal spike | 1006628 KiB (983.035 MiB) at 43.9s | inside the Center heal | probe kill |
| 1 | 1021240 KiB (997.305 MiB) at 56.8s | `4b70ae7aa11a4814973788ef98db5834` | harness 1 GiB stop |
| 2 | 1066268 KiB (1041.277 MiB) | `69f4d313fbe64986b418e95ed33c85c0` | sampler kill, then harness timeout |

The per-frame map copy during the nurse animation is gone: the run continues
through that heal onto the Saffron street instead of dying inside it. The
street is already at the stop. Silph, the Card Key, and the rest of
`route_c_silph` are not inside 1 GiB. No cabin was launched. This is not Mac
phys_footprint and not hardware acceptance.

## Save headers and unchanged snapshots — 2026-11-06

A public Save still checksums, decodes, and validates every new byte string.
Inspecting the two published slots during that Save now keeps only the
validated header (state, sequence, payload, path). The decoded data tree stays
in the existing byte cache. A candidate that may be returned as recovery data
is still copied. Readbacks that match the publication's validation proof return
the detached record already held for that proof. Any other validator, or a
missed proof, still copies before validation and compares the copy. Owner
export, the payload decodes, and `SaveBuildPolicy` are unchanged.

Walking snapshots still record the full party, bag, flags, and Pokédex on the
same cadence. A later snapshot reuses those tables only when the live flag
generation, flag-table identity, dex generation, dex-table identity, bag slot
identity, money, and a party field stamp all match. The closed Pokédex
snapshot reads two species flags instead of copying the dex. `flags()` and
`pokedex()` still return fresh copies to every other caller.

Source `e2d852a7b01951cb818ccb459cd238f64f3baefca35554453113362049a6d618`,
measured against parent `d32629c4`, pool `MallocPoolSize=16645684`, no preload,
one process, exit 1, `parcel journey exceeded semantic action bound`.

Official one-save probe, `pokered:SILPH_CO_1F`, stage `done`, player `(8, 11)` down,
last save `published`:

| Run | VmHWM | Session |
| --- | --- | --- |
| header 1 | 443076 KiB (432.691 MiB) | `76769e064aac47b994afaa4205c41023` |
| header 2 | 442488 KiB (432.117 MiB) | `5c728824bc944287b085d1b3c291e3b0` |

The worse run is under the 520.070 MiB gate and 26312 KiB (25.7 MiB) under the
validation-proof worse run (469388 KiB).

Capped four-save path, `pokered:SAFFRON_POKECENTER`, stage `done`, player
`(3, 3)` up, last save `published`:

| Run | VmHWM | Session |
| --- | --- | --- |
| proof worse | 938032 KiB (916.047 MiB) | `36149f6c288244e1bda4657264eac0f7` |
| header 1 | 818564 KiB (799.379 MiB) | `2b6d51cb2c484afa9f2eaad7420a541d` |
| header 2 | 816424 KiB (797.289 MiB) | `4af24db0426645c0a181c673485a741e` |

The worse header run is 119468 KiB (116.7 MiB) under the proof worse run.
Adding cabin 03's 75148 KiB uncapped offset is 893712 KiB (872.766 MiB),
154864 KiB (151.2 MiB) under the 1 GiB stop at that Center tile.

That margin does not survive the next commands. A further probe with the same
build raised the action, step, and transition bounds and was killed at
1006628 KiB (983.035 MiB) while still inside `pokered:SAFFRON_POKECENTER`,
player `(3, 3)` up, root `event`, Card Key quantity 0, 157 results. It is not
a finished journey. No new cabin was launched. Grass-cut and the persistence
payload cap were not re-run and are not green. This is not Mac phys_footprint
and not hardware acceptance.

## One Save's later readbacks reuse its validation proof — 2026-11-06

A public Save still validates on inspection, on the envelope, and on both
readbacks. The envelope runs the full normalize. Each later call in that same
publication compares the newly decoded table with a detached proof of that
result, including the dependency functions. A difference, a failure, or the
return from Save drops the proof and takes the full path. Owner export, the
payload decodes, the copies that detect a mutating validator, and
`SaveBuildPolicy` are unchanged.

The capped four-save path, no preload, pool `MallocPoolSize=16645684`, one
process, exit 1, `parcel journey exceeded semantic action bound`,
`pokered:SAFFRON_POKECENTER`, stage `done`, player `(3, 3)` up, last save
`published`. Content
`2c17a62bcf434ae86f2fb004d5d96e22492f474a22d6a11ec5514e81a0c37393`:

| Run | VmHWM | Session |
| --- | --- | --- |
| publication reuse | 984392 KiB (961.320 MiB) | `0557a2ea05684bb6b0d672c5b39a7aea` |
| proof 1 | 904832 KiB (883.625 MiB) | `852fd23caf5148b4a5958b59dba43b29` |
| proof 2 | 938032 KiB (916.047 MiB) | `36149f6c288244e1bda4657264eac0f7` |

The worse proof run is 46360 KiB (45.3 MiB) under the publication-reuse run.
The official one-save probe, same guards, `pokered:SILPH_CO_1F`, stage `done`,
player `(8, 11)` down, one process, action bound, last save `published`:

| Run | VmHWM | Session |
| --- | --- | --- |
| proof 1 | 469388 KiB (458.387 MiB) | `bbc18202dc1f4da49a9e1e60c8fd1e4b` |
| proof 2 | 468460 KiB (457.480 MiB) | `c6e7ef83632245ca822f4c26076a6364` |

The worse run is under the 520.070 MiB gate and 15176 KiB under the
publication-reuse worse run (484564 KiB).

Cabin 03 was 75148 KiB above the capped publication-reuse probe at this same
Center tile, because the uncapped journey took the next command. Adding that
gap to the worse proof run is 1013180 KiB, 35396 KiB (34.6 MiB) under the 1 GiB
stop. That is the Center, before the rest of `route_c_silph`. The remaining
route still enters Silph 5F, 9F, 3F, 7F, and 11F, revisits floors, fights, and
saves every 16 walked cells. Those do not fit in 34.6 MiB. No new cabin was
launched. This is not Mac phys_footprint and not hardware acceptance.

Isolated grass-cut on this tree passed once (`/tmp/pd-assess/proof-gc`, 35
passed, 0 failed, exit 0) and failed once (`/tmp/pd-assess/proof-gc2`, 34
passed, 1 failed, exit 1). The failure is still `not enough memory` in
`saved terrain decodes then public Continue restores source grass and position`.
Grass-cut is not green. The persistence payload-cap failure recorded below was
not re-run and is not green.

## Two host memory failures are not green — 2026-11-06

The publication-reuse change was compared, isolated, with the pre-change tree
`37dae3af` (content `16312ba1de83551910ec0229716c8abac20f4870e01dbad47562299a1fb4ca56`,
worktree `/tmp/pd-assess/pre-retain`) and the current tree `a57db9d1` (content
`b815e3854cfbd25bc6dbaae0362a96c8b5a108a4307656e9c5fe0dc5f0936db5`). Neither
failure below is a passing check.

Persistence, `read faults sequence conflicts and bounded payloads never replace
committed bytes`: the fixture builds `string.rep("x", SaveStore.MAX_PAYLOAD)` and
calls `SaveStore:save` on a store that is not `gameSaveStore`.
`retainVerifiedPublications` is never set. The same case reports
`not enough memory` through `contracts.lua:406` on the retain build
(`/tmp/pd-assess/save-retain-persist`, 45 passed, 1 failed), on the immediate
parent (`/tmp/pd-assess/memqual-persist-base`, 45 passed, 1 failed, exit 1), and
on the earlier `51164b5a` tree (`/tmp/pd-assess/save-epoch-contracts3`, 45 passed,
1 failed). The inspect-reuse change did not cause this and did not worsen it.
The bounded-payload case is still a Lua-cap failure.

Grass-cut, isolated, `max_frames` 18000:

| Run | Build | Result |
| --- | --- | --- |
| parent 1 `/tmp/pd-assess/memqual-gc-base` | `37dae3af:16312ba1` | 35 passed, 0 failed, exit 0 |
| parent 2 `/tmp/pd-assess/memqual-gc-base2` | `37dae3af:16312ba1` | 35 passed, 0 failed, exit 0 |
| retain 1 `/tmp/pd-assess/memqual-gc-now` | `a57db9d1:b815e385` | 33 passed, 2 failed |
| retain 2 `/tmp/pd-assess/memqual-gc-now2` | `a57db9d1:b815e385` | 32 passed, 3 failed, exit 1 |

Retain run 1 failed `facing each quadrant selects one source block rather than
player-centered area` (`not enough memory`) and `16 native updates sample 32
source positions and commit once` at `grassCutContracts.lua:13`
(`SessionCodec.encode`). Retain run 2 failed different cases, including
`saved terrain decodes then public Continue restores source grass and position`
at `grassCutContracts.lua:529` around `SessionCodec.decode`. Boot heap on the
retain tree is about 1.1 KiB higher at session import and 5.0 KiB higher at
GameSaves init, and the first cached publication adds about 85 KiB at
`Save.begin`. The parent suite passed twice. The retain tree failed twice.
The change worsened grass-cut reliability. Grass-cut is not green.

## Third Squirtle cabin still stopped at 1 GiB — 2026-11-06

One new cabin ran the admitted 5.5c journey on the publication-reuse build
`4a9d1ce3`. It is not a relaunch of `linux-cabin-pilot-20261106-01` or
`linux-cabin-pilot-20261106-02`. The 16 MB pool, the 1 GiB Linux VmHWM stop,
and the other guards stayed on. No preload.

It published both Silph 1F saves, the Saffron City save, and the fourth save
inside the Saffron Pokémon Center. Cabin 02 had died while that fourth save's
dialog was opening, at `(3, 7)` up, tick 1006. This run finished the save.
The guard then stopped the owned Simulator on the next press, still in the
Center: `owned Simulator exceeds 1 GiB Linux VmHWM`. The peak sample was
**1034.7 MiB** (1059540 KiB), session `5e25a0b8f65843d1b2545bb5d4ec59a7`,
one process, 175 samples, 43.97s. The last snapshot is
`pokered:SAFFRON_POKECENTER`, player `(3, 3)` up, tick 1095, pause closed,
last save `published`. `resumed_steps` was still only `saffron-guard-entry`.
The Continue process did not start. Card Key was still absent. Captures were
not finalized. The capped four-save probe had ended at this tile under the
guard (961.320 MiB) because its action bound fired first. The uncapped cabin
took the next command and crossed. This pilot was not launched again. This
is not a Mac phys_footprint result and not hardware acceptance. C progression
has not started. Evidence, outside Git: `linux-cabin-pilot-20261106-03`.

## A verified public readback is reused on the next Save — 2026-11-06

The epoch cache only filled when a byte string was decoded. A public
readback accepts the promoted file and does not decode it, so the next Save
still decoded that newest slot in full. `SaveStore:retainVerifiedPublications()`
is opt-in. The public game store sets it after
`session-public-dependencies-v1`. After the promoted bytes match the
envelope, that exact string and its detached record are remembered. Owner
export never sets the flag. New payloads still checksum, decode the payload
twice, validate, and read back. `SaveBuildPolicy` is unchanged.

The cabin path, extended through the fourth published save and stopped on
the action bound, no preload, pool `MallocPoolSize=16645684`, one process,
`pokered:SAFFRON_POKECENTER`, stage `done`, player `(3, 3)` up, last save
`published`:

| Run | VmHWM | Session |
| --- | --- | --- |
| epoch only | 1031308 KiB (1007.137 MiB) | `b1861dc3d1a04cf49ac727e134717816` |
| publication reuse | 984392 KiB (961.320 MiB) | `0557a2ea05684bb6b0d672c5b39a7aea` |

The cut is 46916 KiB (45.8 MiB) on that path. 984392 KiB is 64184 KiB under
the 1 GiB stop. That finishes the save cabin 02 died inside. It does not
leave another Silph door. The official one-save probe does not inspect the
new file again. Both runs still stop on `parcel journey exceeded semantic
action bound` at `pokered:SILPH_CO_1F`, stage `done`, player `(8, 11)` down,
one process:

| Run | VmHWM | Session |
| --- | --- | --- |
| retain 1 | 484564 KiB (473.207 MiB) | `1043e7cfe3324746aea06d6127005c97` |
| retain 2 | 483396 KiB (472.066 MiB) | `d8b7d75d101e4316a0e051b71804a597` |

The worse run is under the 520.070 MiB gate and 1652 KiB above the epoch
worse run (482912 KiB). Public GameSaves save/Continue passed. Persistence
passed 45; the same bounded-payload case still reports `not enough memory`.
Owner call-count tests passed. This is not Mac phys_footprint and not
hardware acceptance. Evidence, outside Git: `linux-silph-two-save-before`,
`linux-silph-two-save-after`, `linux-silph-entry-retain-1`,
`linux-silph-entry-retain-2`.

## Public slot proof reused on the next Save — 2026-11-06

Cabin 02's VmHWM did not spike and release. Across 166 samples it never fell.
Two Silph 1F saves left the process at 598.9 MiB. The 1 GiB sample was later,
when a fourth save opened inside the Saffron Center, on top of those saves,
the Saffron door, the Saffron save, and the steps between them. One save's
peak is not the guard.

The public game store decoded and normalized a slot again whenever Save
inspected it, even when Continue had just accepted those exact bytes.
`SessionCodec.gameSaveStore` now sets
`session-public-dependencies-v1` on that store only. The first read of a byte
string still checksums, decodes the payload twice, and validates. A later
inspect of those same bytes reuses the detached record. Owner export stays
off. New payloads still take the public envelope and both readbacks.
`SaveBuildPolicy` is unchanged.

Matched Silph-entry runs, no preload, pool `MallocPoolSize=16645684`, one
process, exit 1, `parcel journey exceeded semantic action bound`,
`pokered:SILPH_CO_1F`, stage `done`, player `(8, 11)` down:

| Run | VmHWM | Session |
| --- | --- | --- |
| epoch 1 | 482912 KiB (471.594 MiB) | `bda530d1d83843a4a84d855abdf2ae08` |
| epoch 2 | 481560 KiB (470.273 MiB) | `54a64c0496304f4385bcdca6a4103d90` |

The worse run is under the 520.070 MiB gate and 20044 KiB (19.6 MiB) under
the shared-scene worse run (502956 KiB). That is the whole-probe difference,
not a per-save measurement of the cabin. Subtracting it once from cabin 02's
1049356 KiB still leaves about 1005 MiB, over the 1 GiB stop. Doors and steps
are untouched. No new cabin was launched. This is not Mac phys_footprint and
not hardware acceptance. C has not started. Evidence, outside Git:
`linux-silph-entry-epoch-1`, `linux-silph-entry-epoch-2`.

## Second Squirtle cabin still stopped at 1 GiB — 2026-11-06

After the shared Silph scene plan, one new cabin ran the same admitted 5.5c
journey. It is not a relaunch of `linux-cabin-pilot-20261106-01`. The 16 MB
pool, the 1 GiB Linux VmHWM stop, and the other guards stayed on. No preload.

It continued from the Silph elevator, saved twice on `pokered:SILPH_CO_1F`,
and published a third save on Saffron City. The last save was `published`.
The guard then stopped the owned Simulator inside the Saffron Pokémon Center:
`owned Simulator exceeds 1 GiB Linux VmHWM`. The peak sample was **1024.8 MiB**
(1049356 KiB), session `ac1ce9bc975f4b8e848b6afd8555b228`, one process. The
last snapshot is `pokered:SAFFRON_POKECENTER`, player `(3, 7)` up, tick 1006,
with a dialog opening and not yet ready. `resumed_steps` was still only
`saffron-guard-entry`. The Continue process did not start. No battle was
recorded. Card Key was still absent.

Pilot 01 had died during that third save, at Saffron City `(4, 22)` left,
tick 810. This run finished the save and reached the Center, then crossed the
same stop. The per-save and per-door climbs are still large enough that the
full journey cannot stay under 1 GiB. This pilot was not launched again.
This is not a Mac phys_footprint result and not hardware acceptance. C
progression has not started. Evidence, outside Git:
`linux-cabin-pilot-20261106-02`.

## Shared Silph scene plans cleared the Linux gate again — 2026-11-06

`SilphStory.scenes()` decoded the pinned scene plan once, then deep-copied
every node on each read. Save validation and map entry ask for that plan once
per actor, including actors that only need to know the plan does not mention
them. The decoded plan is now the shared read source. SaveStore copies, the
second payload decode, validators, readbacks, and SaveBuildPolicy are unchanged.

With the 16 MB pool and no preload, both runs stopped on `parcel journey
exceeded semantic action bound` at `pokered:SILPH_CO_1F`, stage `done`, player
`(8, 11)` down, one process. VmHWM was **491.168 MiB** (502956 KiB) and
**491.086 MiB** (502872 KiB). The worse run is 15.0 percent under the higher
Linux baseline of 577.855 MiB, and both are under the 520.070 MiB bar. It is
also 24.4 MiB under the previous adopted worse run of 515.531 MiB. This is not
a Mac phys_footprint result and not hardware acceptance. Evidence, outside
Git: `linux-silph-entry-scenes-1` and `linux-silph-entry-scenes-2`.

## Save-window records cleared the Linux gate — 2026-11-06

Session normalize rebuilds the item catalog and every Pokémon's six-stat
records while it validates a save. Inventory and the session dependency
projection still check every definition on each construction, and they reuse
one record table per unchanged source identity. A changed or removed
definition rebuilds that projection. Item storage still deep-copies the
catalog once per source, then reuses the detached copy after validation.
Individual stat normalization and calculation build compiler-sized literals.
The defensive primitive copy reuses one cycle set for a root walk and
allocates a fresh set when a copy is already in progress. SaveStore's own
copies, the second payload decode, validators, readbacks, and SaveBuildPolicy
are unchanged.

Reusing only the item-catalog records, without the stat literals or the shared
cycle set, reached the same end state at **555.688 MiB** and missed the bar.
That narrower edit is not what this tree keeps. The combined cut, with the
16 MB pool and no preload, stopped on `parcel journey exceeded semantic action
bound` at `pokered:SILPH_CO_1F`, stage `done`, player `(8, 11)` down, one
process. VmHWM was **515.180 MiB** and **515.531 MiB**. Both are under the
520.070 MiB bar, which is 10 percent under the higher Linux baseline of
577.855 MiB. This is not a Mac phys_footprint result and not hardware
acceptance. Evidence, outside Git: `linux-silph-entry-catalog-1`,
`linux-silph-entry-save-cut-1`, and `linux-silph-entry-save-cut-2`.

One Squirtle cabin pilot then ran the admitted 5.5c journey from that same
save, with the 1 GiB Linux VmHWM stop left on. It continued from the Silph
elevator, saved twice on `pokered:SILPH_CO_1F`, and the guard stopped it at
100 commands: Saffron City, pause menu, player `(4, 22)` left, tick 810.
`resumed_steps` was still only `saffron-guard-entry`. No battle was recorded.
The Continue process did not start. The pilot was not launched again.
Evidence: `linux-cabin-pilot-20261106-01`.

## Linux continuation assessment — 2026-11-06

Clean Linux x86_64 workspace, no prior `env.sh`, SDK, earned saves, or Mac
helper. Official Playdate SDK 3.1.2 is installed at `~/Developer/PlaydateSDK`
(`pdc` reports 3.1.2; `bin/PlaydateSimulator` is the Linux ELF). Pinned pokered
`af519899719f0754965776faac0e836a3b906e6d` checks out. The pinned B2W2 cache
`tools/verify_moves/cache/b2w2/2bf639e5572812a67d2b94903fdcb9d095f5aeb2` verifies.
One interpreter: Python 3.12.3 in `~/Developer/pd-venv` with Pillow 12.0.0.
Disk free is about 245 GiB, above the 31 GiB admission. No
`/dev/cu.usbmodemPD*` node. Swift and `/usr/lib/libproc.dylib` are absent, so
the Mac history helper and `proc_pid_rusage` footprint cannot run. The 1 GiB
stop stays inside `JourneyHistory` and was not replaced or disabled.

The Linux Simulator GUI does start. Its first-run dialog was dismissed, then
Playdate > Malloc Pool > 16 MB was selected in the UI. After quit, the binary
wrote `MallocPoolSize=16645684` to
`~/.config/Playdate Simulator/Playdate Simulator.ini`. That is the file this
platform writes. The runner now uses `bin/PlaydateSimulator` when the macOS app
binary is absent, and reads that ini off Darwin. Darwin still uses the app
bundle and `~/Library/Preferences`. A missing or different pool value still
fails closed. `make test-harness` protocol tests passed 57/57, and the new
platform checks passed 4/4. Commit `ddd8ffc7`. Production `pdc` also compiled
`PokemonPoC.pdx`.

A fresh harness session on that binary reached the title menu (NEW GAME /
OPTIONS), stage `pre_oak`, Lua heap about 10.9 MiB, ready at about 29 s wall.
Evidence, outside Git:
`~/Developer/Pokemon-PlayDate-env/evidence/linux-title-smoke-20261106-01`.
ALSA reported no playback device. This is not a Silph-entry measurement, not a
device result, and not C acceptance.

The strict importer does not reach the cabin marker. It stops on the missing
accepted-B producer
`~/Developer/Pokemon-PlayDate-env/evidence/m55b-earned-fourteenth-resumed-20261030-01/03-midgame--restart-55b-squirtle/run.json`.
The cabin marker `22047333…`, slots `6a20c09e…` / `00f2d64b…`, and chain
`evidence/chain/5.5b/squirtle` are also absent. No save was fabricated. No
allocation edit was made. Rejected experiments stay rejected. The Mac
Silph-entry gate (both runs ≤ 421.26 MiB) was not run and is not claimed from
Linux RSS. The cabin pilot was not relaunched.

Host discovery on this machine: **1161 tests, 7 failures, 62 errors, 1 skip**
(the Darwin footprint proof). Log:
`~/Developer/Pokemon-PlayDate-env/evidence/linux-host-suite-20261106-01/host-suite.log`.
Failures are the inherited C-versus-B inventory/coverage mismatch, including a
stale coverage Source fingerprint that this session did not regenerate. Errors
are missing external reference trees (ability oracle, field-move pins, NPC-trade
manifest) and `libproc`. This is not a green suite and does not requalify C.

## Trace append handle missed the Linux gate — 2026-11-06

`trace.jsonl` was opened, written, and closed on every command completion and
every 30 journey frames (96 rows, 2.9 MB, prefix-sum about 132 MB if each open
kept the bytes). Holding one append handle for the session, and flushing every
row, never published `ready.json`: `file:flush` on that handle did not return.
Publishing ready before the first append and not flushing per row did finish
the probe. Same end state (`pokered:SILPH_CO_1F`, stage `done`, player
`(8, 11)` down, action-bound error, one process) at **576.305 MiB** VmHWM.
The tail of the trace was 93 rows rather than 96, because the handle was still
open when the simulator was stopped. The change was reverted. It is not an
adoption. Evidence: `linux-silph-entry-trace-handle-3`.

The climb is live glibc heap, not WebKit and not freed-but-retained pages.
`mallinfo2` at the peak reported `uordblks` about 506 MB, `fordblks` about
3 MB, and `hblkhd` about 28 MB. WebKit's mapping stayed about 10.7 MB. Lua
`collectgarbage` never passed **8.84 MiB**. A size histogram of still-live
mallocs was about 4.99 million 24-byte objects (114 MB) and 6.60 million
40-byte objects (252 MB), plus the 16 MB pool and one buffer that grew to
about 27 MB. Sampled backtraces of the surviving 16–128 byte objects are
`strdup` and a 40-byte node inside `PlaydateSimulator`, appending
`%s %s:%i` frames (`nSl`) to a list that only grows. Removing the saved
sampler and memory window rects from the simulator ini, keeping
`MallocPoolSize=16645684`, still peaked at **575.750 MiB**. The cabin pilot
was not relaunched.

## Silph elevator surround — 2026-11-06

The live Silph Co. elevator (`pokered:SILPH_CO_ELEVATOR`, imported 13×4 cells,
128 px tall) sat in the lower middle of the 400×240 screen with a solid white
band above it. Pokered's map is 2×2 blocks with border block `$0f`.
`LoadTileBlockMap` fills the overworld buffer with that border before placing
the room, and the scroll origin stays non-negative, so the surround is black
and the room is in the upper portion of the view. This game's authored
interiors pad with void to at least 13×8 because the camera assumed the map
was at least screen-sized. The elevator's vertical padding is 0. `Camera`
applied `map - screen` after the `>= 0` clamp, and that limit is −112 px, so
the room was bottom-aligned. Pixels the tilemap did not cover stayed the
default white sprite background. The catalog viewport already used
`math.max(0, math.min(map - screen, goal))`, which pins a short map to the
origin. `follow` and `snapTo` now do the same. While the live map is narrower
or shorter than the screen, the sprite background is black and the full
display is marked dirty once on entry; screen-sized maps still use white so
transparent roof wedges are unchanged. Elevator menus, persisted floor, and
tile art are untouched. The static catalog clear color is unchanged.
`test_visual*.py` passed 21/21. Protected-source pin mismatches on
`tilefactory.lua`, `spritefactory.lua`, `player.lua`, `zone.lua`, and
`maps.lua` are the existing C-tree drift; those files were not edited.
A fresh guarded probe captured the elevator with the room in rows 0–127 and
solid black from row 128 through 239, then still stopped on the action bound
at `pokered:SILPH_CO_1F` `(8, 11)` down. That run's VmHWM was 585.238 MiB and
is not an allocation adoption. Evidence:
`linux-silph-elevator-surround-1`.

## Path-only await pair missed the Linux gate — 2026-11-06

The second Silph-entry peek run, same probe and end state as the baselines,
peaked at **572.207 MiB** VmHWM (`linux-silph-entry-peek-2`). With peek-1 at
571.262 MiB, both are above the 520.070 MiB bar (about 1.0 and 1.1 percent
under 577.855). The peek was reverted and is not in the tree. The cabin pilot
was not relaunched.

## Earned bundle and Linux Silph-entry baseline — 2026-11-06

`check_bundle.py` on the supplied bundle: artifact hashes PASS, 188 evidence
files. `--project` against a clean full-history checkout at
`4b93ff24d8fec06021be1f72c5950d6d7ea7c5bd`: three imports succeed, 188 mapped
dependencies, no SDK launch. Squirtle slots are `6a20c09e…` and `00f2d64b…`
with completed step only `saffron-guard-entry`. Bulbasaur and Charmander import
with empty completed steps. Creating `/Users/burbujamc/...` was permission
denied, so the files were not hydrated there and no frozen hash was rewritten.
`POKEMON_EVIDENCE_MIRROR` redirects only that namespace for reads.

The short Silph-entry probe (30 steps, 80 actions, 12 transitions, cabin
marker) stops on `parcel journey exceeded semantic action bound` at
`pokered:SILPH_CO_1F`, stage `done`, player `(8, 11)` down. Linux VmHWM, not
Mac phys_footprint: **577.332 MiB** and **577.855 MiB**. The 10 percent bar for
the higher baseline is **520.070 MiB**. The same path-only await peek, measured
on this probe, reached the same end state at 571.262 MiB, 1.14 percent under.
Reverted. The 1 GiB Linux VmHWM stop did not trip. The cabin pilot was not
relaunched. Evidence:
`linux-silph-entry-baseline-1`, `linux-silph-entry-baseline-2`, and
`linux-silph-entry-peek-1` under
`~/Developer/Pokemon-PlayDate-env/evidence/`.

## Await snapshot peek rejected — 2026-11-06

`await` and `assert` built a full diagnostic snapshot on every waiting frame.
A path-only peek kept command-completion and periodic snapshots unchanged.
This is not the Mac Silph-entry probe and does not use phys_footprint. The
labelled Linux scenario skipped the intro, saved from Red's room, and stopped
on a ready save dialog: `reds_house_2f`, stage `done`, player `(5, 3)` up,
save published. Journey-profile VmHWM baselines were 241.664 MiB and
242.465 MiB. The 10 percent bar for that higher baseline is 218.219 MiB.
The peek run reached the same end state at 240.105 MiB, 0.97 percent under.
Reverted. A non-journey build that snapshots every frame climbed to 4.08 GiB
and is not an adoption measurement. The cabin pilot was not relaunched.
Evidence outside Git:
`linux-save-await-journey-baseline-1`, `linux-save-await-journey-baseline-2`,
and `linux-save-await-journey-peek-1` under
`~/Developer/Pokemon-PlayDate-env/evidence/`.

## Save index hold rejected — 2026-11-05

The Save path decodes the same five sprite indexes on each validator pass.
A counter on one Silph-entry Save saw 2,722 primitive tables and 157 KB of
JSON, so the native jump is not those session copies. Holding each immutable
index for the load, and still reading it through the original check, reached
Silph 1F at (8, 11), stage done, and stopped on the action bound on both
runs. The Save published. Peaks were 461.4 MiB and 477.9 MiB against the
468.1 MiB baseline. Neither clears 10 percent. Reverted. The cabin pilot was
not relaunched. `SaveBuildPolicy` is unchanged. Evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-indexhold-1-20261105`
and `c-silph-indexhold-2-20261105`.

## Static-load presents rejected — 2026-11-05

A paused split of the admitted elevator Save put about 41 MiB on slot
inspect, 15 MiB on the new envelope, and 26 MiB on readback. Lua stayed near
8 MiB. Those sections were yielding a full simulator frame about every 30 ms.
The candidate still drew the first static card and still ran the door fade,
then collected without presenting again. The Save itself dropped from roughly
14 yields to zero and finished in 113 ms. The same 30-step run reached Silph
1F at (8, 11), stage done, and stopped on the action bound. Peak footprint
was 476.0 MiB against the 468.1 MiB baseline, about 2 percent higher.
Reverted. The cabin pilot was not relaunched. Evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-noyield-1-20261105`.
The split trace is outside Git at
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-save-split-20261105`.

## Static loading redraw rejected — 2026-11-05

Malloc history on the Silph-entry path still shows the live game cost in Lua
table growth (`luaH_resize` / `luaH_new` through `pd_realloc`). A phase trace
of the admitted elevator Save put the native jump on the Save yields: Lua
stayed at 7.3–8.6 MiB while inspect, envelope, and readback each yielded.
The candidate kept the door-fade callback on every slice and skipped only a
repeat of the default loading card when its label had not changed. The same
30-step run reached Silph 1F at (8, 11), stage done, and stopped on the
action bound. Peak footprint was 466.2 MiB against the 468.1 MiB baseline,
0.4 percent. Reverted. The cabin pilot was not relaunched. Evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-loadingskip-1-20261105`.

## Shared imagetable rejected — 2026-11-05

Malloc samples on this path still center on Lua table allocation
(`luaH_resize` / `luaH_new` through `pd_realloc`), not on the rejected
per-frame intro and travel copies. The new candidate kept one imagetable per
tile registry, dropped the previous view's table, and collected before
allocating the next palette so two full palettes would not be live together.
The same 30-step Silph-entry run reached Silph 1F at (8, 11), stage done, and
stopped on the action bound. Peak footprint was 482.9 MiB against the 468.1
MiB baseline, about 3 percent higher. Reverted. The cabin pilot was not
relaunched. Evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-imagetable-1-20261105`.

## Per-frame copy cut rejected — 2026-11-05

The Silph-entry trace showed most top-level primitive copies were `getIntro()`
inside every settled-world hook and `fieldTravelData()` on sprite updates.
Movement also deep-copied terrain only to read `foot_tile`. Those reads became
scalar accessors. A surf-image check still named the removed travel table, so
the first measurement never left Pallet Town (247.5 MiB, not comparable). After
that fix, the same 30-step path reached Silph 1F at (8, 11), stage done, and
stopped on the existing action bound. Peak footprint was 459.6 MiB against the
468.1 MiB baseline, 1.8 percent. Under the 10 percent bar, so the accessors
were reverted. The cabin pilot was not relaunched. Evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-copycut-2-20261105`.

## Silph-entry copy profile — 2026-11-05

A bounded Silph-entry run of the admitted elevator Save (30 steps, 80 actions,
stop on the existing action bound at Silph 1F) counted the copies that survive
a malloc-log clear. Counters were removed afterward; they are not a behavior
change. The run is outside Git at
`~/Developer/Pokemon-PlayDate-env/evidence/c-silph-alloc-profile-20261105`.

Ninety-nine diagnostic snapshots copied 24,359 primitive tables and 154,412
keys. Pokemon projections ran 675 times. Zone deep-copy ran 472 times, map
descriptors 3 times, and the save payload was decoded 4 times plus 4 mutation
copies. The tile-grid cache was not used (0 loads). Source maps already share
compact terrain, so per-cell terrain duplication is not this path. The earlier
`table.create` preallocation of these primitive copies remains rejected at
9.7/9.1 percent. No new candidate cleared the 10 percent bar, and the unchanged
cabin pilot was not relaunched.

## Cabin pilot stopped at 1 GiB — 2026-11-05

The admitted Squirtle elevator Save (marker
`2204733359f2332c9dd844742cd4d15f457692b880df268e4802ccb15917931b`) was resumed
with the existing guarded runner and history helper. A launch whose output path
lived under `/var` never played: Python records the bundle as `/private/var/...`
and the helper compares Swift's `/var/...` path, so it refused the journey pin.
The same bytes under `/Users/.../evidence/c-cabin-pilot-20261105-03` passed
that pin, cleared once at startup, and reached Silph 1F at (8, 1). The next
pre-Save clear refused because the Malloc Log window was gone. That run is not
a 1 GiB result.

`evidence/c-cabin-pilot-20261105-04` kept the window open. Ten clears
succeeded, including drops from 351 MiB to 140 MiB and from 708 MiB to 418
MiB. Later clears stopped releasing memory and left a floor near 378 MiB. The
player saved through Saffron and Silph 1F, entered Silph 5F, and won the
Scientist at `SILPH_CO_5F:objects:3` (payout 1,300). The following 5F battle
at (9, 16) crossed the 1 GiB host stop before another clear:
`owned Simulator exceeds 1 GiB host footprint`. Six hundred thirty-eight
command results were recorded. The only completed step is still
`saffron-guard-entry`. Card Key, the rival, Giovanni, Lapras, Sabrina, the
Dojo, and Fly did not finish, and the Continue process did not start. This
pilot is not relaunched unchanged. `SaveBuildPolicy`, the 1 GiB stop, and the
16 MiB pool are unchanged. No Playdate port is present on Macintosh. C is not
merged.

## Silph-entry allocation and cabin import — 2026-11-05

The same bounded Silph-entry probe (cabin marker, 30 steps, 80 actions, stop
on the existing action bound at `SILPH_CO_ELEVATOR` then `SILPH_CO_1F`) peaked
at 468.1 MiB and 467.4 MiB on two consecutive runs. Lua heap stayed near 7.5
MiB. A journey-trace slim that still kept full command-result snapshots reached
the same floor and raised the peak to 482.5 MiB and 483.2 MiB. Preallocating
deep copies with `table.create` and dropping the second save-payload JSON
decode reached the same floor at 422.5 MiB and 425.4 MiB, 9.7% and 9.1% under
the 468.1 MiB baseline. Both are under the 10% bar, so both were reverted and
stay rejected with packed terrain, atlas enablement and door tier. The 1 GiB repeated-request/Save ceiling is unchanged.
`SaveBuildPolicy` still disables owner exports whenever `HarnessBuild` exists;
changing that, the guard or the pool needs an explicit decision. The later
cabin pilot is recorded above; it is not a reason to rerun this allocation miss.

The strict importer accepts the pilot12 cabin marker
`2204733359f2332c9dd844742cd4d15f457692b880df268e4802ccb15917931b`, slots
`6a20c09e…` and `00f2d64b…`, the stopped producer (failed-exited, code -9),
eight-step accepted-B ancestry, location `SILPH_CO_ELEVATOR` (7, 1, right),
persisted floor 1, and completed step only `saffron-guard-entry`. It rejects
the newer Silph 1F marker `80617002…` because later Saves overwrote the archived
slots. No Playdate port is present on Macintosh (`/dev/cu.usbmodemPD*` absent).
C is not merged. Earned journeys, restarts, visuals, hardware and latency stay
open.

## Selected-slot receipt rechecked — 2026-11-05

Native `contracts saffron-guards` was run twice on the isolated C tip after
`b530f2ff` and the Vermilion pin `28b60105`. The suite now also canonicalizes
an unequal trusted boundary from the selected-slot bytes, so later play cannot
become that receipt. Both runs passed 111/111 with zero failures, including
all eleven elevator floors, both cabin exits, persisted-floor projection and
unknown-floor rollback. The earlier 110-pass report does not cover these
bytes. C is still unaccepted: allocation, earned journeys, restarts, visuals,
hardware and latency remain open. Both runs are outside Git at
`~/Developer/Pokemon-PlayDate-env/evidence/c-actor-validation-native-saffron-guards-20261105-06`.
Inherited full-host failures were not relabeled.

## C actor-validation correction — 2026-11-05

The reviewed Macintosh C migration had three defects: hidden saved actor
records skipped structural/value validation, the session retention boundary
could accept arbitrary actor deletion, and the diagnostic could report unequal
actor payloads as equal. They are corrected on the isolated C branch
`pi/c-actor-validation-fix` (correction `6fe0357c`, merged reviewed main
`8306f79b` as `2f5bba22`). Every known saved actor is now fully validated before
a bounded visibility drop; only a removal independently proven hidden by a fresh
source descriptor/flags survives, with survivors value-identical; literal
equality and the proven migration are separate, and raw selected-slot payload/
sequence stay distinct from the canonical state. The preserved Fuji visibility
and elevator fixes are unchanged.

Review of that correction found two receipt holes. The host checker read
`worldMotion.actors` as the actor list, but SessionCodec stores the
envelope there and the list at `worldMotion.actors.actors`, so every
genuine migration was rejected. It now compares that envelope and rejects
a flat list, a zone or revision change, a survivor edit, a bad count, and
an extra field. The dev Save/Continue observation also treated a later
`game.session` encode as the canonical form of the selected slot. A
literal match still skips the second decode. Any other payload is
canonicalized from those bytes, so later play cannot become the receipt.
Host receipt tests cover the nested migration. Native `saffron-guards`
was not re-run. C remains unaccepted and is not merged to main.

That receipt change left the Vermilion owner projection pinning the previous
`dev/diagnostics.lua` bytes, so `validate_projection` rejected this tree. The
projection was regenerated. Only that source pin changed, to
`37d98254f8f991958cf9aec7b03568bb37fe6710781477ede6b98a5195500a30`. Historical
validation manifests stay as recorded. This refresh is not C acceptance, and
native `saffron-guards` was not re-run for it.

Fresh actual SDK 3.1.2 export refreshed both dependency pin maps (only
`domain/gameSession.lua` changed); production compiles. Native
`contracts saffron-guards` passes 110/110, now covering malformed hidden records,
custom-validator deletion/addition/mutation, stale flags, all eleven elevator
floors, both exits and unknown-floor rollback. The post-merge host suite runs
1,157 tests with 40 pre-existing C projection/pin/environment failures and **0
new** versus unmodified `03c1bae4`; regenerating the Cerulean and Vermilion
projections fixed two of the former 42. Main remains B149 and C remains
unaccepted.

Two genuine cabin pilots from the frozen pilot12 marker still trip the unchanged
1 GiB host ceiling during repeated route requests/Saves; both failures are
retained. Bounded probes put Continue near 318 MiB and Silph 1F entry near
547 MiB, so the earlier ~900 MB boot figure is not reproduced. Lua heap stays
near 8 MiB while native `Malloc Small` grows. A trusted-boundary observation
change removed a repeated SaveStore deep validation at the dev boundary and
reduced the measured Saffron-walk peak 701→611 MiB (12.8%) with the owner deep
path unchanged. The harness still selects the deep Save path because
`SaveBuildPolicy` disables owner exports whenever `HarnessBuild` exists; changing
that, the guard or the pool needs an explicit user decision. No more pilot
retries were made. The failed pilot's Silph 1F marker is preserved but rejected
by the strict importer because later transit saves overwrote its archived slots.
[Exact correction evidence and scope](../../tools/integration/checkpoint-c/actor-validation-correction-20261105.json).

## C actor-validation review — 2026-11-05

The user asked to review the isolated correction, adjust it, and push. The
branch `pi/c-actor-validation-fix` is `28b60105`. Hidden-actor validation, the
retention boundary, and the Fuji/elevator fixes stay. `b530f2ff` fixes two
receipt holes: the host checker reads the nested `worldMotion.actors` envelope,
and an unequal dev Save/Continue observation is canonicalized from the
selected-slot bytes rather than a later live session. Host receipt tests pass.
`28b60105` refreshes the Vermilion owner pin for `dev/diagnostics.lua`, which
still named the pre-edit bytes. Native `saffron-guards` was not re-run for
either follow-up.

C remains unaccepted. Main is not fast-forwarded to the branch. Earned
completion, restarts, visuals, hardware, memory and latency gates remain open.
The corrected branch is the pushed C line. Main stays 149 maps.

## Macintosh work reviewed and safe subset integrated — 2026-11-04

The user explicitly requested reviewing the Macintosh session and pushing what
is safe to main. The fetched C branch is `origin/pi/checkpoint-c-host-preparation`
at `03c1bae4`, six commits beyond the previous C tip `1464d1a2`. At review it was
44 commits ahead of the merge-base; main `ff598ced` was 9 ahead. C171 is not accepted
and is not merged wholesale. Source-backed Fuji visibility, elevator confirmation
and cabin projection are useful progress, but both independent reviews found
validation defects in the actor compatibility migration and diagnostic equality
exception. Those remain isolated and require correction/native qualification.
[Separate Standards and Spec findings](../reviews/macintosh-c-20261104.md).

Main component `598f64d2` ports only bounded named-contract dispatch and suite-aware
catalog/field evidence classification. Default aggregate order/common cases remain;
unknown suite rejection occurs before RNG-mutating tests. Production B runtime,
data, art, save owners and qualification pins are unchanged; main stays 149 maps.
The helper/acknowledgement hunk is not independently portable because main has no
matching JourneyHistory owner, so it remains on C. The coverage review preserves
all 1,512 rows/facets/proof hashes and prior snapshot history; only current Source
identification advances for the two development Lua changes.

Fresh validation: **1,171/1,171 full host tests pass**, no errors/skips; 32 targeted
checks and 4 coverage checks pass. A guarded thin API probe passes 21 selected and
22 aggregate cases (the 20 original common cases execute twice plus dispatch
sentinels), including unknown-suite/RNG preservation. This is not a full harness
or C journey pass. The ordinary full-contract B probe exceeded 1 GiB and remains
a retained failure; it is a different profile from the B/C journey comparison.
[Exact component scope](main-named-contracts-20261104.json),
[final host result](main-named-contracts-host-20261104.json).

The latest genuine C frontier is pilot12's stopped Silph elevator Save at (7,1,right),
floor 1, marker 22047333..., only saffron-guard-entry complete. It is on Macintosh;
the new prompt/scenario binds those exact slots and ancestry instead of older
record16. No DiveMac Playdate USB port was present at review; hardware work needs
the device reconnected. Source/host work continues independently. No guard, pool,
trust fence or acceptance threshold changes.
[Current continuation prompt](../handoffs/continuation-after-macintosh-review-20261104.md).

The earlier takeover details below remain historical and are superseded above
where the branch tip, frontier, local setup or next action has advanced.

## Macintosh takeover — 2026-11-04

The user requested pushing current accepted main and a complete handover to
Macintosh. Accepted game/validation tip `75eca5d9` and the reviewed cold-archive
allowlist commit `96b53554` were fast-forward pushed. This handover adds no game
Source changes and does not adopt C or the selected-slot/Telekinesis candidates.
[Takeover prompt and exact frontier](../handoffs/macintosh-20261104.md).

Main remains B149 accepted with the existing label. Isolated C is at `1464d1a2`.
Its last Squirtle attempt completed a genuine Saffron guard-entry Save, then
failed at the unchanged64-Clear cap while routing around a source-confirmed
Saffron actor-visibility bug. No complete C journey or new hardware result is
claimed. Reviewer steer8's30-door production-GC route remains unexecuted.
The November4 process audit found no live SDK/journey/device/archive operation.

Both requested superseded Brock failure roots are now archived, fully rehearsed
and locally released; exact receipts and restoration references are in the
handover. Their logical total is8.46GiB, not an isolated free-space delta.
Actual DiveMac free space at the audit was about95GiB. No current earned input
or positive acceptance proof was discarded. Macintosh receives a private all-ref
bundle and dirty-work snapshots separately; raw external evidence stays on
DiveMac/Pi until exact-path hydration is required. The outgoing agent starts no
new campaign during the ownership transfer. All prior scope/latency limits below
continue to apply.

The user then requested an independent handover challenge. One Sol/medium advisor
found two P2 portability gaps and one P3 persistence clarification, no standards
findings. Root supplied the missing pinned reference/cache/environment setup,
an exact188-file frozen seed-dependency closure, and a new scenario bound to
latest C record16. An isolated recovery drill on Macintosh recovers all selected
branch tips and passes the unchanged strict importer for all three starters,
including Squirtle's exact Saffron slots. Goal/task state is explicitly not
transferred; the prompt supplies a fresh local goal instruction. No gameplay
Source changed or runtime started. Runtime/desktop/hardware and C acceptance
remain separate pending gates.
[Review findings, resolutions and actual drill](../handoffs/macintosh-readiness-review-20261104.json).

## What a player can do

Checkpoint B is accepted and merged: Tower/Fuji/Flute, both Snorlax routes,
Bicycle/Cycling Road, rods/fishing, Fuchsia/Koga, Safari, Surf and Strength.
**Simulator-accepted and hardware-safe; device latency targets not yet met.**
All three genuine A→B routes and two-process restarts passed in their retained
source scope. Later fixes have targeted proofs, not a new whole-route replay.
[Acceptance and original hashes](midgame-b-acceptance-20261102.json).

B game code merged as `af9a8938`. Current main adds the reviewed catalogue-query
memory fix `9ba63d68`; historical B acceptance and package retain their original
build identities. The production code matches the measured memory candidate;
only a generated development-fixture dependency hash changed afterward.
Substitute is integrated as`056fe922`:299native executions, six rendering cases,
a native component motion clip and physicalgame smoke pass in their stated scope.
[Substitute proof and limits](substitute-component-adoption-20261102.json).
The six canonical B slot byte strings are unchanged. [Chain identities](chain-saves.json).

The B merge passed 1,152 host tests and 57 protocol tests. After the memory merge,
1,152 host tests ran: 1,149 passed and three stale metadata checks failed. The
projection changed only its reviewed terrain-owner hash; all 64 targeted
metadata checks then passed. Protocol checks pass 57/57 and literal production
`make compile` passes with SDK 3.1.2. No second full-suite run is claimed.

Current main after Save inspection reuse and metadata reconciliation passes the
full **1,169/1,169 host suite**. The earlier six failures were projection digests,
accepted-code preservation pins and the current Source coverage snapshot; their
failed run is retained. Semantic projections, protected assets and all original
coverage proof hashes remain unchanged. No new campaign or hardware acceptance
is inferred. [Exact host result](main-host-after-save-20261102.json).

B acceptance took 73.075 elapsed hours from the first 149-map packet: about
13.466 added maps/day, including tooling, latency work and waits.

## Visual and package evidence

The native 400×240 silent showcase is 86.161 seconds at original speed, with
four explicit cuts: walking, a complete three-Pokémon Fisherman victory,
Snorlax's wake/encounter/removal, and Koga's dialogue/intro/first turn. Koga is
an excerpt, not a new full-victory claim. Root inspected native/decoded samples
and source sequences; all 1,420 decoded frames and timestamps are preserved.
[Showcase](b149-showcase-final-20261102.json).

The historical accepted package contains a production PDX, three earned save
pairs, clip, one-line instructions and known limits. It predates the memory fix
and was not physically timed as an exact normal-production package. User play
feedback is unavailable now and does not block work. The current production PDX
is at `evidence/main-terrain-query-production-20261102-01/PokemonBlue.pdx` outside Git.

The 2,494 protected images retain their accepted pixels/alpha/masks. Existing
41-map spawn views and 82 overlays remain historical visual proof. No full
mechanics fidelity is inferred from green routes or unchanged art.

## Current memory fix and physical observation

`SourceMaps.terrain` returns detached metadata. Field travel stops retaining a
whole catalogue; Vermilion membership uses `hasTile`. Primitive validation and
rollback remain. The fixture lookup follows active record scopes deliberately.
Actual SDK exports preserve transformed values and prior provenance. Nine
selected native cases pass: query isolation, Surf, Fly, rollback, Save/Continue
and Vermilion scene transactions. Combined review has no actionable findings.
[Adoption, exact reports and limitations](terrain-query-memory-adoption-20261102.json).

The accepted baseline reaches the 9 MiB Simulator guard at `Save.publish.end`
on the earned Surf/save route. It was not admitted to hardware. The candidate
completes the same route, including the actual surfing save at Fuchsia `(31,21)`
with 15 Surf PP and a natural Old Rod battle. Safety: 50.176 ms maximum slice,
8.53 MiB sampled Lua peak, 16 MiB pool, no runtime error. The strict Simulator
live-heap budget still fails; this is measurement admission only.

Physical build `ef35f457052b46dcbf9fffa8be447e6c`: no new logs, sampled Lua peak
**6.12 MiB**, post-GC samples **4.64–5.04 MiB**. Keeper inventory was verified and
run acknowledged; its screen was not directly observed. No paired device saving
is claimed because the baseline cannot safely run this route.

| Phase | Device wall | Target | Scope/result |
| --- | ---: | ---: | --- |
| App start → title accepts A | 13.191 s | ≤10 s | Fails; includes 0.876 s diagnostic GC |
| Maximum boot slice | 1.451 s | ≤1 s | Fails |
| Continue | 3.279 s | ≤4 s | Passes this run |
| Save in Center | 1.820 s | ≤2 s | Passes this run |
| Save while Surfing | 3.317 s | ≤2 s | Fails; no paired regression established |
| Fuchsia entry | 4.478 s | ≤1.5 s | Fails |
| Good Rod house / Fuchsia return | 1.664 / 2.435 s | ≤1.5 s | Fail |
| Fishing battle start | 22 ms | ≤1 s | Passes this run |
| Cave walking p95 | Unmeasured | ≤50 ms | Open |

This profile retains default diagnostic full collections and normal soft GC.
Shipped-equivalent timing is unmeasured; do not silently subtract GC. Lua counts
exclude native/transient allocations. The route covers Fuchsia and its rod house,
not all heavy B maps or C's working margin.

The earlier physical long traversal passed 110 doors, 30 maps and 20 wild battles
over 87.44 minutes: 136 post-GC samples, maximum 5.151 MiB, raw peak 6.341 MiB,
no new logs. It is scoped historical resource proof, not current latency.
[Traversal](b149-physical-long-traversal-20261101.json). Idle soak and native image
point probes retain their separate scope.

## Next work and open gates

1. Current physical memory samples now cover Game Corner and Hideout B1F–B4F,
   about 5 MiB collected live with 6.13 MiB sampled peak. Safari Center, East,
   North and West now measure 5.03–5.08 MiB post-GC with the same 6.13 MiB peak;
   seven natural encounters use ordinary RUN. Tower 1F–7F now measures
   4.77–4.84 MiB post-GC, with 6.11 MiB sampled peak and six actual encounters.
   Tower uses the genuine earlier post-Fuji Save, not a fabricated late-B save.
   [Tower samples](tower-memory-20261102.json).
   [Safari samples and retained failures](safari-memory-20261102.json). The current fishing-battle point probe holds eight requested 256 KiB
   native images on hardware, then releases them; allocation plus two collections
   takes 1.243 s. This diagnostic-GC route is not the full C margin.
   [Native point probe](native-headroom-current149-20261102.json).
   Spinner query merge `1860b3c0` reduces ordinary B3 active p95 from 148 to
   39 ms in one hardware comparison; 61 native checks and 24 merged host checks
   pass, with no review findings. Three roughly two-second hitches remain.
   [Scoped adoption](spinner-query-adoption-20261102.json). Audio remains held.
   [Heavy-map samples and hitch scope](heavy-b-memory-20261102.json).
2. Substitute is adopted. The composed host suite ran1,169tests with four
   metadata/art-reference failures;110targeted branch checks and120merged checks
   pass after correction.57protocol checks and productioncompile pass. Current
   shared-owner evidence is rebound only where unchanged assertions reran;
   HelpingHand/Dig stay stale, and no full-mechanics completion is inferred.
3. C's isolated candidate is now wired and SDK-qualified at `5ae77a61` in
   `t3/checkpoint-c-host-preparation`. Main stays 149 maps; candidate has 171.
   Source-derived metadata handles two inert Silph declarations and 13 scripted
   elevator IDs without changing B's 510 classifications. Actual thin SDK export
   preserves Kanto/East/South values and produces Saffron's 30 transformed events
   and 45 trainers; sampled host peak is 194 MiB. Qualified production compile
   passes. Native floor/elevator checks, earned journeys and C's own hardware,
   memory, latency and visual gates remain open. The guarded full-harness export
   stopped at 1 GiB and was replaced, not continued. B memory no longer blocks C
   activation, per reviewer steer 7. Existing earned boundaries remain strict.
   [C ancestry proof](checkpoint-c-restored-ancestry-20261102.json).
4. Controlled four-Save measurement separates ordinal from the earlier mixed
   comparison: Center #1/#2 take 1.947/2.867 s; Fuchsia Surf #1/#2 take
   2.288/3.529 s. Inspection rises 361→1,334 ms and 375→1,600 ms; writes/readbacks
   are nearly flat. Whole-phase marks are private, not a production change.
   Cross-map still combines map, travel and mode; no isolated Surf effect claimed.
   [Actual attribution](save-four-point-attribution-20261102.json).
   A SAVE-only inspection-proof candidate now measures repeated Center Save
   2.867→2.020 s and repeated Surf Save 3.529→2.426 s, 29.5/31.3% faster.
   First Saves are 2.5/3.5% slower. Public loads retain deep validation; 23
   selected native persistence cases pass. Both exact safety routes admit device
   measurement; hardware peak is about 6.14 MiB with unchanged system logs.
   Adopted as `1ffd6fa7` after one combined review with zero findings. All 47
   selected merged host/build checks and production compilation pass; the three
   changed Source files equal the measured candidate. Surf still misses 2 s.
   [Measured candidate and scope](save-inspection-reuse-measured-20261102.json).
5. Matched hardware observations now cover all three canonical B saves, with
   identical code/SDK/compiler and only private build identity differing:
   selected envelopes 21,533/22,650/24,316 bytes; title preparation
   4.589/4.687/4.981 s; input-ready boot 13.325/13.548/13.774 s;
   Continue 3.293/3.360/3.463 s. Store inspection takes 2.419/2.482/2.635 s.
   Default title diagnostic GC is 0.876/0.899/0.968 s; shipped-equivalent timing
   remains unmeasured. Party, PC and flags vary together, so PC causality is not
   isolated. All three exceed boot/slice targets; Continue meets 4 s.
   [Three-save phases and exact proof](boot-three-earned-saves-20261102.json).
   Fix structural door/boot/cave costs. Deferred `import()` splitting is closed:
   SDK 3.1.2 prohibits imports outside PDZ loading; no candidate was created. Do not
   restart the census. The user explicitly allows the existing guarded history
   helper for ordinary C journeys. Its archive-fence correction passes host
   checks, but native qualification remains open: opening the profiler window
   itself can cross the unchanged 1 GiB host guard before Clear. A reviewed
   ready-title pause now proves actual Clear and 67 ordinary requests through
   Route 15, but stops at the unchanged 64-Clear limit: the cleared UI footprint
   exceeds the 512 MiB trigger. Closing the window did not release headroom and
   is rejected. The user approved changing only the soft Clear trigger to
   736 MiB; 36 focused host checks pass and a fresh single-Squirtle pilot is
   running. The 1 GiB hard stop, 16 MiB pool, 64-Clear/131-call caps and other
   limits remain unchanged. No complete C journey is inferred from the earlier
   short qualification.

Compact SMC1 terrain-row consumption is also rejected after native correctness
passes but no whole-phase hardware gain: Fuchsia 4.451→4.507 s, memory unchanged.
Four map cases, one WorldView rollback and nine activation cases pass; no review
or adoption follows. [Measured rejection](packed-terrain-rejected-20261102.json).

The six-set atlas enablement candidate is rejected after matched hardware.
Game Corner load was 3.889→3.933 s; B3 load 1.886→1.907 s, with three >1 s
frames still present. Tower's best floor improvement was 3.0%. Native pixels
passed all 727 keys/20 tables, but no target met the 10% performance rule.
No review, adoption or additional proof work is requested for this candidate.
[Measured rejection](atlas-enable-rejected-20261102.json).

The door-tier candidate remains rejected: primary cold-entry gains were only
3.1% Fuchsia, 8.4% Route17 and 7.8% GameCorner, with Save 11.3% slower. Its
qualified native modes passed 14/14 each, but no further cycle/review is requested.
[Rejected measurement](door-tier-rejected-20261102.json).

The 499-step Safari expiry fixture currently exceeds the 1 GiB host allocation
history limit; no fresh pass is claimed. Its original accepted proof remains.
Other targeted tests ran in fresh processes with their assertions intact. User
resolved desktop dialogs and opened Screen Sharing; native startup works again.
Paired DiveMac-node desktop observation is verified; gateway status alone is not
node availability. No unrelated applications were killed.

## Operating decisions

User disk policy: **30 GiB reserve / 31 GiB new-runtime admission**. Local
maintenance runs at 30→50 GiB. Keep the SDK 3.1.2 pool at 16 MiB, host limit at
1 GiB, Lua guards at 6/8/9 MiB, and ordered ownership locks. All runtime/USB
readers are closed after both measured routes; verified keeper is restored.
Storage is background, exception-only. No current/earned input is discarded.
[Verified census retention](capacity-census04-retention-20261102.json),
[earlier recovery](capacity-census-retention-complete-20261102.json).

Coverage retains all 1,512 rows, facets and historical proof hashes. The current
snapshot was reviewed separately; no fidelity or acceptance level was promoted.
[Previous ledger/history](progress-history-before-b-acceptance-20261102.md).
