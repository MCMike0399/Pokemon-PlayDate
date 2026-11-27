# Postgame scratch

## Lane E tip 79fbcba5, no local patches

`origin/cursor/lane-e-integration` `79fbcba560e34945a130d7e1788ab44be5aa8d77` already contains the Hall release `68fc1f80` and the switchZone release `95554e07`. It does not import `game/postgameStory` at boot. `loadHallContinue` in `Source/game/saves.lua` runs the standalone `game/postgameStory.pdz` only when the save has a Hall team, then calls `PostgameStory.relocateContinue` before `installSession`. A literal boot import is what that tip removed, because it kept the story table on every boot and OOM'd the Hall continue. `tools/notes/lane-e-hof-postgame-import.patch` would put that import back.

Scratch worktree `/tmp/e-continue`, detached at that commit, no patches. SDK 3.1.2. `MallocPoolSize` stayed `16645684`. The bundle contains `game/postgameStory.pdz`. Hall save `tools/tests/fixtures/lane-h-hall-continue-8e72131f.json`. Same Continue buttons as `tools/tests/test_lane_e_hof_continue_releases_hall.py`. `--recent-interval 18000`. One fresh Simulator process.

Continue reaches Pallet. Root `overworld`, zone `kanto_pallet_town`, (5, 6) facing down. The harness result status is ok. Ready heap 12715.5 KiB. Snapshot heap after Continue 13305.3 KiB. `Continue.end` is 13067.8 KiB. Observed peak on that boot is 13744.7 KiB, at `Continue.map.end`. The simulator log has no inflate failure and no out-of-memory error. The continue is not stuck at Hall (7, 2). No new patch.

`tools/notes/lane-e-hof-postgame-import.patch` is the real diff of that boot import against origin/main, with `tools/tests/test_lane_e_hof_postgame_import.py`. It fails on main and passes after `git apply`. Do not apply it on `79fbcba5`.

## Earlier scratch on origin/main

Evidence only. The scratch worktree is `/tmp/postgame-scratch`, detached at origin/main `ea32b55388038021812142a69b107f035b7c1da3`. It has `tools/notes/lane-e-hof-continue-release.patch` applied, and then the literal imports from `tools/notes/lane-e-hof-postgame-import.patch`. Those Source edits are not committed. K's `lane-e-switchzone-release-before-build.patch` is not applied. SDK 3.1.2. `MallocPoolSize` stayed `16645684`. Wild encounters were off. Trainer sight stayed on. Saves were the Hall fixture `tools/tests/fixtures/lane-h-hall-continue-8e72131f.json`, sha256 `8e72131fa1b88f59d3192a82a2e2d3da856ccf3b725b6860ccc69dcbc95d1cc1`.

origin/main at this measurement does not contain `PostgameStory.releaseContinueData`. The same path on unmodified main is waiting until that release is on main.

Heap is `collectgarbage("count")` from the snapshot (`performance.heap_kib`) and from `boot-trace.tsv` (`heap_kib`, then `observed_peak_kib`). The trace peak only moves when a mark is written.

## Hall continue

Buttons are the Continue list in `tools/tests/test_lane_e_hof_continue_releases_hall.py`.

On origin/main plus the release patch, with `lateKantoStory.lua` still calling `importer "game/postgameStory"`, the continue stays in the Hall. Session `13e413937e7984ba79e596cf5106a6a9`. The harness assertion was `zone expected kanto_pallet_town got kanto_hall_of_fame`. The player was at (7, 2) facing up, root `overworld`, snapshot heap 13158.7 KiB. `Continue.context.install` ran. No `Continue.wrap` or `Continue.relocate` mark ran. `Continue.end` was 13206.6 KiB, observed peak 13206.6 KiB. `PostgameStory.boot` never installed the continue wrap, so `relocateContinue` never moved the save to Pallet (5, 6) down.

`import` in that file is a local call inside `if type(importer) == "function"`. pdc records the module name and does not run the chunk. `PostgameStory` stays nil, and `main.lua`'s later `PostgameStory.ensureRuntime()` is skipped. The same variable call is how `fossilRevival` is loaded.

Replacing both calls with literal `import` statements, still on top of the release patch, sends the same buttons to Pallet. Session `55e38aae6824b2dcb6f04e36f33f81c6`. After the title Continue, the player is in `kanto_pallet_town` at (5, 6) facing down. Snapshot heap 13523.3 KiB. `Continue.end` is 13390.6 KiB. The observed peak on that mark is 14130.8 KiB, from the relocate that builds Pallet while the Hall definition is still live. A one-shot confirm on session `3b20162704472fc02e0db85c4a5a0717` printed `Continue.relocate.ok` and the same Pallet cell, snapshot heap 13524.7 KiB, `Continue.end` 13392.1 KiB, observed peak 14131.5 KiB.

Frame: `artifacts/lane-h/postgame-continue-pallet.png` (sha256 `96b12a29249db38257940ec0e4e94f28f9509a66b4041e1339fc0e606a1b9020`). RED is on the Pallet dirt south of the lab.

That literal import is `tools/notes/lane-e-hof-postgame-import.patch` again, because the Source edit cannot stay on this branch. `79fbcba5` loads the chunk lazily. Applying the patch there puts the boot import back.

## Cerulean Cave access

pokered hides the cave guard `pokered:CERULEAN_CITY:objects:10` when `TOGGLE_CERULEAN_CAVE_GUY` is set, which the Hall of Fame sets. `LateKantoStory.caveEntry` returns `"open"` when that flag is set. The door is city (4, 11), warp to Cerulean Cave 1F.

The Hall fixture has `TOGGLE_CERULEAN_CAVE_GUY` true and `EVENT_GOT_POKEDEX` absent. After the Pallet continue, real steps went Pallet (6, 6) → Route 1 (9, 24) → Route 1 (14, 10) → Viridian (19, 26). The next steps walk onto Viridian (19, 9). `TutorialEscort.trigger` starts the sleepy old man there while the Pokédex flag is false. The scene says "Yawn! I must have dozed off in the sun." and walks RED one tile south. Stepping back onto (19, 9) starts it again. The north road, the forest, Pewter, and Mt. Moon are on the other side of that tile. With the tile closed, the route graph from Pallet reaches Cinnabar by surfing Route 21 and stops at Seafoam. It does not reach Cerulean. The parcel that sets `EVENT_GOT_POKEDEX` is a Viridian Mart gift, and the clerk's counter has no adjacent walkable cell in the route graph, so this continue did not take the dex.

