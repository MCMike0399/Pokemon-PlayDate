# Lane J — Squirtle

Branch `cursor/lane-j-squirtle`. Merged E tip `51764017` (Oak at lab cell 6, 2 in `837a61e6`). The remote branch only moved forward. Real Simulator presses only. Earned saves stay outside git.

## Position

- Badges: none
- BLUE, rival RED. Squirtle, level 6, 21 HP, Tackle and Tail Whip
- Intro done. Lab rival won (his Bulbasaur)
- Oak's Parcel has been delivered. `EVENT_GOT_POKEDEX` and `EVENT_OAK_GOT_PARCEL` are set. The bag is empty.
- Standing in Oak's Lab at (6, 3), facing up. Squirtle is still level 6, 21 HP, Tackle and Tail Whip.
- Earned pause save: `/opt/cursor/artifacts/lane-j/saves/930683c875b3/adventure.a.json` sha256 `846b901711349edf2b2f4abfea505fb3b66593d290e4e3170e0e354aad7ced3a`. The Mart file is still `adventure.b.json` sha256 `9a801867ea18179a35c24ced5379781cea0dc7a07fd796b741454c0c2b4a48f7` in that same folder and in `mart-a7df918d`. The earlier city file is sha256 `ecd88d08d5b91a3627aa5b8aa33113d7690d241a44da9b3d2ed14f0de0b17f91`. None of these are in git.

## Clips

Decoded frames are only 0 and 255.

| Clip | Duration | sha256 | What it shows |
| --- | --- | --- | --- |
| `artifacts/lane-j/20261120T001412Z-rival-lab.mp4` | 37.03s | `d9b57b21ed0ceca5c0bf01bbf83d25ede123fe13fd2bddf5e396265ee42563bc` | Lab rival win |
| `artifacts/lane-j/20261120T002027Z-rival-lab.mp4` | 36.83s | `9edcfcad7374969896bf63b6d3146e80db78043ee6397aafc5440f24ad05fe58` | Lab rival win only. The recorder stopped when the battle ended, so this is not a Route 1 walk. |
| `artifacts/lane-j/20261120T005708Z-pokedex-lab.mp4` | 31.97s | `71f1cded1ecffbdd3646087cb355c73fa8e74021b5cca23ad01b6dc636a592dd` | Oak takes the parcel and gives the Pokédex. Decoded frames are only 0 and 255. |

## Title intro

The hang was in this driver. One `wait 250` held the copyright screen. Copyright (180 frames) and the black bars (64) ignore A; the shooting star and the fight accept it (`Source/game/introMovie.lua`, pret/pokered `engine/movie/intro.asm` `PlayIntroScene`). The skip is now a 12-frame wait plus A, repeated until the title leaves the intro, which still covers the whole movie if every A is ignored. A later session cleared that intro, chose CONTINUE on the earned Viridian save, and reached the Mart. No Source change.

## How we got here

New Game from the title. Bedroom stairs, Red's house, Pallet grass, Oak's lab, Squirtle ball at the padded (8, 3) object. Tackle won the lab fight. Out of the lab, north through Route 1, into Viridian City. CONTINUE from that pause save, in the Mart door. The entry program gave Oak's Parcel. Pause save inside the Mart.

## Parcel handoff

An earlier walk reached the same lab before Oak was placed. A at (6, 3) did nothing and the parcel stayed in the bag. After `837a61e6`, CONTINUE from the Mart save again. The title intro cleared, then Mart door to Viridian (29, 20), south edge (21, 35), Route 1 (11, 0) to (10, 35), Pallet (9, 0). The seam at (9, 0) is solid in `PalletTown.json` and open at runtime. The lab door entered `oaks_lab` at (6, 10). Faced Oak at (6, 2) from (6, 3) and pressed A. The handoff ran: dialogue, the rival's walk in, the Pokédex pages, and the rival leaving. The parcel count went to 0. Pause save in the lab. The clip is `20261120T005708Z-pokedex-lab.mp4` (31.97s).

## Next

Viridian's old man (source object at 17, 5 once the Pokédex is owned), then Route 2, Viridian Forest, and Brock. A Route 1 walk clip is still owed; `20261120T002027Z-rival-lab.mp4` does not include it.

## Blockers

None. The missing Oak was E's `837a61e6`, merged here from `51764017`. `tools/tests/test_lane_e_oaks_lab_oak.py` passes.

## Tests

`python3 -m unittest tools.tests.test_lane_j_squirtle tools.tests.test_lane_e_oaks_lab_oak` — 11 tests, all passed. No skips.
