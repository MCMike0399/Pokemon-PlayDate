# Step-2 pre-verify against main f79bce30

Comparison base is `f79bce3039e47e0240e82fad70d5053a67045763`. The suites were not re-run on `fafc40fd`. Merge-base of both branches with that main is `247d60a9216307c0e1b15316f2b052ae10d23a6c`. Neither branch was rebased. PR #9 was not merged and its branch was not pushed.

| Tree | SHA | Host | Device shards |
| --- | --- | --- | --- |
| main | `f79bce30` | 1521 tests, 25 failed, 54 errors, 11 skipped, 536.345s | 133/133, 81 green, 52 red |
| PR #9 `cursor/lane-h-postgame-step2-f857` | `6129d8adcf7b8d0f658e9262cc0b32daf946acc8` | 1467 tests, 8 failed, 49 errors, 11 skipped, 448.422s | 89 recorded, then stopped |
| `cursor/lane-k-gap-moves-f857` | `3309449272843100e32cfc2bb075710c6e841d90` | 1466 tests, 19 failed, 52 errors, 11 skipped, 413.937s | not started |

`MallocPoolSize` stayed `16645684`. The H device runner later died with no inodes left (`Errno 28`). Those outputs were deleted only after the scores above were recorded. `ability-compatibility` on H is not a product red: it aborted in 1.9s while writing `outcome.json`.

## Elite Four door lock

On `6129d8ad`, Lorelei, Bruno, and Agatha match pret/pokered `af519899`. `LoreleisRoomDefaultScript`, `BrunosRoomDefaultScript`, and `AgathasRoomDefaultScript` do not check the beat flag. Coord index below 3, or index 3 or 4 after the autowalk flag, prints Don't run away and forces one step up. Entrance coords are `(4,10)`, `(5,10)`, `(4,11)`, `(5,11)`. `ShowOrHideExitBlock` opens only the north block (`lb bc, 0, 2`), and `story.json` `exit_block` is `{x:2,y:0}`. `entranceAction` still returns `dont-run` when the room flag is set, and `EndgameStory.check` still dispatches it.

Lance's `DefaultScript` is `CheckEvent EVENT_BEAT_LANCE / ret nz`. The physical door is `EVENT_LANCES_ROOM_LOCK_DOOR` at `(y=6,x=2)` and `(y=6,x=3)`, matching `entrance_blocks`. Lock coords are `(5,11)` and `(6,11)`. `walk_coord` `(24,16)` is the staircase. Beating Lance does not reopen the south door. `ChampionsRoomDefaultScript` is `ret`. The champion is not in the elite-four entrance loop. `33094492` does not change `endgameStory.lua` or `story.json`.

## Go / no-go

**`6129d8ad` is no-go.** The door lock matches pokered. These reds are green on `f79bce30` and red on this SHA:

| Test | Cause |
| --- | --- |
| `test_lane_e_fly_contract.FlyContractTest.test_fly_visited_cities_stays_under_the_pool` | Embedded `field-travel` scored 2 passed / 1 failed at 12794.4 KiB. Fly itself was ok. `field-travel: expired Surf takes input before held traversal` died at `dev/fieldTravelContracts.lua:367` with `pd_readcompressed inflate failed, out of memory`. |
| `battle-rewards-v1` | 23 passed / 4 failed, heap 12819.3 KiB. `level-up recomputes from EV already allocated before next foe and typed learning` expected one Pokemon object and got another. `HUD holds before vitals through gained message then releases before grew message` and `active second member stays held while first bench member narrates and learns` were `script-cancelled`. `level-up stats box follows the grew line and waits before learning` expected true and got false. |

Host shared 56 failures with main and had 23 failures that are on main only. Device shared 29 reds. Suites red on both, with a different first failure: `brock-mechanics` (H expects `focusEnergy` and gets nil; main expects `DEX TEST wants to battle!` and gets `wants to fight!`) and `early-abilities` (H fails `abilityContracts.lua:308`; main's run timed out).

H device did not run these 41 contracts: whirlwind, move-failure, source-maps, source-events, source-text, scripted-npc, generic-actors, source-map-activation, cerulean-content, cerulean-story, cerulean-scenes, cerulean-routes, tutorial-escort, kanto-scenes, kanto-services, common-abilities, cerulean-ambient-dialogue, entry-abilities, contact-abilities, field-moves, field-world, vermilion-gifts, vermilion-story, daycare, vermilion-preparation, vermilion-ship, field-acquisition, vermilion-abilities, vermilion-catalog, cave-encounters, pickup, grass-cut, vermilion-ambient, battle-presentation, approved-qol, npc-trades, saffron-guards, field-travel, source-encounters, field-gear, celadon-services.

**`33094492` is no-go as a finished step-2 check.** Host branch-only reds: none (71 shared with main, 8 on main only). The device suite was not started, so none of the 133 shards ran. The door-lock behavior is not in this commit.
