# Cerulean to Erika

Faithful. pret/pokered `af519899`. J is `cursor/lane-j-squirtle` `6926904a`, sequence 57, standing on Cerulean `(0, 18)` facing right. The pause is `/opt/cursor/artifacts/lane-j/saves/route6-bird/adventure.a.json`, sha256 `dc5d793037c2eb04e10984b05617ab8ff17b4d30b558471480b9d25681b720f2`. The party is Wartortle 27, Bellsprout 15, Pidgeotto 20, and Dugtrio 27. Boulder, Cascade, and Thunder are set. Money is ¥321, with 3 Super Potions. Cut is already in the party.

Every coordinate below is the live grid. `tools/tests/test_lane_k_cerulean_to_erika.py` replays the walk on `sourceMapCache/compact.json`. Cerulean, Route 9, Route 10, both tunnel floors, Lavender, Route 8, Route 7, and Celadon have padding 0, so these match the object files. Celadon Gym's padding is 1. The two underground entrance rooms have padding 2.

The east road in Cerulean is a separate component until Cut. The Route 9 entrance is the same. Route 10's four trees and Celadon's south tree are the same kind of cut. The gym's three trees are the pokered gym swaps. The floor art on that gym is mockup C, approved on main `9a33a835` for every GYM tileset. A solid tree on this walk is the cut site from `CutTreeBlockSwaps`. The installed feet for Cerulean, Route 9, Route 10, Celadon, and the gym match the pokered block maps.

Flash does not change a step. `fieldMoveIndex.json` lists both Rock Tunnel floors as dark maps so Flash is legal there. Walking uses the cavern collision either way.

Heal at the Route 10 Center before the tunnel, at the Lavender Center, and at the Celadon Center. Each nurse is `(3, 1)` behind the counter. Stand on `(3, 3)` facing up. The seven sight fights below are the ones this line steps on. Their payouts are the chunk values: ¥360, ¥200, ¥440, ¥420, ¥735, ¥330, and ¥1820, then Erika ¥2871. The other trainers in the tables are on open rays this line does not use. Stepping on one of those cells starts that fight. The Fearow 34 sample in `lane-k-vermilion-to-celadon.md` is a different party.

Leave the Power Plant, the Pokémon Tower, and both Saffron gates. Route 5 south of Cerulean is the Saffron side. Route 12 is still closed by Snorlax.

## Cerulean

From `(0, 18)` the east edge is not reachable. The column at x=35, foot `$55`, and the one-way down ledges at `(32, 18)`, `(33, 18)`, `(34, 18)`, and `(37, 18)` keep the Route 9 road on the other side. `maps/CeruleanCity.blk` has the same feet. The opening is the tree at `(19, 28)`, foot `$3d`, block `$32`. `CutTreeBlockSwaps` replaces `$32` with `$6D`, and `fieldMoveMaps/CeruleanCity.json` changes that one cell to `2c-2c-2c-2c`. The open cell beside it is `(19, 27)`.

1. Down 1, to `(0, 19)`.
2. Right 5, to `(5, 19)`.
3. Down 7, to `(5, 26)`.
4. Right 5, to `(10, 26)`.
5. Down 1, to `(10, 27)`.
6. Right 9, to `(19, 27)`.
7. Face down. Cut.

Then the east road:

1. Down 2, to `(19, 29)`.
2. Right 17, to `(36, 29)`.
3. Up 12, to `(36, 17)`.
4. Right 3, to `(39, 17)`.
5. Right again. Route 9's west connection lands on `(0, 9)`, still facing right. `(39, 16)` would land on `(0, 8)`.

## Route 9

The entrance pocket is nine cells until the tree at `(5, 8)`. Foot `$3d`, block `$35`, replacement `$4C`. Stand on `(4, 8)` and face right.

