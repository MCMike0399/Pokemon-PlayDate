"""SHIFT YES/NO before the next foe when the lead has fainted.

pret/pokered af519899 engine/battle/core.asm HandleEnemyMonFainted sends
a fainted battle mon through ChooseNextMon and then ReplaceFaintedEnemyMon.
ReplaceFaintedEnemyMon still prints _TrainerAboutToUseText and opens
TWO_OPTION_MENU when BIT_BATTLE_SHIFT is clear and the party has a bench
(data/text/text_2.asm). The Charmander E4 clips skip that question for
Lapras after Lorelei and for Onix with Weepinbell benched.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_k_shift_slots_host.lua"


class ShiftSlotTests(unittest.TestCase):
    def test_fainted_lead_still_asks_before_the_next_foe(self):
        completed = subprocess.run(
            ["lua5.4", str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("shift-slots-held", completed.stdout)


if __name__ == "__main__":
    unittest.main()
