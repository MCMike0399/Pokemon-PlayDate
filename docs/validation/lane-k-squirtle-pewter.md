# Squirtle to Brock

Tip: `6e4bc90fe6c9c72a23f8249ff453babc777193aa`. E had not moved when this was checked. No Source change. The gym-guide sprite patch stays queued and is not part of this note.

The fixture is a finished Oak intro with Squirtle in the party. The checks do not debug-warp. They follow the source connections and doors.

## Path

`tools/tests/test_lane_e_squirtle_pewter.py` reads the compact map cache.

| Step | Link |
| --- | --- |
| Pallet Town | north connection to Route 1 |
| Route 1 | north connection to Viridian City |
| Viridian City | north connection to Route 2 |
| Route 2 | north connection to Pewter City |
| Forest | Route 2 warp 2 to the north gate, warp 6 to the south gate. Both gates name Route 2 as `last_outdoor` |
| Gym door | Pewter City `(16, 17)` to `PEWTER_GYM` warp 1. The gym's `last_outdoor` is Pewter City |
| Brock | `pokered:PEWTER_GYM:objects:1` at source `(4, 1)` |

## Brock

`data/trainers/parties.asm` `BrockData` is `$FF, 12, GEODUDE, 14, ONIX`. The trainer row is Geodude 12, Onix 14, payout 1386. Sight is 0 and `talk_only` is true, so the battle starts from the talk, not a sight line. The junior trainer is Diglett 11 and Sandshrew 11, sight 5, and Brock's victory marks him beaten.

`scripts/PewterGym.asm` `PewterGymScriptReceiveTM34` sets the Boulder Badge and gives TM34. The event victory sets `BADGE_BOULDER`, gives `tm34` under `EVENT_GOT_TM34`, clears `EVENT_1ST_ROUTE22_RIVAL_BATTLE` and `EVENT_ROUTE22_RIVAL_WANTS_BATTLE`, and retires the junior trainer.

Water is 2x against rock and 2x against ground, so Bubble and Water Gun are 4x on both of Brock's Pokémon. Squirtle's B2W2 learnset has Bubble at 7 and Water Gun at 13. A level 5 Squirtle still has Tackle, which is not very effective on rock. That is the Gen V learnset, not a missing gym move.

## What J can run once Oak lands

1. Finish the intro and take Squirtle.
2. Walk north through Route 1, Viridian, and Route 2. The forest gates are the source doors above; the Route 2 north connection also reaches Pewter.
3. Enter the gym at `(16, 17)` and talk to Brock. Do not zone-switch.
4. Expect Geodude then Onix, then the Boulder Badge and TM34.

No new `lane-e-*.patch`. The three faint-path repros on this same tip are already on the tree: SHIFT asks before the next send-out, the wipe page is `_PlayerBlackedOutText2` and the Center fly warps match, and the twelve Viridian arrows redirect and swap frames.