1. Up 1, to `(0, 8)`.
2. Right 4, to `(4, 8)`.
3. Face right. Cut.
4. Right 1, to `(5, 8)`.
5. Down 1, to `(5, 9)`.
6. Right 5, to `(10, 9)`.
7. Down 1, to `(10, 10)`. The Jr. Trainer at `(13, 10)` faces left with range 3, so `(12, 10)`, `(11, 10)`, and `(10, 10)` are her ray. Oddish 18, Bellsprout 18, Oddish 18, Bellsprout 18. ¥360.
8. Down. `(10, 10)` is a ledge, so the step lands on `(10, 12)`.
9. Right 10, to `(20, 12)`.
10. Up 1, to `(20, 11)`.
11. Right 8, to `(28, 11)`.
12. Down 1, to `(28, 12)`.
13. Right 13, to `(41, 12)`.
14. Up 3, to `(41, 9)`.
15. Up 1, to `(41, 8)`. The Bug Catcher at `(40, 8)` faces right with range 2, so `(41, 8)` and `(42, 8)` are his ray. Caterpie 20, Weedle 20, Venonat 20. ¥200.
16. Up 1, to `(41, 7)`.
17. Left 2, to `(39, 7)`.
18. Up 3, to `(39, 4)`.
19. Right 5, to `(44, 4)`.
20. Up 1, to `(44, 3)`.
21. Right 6, to `(50, 3)`.
22. Down 1, to `(50, 4)`.
23. Down. Ledge, landing `(50, 6)`.
24. Down 1, to `(50, 7)`.
25. Right 1, to `(51, 7)`.
26. Down 1, to `(51, 8)`.
27. Right 8, to `(59, 8)`.
28. Right again. Route 10 `(0, 8)`, facing right.

The other Route 9 rays, all open, are off this line:

| Trainer | Ray | Party |
| --- | --- | --- |
| Jr. Trainer `(24, 7)` left 2 | `(23, 7)` `(22, 7)` | Growlithe 21, Charmander 21 |
| Jr. Trainer `(31, 7)` right 4 | `(32, 7)` through `(35, 7)` | Rattata 19, Diglett 19, Ekans 19, Sandshrew 19 |
| Jr. Trainer `(48, 8)` right 2 | `(49, 8)` `(50, 8)` | Meowth 23 |
| Hiker `(16, 15)` left 2 | `(15, 15)` `(14, 15)` | Machop 20, Onix 20 |
| Hiker `(43, 3)` left 3 | `(42, 3)` `(41, 3)` `(40, 3)` | Geodude 20, Machop 20, Geodude 20 |
| Bug Catcher `(22, 2)` down 4 | `(22, 3)` `(22, 4)` `(22, 5)` | two Beedrill 19 |
| Hiker `(45, 15)` right 2 | `(46, 15)` `(47, 15)` | Geodude 21, Onix 21 |

`(22, 6)` is solid, so that Bug Catcher's fourth cell never opens. `(41, 3)` is the Hiker's ray. The walk uses `(39, 4)` and `(44, 4)` and stays off it. `(50, 8)` is the Jr. Trainer's ray. The walk uses `(51, 8)`.

## Route 10, then the tunnel

1. Down 1, to `(0, 9)`.
2. Right 2, to `(2, 9)`.
3. Down 1, to `(2, 10)`.
4. Down. Ledge, landing `(2, 12)`.
5. Down 1, to `(2, 13)`.
6. Right 8, to `(10, 13)`.
7. Down 2, to `(10, 15)`.
8. Right 4, to `(14, 15)`.
9. Down 5, to `(14, 20)`.
10. Left 3, to `(11, 20)`.
11. Up, onto the door `(11, 19)`, foot `$1b`. The Center is not a door tileset, so the arrival stays on `(3, 7)` facing up.
12. Up 4, to `(3, 3)`. Face is already up. Talk to the nurse.
13. Down 3, to `(3, 6)`.
14. Down, onto `(3, 7)`. The outdoor door steps out to `(11, 20)` facing down.

The tunnel door is `(8, 17)`, foot `$58`. The four trees at `(9, 18)`, `(9, 20)`, `(9, 22)`, and `(9, 24)` are block `$35`, the same `$35` to `$4C` swap. This line goes around them.

1. Left 1, to `(10, 20)`.
2. Down 5, to `(10, 25)`.
3. Left 1, to `(9, 25)`. The tree is the cell above.
4. Down 1, to `(9, 26)`.
5. Left 6, to `(3, 26)`.
6. Up 8, to `(3, 18)`.
7. Right 5, to `(8, 18)`.
8. Up, onto `(8, 17)`. Rock Tunnel 1F `(15, 3)`, facing up. Cavern warps stay on the warp tile.

The Jr. Trainer at `(7, 25)` faces left with range 3. Her open ray is `(6, 25)`, `(5, 25)`, and `(4, 25)`. The walk uses `(9, 25)` and `(3, 26)`.

## Rock Tunnel

1F, missing every ray:

1. Down 4, to `(15, 7)`.
2. Right 16, to `(31, 7)`.
3. Down 1, to `(31, 8)`.
4. Right 3, to `(34, 8)`.
5. Up 5, to `(34, 3)`.
6. Right 2, to `(36, 3)`.
7. Right, onto `(37, 3)`. B1F `(33, 25)`, facing right.

B1F. The Hiker at `(33, 5)` faces right. Leave him by going left from the arrival.

