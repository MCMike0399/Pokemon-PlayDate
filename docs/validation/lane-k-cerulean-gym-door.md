# Cerulean Gym door

pret/pokered `af519899719f0754965776faac0e836a3b906e6d`. Source tip `e2f540aa`. No Source change. The door matches the pokered warp. It is not a product disconnect. `(12, 19)` is the Vermilion Gym door, documented for after the Cascade Badge in `lane-k-squirtle-nugget-bill-vermilion.md`.

## Warp

`data/maps/objects/CeruleanCity.asm` warp 4 is `(30, 19) CERULEAN_GYM, 1`. `CeruleanGym.asm` warp 1 is `(4, 13) LAST_MAP, 4`, and warp 2 is `(5, 13) LAST_MAP, 4`. `CeruleanCity.json` and `CeruleanGym.json` use those coordinates. Neither warp is in `blocked_events`.

The outdoor door foot is `$1B`, which is in `Overworld_Coll` and in the overworld door list. Collision is 0. The only open neighbor is south, `(30, 20)`, foot `$39`, collision 0. `(30, 18)`, `(29, 19)`, and `(31, 19)` are solid. The step that enters is north from `(30, 20)` onto `(30, 19)`.

The gym arrival is `(4, 13)`. That row is the bottom of the 5×7 gym. There is no cell south of it, so the usual one-step door advance does not move.

## From the Center

Center door `(19, 17)`, or the step-out tile `(19, 18)`:

1. South to `(19, 20)`.
2. East along `y=20` to `(30, 20)`.
3. North onto `(30, 19)`.

That is 15 steps from the Center door. Every cell is open in `maps/CeruleanCity.blk` and in `CeruleanCity.json`.

## From the Mart

Mart door `(25, 25)`. The step-out tile is `(25, 26)`.

1. South from the door onto `(25, 26)`, if still inside the door.
2. East to `(34, 26)`.
3. North to `(34, 20)`.
4. West to `(30, 20)`.
5. North onto `(30, 19)`.

## Inside, to Misty

Misty stands at `(4, 2)`, facing down. Staryu 18, Starmie 21. The battle starts from the talk. The side she can be faced from is `(5, 2)`.

From `(4, 13)`:

1. North to `(4, 8)`.
2. East to `(5, 8)`.
3. North to `(5, 5)`.
4. East to `(7, 5)`.
5. North to `(7, 3)`.
6. West to `(5, 3)`.
7. North to `(5, 2)`, then face left.

The cooltrainer at `(2, 3)` faces right with sight 3, so `(3, 3)`, `(4, 3)`, and `(5, 3)` are her line. Step 6 is on that line. Her party is Goldeen 19. The swimmer at `(8, 7)` faces left with sight 3 and watches `(5, 7)`, `(6, 7)`, and `(7, 7)`. This walk does not use those cells. His party is Horsea 16, Shellder 16.

`tools/tests/test_lane_k_cerulean_gym_door.py` is the graph check.
