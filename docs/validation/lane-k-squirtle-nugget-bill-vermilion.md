# Squirtle: Nugget Bridge, Bill, Vermilion

Source tip `e2f540aa`, already on `cursor/lane-k-qa`. No Source change. No Misty assist: there is no gym-fail to answer. The assist is `tools/tests/test_lane_k_squirtle_nugget_path.py`. It pins pret/pokered `af519899` and raises if `POKERED_REFERENCE_DIR` is unset.

## Nugget Bridge

North from the Cerulean Center. `(20, 0)` and `(21, 0)` are the bridge, landing on Route 24 `(10, 35)` and `(11, 35)`. Walk north. The first trainer is the south one.

| Order | Who | Tile | Party |
| --- | --- | --- | --- |
| 1 | Bug Catcher, sight 1, facing left | `(11, 31)` | Caterpie 14, Weedle 14 |
| 2 | Lass, sight 1, facing right | `(10, 28)` | Pidgey 14, Nidoran♀ 14 |
| 3 | Youngster, sight 1, facing left | `(11, 25)` | Rattata 14, Ekans 14, Zubat 14 |
| 4 | Lass, sight 1, facing right | `(10, 22)` | Pidgey 16, Nidoran♀ 16 |
| 5 | Jr.Trainer♂, sight 1, facing left | `(11, 19)` | Mankey 18 |
| 6 | Jr.Trainer♂, sight 4, facing up | `(5, 20)` | Rattata 14, Ekans 14 |
| 7 | Rocket | `(11, 15)` | Ekans 15, Zubat 15 |

The Rocket is not a sight line. Step on `(10, 15)` while `EVENT_GOT_NUGGET` is clear. He gives one Nugget, then battles. A full bag sets `EVENT_NUGGET_REWARD_AVAILABLE` and steps you south so the tile can be tried again. TM Thunder Wave is the ball at `(10, 5)`. The Jr.Trainer at `(5, 20)` can see four tiles up, off the main line of the bridge.

East from that same walk only at Route 24 `y=8` and `y=9`. Both land on Route 25 `x=0` and reach Bill's door `(45, 3)`.

## Bill

Door `(45, 3)` is `BILLS_HOUSE` warp 1. The return mats are `(2, 7)` and `(3, 7)`. Talk to the Pokémon at `(6, 5)`. YES and NO both set `SCRIPT_BILLSHOUSE_POKEMON_WALK_TO_MACHINE`. NO is not a cancel. After the machine, Bill gives the S.S. Ticket. A full bag does not set `EVENT_GOT_SS_TICKET`.

## Rival on the way back

`(20, 6)` and `(21, 6)`, only while `EVENT_BEAT_CERULEAN_RIVAL` is clear. Standing on `x=20` places him at `x=25` before he walks down three steps. Squirtle means `wRivalStarter` is Bulbasaur (`STARTER3`), so the team is `$8`: Pidgeotto 18, Abra 15, Rattata 15, Bulbasaur 17. A loss clears the script and the tile can be tried again.

Host spot-check on this tip, Wartortle plus a Pidgey bench, seed 1: forced switch, shift YES, shift NO, and a solo whiteout all returned to a clear `selectionKind`. Pidgeotto 18's moves include Whirlwind. Abra 15's moves are Teleport. Switching into either also cleared `selectionKind`. No `lane-e-*.patch`.

## Cerulean to Vermilion

The Center walk does not reach the south edge. The tree line and the Cut tree are not the exit. Use the burgled house.

1. Front door `(27, 11)`, house warps `(2, 7)` and `(3, 7)`.
2. Back door `(3, 0)` exits to Cerulean `(27, 9)`. The Center walk does not reach that tile.
3. The only walk from `(27, 9)` to the south edge crosses `(30, 7)`, `(30, 8)`, and `(30, 9)`. The Rocket stands on `(30, 8)`. Stepping on `(30, 7)` or `(30, 9)` starts him while `EVENT_BEAT_CERULEAN_ROCKET_THIEF` is clear. Party index 5: Machop 17, Drowzee 17, then TM28. He is not the Nugget Rocket.
4. Leave the south edge at `x=11` through `x=14`, or `x=25` through `x=28`. Cerulean's south adjustment is `-10`, so those are Route 5 `x=1` through `x=4` and `x=15` through `x=18`. That component reaches the underground door `(17, 27)`.
5. Do not hop the ledge at `y=32`, `x=16` through `x=23`. It lands on Route 5 `x=6` through `x=13`, and `(6, 0)` does not reach the underground door.
6. On Route 5, `(9, 29)` and `(10, 29)` are the Saffron gate. `(10, 33)` is that gate's south door and is not on this walk. The underground door is `(17, 27)`.
7. Route 5 house: door `(3, 7)` or `(4, 7)`, stairs `(4, 4)`.
8. North-south corridor `(5, 4)` walks to `(2, 41)`. The block map is 4×23; the const says 4×24. The committed collision matches the 46 source rows, and both warps are inside them.
9. Route 6 house stairs `(4, 4)` exit at `(17, 13)`. South edge cells on that walk are only `(8, 35)` and `(9, 35)`. Route 6's south adjustment is `+10`, so Vermilion `(18, 0)` and `(19, 0)`. `(10, 7)` is the Saffron gate. Do not take it.
10. Vermilion `(18, 0)` reaches the Center `(11, 3)` and the Mart `(23, 13)`. It does not reach the Gym door `(12, 19)`. Those feet match pokered. `(12, 19)` is Vermilion's door. Misty's door is Cerulean `(30, 19)`, in `lane-k-cerulean-gym-door.md`.

## What J can run

1. Finish the bridge northbound, take the Nugget at `(10, 15)`, and cross east at `y=8` or `y=9`.
2. Talk to Bill's Pokémon. Either answer starts the machine. Take the S.S. Ticket.
3. On the way back into Cerulean, expect the Bulbasaur rival team at `(20, 6)` or `(21, 6)`. Whirlwind and Teleport did not leave a battle selection stuck.
4. For Vermilion, go through the burgled house and the backyard Rocket, then leave at the south-edge ranges above. Skip the `y=32` ledge and both Saffron gates.

## Post-Cascade: Vermilion Gym

`(12, 19)` is `warp_event 12, 19, VERMILION_GYM, 1` in `data/maps/objects/VermilionCity.asm`. It is a separate walk component from the north arrival `(18, 0)`. The Center and the Mart are on the north arrival. The Gym door is not. The committed feet match pokered `af519899`, so this is not a Cerulean disconnect and not a slice drift. Leave it until after the Cascade Badge.
