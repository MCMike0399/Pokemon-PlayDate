# Bruno’s Hitmonlee moves

pret/pokered `af519899719f0754965776faac0e836a3b906e6d`. Party row from `ab91045f` / `Source/data/redPartyMoves.lua`, applied in `Source/game/trainerEvents.lua` `TrainerEvents:launch` with `created:usePartyMoves(scripted)`.

The Charmander E4 clip printed `Wide Guard`. That string is the Gen V move. Bruno’s party table lists the four pokered moves instead.

## Party table

`Source/data/redPartyMoves.lua`

```lua
["pokered:BRUNOS_ROOM:objects:1"] = {
    hitmonlee = {"jumpKick", "focusEnergy", "highJumpKick", "megaKick"},
},
```

`Source/data/endgame/story.json` (`pokered:BRUNOS_ROOM:objects:1`) stores species and level only: Hitmonlee is level 55, the third member. `data/trainers/parties.asm` `BrunoData` is the same team with no move list:

```
db $FF, 53, ONIX, 55, HITMONCHAN, 55, HITMONLEE, 56, ONIX, 58, MACHAMP, 0
```

A level-55 `Pokemon("hitmonlee")` after `usePartyMoves` on that row:

| Slot | Key | Battle name | PP | pokered id | Gen V id |
| --- | --- | --- | ---: | --- | ---: |
| 1 | `jumpKick` | JUMP KICK | 10 | `$1A` (26) | 26 |
| 2 | `focusEnergy` | FOCUS ENERGY | 30 | `$74` (116) | 116 |
| 3 | `highJumpKick` | HIGH JUMP KICK | 10 | `$88` (136) | 136 |
| 4 | `megaKick` | MEGA KICK | 5 | `$19` (25) | 25 |

pokered ids are `constants/move_constants.asm` (`const_def`, `NO_MOVE` = `$00`). Display names are `data/moves/names.asm` and `Source/battle/moves.lua`. The Gen V ids are the last field of the B2W2 learnset in `Source/data/pokemon.lua` (`jumpKick|13|-|26`, `focusEnergy|21|-|116`, `highJumpKick|29|-|136`, `megaKick|53|-|25`). `tools/tests/test_lane_e_bruno_hitmonlee.py` locks this row.

## Where the four come from

`data/pokemon/base_stats/hitmonlee.asm` level 1: `DOUBLE_KICK`, `MEDITATE`.

`data/pokemon/evos_moves.asm` `HitmonleeEvosMoves`:

| Level | Move | id |
| ---: | --- | --- |
| 33 | ROLLING KICK | `$1B` |
| 38 | JUMP KICK | `$1A` |
| 43 | FOCUS ENERGY | `$74` |
| 48 | HI JUMP KICK | `$88` |
| 53 | MEGA KICK | `$19` |

WriteMonMoves keeps the last four of level 1 plus those events at level 55: JUMP KICK, FOCUS ENERGY, HI JUMP KICK, MEGA KICK.

## Clip string `Wide Guard`

`Source/battle/moves.lua` `wideGuard` is name `WIDE GUARD`, type rock, status, power 0, accuracy 0, pp 10. The B2W2 learnset teaches it at level 41 as id 469 (`wideGuard|41|-|469`). It is absent from `data/moves/moves.asm`. No Gen 1 learnset or TM teaches it. `docs/validation/fidelity-ledger.md` marks Wide Guard N/A and says the Gen V side guard stays unimplemented.

Before `usePartyMoves`, a level-55 FIFO of that learnset (wideGuard included) is:

| Key | Gen V id | Name |
| --- | ---: | --- |
| `wideGuard` | 469 | WIDE GUARD |
| `blazeKick` | 299 | BLAZE KICK |
| `endure` | 203 | ENDURE |
| `megaKick` | 25 | MEGA KICK |

That first slot is the clip string. `Pokemon.initialMovesFor` now skips `wideGuard`, so a generic level 55 is `foresight` (193), `blazeKick` (299), `endure` (203), `megaKick` (25). Bruno’s send-out uses the party row above, whose four names are JUMP KICK, FOCUS ENERGY, HIGH JUMP KICK, and MEGA KICK.
