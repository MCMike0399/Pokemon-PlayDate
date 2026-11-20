# S.S. Anne rival

Main is still `fe6376b9`. The champion-rival patch and the Hyper Beam recharge patch are not on it. J is `cursor/lane-j-squirtle` `2276d20b`. The resume is sequence 19, `de26045b6d06/adventure.a.json`, sha256 `51ade10899094ca5582d70e13e6664bb0fe9adff6b95c19036ed86770c32a4e3`. That file is not on this disk. The note puts Wartortle at level 25, 67 HP, Tackle, Water Gun, Bubble, and Bite, outside the Vermilion Center at `(11, 4)`. The blackout was not written.

pret/pokered `af519899`. A Squirtle player has rival starter Bulbasaur. `SSAnne2F.asm` loads `OPP_RIVAL2` and, for `wRivalStarter == STARTER3`, trainer `$2`. That row in `Rival2Data` is `db $FF, 19, PIDGEOTTO, 16, RATICATE, 18, KADABRA, 20, IVYSAUR`. `Source/data/vermilionStory/trainers.json` uses the same four for `rival_parties.squirtle`. No Source change.

| Pokémon | Pokered moves at that level |
| --- | --- |
| Pidgeotto 19 | Gust, Sand Attack, Quick Attack |
| Raticate 16 | Tackle, Tail Whip, Quick Attack, Hyper Fang |
| Kadabra 18 | Teleport, Confusion, Disable |
| Ivysaur 20 | Tackle, Growl, Leech Seed, Vine Whip |

Kadabra's level-1 moves are Teleport, Confusion, and Disable. Disable at 20 is the same move again, so level 18 already has it. Ivysaur's level-1 moves are Tackle, Growl, and Leech Seed, and Vine Whip is 13. Poison Powder is 22, so it is not in this set. The live `Pokemon.trainerMovesFor` rows match those four. J's Disable, then Confusion, then Vine Whip and Leech Seed are on this party.

The send order is Pidgeotto, Raticate, Kadabra, Ivysaur. The engine does not skip the first two. The writeup starts at Kadabra. A Wartortle that begins level 25 on the level floor (`xp` 11735, next 13411) gains 517, 429, and 531 from the first three and is still level 25, 199 short. Ivysaur's 672 is the KO that reaches 26 from that floor. Growing when Kadabra faints means at least 199 XP was already inside the level, which is what those two KOs leave. The clip is not on this disk.

Damage samples use the engine, seeds 1 onward, 0 IV / 0 EV. That Wartortle has 64 HP. J's healed 67 is three above this floor. Super Potion heals 50 and costs 700. The Vermilion Mart sells it. The lost walk bought 8 Poké Balls and 6 Super Potions and had 3745 left, so sequence 19 still holds the money from before that buy.

## The rival

Bite only, from level 25, potion at 26 HP, 6 Super Potions: 112/200. That is the blackout. Ivysaur was left at 6 HP.

Kadabra's Speed is 42 and Wartortle's is 34, so Kadabra moves first. Disable locks the last move that landed, for 4 residual turns if Wartortle still has an action that round, otherwise 5. The first Disable fails when Wartortle has not moved yet. After Bite lands, the next Disable locks Bite. Use Tackle until the "no longer disabled" line. Do not confirm the disabled move.

Catch on Route 6. English Blue grass is Bellsprout at 13, 15, and 16, and Pidgey at 13, 15, and 16. The same Blue tables put Bellsprout on Routes 5, 24, and 25. Bellsprout is the Blue Cut user. HM01 is the captain's reward after this fight, so the catch waits in the party until then.

Level the Pidgey to Pidgeotto 19. Its moves are Gust, Sand Attack, and Quick Attack, and its Speed is 31 against Ivysaur's 29. Gust only. Do not grind to 21: that adds Whirlwind.

Buy 4 Super Potions. Board again. The trigger is 2F `(36, 8)`.

1. Wartortle leads. Bite Pidgeotto and Raticate. Potion when Wartortle's HP is 30 or lower.
2. Bite Kadabra. If Bite is disabled, Tackle.
3. On the shift question for Ivysaur, switch to Pidgeotto. Gust. Vine Whip is resisted. Leech Seed still sticks. Potion at 30.

Pidgeotto 19, Gust, 4 Super Potions, threshold 30: 195/200, about 2.2 potions on the wins. Pidgeotto 18 was 93/100. A Route 11 Spearow evolved to Fearow 20, Peck only, was 100/100 and used about 1 potion. Spearow 19, before that evolution, was not this plan.

Then the captain, HM01, and Cut on Bellsprout.

## Lt. Surge

`LtSurgeData` is Voltorb 21, Pikachu 18, Raichu 24. Pokered moves:

| Pokémon | Moves |
| --- | --- |
| Voltorb 21 | Tackle, Screech, Sonic Boom |
| Pikachu 18 | Thunder Shock, Growl, Thunder Wave, Quick Attack |
| Raichu 24 | Thunder Shock, Growl, Thunderbolt |

Sonic Boom still deals 20. Thunderbolt does not. Wartortle 26 using Bite, 8 Super Potions, threshold 30: 0/100.

The Center walk reaches the east edge at `(39, 14)` and `(39, 15)`, toward Route 11. Diglett's Cave is Diglett 15–22 and Dugtrio 29 and 31. Diglett 22 knows Scratch, Growl, and Dig. Dugtrio 26 knows Scratch, Growl, Dig, and Sand Attack. Dig only. Electric moves, including Thunderbolt and Thunder Wave, do not hit Ground. Diglett 22, Dig, potion at 20, 6 Super Potions: 99/100, under 1 potion on the wins. Dugtrio 26, Dig, no potion: 100/100.

The Gym door `(12, 19)` is still the 42-tile pocket in `lane-k-squirtle-nugget-bill-vermilion.md`. `(12, 20)` is in that pocket. The Center, the Mart, the dock, and the east edge are not. The step onto the door is down from `(12, 20)` once the walk is in the pocket.
