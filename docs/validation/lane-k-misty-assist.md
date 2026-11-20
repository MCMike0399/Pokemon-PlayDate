# Misty assist for J

Lane K `6487d93e` contains main `84a8d45e`. J is `cursor/lane-j-squirtle` `45116a70`. Resume save `e0f8ae50d17a/adventure.a.json`, sha256 `9607c066…c4f9b`, was not in this workspace. The fight below uses the stated party: Wartortle 17, 232 money, no Potions, Cerulean `(25, 26)`. Stats are the engine's 0 IV / 0 EV floor. Real IVs or EVs only raise Bite.

No Source change. No lane-e patch. The host pin is `tools/tests/test_lane_k_misty_assist.py`.

## Fidelity

pret/pokered `af519899`. Misty's party is Staryu 18 and Starmie 21. Pokered level-up sets are Tackle + Water Gun, and Tackle + Water Gun + Harden. Neither learns Recover or Bubblebeam by level. Pokered MistyAI rolls an X Defend about one time in four and never uses a Potion. `move_choices` for MISTY is `1, 3`.

This game matches the AI class and the item rule. `trainerLayers.MISTY` is `{1, 3}`. There is no enemy item. Two hundred turns with Starmie at 1 HP still split Swift and Recover, and Water Gun was never chosen. Crits are the Gen V 1/16. Pokered Starmie crits from speed 115, about 57/256, which is higher. The damage roll is 85–100, the same band as pokered. Gen V special defense makes her Water Gun weaker into Wartortle than pokered's single Special: at level 17 it is 3–4, not a KO.

The moves are the B2W2 list kept by `Pokemon.trainerMovesFor`, with ids above 165 dropped. That is the standing learnset rule.

| Pokémon | This game | Pokered |
| --- | --- | --- |
| Staryu 18 | Harden, Water Gun, Recover, Swift | Tackle, Water Gun |
| Starmie 21 | Water Gun, Recover, Swift | Tackle, Water Gun, Harden |
| Wartortle 17 | Bubble, Withdraw, Water Gun, Bite | Bite is level 24 there |

Starmie has 56 HP. Recover heals 28. Harden only raises her Defense and is not on this Starmie. Bubblebeam and Tackle are not in the fight. Bite is Dark here, so it is 2× into Water/Psychic: 12–16 at level 17, 18–22 at level 20. Swift back into a level 20 Wartortle is 14–17, and a crit doubles that.

That Recover is why both blackouts stopped at 1 HP. A heal of 28 erases two level-17 Bites, and she outspeeds. Nothing in the formula, the crit rate, or the item AI is stronger than pokered.

## Do this

Do not walk back into the gym at level 17.

1. From the Mart step-out `(25, 26)`, go north to Cerulean `(20, 0)` or `(21, 0)`. That is Route 24 `(10, 35)` or `(11, 35)`. If BLUE is still on `(20, 6)` or `(21, 6)`, fight him on the way. His Squirtle-rival team is the extra XP, not a detour to skip.
2. Walk the bridge north and fight every trainer in `lane-k-squirtle-nugget-bill-vermilion.md`, including the Jr.Trainer♂ at `(5, 20)` (Rattata 14, Ekans 14). He stands off the main line. The main line alone ends at level 19 with 37 XP short of 20. Adding him ends the bridge at level 20. Step on `(10, 15)` for the Nugget, then fight that Rocket (Ekans 15, Zubat 15).
3. Return to the Cerulean Mart, door `(25, 25)`. Sell the Nugget. The shop pays 5000, not 2500. Money is at least 5232.
4. Buy 8 Potions at 300. That is 2400, and at least 2832 is left. Each heals 20. This Mart does not stock Super Potions. Those are 700 and start at Vermilion. The trip is not required.
5. Enter the gym from `(30, 20)` north onto `(30, 19)`, then the indoor walk in `lane-k-cerulean-gym-door.md`. The Cooltrainer♀ at `(2, 3)` sees `(5, 3)`. Goldeen 19 is worth 346 XP at level 20, which does not reach 21. Expect Misty at level 20.

## Move order

Bite only, on both of hers. Water Gun is 3–4 into Starmie. Bubble is worse. Withdraw gives her a free Recover.

She moves first. Potion on your turn when HP is 34 or lower, so a critical Swift does not KO. A normal Swift is 14–17. Eight Potions cover her and the Staryu before her. In a 200-fight sample at level 20 with six Potions, Starmie fell 192 times and the wins spent about one Potion. Level 17 with ten Potions fell to 152 of 200. That is the same 1 HP pattern.

If Staryu Hardens, keep Biting. A crit ignores the Defense stage. If Starmie Recovers at 1 HP, the next Bite still goes through 28 of the 56. Do not change moves. Bite has 25 PP, and level 20 outruns the ten Recovers.