The cave door itself was measured with real `move up` input on the same scratch, before the import edit, from a fixture standing on Cerulean (4, 13) facing up with the champion flag set. Session output `/tmp/cave-probe-out`.

| step | zone | cell | heap KiB |
| --- | --- | --- | ---: |
| fixture | `kanto_cerulean_city` | (4, 13) up | 13379.0 |
| move up | city | (4, 12) up | 13452.0 |
| move up | city | (4, 11) up | 13473.8 |
| move up | `kanto_cerulean_cave_1f` | (24, 16) up | 13806.8 |
| snapshot | cave 1F | (24, 16) up | 13847.6 |

Boot trace: `map.CeruleanCity.zone.end` 13591.6 KiB, `door.begin` 13475.2 KiB, `map.CeruleanCave1F.zone.end` 13835.6 KiB, `door.map.end` 13918.9 KiB, observed peak 13918.9 KiB. No inflate error. The session status was ok. That is under the 14000 KiB zone-end note, so K's switchZone release was not applied.

Frame: `artifacts/lane-h/postgame-cave-1f.png` (sha256 `8f0628bec188486422d3bcdff53c678bbbfef0e825fbf9c2efab82db35303abc`). RED is inside the cave, facing up. The Hall continue never reached this door.

## Mewtwo

Not reached from the Hall continue. The sleepy gate closed the only graph path to `CeruleanCaveB1F`. No encounter started. No battle frame.

`PostgameStory.installEvents` on this main does register `data.cave.mewtwo` once the chunk runs. The chunk does not run until the literal import above. This walk did not get far enough to press A on the static.

## Mew gift

Not reached from the Hall continue. The scientist is Cerulean Cave 1F (23, 16). origin/main's `postgameStory.lua` has no `presentGift`, `giveMew`, or `tryGift`. `tools/notes/lane-e-mew-gift-dispatch.patch` is superseded. `79fbcba5` already registers the gift inside `PostgameStory.installEvents`. The remaining gift diff against main is `tools/notes/lane-e-mew-link-cable-gift.patch`.

## Heap along the continue

Session `55e38aae6824b2dcb6f04e36f33f81c6`, release patch plus literal import.

| point | heap KiB | observed peak KiB |
| --- | ---: | ---: |
| ready | 12806.9 | |
| Continue.end | 13390.6 | 14130.8 |
| Pallet (6, 6) | 13560.5 | 14130.8 |
| Route 1 (9, 24) | 13785.2 | 14130.8 |
| Route 1 (14, 10) | 14149.6 | 14130.8 |
| Viridian (19, 26) | 14089.1 | 14385.4 |
| sleepy dialog, Viridian (19, 9) | 24749.7 | 14385.4 |

The 24749.7 KiB reading is the highest snapshot while the sleepy scene was being retriggered. The boot trace did not mark during that loop, so its observed peak stayed 14385.4 KiB. The process was still answering at 24749.7 KiB when it was stopped. There is no settled reading after the loop ended. Frame: `artifacts/lane-h/postgame-viridian-sleepy.png` (sha256 `f6f54ff4a2692c169aa6454cefcecb0f44cb60dab327236f2ed94bf3deedbb96`).

## Sleepy retrigger heap

The 24749.7 KiB climb is the full harness, not a live retainer in the sleepy scene. On `79fbcba5`, four separate retriggers of Viridian (19, 9) with no major collection:

| request | settled heap KiB |
| --- | ---: |
| cycle 1 | 13225.4 |
| cycle 2 | 13308.3 |
| cycle 3 | 13391.4 |
| cycle 4 | 13474.6 |

About 83 KiB per request. A `collectgarbage("collect")` before `collectgarbage("count")` holds the same scene at 13216–13217 KiB across eight retriggers, and a lone snapshot after that is 13158.9 KiB. Sprites stay at 10. `GameBootstrap` switches to generational collection, and the frame loop only steps once. `Harness.finish` major-collected only when `journey_profile` was set, after `json.encodeToFile` had kept the request graph alive long enough to tenure it.

`tools/notes/lane-e-viridian-sleepy-retrigger-heap.patch` drops that graph and collects on every request. The same four retriggers then read 13225.4, 13243.6, 13244.4, 13244.2 KiB. A snapshot after the fourth request is 13179.7 KiB. Test: `tools/tests/test_lane_e_viridian_sleepy_retrigger_heap.py`, `test_retriggers_stay_near_the_first_heap`. It fails while the collect stays inside the journey-profile branch.

## Hall fixture

No lane B or lane J save in the repo is an endgame file. Lane J's published save is the Route 6 bird continue. The Hall fixture was introduced as raw bytes in `0eed8277`, with no generator. `tools/generate_hall_continue_fixture.py` keeps that envelope, sets the champion flags, and recomputes `SaveStore`'s FNV-1a checksum. The written file is that output.

sha256 `45e3561a263ee2844da599e1862d27b973fae1622d6dd8728b22546c4b94bd8d` (3920 bytes). Checksum `2c16b842`. The previous pin was sha256 `8e72131f…`, checksum `1c43d824`. The bag was empty; the generator also puts one stack of 20 POKé Balls in it so a catch can be thrown. That is not a story flag.

Flags set true, citing the scripts named in the generator: `EVENT_GOT_OAKS_PARCEL`, `EVENT_OAK_GOT_PARCEL`, `EVENT_GOT_POKEDEX` (this is also the awake old man), `EVENT_GOT_TOWN_MAP`, `TOGGLE_CERULEAN_ROCKET`, `EVENT_GOT_SS_TICKET`, `EVENT_MET_BILL`, `EVENT_MET_BILL_2`, `EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING`, `EVENT_GOT_DOME_FOSSIL`, `EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI`, and the eight badges. Brock's trainer id `pokered:PEWTER_GYM:objects:1` is defeated, so the Pewter escort does not block. `EVENT_BEAT_LANCE` stays false because the Hall reset clears that range. `TOGGLE_CERULEAN_CAVE_GUY` was already true.

Test: `tools/tests/test_lane_e_hall_continue_fixture.py`, `test_fixture_matches_the_generator_and_has_the_dex`. `tools/tests/test_lane_e_hof_continue_releases_hall.py` pins the new sha256.

## Walk on 79fbcba5 with the champion fixture

