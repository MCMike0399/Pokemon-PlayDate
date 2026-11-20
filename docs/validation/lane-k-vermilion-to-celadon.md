# Vermilion to Celadon

Main is still `fe6376b9`. The champion-rival patch and the Hyper Beam recharge patch are not on it. J is `cursor/lane-j-squirtle` `2276d20b`, sequence 19 at Vermilion `(11, 4)`, Wartortle 25. The Gym door `(12, 19)` is still the separate pocket in `lane-k-squirtle-nugget-bill-vermilion.md`. This plan starts inside the Gym.

pret/pokered `af519899`. Parties below are the object roster numbers in `parties.asm`. Moves are that species' level-1 set plus `evos_moves`, and then LoneMoves for the two leaders. Samples are the engine, seeds 1 onward, 0 IV / 0 EV. Super Potion heals 50.

The team is Wartortle 28–30 (Tail Whip, Bubble, Water Gun, Bite), Bellsprout with Cut, one flyer, and Diglett or Dugtrio. Cut is required once, on the Route 2 tree at `(5, 10)`, before Pewter. The rest of this walk does not need it. Bellsprout keeps it. Flash is optional: both Rock Tunnel floors are the dark maps, and nothing in the field move stops walking. This team does not learn Flash.

## Trash cans

`GymTrashScript` has 15 cans. Vermilion Gym's padding is 1, so the played x is the source x plus 1. The source cells, left to right and top to bottom, are indexes 0 through 14:

|  | x=1 | x=3 | x=5 | x=7 | x=9 |
| --- | --- | --- | --- | --- | --- |
| y=7 | 0 | 3 | 6 | 9 | 12 |
| y=9 | 1 | 4 | 7 | 10 | 13 |
| y=11 | 2 | 5 | 8 | 11 | 14 |

The first lock is `Random` masked with `$e`: an even index, 0, 2, 4, 6, 8, 10, 12, or 14. `VermilionGym.asm` does not roll it. That script's map-load bit only calls `.LoadNames`, the city name and LT.SURGE. The roll is `VermilionCity_Script.setFirstLockTrashCanIndex`. It runs when `BIT_CUR_MAP_LOADED_1` is set, which overworld entry sets on a door and on a connection, and which a battle return and Continue set too. This build rolls on a door into Vermilion City, on the first trash check if that entry has not happened, and again when a second-can guess is wrong. It does not roll on Gym entry. A connection walk and Continue do not roll here. That narrower city trigger is the tested rule in `vermilionStoryContracts`. Leaving the Center re-rolls an unopened first lock here. Walking to Route 11 and back does not.

Check the eight even cans. Start at can 0, source `(1, 7)`. A click is the first switch. The second can is `swap(random) & mask`, then minus 1, read from `GymTrashCans`. A zero result underflows and becomes can 0. That is the same byte the engine uses.

| First can | Second can |
| --- | --- |
| 0 `(1, 7)` | 0 or 3, half each |
| 2 `(1, 11)` | 0 or 5, half each |
| 4 `(3, 9)` | 0 or 7, half each |
| 6 `(5, 7)` | 0, 3, 7, or 9, a quarter each |
| 8 `(5, 11)` | 0, 5, 7, or 11, a quarter each |
| 10 `(7, 9)` | 0 or 13, half each |
| 12 `(9, 7)` | 0 or 13, half each |
| 14 `(9, 11)` | 0 or 13, half each |

If can 0 clicked, press it again. Half the time the second lock is the same can. Otherwise press can 0 next, then the other can in that row. A wrong second can closes the first lock, rolls a new even first can, and the eight start over. The second click opens the door. Solved cans stay ordinary trash.

## Lt. Surge

| Pokémon | Moves |
| --- | --- |
| Voltorb 21 | Tackle, Screech, Sonic Boom |
| Pikachu 18 | Thunder Shock, Growl, Thunder Wave, Quick Attack |
| Raichu 24 | Thunder Shock, Growl, Thunderbolt |

Raichu's level-up third move is Thunder Wave. LoneMoves writes Thunderbolt into that slot, and this build does that. A cartridge never stores `wLoneAttackNo`, so the cartridge third move stays Thunder Wave. Sonic Boom still deals 20.

Dugtrio 26, Dig, potion at 20, 4 Super Potions: 100/100, none used. Dugtrio 28 is the same. Diglett 25, the level before it evolves: 50/50, almost none used. Electric moves, including Thunderbolt and Thunder Wave, do not hit Ground.

The same room has a Gentleman with Pikachu 23, a Rocker with Voltorb 20, Magnemite 20, and Voltorb 20, and a Sailor with two Pikachu 21. Dig is the same answer.

## The walk

