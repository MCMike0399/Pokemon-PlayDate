# Pokered moves still in MoveSupport.gaps

Pinned pret/pokered commit `af519899719f0754965776faac0e836a3b906e6d`. A move is listed when its name in `data/moves/moves.asm` matches a key that `Source/battle/moveSupport.lua` still marks as a gap. Field moves Cut, Fly, Surf, Strength, and Flash are registered in `Source/data/fieldMoveBattleData.lua` and are not gaps. Psychic and Hi Jump Kick have handlers.

Counter is not in this table. It is the unapplied handoff in `tools/notes/lane-e-counter.patch`. `tools/tests/test_lane_e_counter.py` fails until that patch is applied. The rule is the Combat row of `docs/validation/fidelity-ledger.md`: Gen V/B2W2 rules and the physical/special split. The Wide Guard row states that Gen V rules apply to moves pokered has. Pokered `HandleCounterMove` in `engine/battle/core.asm` only accepts Normal and Fighting. That type filter is the Gen I rule the ledger replaced.

Mirror Coat is a gap and is not in pokered. Curse is not in pokered. Both stay out of this list.

| Move | Gap | Pokered source |
| --- | --- | --- |
| Razor Wind | onTryMove | `engine/battle/effects.asm` (`ChargeEffect`) |
| Mist | sideCondition | `engine/battle/move_effects/mist.asm` |
| Mimic | onHit | `engine/battle/effects.asm` (`MimicEffect`) |
| Minimize | volatileStatus | `engine/battle/effects.asm` (`StatModifierUpEffect`, `EVASION_UP1_EFFECT`) |
| Metronome | onHit | `engine/battle/core.asm` (`MetronomePickMove`) |
| Dream Eater | onTryImmunity | `engine/battle/core.asm` (`MoveHitTest` sleep check) and `engine/battle/move_effects/drain_hp.asm` |
| Sky Attack | onTryMove | `engine/battle/effects.asm` (`ChargeEffect`) |
| Conversion | onHit | `engine/battle/move_effects/conversion.asm` |

Bide, Mirror Move, Transform, and Substitute are in pokered and are not gaps. Bide is `BideEffect` in `engine/battle/effects.asm` and the handler is `engine-dsl`. Mirror Move is `MirrorMoveCopyMove` in `engine/battle/core.asm` and the handler is `battle-condition`. Transform is `engine/battle/move_effects/transform.asm`. Substitute is `engine/battle/move_effects/substitute.asm`.