Scratch `/tmp/e-continue` at `79fbcba560e34945a130d7e1788ab44be5aa8d77`, plus `tools/notes/lane-e-viridian-sleepy-retrigger-heap.patch` so the retrigger retain does not pile up on a long session. No boot import. The save is the regenerated Hall fixture. Wild encounters off. Trainer sight on. `MallocPoolSize` stayed `16645684`. No inflate and no out-of-memory line in the simulator log.

Continue lands on Pallet (5, 6) down. Heap 13326.3 KiB. `Continue` observed peak 13737.9 KiB. `EVENT_GOT_POKEDEX` is set, so Viridian (19, 9) does not start the sleepy scene. RED walks through to the forest.

The route graph treats `kind == "item"` as open. The live Antidote ball `pokered:VIRIDIAN_FOREST:objects:5` at (25, 11) is solid. Pressing A takes it. Later trainers who walk onto the path and stay there, such as the Route 3 lass at (20, 4) after her battle, are not on the graph's home cell. The walk stepped around that cell.

| point | heap KiB | observed peak KiB |
| --- | ---: | ---: |
| Continue, Pallet (5, 6) | 13326.3 | 13737.9 |
| Viridian (19, 26) | 13388.0 | 13737.9 |
| Viridian Forest (25, 32) | 13403.4 | 13737.9 |
| Pewter (19, 20) | 13827.1 | 14173.6 |
| Route 3 (1, 9) | 14032.6 | 14264.6 |
| Route 3 after the lass | 13846.3 | 14538.6 |
| Route 4 (12, 9) | 14006.9 | 14538.6 |
| Mt Moon 1F (16, 22) | 14264.3 | 14538.6 |
| Mt Moon 1F (30, 7), battle | 14732.5 | 14809.8 |

The walk stops in the battle with `pokered:MT_MOON_1F:objects:3`. The message is still `Go! BLASTOISE!`, the move menu is open on SURF, and Oddish is still 32/32. Further A input does not select the move. Cerulean Cave, the Mew gift, and Mewtwo are not reached. No new patch for that stall. No frame: the run stops before the cave shots.

## Main continue does not leave the Hall

`git fetch origin main` left `origin/main` at `ea32b55388038021812142a69b107f035b7c1da3`. This branch's `Source/` matches that tree. `GameSaves.continueGame` installs the saved location. It has no `loadHallContinue` and no `PostgameStory.relocateContinue`. The fixture's location is `pokered:HALL_OF_FAME`.

Real input on that Source, same CONTINUE presses as the Hall test, save `tools/tests/fixtures/lane-h-hall-continue-8e72131f.json`. `MallocPoolSize` stayed `16645684`. The simulator log has no inflate and no out-of-memory line.

| point | heap KiB | observed peak KiB |
| --- | ---: | ---: |
| ready | 12711.8 | |
| Continue.end | 13294.4 | 13294.4 |
| settled overworld | 13068.2 | |

The player is still in `kanto_hall_of_fame` at (7, 2) facing up. pokered `data/maps/special_warps.asm` `.PalletTown` is the Hall continue spawn, and this continue never takes it. Cerulean Cave, the Mew gift, and Mewtwo are not reached. Mewtwo remains pokered `data/maps/objects/CeruleanCaveB1F.asm` object 1. Mew is not an object in `data/maps/objects/CeruleanCave1F.asm`.

## Main 93c15d86

`origin/main` is `93c15d86eaa497baa944e39cdc7e364dcc7df739`. This branch merged it. `Source/` matches that tree. `loadHallContinue` still `playdate.file.run`s the postgame chunk and calls `relocateContinue`. No new continue patch. `MallocPoolSize` stayed `16645684`. The simulator log has no inflate line and no out-of-memory line.

Real input, same CONTINUE presses, champion Hall fixture. Wild encounters off. Trainer sight on. One Cerulean Center heal so Struggle does not black out before the cave. The start menu's first row is POKéDEX because `EVENT_GOT_POKEDEX` is set (`draw_start_menu.asm` `DrawStartMenu`). The field SURF sequence presses Down once before POKéMON.

| point | heap KiB | observed peak KiB |
| --- | ---: | ---: |
| ready | 12716.8 | |
| Continue, Pallet (5, 6) down | 13296.0 | 13740.0 |
| Route 1 | 13470.2 | 13740.0 |
| Viridian | 13805.5 | 14276.9 |
| forest south | 13572.7 | 14540.6 |
| Pewter | 14306.4 | 15714.7 |
| Route 3 | 14366.8 | 15714.7 |
| Mt Moon 1F | 14857.0 | 15738.1 |
| Route 4 | 14432.3 | 15738.1 |
| after the Cerulean nurse | 13996.2 | 15738.1 |
| Route 24 | 14640.9 | 16030.4 |
| Cerulean Cave 1F (24, 16) | 14757.6 | 17136.8 |
| gift talk, root event | 14894.7 | 17136.8 |
| still on that event | 46484.3 | 17136.8 |

Continue lands on Pallet (5, 6) down. The cave door opens. The gift talk at Cerulean Cave 1F (24, 16) facing left starts `presentGift` and stays on root `event`. A does not leave it. `EventState:handleInput` only feeds the menu during `heal-confirm`, and `presentGift` shows `MEW` / `LINK CABLE` on that same menu. Mewtwo, `data/maps/objects/CeruleanCaveB1F.asm` object 1, is not reached. The handoff is `tools/notes/lane-e-gift-menu-input.patch` with `tools/tests/test_lane_e_gift_menu_input.py`. The test fails on this tree and passes after `git apply`.

Type names, in a throwaway with the type-display patch and K's file-scope import from `cursor/lane-k-qa` `b20a7aa3`: both `test_lane_e_type_display_names` tests pass, and the Mewtwo TYPE1 row is `PSYCHIC`. On this unpatched tree the row is still `PSYCHIC_TYPE`.

## The 46484 KiB reading

That number is the harness request graph, not a gift-event allocation loop. The stuck walker sent 180 snapshot requests while root stayed `event`. Saved results `01970` through `01983` climb by 175.3 KiB every request, from 44205.6 to 46484.3. `(46484.3 - 14894.7) / 175.3` is 180 requests. `finish()` still major-collects only when `config.journey_profile` is set, so `json.encodeToFile` tenures each request's snapshot. `tools/notes/lane-e-viridian-sleepy-retrigger-heap.patch` already nils those locals and calls `collectgarbage("collect")` on every finish. It still applies on this tree. No second patch.