The Center's east edge is `(39, 14)` and `(39, 15)`, onto Route 11. Do not keep going east for Lavender. Route 11's open east edge is y=8 and y=9. The connection adds 54, so those steps land on Route 12 at `(0, 62)` and `(0, 63)`. `(0, 63)` is solid. `(0, 62)` is the west end of Snorlax's row. He stands at `(10, 62)` until the Poké Flute fight, and the tile east of him is on the far side of that cell. No ledge leaves the pocket. The Route 12 gate is north of him, at y=15 and y=21. Its south door is the way through the building onto the north road, and that door is past him. The Route 11 gate returns to Route 11. Neither gate reaches Lavender or Rock Tunnel. The feet match pokered, so this build does not either.

Lavender is the other way. Diglett's Cave is Route 11 source `(4, 5)`. It comes out on Route 2 `(12, 9)`. The east side does not connect to Pewter until Cut on the tree at `(5, 10)`. That walk is `lane-k-route2-cave-side.md`. From Pewter, east is Route 3, Mt. Moon, Route 4, and Cerulean, then Route 9, Rock Tunnel, and Lavender. These tunnel trainers are on that walk, before Erika. Route 8's underground door is source `(13, 3)`. The west-east path comes out on Route 7, and Route 7's west edge is Celadon. The flute is in Lavender, so it cannot open Route 12 before this. The Saffron gates want a drink from the Celadon roof, which is after this. The Bike Voucher is the Fan Club in Vermilion and the bicycle is the Cerulean shop. Neither is required for Erika.

## Rock Tunnel

Wartortle 28 leads with Water Gun. Bite when the target is Slowpoke. On the shift question, send the flyer if the next Pokémon is Oddish, Bellsprout, or Bulbasaur, and send Wartortle back for anything else. Potion at 30 HP. Carry 6 Super Potions. Every trainer below was won in a 40-fight sample, and the Oddish/Bulbasaur pair was 100/100, about 4.4 potions. A Pidgeotto 25 using Gust is enough for that pair. Whirlwind is on that Pidgeotto. Do not select it.

1F, in object order:

| Trainer | Party |
| --- | --- |
| Hiker | Geodude 19, Machop 19, Geodude 19, Geodude 19. Geodude is Tackle, Defense Curl, Rock Throw. Machop is Karate Chop. |
| Hiker | Onix 20, Onix 20, Geodude 20. Onix is Tackle, Screech, Bind, Rock Throw. |
| Hiker | Geodude 21, Graveler 21. Both know Selfdestruct. |
| Pokemaniac | Cubone 23 (Bone Club, Growl), Slowpoke 23 (Confusion, Disable, Headbutt). |
| Jr. Trainer | Bellsprout 22 (Wrap, Poison Powder, Sleep Powder, Stun Spore), Clefairy 22 (Pound, Growl, Sing, Double Slap). |
| Jr. Trainer | Meowth 20 (Scratch, Growl, Bite, Pay Day), Oddish 20 (Absorb, Poison Powder, Stun Spore, Sleep Powder), Pidgey 20 (Gust, Sand Attack, Quick Attack, Whirlwind). |
| Jr. Trainer | Pidgey 19, Rattata 19, Rattata 19, Bellsprout 19. |

B1F:

| Trainer | Party |
| --- | --- |
| Jr. Trainer | Jigglypuff 21 (Sing, Pound, Disable, Defense Curl), Pidgey 21, Meowth 21. |
| Hiker | Geodude 21, Geodude 21, Graveler 21. Selfdestruct. |
| Pokemaniac | three Slowpoke 20, Confusion and Disable. |
| Pokemaniac | Charmander 22 (Growl, Ember, Leer, Rage), Cubone 22. |
| Hiker | Geodude 25. Selfdestruct. |
| Jr. Trainer | Oddish 22, Bulbasaur 22 (Growl, Leech Seed, Vine Whip, Poison Powder). |
| Hiker | Machop 20 (Karate Chop, Low Kick), Onix 20. |
| Pokemaniac | Slowpoke 25 (Confusion, Disable, Headbutt). |

## Erika

| Pokémon | Moves |
| --- | --- |
| Victreebel 29 | Razor Leaf, Wrap, Poison Powder, Sleep Powder |
| Tangela 24 | Constrict, Bind |
| Vileplume 29 | Petal Dance, Poison Powder, Mega Drain, Sleep Powder |

Vileplume's level-up third move is Stun Spore. LoneMoves writes Mega Drain there, and this build does that. The cartridge third move stays Stun Spore.

Lead Fearow 34. Its moves are Leer, Fury Attack, Mirror Move, and Drill Peck. Drill Peck only. Potion at 30, 6 Super Potions: 100/100, about none used. Sleep Powder can land. The sample won without an Awakening.

Pidgeotto 28 still has Gust and was 28/100. Peck has left Fearow by level 25, and Fearow 28 has no Drill Peck yet. Pidgeotto 31 has Wing Attack. With 10 Super Potions at HP 40 it was 89/100. The plan is the Fearow. Spearow is on Route 11. It evolves at 20, and Drill Peck is 34. Do that grind before the Gym.