1. Left 5, to `(28, 25)`.
2. Down 5, to `(28, 30)`.
3. Left 1, to `(27, 30)`.
4. Down 4, to `(27, 34)`.
5. Left 2, to `(25, 34)`.
6. Up 1, to `(25, 33)`.
7. Left 8, to `(17, 33)`.
8. Up 4, to `(17, 29)`.
9. Up 1, to `(17, 28)`. The Jr. Trainer at `(14, 28)` faces right with range 4, so `(15, 28)` through `(18, 28)` are her ray. Oddish 22, Bulbasaur 22. ¥440.
10. Up 4, to `(17, 24)`.
11. Right 3, to `(20, 24)`.
12. Up 2, to `(20, 22)`.
13. Left 3, to `(17, 22)`.
14. Up 1, to `(17, 21)`.
15. Left 3, to `(14, 21)`.
16. Up 3, to `(14, 18)`.
17. Left 1, to `(13, 18)`.
18. Up 1, to `(13, 17)`.
19. Left 1, to `(12, 17)`.
20. Left 1, to `(11, 17)`. The Jr. Trainer at `(11, 13)` faces down with range 4, so `(11, 14)` through `(11, 17)` are her ray. Jigglypuff 21, Pidgey 21, Meowth 21. ¥420.
21. Left 3, to `(8, 17)`.
22. Up 1, to `(8, 16)`.
23. Left 1, to `(7, 16)`.
24. Up 3, to `(7, 13)`.
25. Left 1, to `(6, 13)`. The Hiker at `(6, 10)` faces down with range 3, so `(6, 11)` through `(6, 13)` are his ray. Geodude 21, Geodude 21, Graveler 21. ¥735.
26. Left 2, to `(4, 13)`.
27. Up 9, to `(4, 4)`.
28. Left 1, to `(3, 4)`.
29. Up, onto `(3, 3)`. 1F `(37, 17)`, facing up.

South to the Route 10 door, still on 1F:

1. Left 5, to `(32, 17)`.
2. Down 6, to `(32, 23)`.
3. Right 5, to `(37, 23)`.
4. Down 2, to `(37, 25)`.
5. Left 5, to `(32, 25)`.
6. Down 3, to `(32, 28)`.
7. Left 6, to `(26, 28)`.
8. Up 1, to `(26, 27)`.
9. Left 3, to `(23, 27)`.
10. Down 2, to `(23, 29)`.
11. Left 2, to `(21, 29)`.
12. Up 2, to `(21, 27)`.
13. Left 6, to `(15, 27)`.
14. Down 5, to `(15, 32)`.
15. Down, onto `(15, 33)`. Route 10's door is `(8, 53)`, foot `$58`, and the step-out is `(8, 54)` facing down.

1F rays this line does not use:

| Trainer | Ray | Party |
| --- | --- | --- |
| Hiker `(7, 5)` down 4 | `(7, 6)` through `(7, 9)` | Geodude 19, Machop 19, Geodude 19, Geodude 19 |
| Hiker `(5, 16)` down 4 | `(5, 17)` through `(5, 20)` | Onix 20, Onix 20, Geodude 20 |
| Hiker `(17, 15)` left 3 | `(16, 15)` `(15, 15)` `(14, 15)` | Geodude 21, Graveler 21 |
| Pokémaniac `(23, 8)` left 3 | `(22, 8)` `(21, 8)` `(20, 8)` | Cubone 23, Slowpoke 23 |
| Jr. Trainer `(37, 21)` left 4 | `(36, 21)` through `(33, 21)` | Bellsprout 22, Clefairy 22 |
| Jr. Trainer `(22, 24)` down 4 | `(22, 25)` through `(22, 28)` | Meowth 20, Oddish 20, Pidgey 20 |
| Jr. Trainer `(32, 24)` right 4 | `(33, 24)` through `(36, 24)` | Pidgey 19, Rattata 19, Rattata 19, Bellsprout 19 |

`(32, 23)` and `(37, 23)` are the row above that last ray. `(23, 27)` and `(21, 27)` are beside the down ray at x=22.

B1F rays this line does not use:

| Trainer | Ray | Party |
| --- | --- | --- |
| Pokémaniac `(3, 5)` down 3 | `(3, 6)` through `(3, 8)` | three Slowpoke 20 |
| Pokémaniac `(20, 21)` right 4 | `(21, 21)` through `(24, 21)` | Charmander 22, Cubone 22 |
| Hiker `(30, 10)` down 3 | `(30, 11)` through `(30, 13)` | Geodude 25 |
| Hiker `(33, 5)` right 3 | `(34, 5)` through `(36, 5)` | Machop 20, Onix 20 |
| Pokémaniac `(26, 30)` down 3 | `(26, 31)` through `(26, 33)` | Slowpoke 25 |

