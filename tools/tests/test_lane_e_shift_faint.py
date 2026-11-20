"""SHIFT asks before the next send-out after a trainer's Pokémon faints.

pret/pokered af519899 engine/battle/core.asm: a clear BIT_BATTLE_SHIFT
prints _TrainerAboutToUseText and opens TWO_OPTION_MENU before
_TrainerSentOutText. SET (the bit) skips the question. The question is
"Will <PLAYER>" / "change #MON?" in data/text/text_2.asm.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_e_faint_host.lua"


class ShiftFaintTests(unittest.TestCase):
    def test_post_faint_shift_asks_before_send_out(self):
        completed = subprocess.run(
            ["lua5.4", str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("shift-faint-ok", completed.stdout)


if __name__ == "__main__":
    unittest.main()
