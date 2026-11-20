# Lane J — Squirtle

Branch `cursor/lane-j-squirtle`. Merged E tip `51764017` (Oak at lab cell 6, 2 in `837a61e6`), then main `9a33a835`, `2e7863ff`, `e0e9a209`, `ff64287c`, and `e142281e` (the fainted-lead shift question). The remote branch only moved forward. Real Simulator presses only. Earned saves stay outside git.

## Position

- Badges: Boulder Badge (`BADGE_BOULDER`). TM34 is in the bag. Payout was 1386.
- BLUE, rival RED. Squirtle, level 15, 39 HP, no status, Tackle, Water Gun, Bubble, and Withdraw. Tail Whip was replaced when Water Gun was learned.
- Intro done. Lab rival won (his Bulbasaur)
- Oak's Parcel has been delivered. `EVENT_GOT_POKEDEX` and `EVENT_OAK_GOT_PARCEL` are set.
- Route 3 is crossed. Mt. Moon is crossed. Wartortle, level 17, 22 HP, no status, Tackle, Water Gun, Bubble, and Bite. `EVENT_GOT_DOME_FOSSIL` and `EVENT_BEAT_MT_MOON_EXIT_SUPER_NERD` are set. Standing on Route 4 at (59, 4), facing right. Healing checkpoint is still Pewter City (13, 26) facing down.
- Earned pause save: `/opt/cursor/artifacts/lane-j/saves/5a428a2c98f5/adventure.a.json` sha256 `9f3237a35d79f667b80884f3b0711356450817f5f068e67611f02ffdd29e2a14` (sequence 11, the cliff). The east-side exit pause is `adventure.b.json` sha256 `35c11c6985486b732e734bf14c15832c1367b4c638b16d9c27a68438b590fb8d` (sequence 10, Route 4 (24, 6)). The Dome Fossil pause is `/opt/cursor/artifacts/lane-j/saves/c964b798257f/adventure.a.json` sha256 `d7c9172de14d727711569feeb8d1b5eac274d43f03223898d55afbcbdd47d2f4` (sequence 9). Earlier: Route 4 entrance sequence 8 `362f03f4ab81c87ca6421b4d419090fb17e557a79e3d27146398fc9f872772d9`, Boulder Badge `fca4f05f2567bd621c35b195f24c0f7db80655b09b67409d282e3e4550a1b05b`. None of these are in git.

## Clips

Decoded frames are only 0 and 255.

| Clip | Duration | sha256 | What it shows |
| --- | --- | --- | --- |
| `artifacts/lane-j/20261120T001412Z-rival-lab.mp4` | 37.03s | `d9b57b21ed0ceca5c0bf01bbf83d25ede123fe13fd2bddf5e396265ee42563bc` | Lab rival win |
| `artifacts/lane-j/20261120T002027Z-rival-lab.mp4` | 36.83s | `9edcfcad7374969896bf63b6d3146e80db78043ee6397aafc5440f24ad05fe58` | Lab rival win only. The recorder stopped when the battle ended, so this is not a Route 1 walk. |
| `artifacts/lane-j/20261120T005708Z-pokedex-lab.mp4` | 31.97s | `71f1cded1ecffbdd3646087cb355c73fa8e74021b5cca23ad01b6dc636a592dd` | Oak takes the parcel and gives the Pokédex. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T010900Z-route1.mp4` | 24.03s | `f46446c1aed298405a06c00b055444af84f15359ac4a04d2f12cdf44a0d33023` | The walk north on Route 1 into Viridian. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T011836Z-gym-pewter.mp4` | 45.37s | `341d2404b7f16eabd0f526dccc5dc5cb660a774360d9540157079efd6d0c6e58` | The Pewter Gym trainer battle that blacked out. This is not the Boulder Badge. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T012706Z-gym-pewter.mp4` | 70.93s | `1d3c2df84e1aeb53e5da03654da14a58756c6e2346c549ab10dd8bec87b9c6f7` | Brock, Geodude then Onix, and the Boulder Badge. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T020656Z-route3.mp4` | 80.73s | `8c25bf7a0134b25b5d0e77ca881ed771f53037c9d96e109ee747826fe4d5516a` | Leaving Pewter onto Route 3. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T023747Z-mt-moon.mp4` | 60.57s | `805cc8f940fa66a4139c6312c6eb80033ff72e0b6001edb1f41c62a5dc2894f9` | The Mt. Moon 1F stair walk. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T024836Z-mt-moon.mp4` | 60.13s | `2a634e95b62d40d1b93ab96129b1a5aeadcfad7bab452f3a587a133e0d95067d` | The next 1F stair walk, before the fossil nerd blackout. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T025319Z-route3.mp4` | 41.33s | `35ffa5094d9b1e68b6fc2b7dbfcc1cb264ef8bc055353d22f84371cda4dd47e4` | The Route 3 recross after that blackout. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T025414Z-mt-moon.mp4` | 47.53s | `79723686ea1ea0cb8af33a75c2967d71483723e70ab11cfa2803902addac4671` | The retry's 1F stair walk. Decoded frames are only 0 and 255. |