`(20, 22)` is the cell under the Charmander ray. The walk turns there and goes left.

## Lavender, Route 8, the underground, Route 7

Route 10 south of the tunnel. The Jr. Trainer at `(7, 54)` faces down onto `(7, 55)` and `(7, 56)`. The Hiker at `(3, 57)` faces up onto `(3, 54)` through `(3, 56)`. The Hiker at `(3, 61)` faces down onto `(3, 62)` and `(3, 63)`. The Pokémaniac at `(14, 64)` faces left onto `(13, 64)` through `(10, 64)`. The walk uses the column x=14 and then x=15.

1. Right 2, to `(10, 54)`.
2. Down 1, to `(10, 55)`.
3. Right 4, to `(14, 55)`.
4. Down 1, to `(14, 56)`.
5. Down. Ledge, landing `(14, 58)`.
6. Down 2, to `(14, 60)`.
7. Down. Ledge, landing `(14, 62)`.
8. Down 1, to `(14, 63)`.
9. Right 1, to `(15, 63)`.
10. Down 2, to `(15, 65)`.
11. Left 5, to `(10, 65)`.
12. Down 1, to `(10, 66)`.
13. Down. Ledge, landing `(10, 68)`.
14. Left 1, to `(9, 68)`.
15. Down 3, to `(9, 71)`.
16. Down. Lavender `(9, 0)`, facing down.

Lavender Center is the door `(3, 5)`.

1. Left 3, to `(6, 0)`.
2. Down 6, to `(6, 6)`.
3. Left 3, to `(3, 6)`.
4. Up, onto `(3, 5)`. Arrival `(3, 7)` facing up.
5. Up 4, to `(3, 3)`. Talk to the nurse.
6. Down 3, to `(3, 6)`, then down onto the door. Outside `(3, 6)` facing down.
7. Left 3, to `(0, 6)`.
8. Down 2, to `(0, 8)`.
9. Left. Route 8 `(59, 8)`, facing left.

Route 8. One sight fight, then the underground door `(13, 3)`.

1. Left 7, to `(52, 8)`.
2. Down 5, to `(52, 13)`.
3. Left 5, to `(47, 13)`.
4. Up 1, to `(47, 12)`. The Lass at `(51, 12)` faces left with range 4, so `(50, 12)` through `(47, 12)` are her ray. Two Clefairy 22. ¥330.
5. Left 5, to `(42, 12)`.
6. Up 3, to `(42, 9)`.
7. Left 1, to `(41, 9)`.
8. Up 2, to `(41, 7)`.
9. Left 1, to `(40, 7)`.
10. Up 1, to `(40, 6)`.
11. Left 11, to `(29, 6)`.
12. Down 1, to `(29, 7)`.
13. Left 6, to `(23, 7)`.
14. Down 3, to `(23, 10)`.
15. Left 1, to `(22, 10)`.
16. Down 2, to `(22, 12)`.
17. Left 8, to `(14, 12)`.
18. Up 8, to `(14, 4)`.
19. Left 1, to `(13, 4)`.
20. Up, onto `(13, 3)`. Underground Path Route 8, played `(5, 7)`, facing up. That room's padding is 2, and `(5, 7)` is the bottom row, so the door does not step down.

The Gambler at `(13, 9)` faces up. His ray is `(13, 8)` through `(13, 5)`. `(13, 4)` is the cell above that ray, which is where the walk turns into the door. The other Route 8 rays stay off this line: Super Nerd `(8, 5)` right through `(12, 5)`, Super Nerd `(42, 6)` up through `(42, 2)`, Lass `(26, 3)` left to `(24, 3)`, Super Nerd `(26, 4)` right to `(29, 4)`, Lass `(26, 5)` left to `(23, 5)`, Lass `(26, 6)` right to `(28, 6)`, Gambler `(46, 13)` down to `(46, 15)`. The two Route 8 trees, `(41, 10)` and `(29, 12)`, are real `$35` trees. This line does not stand on them.

Through the path:

1. Up 2, to `(5, 5)`.
2. Right 1, to `(6, 5)`.
3. Up, onto `(6, 4)`. West-east path `(47, 2)`, facing up.
4. Left 45, to `(2, 2)`.
5. Down 2, to `(2, 4)`.
6. Down, onto `(2, 5)`. Route 7 entrance, played `(6, 4)`, facing down.
7. Down 2, to `(6, 6)`.
8. Down, onto `(6, 7)`. Route 7 `(5, 14)`, facing down. That outdoor door does step out.