A fresh Hall continue, then `switchZone` straight to `kanto_cerulean_cave_1f` at (24, 16). `switchZone` is the debug menu's call: `releaseDepartingWorld` drops the retained runtime maps and major-collects twice before the cave is built. `MallocPoolSize` stayed `16645684`. No inflate line.

| request | unpatched KiB | reclaim patch KiB |
| --- | ---: | ---: |
| Continue, Pallet (5, 6) | 13296.7 | 13296.7 |
| fresh cave (24, 16) | 13245.5 | 13245.5 |
| idle snapshot 0 | 13268.5 | 13205.0 |
| idle snapshot 3 | 13327.7 | 13205.4 |
| gift dialog | 13520.2 | 13378.2 |
| dialog snapshot 0 | 13543.1 | 13342.3 |
| dialog snapshot 7 | 13681.3 | 13343.0 |

Unpatched idle and dialog requests each leave about 19.7 KiB. The reclaim patch leaves 0.4 KiB across four idle requests and 0.7 KiB across eight dialog requests. The observed peak stays the Continue peak, 13751 unpatched and 13741 patched. It does not become 17 MB when the cave is the only map loaded.

The long walk's 15714–17136 KiB figures are that boot-trace high-water mark. It never falls. Settled overworld on that walk stayed 14.3–15.1 MB, about 1.5 MB above this fresh cave, after roughly 1800 requests whose graphs were tenured. A battle request itself reached 35002 KiB and the next settled overworld was 14592 KiB. The cave is not holding the maps visited on the way. The fresh cave is 13.2 MB, under the 14 MB Lua budget.

## Gift menu and Mewtwo on the patched scratch

Scratch `/tmp/gift-walk`, not committed. Applied `lane-e-gift-menu-input.patch`, `lane-e-type-display-names.patch`, K's file-scope import from `cursor/lane-k-qa` `da5cfca6` (same diff as `b20a7aa3`), and the harness reclaim patch so the table is not the request graph. Same Continue, then `switchZone` to the cave. The gift talk and the walk down to Mewtwo are real button input. Encounters off. No inflate line.

| point | heap KiB | observed peak KiB |
| --- | ---: | ---: |
| ready | 12724.2 | |
| Continue, Pallet (5, 6) down | 13303.4 | 13747.5 |
| cave 1F (24, 16), before the talk | 13253.0 | 13747.5 |
| MEW chosen, back on the overworld | 13334.7 | 13747.5 |
| LINK CABLE chosen, back on the overworld | 13336.3 | 13747.5 |
| Cerulean Cave 2F | 13304.5 | 13747.5 |
| Cerulean Cave B1F | 13462.5 | 13747.5 |
| beside Mewtwo (26, 13) | 13269.2 | 13747.5 |
| wild Mewtwo, level 70, 229 HP | 13626.4 | 13747.5 |

The menu is `MEW`, `LINK CABLE`, and A selects it. After MEW the party is Blastoise and Mew, `EVENT_GOT_MEW` is true, and root is `overworld`. After LINK CABLE the bag has one `linkCable` beside the 20 POKé Balls, and root is `overworld` again. Real steps then go 1F to 2F to B1F. A at (26, 13) facing right starts the battle. Hydro Pump misses. One POKé Ball is thrown at 229 HP: catch rate 3, one shake check, `caught` false, message `Oh no! The POKEMON broke free!` Mewtwo is not caught. Settled heaps stay under 14000 KiB.

The Psychic card is a separate handoff. `tools/notes/lane-e-type-display-names.patch` maps the constant through pokered `data/types/names.asm` (`af519899`), which prints `PSYCHIC`, and doubles `_` and `*` before `drawText`. `tools/tests/test_lane_e_type_display_names.py` fails on this tree: the Mewtwo TYPE1 row is `PSYCHIC_TYPE`. `pdc` still needs K's file-scope import after that patch.

A later scratch of lane E `79fbcba5` did leave the Hall and walked as far as Route 24. Door heaps on that scratch, not on main: Route 1 13267.2, Viridian 13525.6, Pewter 13973.4, Route 3 14036.4, Route 4 14020.1, Mt Moon 1F 14484.2, Cerulean 14500.3 (peak 14811.7), Route 24 14303.2. Every move was then at 0 PP. Struggle's recoil fainted the only Pokémon on the winning blow, and the blackout returned to the fixture checkpoint, Pallet (3, 17) up. The cave, the gift, and Mewtwo were not reached there either.

## Mewtwo caught on the patched scratch

Scratch `/tmp/mewtwo-catch`, detached at the local main merge `d6e06010` (`origin/main` `61a70ffe`). Applied, and not committed: `lane-e-gift-menu-input.patch`, `lane-e-type-display-names.patch`, K's file-scope import, and `lane-e-viridian-sleepy-retrigger-heap.patch`. The Hall save has no Master Ball. Real buttons picked up TM45 on Route 24, a Full Restore and a Nugget in the cave, caught a level 46 Hypno with three Poké Balls (the third shake triple was 4710, 16520, 7645, all under the Gen V threshold 36671), and taught Thunder Wave over Hypno's fourth move. The Fuchsia Mart clerk, faced through the counter, sold the Nugget and the leftover Poké Balls, then sold 4 Super Potions and 5 Ultra Balls (¥900 left). The visible Ultra Balls on Cerulean Cave 2F and B1F raised the count from 5 to 7. `MallocPoolSize` stayed `16645684`. No inflate line and no out-of-memory line.

A at B1F (26, 13) facing right starts the static Mewtwo, level 70, 229 HP, catch rate 3. Thunder Wave paralyzed him. Surf landed once, 229 to 163. Recover put him back to 229 before the balls. Hypno, who resists Psychic, stayed in and was healed with the Super Potions and the Full Restore. Six Ultra Balls were thrown, all at 229/229 paralyzed. The sixth caught. Every throw's `modifiedRate4096` was 12288 and every `shakeThreshold` was 21583, with `criticalThreshold` 0. That is the Gen V formula in `Source/domain/capture.lua` for an Ultra Ball (half-unit ball 4), rate 3, and paralysis (half-unit status 3).

| throw | shakes | checks | caught |
| --- | --- | ---: | --- |
| 1 | 56697 | 1 | false |
| 2 | 58411 | 1 | false |
| 3 | 21565, 56751 | 2 | false |
| 4 | 59534 | 1 | false |
| 5 | 8356, 24767 | 2 | false |
| 6 | 13959, 14840, 10882 | 3 | true |