## Title intro

The hang was in this driver. One `wait 250` held the copyright screen. Copyright (180 frames) and the black bars (64) ignore A; the shooting star and the fight accept it (`Source/game/introMovie.lua`, pret/pokered `engine/movie/intro.asm` `PlayIntroScene`). The skip is now a 12-frame wait plus A, repeated until the title leaves the intro, which still covers the whole movie if every A is ignored. A later session cleared that intro, chose CONTINUE on the earned Viridian save, and reached the Mart. No Source change.

## How we got here

New Game from the title. Bedroom stairs, Red's house, Pallet grass, Oak's lab, Squirtle ball at the padded (8, 3) object. Tackle won the lab fight. Out of the lab, north through Route 1, into Viridian City. CONTINUE from that pause save, in the Mart door. The entry program gave Oak's Parcel. Pause save inside the Mart.

## Parcel handoff

An earlier walk reached the same lab before Oak was placed. A at (6, 3) did nothing and the parcel stayed in the bag. After `837a61e6`, CONTINUE from the Mart save again. The title intro cleared, then Mart door to Viridian (29, 20), south edge (21, 35), Route 1 (11, 0) to (10, 35), Pallet (9, 0). The seam at (9, 0) is solid in `PalletTown.json` and open at runtime. The lab door entered `oaks_lab` at (6, 10). Faced Oak at (6, 2) from (6, 3) and pressed A. The handoff ran: dialogue, the rival's walk in, the Pokédex pages, and the rival leaving. The parcel count went to 0. Pause save in the lab. The clip is `20261120T005708Z-pokedex-lab.mp4` (31.97s).

The lab save walked out, filmed Route 1 (24.03s), and talked to the old man at (17, 6). The next walk crossed Route 2, Viridian Forest, and the north gate into Pewter at level 8 with 10 HP. Bubble was learned. A forest battle left Squirtle poisoned. The first Center visit looked for a tile beside the nurse and left without healing. The gym path then crossed the junior trainer's sight at (5, 7). Squirtle fainted. That blackout was not saved. The Pewter pause at (18, 35) resumed. The nurse is at (3, 1) behind the solid counter at (3, 2). Standing at (3, 3) and facing up opened the heal, and YES restored Squirtle to 25 HP. The walk to Brock avoided (4, 7) and (5, 7). Brock's Geodude and Onix fainted. `last_battle_outcome.won` is true, `BADGE_BOULDER` is set, and the bag holds one TM34. Squirtle reached level 12 with 20 HP and learned Withdraw. The clip is `20261120T012706Z-gym-pewter.mp4` (70.93s).

