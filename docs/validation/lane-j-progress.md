# Lane J — Squirtle

Branch `cursor/lane-j-squirtle`, fast-forwarded onto `6e4bc90fe6c9c72a23f8249ff453babc777193aa`. Real Simulator presses only. Earned saves stay outside git.

## Position

- Badges: none
- BLUE, rival RED. Squirtle, level 6, 21 HP, Tackle and Tail Whip
- Intro done. Lab rival won (his Bulbasaur)
- Oak's Parcel is still in the bag (`EVENT_GOT_OAKS_PARCEL`)
- Earned pause save is still the Viridian Mart: `adventure.b.json` sha256 `9a801867ea18179a35c24ced5379781cea0dc7a07fd796b741454c0c2b4a48f7` at (4, 5) facing left. The earlier city save is `adventure.a.json` sha256 `ecd88d08d5b91a3627aa5b8aa33113d7690d241a44da9b3d2ed14f0de0b17f91` (Viridian City, 21, 35). Both are under `/opt/cursor/artifacts/lane-j/saves/`, not in git.
- A later real-input walk left that Mart, crossed Route 1, and entered Pallet's lab. It did not save, because Oak never took the parcel.

## Clips

Decoded frames are only 0 and 255.

| Clip | Duration | sha256 | What it shows |
| --- | --- | --- | --- |
| `artifacts/lane-j/20261120T001412Z-rival-lab.mp4` | 37.03s | `d9b57b21ed0ceca5c0bf01bbf83d25ede123fe13fd2bddf5e396265ee42563bc` | Lab rival win |
| `artifacts/lane-j/20261120T002027Z-rival-lab.mp4` | 36.83s | `9edcfcad7374969896bf63b6d3146e80db78043ee6397aafc5440f24ad05fe58` | Lab rival win only. The recorder stopped when the battle ended, so this is not a Route 1 walk. |

## Title intro

The hang was in this driver. One `wait 250` held the copyright screen. Copyright (180 frames) and the black bars (64) ignore A; the shooting star and the fight accept it (`Source/game/introMovie.lua`, pret/pokered `engine/movie/intro.asm` `PlayIntroScene`). The skip is now a 12-frame wait plus A, repeated until the title leaves the intro, which still covers the whole movie if every A is ignored. A later session cleared that intro, chose CONTINUE on the earned Viridian save, and reached the Mart. No Source change.

## How we got here

New Game from the title. Bedroom stairs, Red's house, Pallet grass, Oak's lab, Squirtle ball at the padded (8, 3) object. Tackle won the lab fight. Out of the lab, north through Route 1, into Viridian City. CONTINUE from that pause save, in the Mart door. The entry program gave Oak's Parcel. Pause save inside the Mart.

## Parcel handoff

CONTINUE from the Mart save. The title intro cleared (12-frame A pulse, then CONTINUE). Out the Mart door to Viridian (29, 20), south edge (21, 35), Route 1 (11, 0) to (10, 35), Pallet (9, 0). That seam is solid in `PalletTown.json` and open at runtime (`maps.lua` opens `(9, 0)`). The walk treats the cell the player is already standing on as open. Pallet's door (12, 11) entered `oaks_lab` at (6, 10). Walked to (6, 3), faced up, pressed A. No dialog. `oaksParcel` stayed 1. No handoff clip, because the handoff did not happen.

`oaks_lab` registers doors and no NPCs. pret/pokered `OaksLab.asm` object (5, 2) is Oak, STAY DOWN; padding 1 is (6, 2), the faced cell. `KantoWorld.tryInteract` starts `pokered:OAKS_LAB:script:parcel-handoff` only for an actor named OAK, and `EventState` then requires `findByName("OAK")`.

## Next

Blocked on that lab actor. After E places Oak, deliver the parcel from the Mart save, clip the Pokédex handoff, then the old man, Route 2, Viridian Forest, and Brock. A Route 1 walk clip is still owed; `20261120T002027Z-rival-lab.mp4` does not include it.

## Blockers

Authored Oak's Lab has no Oak. Parked. `tools/notes/lane-e-oaks-lab-oak.patch` and `tools/tests/test_lane_e_oaks_lab_oak.py` (fails on current `Source/data/maps.lua`). No Source edit on this branch.

## Tests

`python3 -m unittest tools.tests.test_lane_j_squirtle` — 9 tests, all passed. No skips.

`python3 -m unittest tools.tests.test_lane_e_oaks_lab_oak` — fails until the patch is applied. That failure is the handoff.