pokered `engine/items/item_effects.asm` ItemUseBall (`af519899`) is a different roll. An Ultra Ball redraws Rand1 into [0, 150], subtracts 12 for paralysis, fails when that remainder is above the catch rate 3, and otherwise compares Rand2 with X. BallFactor is 12, so W = ((229 * 255) / 12) / max(229 / 4, 1) = 85 and X = 85. A cartridge catch needs Rand1 ≤ 15 and then Rand2 ≤ 85. The live engine caught on three 16-bit shakes under 21583. BlueBot ruled that source capture stays the Gen V hybrid. `GameSession:attemptSourceCapture` still calls `Capture.attempt`. The formula handoff files are removed. Capture pins are unchanged.

After the catch the party is Blastoise (23 HP), Hypno (fainted), and Mewtwo at level 70, 229/229, paralyzed, moves Swift, Psychic, Barrier, Recover, `types` `psychic`. `EVENT_BEAT_MEWTWO` is true. On B1F the NPC `pokered:CERULEAN_CAVE_B1F:objects:1` is gone. `data/endgame/visual.json` stores `PSYCHIC_TYPE`, `PSYCHIC_TYPE`. With the type-display patch and K's import, `DrawnText.typeName` prints `PSYCHIC`, and `EndgameStory.hallRows` puts `TYPE1/` on row 8 and `PSYCHIC` on row 9. The two types are equal, so there is no TYPE2 row. The party stats page does not draw the TYPE1 label. Its shot is the stats and the four moves.

| point | heap KiB | observed peak KiB |
| --- | ---: | ---: |
| ready | 12734.6 | |
| Continue, Pallet (5, 6) down | 13149.7 | 13699.9 |
| after the Hypno catch | 13747.3 | 13861.0 |
| Thunder Wave taught | 13720.7 | 13861.0 |
| Fuchsia Mart, after the sale | 13445.5 | 13861.0 |
| beside Mewtwo | 13669.9 | 13861.0 |
| overworld after the catch | 13780.8 | 13861.0 |
| party stats | 13696.1 | 13861.0 |

A fresh Continue, then the same B1F tile, still has the object and `EVENT_BEAT_MEWTWO` false. Blastoise is the only Pokémon. Mewtwo's first Swift is a critical hit, 177 to 74. Surf chips him, Recover takes him from 109 to 227, and Psychic faints Blastoise at 157 HP. The blackout returns to Pallet (3, 17) up and the flag stays false. That is `stay_on` defeat in `Source/data/postgame/story.json`.

The follow-up command was `zone kanto_cerulean_cave_1f 20 10 down`. That cell is collision 1 in `CeruleanCave1F`. `switchZone` nils `game.player`. `OverworldState:enter` asserted `fieldWorld.enter` before `Player()` ran. The harness `beforeFrame` swallowed that assert, and `ExploreSubstate:update` then indexed `player.pendingBoulder` at `game/overworldState.lua:88`. The published snapshot is already cave 1F, player absent, sprites 0, npcs 0, heap 13436.9 KiB, checkpoint Pallet (3, 17) up, `EVENT_BEAT_MEWTWO` absent. The door landing (24, 16) is collision 0. A later fresh Continue lost again and returned to Pallet (3, 17) up. A private harness command, not part of this tree, then zoned to cave 1F (24, 16) up. The player settled there. The same command into B1F (26, 13) right reported `mewtwo-flag=false` and `mewtwo-object=true` (3 NPCs). Before that fight the same tile had already reported the object present and the flag false. Heap after the revisit was 13559.7 KiB, peak 13994.4 KiB. The nil index is the blocked cell. The walkable landing does not hit it. The handoff is `tools/notes/lane-e-nil-player-reentry.patch` with `tools/tests/test_lane_e_nil_player_reentry.py` (2 tests). The explore update and exit return while the player is nil, and the field-reload assert runs after `Player()`. It is not applied. `Source/` stays `origin/main` `247d60a9`.

`scripts/CeruleanCaveB1F.asm` lines 10–14 point `END_BATTLE` at `EndTrainerBattle`. The header on lines 23–26 is `trainer EVENT_BEAT_MEWTWO, 0`. `home/trainers.asm` `EndTrainerBattle` skips the flag only when `wIsInBattle` is `LOST_BATTLE`. `engine/battle/core.asm` `.canEscape` stores `wBattleResult` 2 and returns to `EndOfBattle`, which clears `wIsInBattle`. Only `.allPokemonFainted` writes `LOST_BATTLE`. A catch, a KO, and a run set the flag and hide the object. A blackout leaves him, flag false. A second prepare after a hide is `already-complete`, so he does not respawn. `story.json` `hide_on` is victory, caught, run and `stay_on` is defeat. `tools/tests/test_lane_e_mewtwo_outcomes.py` (2 tests) pins that path. It passes on the current tree, so there is no outcome patch. Grouping a run with a blackout does not match `EndTrainerBattle`.

`engine/menus/status_screen.asm` is absent. `engine/pokemon/status_screen.asm` `StatusScreen` places `TypesIDNoOTText` (`TYPE1/` then `TYPE2/`) at hlcoord 10, 9 and `PrintMonType` at hlcoord 11, 10. Equal type bytes skip the second name. The party stats page draws the stats and the four moves and has no `TYPE1/`. The Hall card already prints it. The handoff is `tools/notes/lane-e-party-status-type.patch` with `tools/tests/test_lane_e_party_status_type.py` (1 test). Mewtwo's `type` `psychic` draws `TYPE1/ PSYCHIC` and a bare `TYPE2/`. It is not applied.

## Acceptance on 247d60a9

Scratch `/tmp/postgame-accept-out`, not committed. The four handoffs were applied only in that simulator: `lane-e-gift-menu-input`, `lane-e-viridian-sleepy-retrigger-heap`, `lane-e-nil-player-reentry`, and `lane-e-party-status-type`. `Source/` in the tree is `origin/main` `247d60a9`. `MallocPoolSize` stayed `16645684`. No inflate line and no out-of-memory line. Buttons chose the gifts, taught TM45, bought at the Fuchsia Mart, caught Mewtwo, and saved. Map changes used the private `zone` command.

The gift menu is `MEW` then `LINK CABLE`. A on MEW adds Mew at level 5, 25/25, Pound, and sets `EVENT_GOT_MEW`. Down, then A, adds one `linkCable`. The bag still had the 20 Poké Balls. Root returned to the overworld both times.