The gym pause walked east. Pewter's Center healed Squirtle before Route 3. The northern road is blocked by trainer sight, so the walk crossed four of them and returned to Pewter whenever HP fell under 22 or a status landed: the bug catcher at (10, 6), the youngster at (14, 4), the youngster at (19, 5), and the youngster at (24, 6). Their flags are `pokered:ROUTE_3:objects:2`, `:3`, `:5`, and `:8`. Water Gun replaced Tail Whip at level 13. Route 3's north edge at (59, 0) opened Route 4 at (9, 17). The pause there is sequence 8. A later step entered Mt. Moon and reached level 16; the evolution announcement was on screen and this driver never pressed A, so that cave progress was not saved. The Route 4 pause is the resume. The clip is `20261120T020656Z-route3.mp4` (80.73s).

A second cave attempt used the pair-legal path. Foot tiles 32 and 5 cannot be stepped between, so the collision-only route west from (10, 22) is refused and the other stairs drop into a dead pocket. The legal path reached B2F. Squirtle evolved to Wartortle at level 16. The super nerd's battle then left Water Gun disabled, and the menu kept confirming that move, so the fight never advanced. That cave was not saved. The Route 4 pause above is still the resume. The clip is `20261120T023747Z-mt-moon.mp4` (60.57s).

A third crossing evolved to Wartortle again, lost to the fossil super nerd, and blacked out to Pewter. The retry beat him at B2F (12, 7) and learned Bite, but Grimer's Disable page stayed up while the cursor moved, so every move was marked rejected and the rest of the fight used Tackle. Wartortle finished paralyzed at 14 HP. The Dome Fossil sprite at (12, 6) is the only step into the exit pocket, and treating that blocked step as a wall left no route. The win was not written. The sequence 8 Route 4 pause is still the resume. The clips are `20261120T024836Z-mt-moon.mp4` (60.13s), `20261120T025319Z-route3.mp4` (41.33s), and `20261120T025414Z-mt-moon.mp4` (47.53s).

The retry beat the fossil super nerd. Wartortle is level 17, 22 HP, with Tackle, Water Gun, Bubble, and Bite, and `EVENT_GOT_DOME_FOSSIL` is set. The first exit walk stepped on warp (5, 7) early. The next walk kept that stair for the last step, returned through B1F, and landed on Route 4 (24, 6). The Center is west of the wall at x=20, so the east side cannot heal there. The walk reached (59, 4) and a right step was blocked. Cerulean did not open.

## Next

Stopped on Route 4. The east step at (59, 4) is blocked, so Cerulean and Misty are not reached. Resume sequence 11 only after that step can enter Cerulean.

## Blockers

Route 4's northern road does not continue east. Standing at (59, 4) facing right, one real `press right` stayed on (59, 4) (`cliff_step` `blocked`). The next cell (60, 4) is foot tile `0x27`. Cerulean City is on the far side of that tile. The same collision matches pret/pokered `af519899` `maps/Route4.blk` plus `gfx/blocksets/overworld.bst`. The Mt. Moon B2F exit returns to (24, 5), which is on this east side. The Pokémon Center at (11, 5) is west of the wall around x=20, so it cannot be reached from here. There is no other land exit on this side. Surf is not available. No Source edit from this lane. Pause: `/opt/cursor/artifacts/lane-j/saves/5a428a2c98f5/adventure.a.json` sha256 `9f3237a35d79f667b80884f3b0711356450817f5f068e67611f02ffdd29e2a14`.

## Tests

`python3 -m unittest tools.tests.test_lane_j_squirtle tools.tests.test_lane_e_oaks_lab_oak` — 12 tests, all passed before the Route 3 walk. The Route 3 host checks passed again after that walk (`SquirtleRouteTests`, 11 tests). The Simulator run is `/tmp/lane-j-squirtle-17`. It saved Route 4 and then stopped on the evolution announcement inside Mt. Moon.
