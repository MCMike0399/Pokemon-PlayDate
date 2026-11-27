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