The same Hall fixture then picked up TM45, the cave Full Restore, and the Nugget. A level 46 Hypno was caught on the third Poké Ball. Thunder Wave replaced Hypno's fourth move. The Fuchsia clerk sold the Nugget and the leftover Poké Balls and sold 4 Super Potions and 5 Ultra Balls (¥900 left). The cave pickups raised Ultra Balls from 5 to 7. A at B1F (26, 13) facing right started Mewtwo, level 70, 229 HP. Thunder Wave paralyzed him. Surf landed once. Recover restored him to 229. The sixth Ultra Ball, still 229/229 paralyzed, caught. `modifiedRate4096` was 12288 and `shakeThreshold` was 21583 on every throw. That matches the Gen V hybrid already pinned. `EVENT_BEAT_MEWTWO` became true. The party on the overworld was Blastoise 23/177, Mew 25/25, Hypno fainted with Thunder Wave, and Mewtwo 229/229 paralyzed, Swift / Psychic / Barrier / Recover.

SAVE was the fifth start-menu row. YES wrote `adventure.b.json`, sequence 2, 6573 bytes. The published payload has that party, one `linkCable`, location `pokered:CERULEAN_CAVE_B1F` (26, 13) right, `EVENT_GOT_MEW` true, `EVENT_BEAT_MEWTWO` true, and the Hall record version 1, Blastoise level 65. Slot A is still the original Hall fixture, sequence 1.

Quit and Continue loaded slot A. The player is in Pallet (5, 6) down with only Blastoise. `EVENT_GOT_MEW` and `EVENT_BEAT_MEWTWO` are false. The Hall record is the fixture's Blastoise team, which slot A already had. Title inspect marks slot B corrupt before `loadHallContinue` installs the postgame chunk:

`domain/worldMotion.lua:139: missing visible source actor`

The saved actor list keeps the visible Max Revive, `pokered:CERULEAN_CAVE_B1F:objects:3`, and omits object 1 because the flag is set. `LateKantoStory.actorMetadata` only reads `PostgameStory.visibility` after that chunk is loaded, so the boot validation still treats Mewtwo as visible. The handoff is `tools/notes/lane-e-mewtwo-continue-actor.patch` with `tools/tests/test_lane_e_mewtwo_continue_actor.py` (1 test). It fails on this tree and passes after `git apply`. The four earlier patches still apply on `247d60a9`. None of them is in `Source/`.

| point | heap KiB | observed peak KiB |
| --- | ---: | ---: |
| ready | 12739.8 | |
| Continue, Pallet (5, 6) down | 13171.3 | 13718.0 |
| cave 1F (24, 16), before the gift | 13230.4 | 13718.0 |
| MEW chosen, overworld | 13325.8 | 13718.0 |
| LINK CABLE chosen, overworld | 13340.8 | 13718.0 |
| after the Hypno catch | 13841.4 | 13860.8 |
| Thunder Wave taught | 13756.8 | 13901.8 |
| Fuchsia Mart, after the sale | 13641.1 | 13901.8 |
| beside Mewtwo | 13799.9 | 13901.8 |
| overworld after the catch | 13904.8 | 13999.5 |
| saved, overworld, B1F (26, 13) | 13770.9 | 13999.5 |
| Continue of the rejected slot | 13173.5 | 13693.1 |

## Cave Continue on 247d60a9

The five local patches, plus the pickup handoff below, were applied only in the simulator. `Source/` in the tree is `origin/main` `247d60a9`. `MallocPoolSize` stayed `16645684`. No inflate line and no out-of-memory line. The post-catch pair was `/tmp/postgame-accept-save`: slot A sequence 1, the Hall fixture, and slot B sequence 2, B1F (26, 13) right.

The static hide rule is not enough. With only `lane-e-mewtwo-continue-actor.patch`, title inspect still rejects slot B:

`missing visible source actor pokered:CERULEAN_CAVE_B1F:objects:2`

That is the Ultra Ball. `PostgameStory.installEvents` is what registers the cave and Power Plant balls. The chunk is not loaded during title inspect, so `SourceEvents.descriptor` is nil and the taken ball stays visible. The handoff is `tools/notes/lane-e-postgame-pickup-continue.patch`, applied after the static patch. The same test covers both. Snorlax on Routes 12 and 16 is already hidden by `SnorlaxStory.actorMetadata` through `HideoutTowerContent`, which the boot install calls. Articuno is decorated by `CoastStoryWorld.install`. Moltres is in `EndgameStory` `VISIBILITY`. The Mew gift actor is not a pokered source object. Those four do not fail this check.

With both rules present, Continue of slot B loads the cave. Party is Blastoise, Mew, Hypno, and Mewtwo. `EVENT_GOT_MEW` and `EVENT_BEAT_MEWTWO` are true. The player is at B1F (26, 13) facing right. The Hall record is version 1, Blastoise level 65. The only actor is the Max Revive, `pokered:CERULEAN_CAVE_B1F:objects:3`. Mewtwo is absent.

SAVE is the fifth start-menu row. YES writes `adventure.a.json` sequence 3, 6573 bytes. Quit and Continue loads that newer slot. The same party, both flags, B1F (26, 13) facing right, the Hall record, and the absent Mewtwo all come back. The clip is `artifacts/continue-cave-b1f.mp4`.

The floor under Mewtwo is 14 walkable cells, (25–28, 12–15) with (26, 15) and without (25, 15) or (28, 15). Eighty-three real steps walked every one of them and returned to (26, 13). None of them leaves the room. The stair at (3, 6) is a different component, so the walk out to 1F and back cannot be done from this save. After those steps the party and both flags are unchanged, and the only actor is still the Max Revive.

| point | heap KiB |
| --- | ---: |
| ready, slot B present | 12734.8 |
| Continue of slot B, B1F (26, 13) right | 13114.4 |
| after SAVE / YES | 13080.3 |
| ready, sequence 3 present | 12734.9 |
| Continue of sequence 3, B1F (26, 13) right | 13061.6 |
| after walking the chamber | 12957.6 |

## Cable Club, Hall Continue, and the walk to Cerulean

