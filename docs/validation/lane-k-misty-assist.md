# Misty

Main `fe6376b9` sends the pokered sets. The source commit is `2e6f3bfb`. Pret/pokered `af519899`. `MistyData` is `db $FF, 18, STARYU, 21, STARMIE`. Staryu is Tackle, then Water Gun at 17. Starmie's level-1 moves are Tackle, Water Gun, and Harden. `LoneMoves` entry 2 is `db 1, BUBBLEBEAM`, and Misty's gym number is 2, so Bubblebeam replaces Starmie's third move.

| Pokémon | Send-out |
| --- | --- |
| Staryu 18 | Tackle, Water Gun |
| Starmie 21 | Tackle, Water Gun, Bubblebeam |

J is `cursor/lane-j-squirtle` `45116a70`. That tip does not contain `2e6f3bfb`, so this fight is the one after that commit is in the build. The resume file `e0f8ae50d17a/adventure.a.json` (`9607c066…c4f9b`) was not on this disk. The gym-fail bag had no Potions and 232. The lane-j note on that tip says the same resume holds eight Potions. The file was not re-read here.

Damage is the engine's 0 IV / 0 EV floor. Crits stay 1/16. The roll stays 85–100. Misty's class layers stay `{1, 3}`, and she has no item.

## The fight

Both of hers use Tackle. Water Gun and Bubblebeam are resisted, and layer 3 keeps the neutral Tackle. Bubblebeam's own roll into this Wartortle is 12–15. It was not selected in 100 turns. Starmie Tackle is 11–13. Wartortle Bite into Starmie is 12–16. Starmie has 56 HP and outspeeds. There is no Recover.

A 200-fight sample at level 17, potion when HP is 26 or lower, Bite only:

| Potions | Wins | Used on the wins |
| --- | ---: | --- |
| 0 | 0/200 | |
| 2 | 163/200 | 2 |
| 3 | 200/200 | about 3 |

Water Gun is 3–4 into Starmie. A critical Tackle is double 11–13.

If the bag is still empty, one Potion costs 300 and 232 cannot buy it. The seven Route 24 trainers pay 1890 (`sourceSlice/trainers.json`): Bug Catcher 140, Lass 210, Youngster 210, Lass 240, Jr.Trainer♂ 360, the off-line Jr.Trainer♂ 280, Rocket 450. After them the money is 2122. That bridge, including `(5, 20)`, ends at level 20. At level 20 the same sample won 199/200 with one Potion and 200/200 with two.

1. From `(25, 26)`, go north to `(20, 0)` or `(21, 0)` and clear the bridge, including `(5, 20)`, when the bag has fewer than three Potions.
2. Buy until the bag has 4. Four cost 1200, and about 922 is left from 2122. The Nugget at `(10, 15)` sells for 5000 and is not required.
3. Enter from `(30, 20)` onto `(30, 19)`. The gym door note has the indoor steps. Goldeen does not change the plan.
4. Bite. Potion at 26 HP or below. Expect level 20 and 4 Potions when the bridge was required. Two were enough in the level-20 sample. Three were enough at level 17.

A settled Wartortle saved as Tackle, Water Gun, Bubble, Bite reloads those four. A pending choice written from the old table still resolves: Charmander's Smokescreen at level 10, id 108, learns into an open slot and declines without changing the moves. Bulbasaur's Poison Powder at 13, order 1, id 77, learns into an explicit slot. Neither row is in the pokered table.
