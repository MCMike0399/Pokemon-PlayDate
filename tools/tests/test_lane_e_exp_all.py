#!/usr/bin/env python3
"""EXP.ALL in the bag splits the award. The item itself is not usable.

pret/pokered af519899 engine/battle/core.asm, after EnemyMonFaintedText:

    ld b, EXP_ALL
    call IsItemInBag
    jr z, .giveExpToMonsThatFought
    ; halve the exp data, then
    ; give that half to the mons that fought
    ; set wPartyGainExpFlags for every party member
    ; GainExperience again for the other half

engine/items/item_effects.asm maps EXP_ALL to UnusableItem. Owning it is
the switch. Source/battle/rewards.lua only pays conscious participants and
never reads the bag, so a benched mon gains nothing.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASM = ROOT / "tools/references/tutorial-escort/engine/battle/core.asm"


class ExpAllTests(unittest.TestCase):
    def test_bag_exp_all_pays_the_bench(self):
        asm = ASM.read_text()
        block = asm.split("ld b, EXP_ALL", 1)[1].split("EnemyMonFaintedText:", 1)[0]
        self.assertIn("call IsItemInBag", block)
        self.assertIn(".giveExpToMonsThatFought", block)
        self.assertIn("wPartyGainExpFlags", block)
        effects = (ROOT / "tools/references/tutorial-escort/engine/items/item_effects.asm").read_text()
        self.assertIn("dw UnusableItem      ; EXP_ALL", effects)

        rewards = (ROOT / "Source/battle/rewards.lua").read_text()
        pokemon = (ROOT / "Source/data/pokemon.lua").read_text()
        self.assertIn('quantity("expAll")', rewards)
        self.assertIn("not set[mon]", rewards)
        self.assertIn("function Pokemon:gainXP(amount, allowFainted)", pokemon)
        self.assertIn("not allowFainted and not self:isAlive()", pokemon)


if __name__ == "__main__":
    unittest.main()