`origin/main` is `247d60a9`. The six handoffs were applied only in the simulator, in this order: `lane-e-gift-menu-input`, `lane-e-viridian-sleepy-retrigger-heap`, `lane-e-nil-player-reentry`, `lane-e-party-status-type`, `lane-e-mewtwo-continue-actor`, `lane-e-postgame-pickup-continue`. `Source/` in the tree is `origin/main`. `MallocPoolSize` stayed `16645684`. No inflate line and no out-of-memory line. The save was only the Hall fixture `tools/tests/fixtures/lane-h-hall-continue-8e72131f.json`. Buttons did the Continue, the receptionist A, and every step. Encounters were off. Trainer sight stayed on.

Cable Club fails. The Viridian Center receptionist is `pokered:VIRIDIAN_POKECENTER:objects:4`. The player stood at (11, 3), pressed up, and pressed A. The event stayed closed. `lastTraversalBlock` was `{kind="unimplemented-source-event", id="pokered:VIRIDIAN_POKECENTER:objects:4"}`. No welcome line and no warp. The same press on a second boot landed on the same block. Heap 13244.4 KiB, then 13211.5 KiB. The clip is `artifacts/cable-club-viridian.mp4`.

`scripts/ViridianPokecenter.asm` (af519899) `ViridianPokecenterLinkReceptionistText` is `script_cable_club_receptionist`. The other center receptionists use that macro. Indigo Plateau lobby object 5 already says the welcome line and the save line and does not warp. The handoff is `tools/notes/lane-e-cable-club-dialog.patch` with `tools/tests/test_lane_e_cable_club_dialog.py` (1 test). It registers the eleven center receptionists as those two dialog steps. `TRADE_CENTER` and `COLOSSEUM` stay closed. The test fails on this tree and passes after `git apply`.

The LINK CABLE was not received. The only giver is the cave scientist at Cerulean Cave 1F (23, 16), and that room sits on the pocket below. The four `linkCable` edges are already in `Source/data/evolutionData.lua`. The bag never held a cable, so the non-target use was not played.

Hall Continue passes. The same buttons land in `kanto_pallet_town` at (5, 6) facing down. The Hall record is version 1, Blastoise level 65. The party is that Blastoise. `EVENT_GOT_POKEDEX` and `TOGGLE_CERULEAN_CAVE_GUY` are true. `EVENT_GOT_MEW` and `EVENT_BEAT_MEWTWO` are false. Heap 13168.7 KiB. The clip is `artifacts/continue-pallet.mp4`.

The walk from that Pallet cell used real steps: Viridian Center, Route 2, the forest gates and the forest, Pewter, Route 3, Mt. Moon 1F, B1F, and B2F, Route 4's lower road, and Cerulean (0, 18). Route 3 and Mt. Moon trainer scripts took A through the text and the walk continued. The player reached Cerulean (8, 18), then (8, 12) facing left. `move left` stayed on (8, 12). No map refused an exit. The clips are `artifacts/cerulean-streets.mp4` and `artifacts/cave-approach.mp4`.

The cave door is city (4, 11). Its land is the 13 cells (0, 12), (0, 13), (1, 12), (1, 13), (2, 12), (2, 13), (3, 12), (3, 13), (4, 11), (4, 12), (4, 13), (5, 12), and (5, 13). (6, 12) and (6, 13) are water, foot `$14`. (7, 12) and (7, 13) are shore, foot `$3A`, which is not in `Overworld_Coll` and is not a surf surface. The street component from (8, 18) is 378 cells and does not touch that pocket or that water. The pocket's west edge is Cerulean (0, 12). Route 4's east connection is `connection east, CeruleanCity, CERULEAN_CITY, -4` (af519899), adjustment `+8`, so Route 4 (89, 4) lands there and Route 4 (89, 10) lands on the street (0, 18). The upper strip is Route 4 y=2..4 east of x=60. Cell (60, 4) is foot `$27`, collision 1. (59, 4) and (61, 4) are foot `$2C`. `data/tilesets/ledge_tiles.asm` hops left from `$2C` onto `$27` and has no right hop onto `$27`. The Mt. Moon exit component, 353 cells from (24, 5), stops at that cliff. Opening a tile would contradict those pins, so there is no collision handoff.

| point | heap KiB | where |
| --- | ---: | --- |
| Continue, Pallet (5, 6) down | 13168.7 | hall record kept |
| Viridian Center (11, 3), after A | 13211.5 | receptionist blocked |
| Cerulean (8, 18) | 14102.9 | streets |
| Cerulean (8, 12), facing left | 14095.9 | step left did not move |

## Surf to the cave, the Cerulean heap, and which scientist

`origin/main` is `247d60a9`. The six handoffs were applied only in the simulator. `Source/` in the tree is `origin/main`. `MallocPoolSize` stayed `16645684`. No inflate line and no out-of-memory line. The save was only the Hall fixture. Buttons did the Continue, every step, and the party SURF command. Encounters were off. Trainer sight stayed on.

Surf does not board from the street, and that matches the pin, so there is no handoff. The Hall Blastoise already knows SURF. It is the first party action, ahead of STATS, SWITCH, ITEM, and CANCEL. No HM was used. The player stood at Cerulean (8, 12), faced left, and pressed A on SURF. The party stayed on its actions menu and said "That move can't be used here." Root stayed `party`. The clips are `artifacts/surf-shore.mp4` and `artifacts/surf-use.mp4`.

`GetTileAndCoordsInFrontOfPlayer` (`engine/overworld/player_state.asm` 283, af519899) reads the cell one step left. That cell is (7, 12). It is overworld block 25's right quadrant, foot `$3A`. `IsNextTileShoreOrWater` (`engine/items/item_effects.asm` 2829–2845) accepts `$48`, `$32`, and `$14`, and rejects anything else. `$3A` is not one of those, and it is not in `Overworld_Coll`. `FieldTravel.surfSurface` uses the same three feet. The only land cells in the city that face `$14`, `$32`, or `$48` are the cave pocket and the east bank at (39, 6). The east bank's water does not connect to the pond in front of the door. The street component does not touch a surf tile. The pocket is the water the user already called correct, so nothing here opens `$3A` or a land tile. The door was not entered. No save was written inside, and Continue-inside was not reached.

