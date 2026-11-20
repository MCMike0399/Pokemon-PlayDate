# Lane J — Squirtle

Branch `cursor/lane-j-squirtle`. Merged E tip `51764017` (Oak at lab cell 6, 2 in `837a61e6`). The remote branch only moved forward. Real Simulator presses only. Earned saves stay outside git.

## Position

- Badges: Boulder Badge (`BADGE_BOULDER`). TM34 is in the bag. Payout was 1386.
- BLUE, rival RED. Squirtle, level 12, 20 HP, no status, Tackle, Tail Whip, Bubble, and Withdraw
- Intro done. Lab rival won (his Bulbasaur)
- Oak's Parcel has been delivered. `EVENT_GOT_POKEDEX` and `EVENT_OAK_GOT_PARCEL` are set.
- Standing in Pewter Gym at (5, 2), facing up, on the tile where Brock was fought.
- Earned pause save: `/opt/cursor/artifacts/lane-j/saves/a6328d508ccc/adventure.a.json` sha256 `fca4f05f2567bd621c35b195f24c0f7db80655b09b67409d282e3e4550a1b05b` (sequence 7). The pre-gym Pewter pause remains `/opt/cursor/artifacts/lane-j/saves/d03e3f4459d1/adventure.b.json` sha256 `d8c3b1e1fa226fe42174ab076467d39a6bd21aa8505fae9df87d4f00e6488217`. Earlier pauses: Viridian `56f56cb938174c80ffc7465e41c75d83c76e7fbb1c311e7b0e64231638917122`, lab `846b901711349edf2b2f4abfea505fb3b66593d290e4e3170e0e354aad7ced3a`. None of these are in git.

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

## Title intro

The hang was in this driver. One `wait 250` held the copyright screen. Copyright (180 frames) and the black bars (64) ignore A; the shooting star and the fight accept it (`Source/game/introMovie.lua`, pret/pokered `engine/movie/intro.asm` `PlayIntroScene`). The skip is now a 12-frame wait plus A, repeated until the title leaves the intro, which still covers the whole movie if every A is ignored. A later session cleared that intro, chose CONTINUE on the earned Viridian save, and reached the Mart. No Source change.

## How we got here

New Game from the title. Bedroom stairs, Red's house, Pallet grass, Oak's lab, Squirtle ball at the padded (8, 3) object. Tackle won the lab fight. Out of the lab, north through Route 1, into Viridian City. CONTINUE from that pause save, in the Mart door. The entry program gave Oak's Parcel. Pause save inside the Mart.

## Parcel handoff

An earlier walk reached the same lab before Oak was placed. A at (6, 3) did nothing and the parcel stayed in the bag. After `837a61e6`, CONTINUE from the Mart save again. The title intro cleared, then Mart door to Viridian (29, 20), south edge (21, 35), Route 1 (11, 0) to (10, 35), Pallet (9, 0). The seam at (9, 0) is solid in `PalletTown.json` and open at runtime. The lab door entered `oaks_lab` at (6, 10). Faced Oak at (6, 2) from (6, 3) and pressed A. The handoff ran: dialogue, the rival's walk in, the Pokédex pages, and the rival leaving. The parcel count went to 0. Pause save in the lab. The clip is `20261120T005708Z-pokedex-lab.mp4` (31.97s).

The lab save walked out, filmed Route 1 (24.03s), and talked to the old man at (17, 6). The next walk crossed Route 2, Viridian Forest, and the north gate into Pewter at level 8 with 10 HP. Bubble was learned. A forest battle left Squirtle poisoned. The first Center visit looked for a tile beside the nurse and left without healing. The gym path then crossed the junior trainer's sight at (5, 7). Squirtle fainted. That blackout was not saved. The Pewter pause at (18, 35) resumed. The nurse is at (3, 1) behind the solid counter at (3, 2). Standing at (3, 3) and facing up opened the heal, and YES restored Squirtle to 25 HP. The walk to Brock avoided (4, 7) and (5, 7). Brock's Geodude and Onix fainted. `last_battle_outcome.won` is true, `BADGE_BOULDER` is set, and the bag holds one TM34. Squirtle reached level 12 with 20 HP and learned Withdraw. The clip is `20261120T012706Z-gym-pewter.mp4` (70.93s).

## Next

Stopped after the Boulder Badge, as requested. The gym pause above is the resume for Route 3.

## Blockers

None. The missing Oak was E's `837a61e6`, merged here from `51764017`. `tools/tests/test_lane_e_oaks_lab_oak.py` passes.

## Tests

`python3 -m unittest tools.tests.test_lane_j_squirtle tools.tests.test_lane_e_oaks_lab_oak` — 12 tests, all passed. No skips. The Pewter resume then won Brock in the Simulator (`/tmp/lane-j-squirtle-10`, exit 0).