Route 7 to Celadon:

1. Right 3, to `(8, 14)`.
2. Up 5, to `(8, 9)`.
3. Left 4, to `(4, 9)`.
4. Up 3, to `(4, 6)`.
5. Left 2, to `(2, 6)`.
6. Up 3, to `(2, 3)`.
7. Left 2, to `(0, 3)`.
8. Left. Celadon `(49, 11)`, facing left. `(0, 2)` would land on `(49, 10)`.

## Celadon and Erika

The Center door is `(41, 9)`.

1. Left 8, to `(41, 11)`.
2. Up 1, to `(41, 10)`.
3. Up, onto `(41, 9)`. Arrival `(3, 7)` facing up.
4. Up 4, to `(3, 3)`. Talk to the nurse.
5. Down 3, to `(3, 6)`, then down onto the door. Outside `(41, 10)` facing down.

The gym door `(12, 27)` is past the tree at `(35, 32)`, foot `$3d`, block `$32`, replacement `$6D`. The other city tree, `(47, 20)`, block `$35`, is on the east side and this line leaves it.

1. Left 5, to `(36, 10)`.
2. Down 12, to `(36, 22)`.
3. Left 10, to `(26, 22)`.
4. Down 1, to `(26, 23)`.
5. Left 1, to `(25, 23)`.
6. Down 8, to `(25, 31)`.
7. Right 10, to `(35, 31)`.
8. Face down. Cut `(35, 32)`.
9. Down 3, to `(35, 34)`.
10. Left 30, to `(5, 34)`.
11. Up 5, to `(5, 29)`.
12. Right 7, to `(12, 29)`.
13. Up 1, to `(12, 28)`.
14. Up, onto `(12, 27)`. Celadon Gym played `(5, 17)`, facing up. The gym warp is source `(4, 17)` plus the left pad.

The gym's three cut trees, source coordinates in the object file and played coordinates on the live grid:

| Source | Played | Block | Replacement | After |
| --- | --- | --- | --- | --- |
| `(2, 4)` | `(3, 4)` | `$3C` | `$35` | foot `$2b`, which `Gym_Coll` allows |
| `(7, 5)` | `(8, 5)` | `$3D` | `$36` | `$2b` |
| `(5, 7)` | `(6, 7)` | `$3F` | `$35` | `$2b` |

`maps/CeladonGym.blk` has foot `$50` on all three. `$50` is absent from `Gym_Coll`, so each one is solid until that swap. This line cuts the west tree only. The other two stay solid. That matches the block map.

Played rays. Erika at `(5, 3)` faces down with range 0. She stays put until A.

| Trainer | Played ray | Party |
| --- | --- | --- |
| Lass `(3, 11)` right 2 | `(4, 11)` `(5, 11)` | Bellsprout 23, Weepinbell 23 |
| Beauty `(8, 10)` left 2 | `(7, 10)` `(6, 10)` | Oddish 21, Bellsprout 21, Oddish 21, Bellsprout 21 |
| Jr. Trainer `(10, 5)` down 4 | `(10, 6)` through `(10, 9)` | Bulbasaur 24, Ivysaur 24 |
| Beauty `(2, 5)` down 4 | `(2, 6)` through `(2, 9)` | two Bellsprout 24 |
| Lass `(7, 3)` down 2 | `(7, 4)` `(7, 5)` | Oddish 23, Gloom 23 |
| Beauty `(4, 3)` down 2 | `(4, 4)` `(4, 5)` | Exeggcute 26 |
| Cooltrainer `(6, 3)` down 3 | `(6, 4)` through `(6, 6)` | Weepinbell 24, Gloom 24, Ivysaur 24 |

The west aisle is x=1, which is beside the Beauty at `(2, 5)` and short of her ray.

1. Left 3, to `(2, 17)`.
2. Up 7, to `(2, 10)`.
3. Left 1, to `(1, 10)`.
4. Up 6, to `(1, 4)`.
5. Right 1, to `(2, 4)`.
6. Face right. Cut `(3, 4)`.
7. Right 1, to `(3, 4)`.
8. Right 1, to `(4, 4)`. The Beauty at `(4, 3)` walks down. Exeggcute 26. ¥1820.
9. Right 1, to `(5, 4)`.
10. Face up. A talks to Erika at `(5, 3)`. Victreebel 29, Tangela 24, Vileplume 29. ¥2871.

`(5, 4)` is off every other ray. `(4, 5)` is the Beauty's second cell. `(2, 6)` through `(2, 9)` are the other Beauty. `(4, 11)` and `(5, 11)` are the Lass by the south tree.
