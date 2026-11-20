# Misty assist for J

Lane K tip after this note is the commit that adds it. It contains main `84a8d45e`. J is `cursor/lane-j-squirtle` `45116a70`. The save `e0f8ae50d17a/adventure.a.json` (`9607c066…c4f9b`) was not in this workspace. Wartortle is level 17, money is 232, there are no Potions, and the player is on Cerulean `(25, 26)`. Damage uses the engine's 0 IV / 0 EV floor.

No Source edit. The B2W2 trainer moves are drift. Gen V covers battle rules only.

## Drift

pret/pokered `af519899`. `MistyData` is `db $FF, 18, STARYU, 21, STARMIE`. Staryu's level-1 move is Tackle, then Water Gun at 17. Harden is 22, Recover is 27, Swift is 32. Starmie's level-1 moves are Tackle, Water Gun, and Harden, and `StarmieEvosMoves` adds nothing. `LoneMoves` entry 2 is `db 1, BUBBLEBEAM`. `wGymLeaderNo` is 2 for Misty, and that byte is `wLoneAttackNo`. AddNTimes from the first Pokémon's third move lands on Starmie and replaces Harden.

| Pokémon | Faithful set | Current send-out |
| --- | --- | --- |
| Staryu 18 | Tackle, Water Gun | Harden, Water Gun, Recover, Swift |
| Starmie 21 | Tackle, Water Gun, Bubblebeam | Water Gun, Recover, Swift |

`Pokemon.trainerMovesFor` returns `initialMovesFor`, which walks the B2W2 learnset and drops ids above 165. Recover and Swift are inside that cap. The same B2W2 table feeds wild and gift construction (`Pokemon:init`), starter construction (the same function), and level-up (`gainXP` through `learnsetEntriesFor`). Daycare and evolution call `learnsetEntriesFor` too. The codec checks a pending choice against that B2W2 row. Charmander 15 is Scratch, Growl, Ember, Smokescreen here and Scratch, Growl, Ember, Leer in pokered. Staryu gaining level 17 is offered nothing here and Water Gun there.

Crits stay 1/16. The damage roll stays 85–100. Misty's class layers stay `{1, 3}`, and she still has no item. Those are not stronger than pokered. The learnset is.

Apply `tools/notes/lane-e-trainer-movesets.patch` first. It adds the generated `Source/data/pokeredLearnsets.lua` and teaches trainer send-out WriteMonMoves, then LoneMoves and TeamMoves. `tools/notes/lane-e-pokered-learnsets.patch` does not apply until that file and the new `trainerMovesFor` arguments exist. The sibling points wild, gift, starter, level-up, daycare, evolution, and the choice codec at the same table. `tools/generate_pokered_learnsets.py` is the only writer of that table.

`test_lane_e_trainer_fifo.py` and the 165-cap asserts in `test_lane_e_bruno_hitmonlee.py` still describe the current cap. They pass on this tree and will need to move when the sibling lands. Bruno's Hitmonlee row in `redPartyMoves.lua` already matches the pokered four.

## What J's build does today

`45116a70` still has the drifted Starmie. Bubblebeam is not the move that ended the two fights. Recover is, until the trainer patch is in the build. Do not walk back in on that build with the faithful plan below.

## Faithful fight

Once the sets are corrected, both of hers use Tackle on every sample turn. Water Gun and Bubblebeam are resisted, and layer 3 keeps the neutral Tackle. Bubblebeam's own roll into this Wartortle is 12–15. It was not selected in 100 turns. Starmie Tackle is 11–13. Wartortle Bite into Starmie is 12–16. Starmie has 56 HP and outspeeds. There is no Recover.

A 200-fight sample at level 17:

| Potions | Wins | Used on the wins |
| --- | ---: | --- |
| 0 | 0/200 | |
| 2 | 163/200 | 2 |
| 3 | 200/200 | about 3 |

Potion when HP is 26 or lower. A critical Tackle is double 11–13. Bite only. Water Gun is 3–4 into Starmie.

J cannot buy a Potion yet. One costs 300 and the bag has 232. The seven Route 24 trainers pay 1890 (`sourceSlice/trainers.json`): Bug Catcher 140, Lass 210, Youngster 210, Lass 240, Jr.Trainer♂ 360, the off-line Jr.Trainer♂ 280, Rocket 450. After them the money is 2122, and the bridge still ends at level 20 if that off-line trainer is fought. At level 20 the same sample won 199/200 with one Potion and 200/200 with two.

1. From `(25, 26)`, go north to `(20, 0)` or `(21, 0)` and clear the bridge, including `(5, 20)`.
2. Buy 4 Potions at the Cerulean Mart `(25, 25)`. That is 1200, and about 922 is left. The Nugget from `(10, 15)` sells for 5000 and is not required for these four.
3. Enter from `(30, 20)` onto `(30, 19)`. The gym door note has the indoor steps. Goldeen does not change the plan.
4. Bite. Potion at 26 HP or below. Expect level 20 and 4 Potions, with two of them enough in the sample.