There is no pokered cave scientist at af519899. `data/maps/objects/CeruleanCave1F.asm` lines 22–25 are `def_object_events` and three `SPRITE_POKE_BALL` objects: Full Restore (7, 13) line 23, Max Elixer (19, 3) line 24, Nugget (5, 0) line 25. Line 27 is `def_warps_to CERULEAN_CAVE_1F`. `scripts/CeruleanCave1F.asm` line 1 is `CeruleanCave1F_Script:`, line 2 is `jp EnableAutoTextBoxDrawing`, and lines 4–8 are three `PickUpItemText` pointers. The script status on the ported map is unimplemented. The giver in this port is not that file. It is `postgame:CERULEAN_CAVE_1F:mew-gift` at (23, 16), `SPRITE_SCIENTIST`, `STAY`, `RIGHT`, text `_PostgameGiftIntroText`, `source_line` null. The talk id `pokered:CERULEAN_CAVE_1F:script:mew-gift` is not a label in that asm. The NPC standing on the city door is `CERULEANCITY_SUPER_NERD3`, `data/maps/objects/CeruleanCity.asm` line 47, `object_event 4, 12, SPRITE_SUPER_NERD, STAY, DOWN`. That is the guard the Hall flag hides, not the gift giver.

The 14095.9 KiB reading is the live map after Mt. Moon, not a Cerulean allocation and not a number that comes back down on the same boot. On the next walk the same shore, facing up, was 14066.2 KiB. Route 4 before Mt. Moon was 13854.0. Mt. Moon 1F was 14287.0. Route 4 after leaving the cave was 14023.4. Cerulean at the west connection was 14272.4, and (8, 12) settled at 14066.2. The Viridian Center counter on the way out, the same boot, was 13157.8 KiB at (11, 3). Leaving the city into the Cerulean Center, the same kind of interior, landed at 14105.3 on the mat and settled at 13801.3 at (7, 4). That is 643 KiB above the Viridian Center and only 265 KiB below the shore. The clip of that interior is `artifacts/leave-city.mp4`. The one-way Route 4 ledges block a walk back to the Viridian Center, so the return sample is this Center rather than the same room.

A fresh Viridian Center fixture, before any of those maps, is 12800.1 KiB. `switchzone` through Mt. Moon 1F, Route 4, and Cerulean, then back to that Center, settles at 13156.9 KiB. The interior is 356.8 KiB higher after the three maps. `switchZone` already drops the departing view, the retained runtime, and the imported cache. What stays is the append-only `TileRegistry`: each visit keeps its shade grids, and `TileFactory.generateAll` draws every registered id into the next imagetable. Nilling the shade grids of maps that are no longer on screen does drop the next definition (Cerulean actors 13762.5 KiB, the following Center definition 12921.2 KiB) and then faults on the way back into the Center, in `OverworldState:enter`, after `field_prepare`. The reported fault is `game/overworldState.lua:88` with `game.player` nil. The error underneath, before the state machine rethrows it, is `world/tileRegistry.lua` `conflicting duplicate tile key: pokered:POKECENTER:cell:01-0b-11-1b` once the grid has been cleared and the Center is built again. That release is not a handoff. No lane-e patch is in this commit.

| point | heap KiB | where |
| --- | ---: | --- |
| Viridian Center (11, 3), before Cerulean | 13157.8 | same boot, way out |
| Route 4 (9, 17), before Mt. Moon | 13854.0 | lower road |
| Mt. Moon 1F (14, 35) | 14287.0 | first cave room |
| Route 4 (24, 6), after Mt. Moon | 14023.4 | upper strip |
| Cerulean (8, 12), facing up | 14066.2 | shore, SURF refused |
| Cerulean Center (7, 4) | 13801.3 | after leaving the city |
| fresh Viridian Center fixture | 12800.1 | before the three maps |
| same Center after Moon, Route 4, Cerulean | 13156.9 | 356.8 KiB retained |

## Route 24 water, the cave Continue, and the heap that stays

`origin/main` is `247d60a9`. `Source/` in this commit matches it. `MallocPoolSize` stayed `16645684`. Buttons did the party SURF, every step, the save, and Continue. Encounters were off. The water connection is in the port, so there is no collision or surf handoff.

`data/maps/headers/Route24.asm` at af519899 line 2 is `connection south, CeruleanCity, CERULEAN_CITY, -5`. `data/maps/headers/CeruleanCity.asm` line 2 is `connection north, Route24, ROUTE_24, 5`. The compact catalogue stores those as south adjustment `+10` and north adjustment `-10`. Route 24 (6, 15) is land, foot `$2C`. The cell in front, (6, 16), is foot `$32`, a surf surface. The south row x=4..8 is foot `$14`, and x=9 is `$3A`. Cerulean's north row x=14..18 is `$14`, and x=19 is `$3A`. Route 24 (6, 35) therefore lands on Cerulean (16, 0), both `$14`. The pocket land at (5, 12) faces (6, 12), foot `$14`.

The live walk started at Route 24 (6, 15) facing down, with the Soul Badge and the other seven, and Blastoise already knowing SURF. The party menu boarded onto (6, 16). Surf down the west channel crossed the connection into Cerulean, left along the pond, and landed on the pocket. The door at (4, 11) entered Cerulean Cave 1F. The same buttons, including two more SURF uses where the path returns to water, went through 1F and 2F and reached B1F (26, 13) facing up, short of Mewtwo at (27, 13). SAVE wrote `adventure.a.json` sequence 1, checksum `4cf17a11`, location `pokered:CERULEAN_CAVE_B1F` (26, 13) up, mode walking. Continue loaded that cell. Heap on the load was 12949.1 KiB. The clips are `artifacts/surf-board.mp4`, `artifacts/river-cross.mp4`, `artifacts/pocket.mp4`, `artifacts/cave-1f.mp4`, `artifacts/cave-b1f.mp4`, `artifacts/b1f-save.mp4`, and `artifacts/continue-b1f.mp4`.

The heap test is `tools/tests/test_lane_e_departed_tile_registry.py`. It fails on this tree. `switchzone` from a fresh Viridian Center through Mt. Moon 1F, Route 4, and Cerulean, then back, collects before each definition. The Center's `definition.begin` goes from 12500.1 KiB to 13014.1 KiB, 514 KiB, against a 96 KiB bound. The Center rebuilds. A second lap of the same maps, measured on this tree before the test was cut to one lap, returned at 13015.3 KiB and then 13020.5 KiB. The second return is 5 KiB above the first. The write-up is `tools/notes/lane-e-departed-tile-registry.md`. A suffix release that forgets unreferenced tile keys does let the Center register its cells again, and it still leaves the return definition 366 KiB up, so it is not a handoff. Niling the grids without removing the keys is the `conflicting duplicate tile key` fault and is not a handoff either.
