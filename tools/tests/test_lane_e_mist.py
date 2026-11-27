#!/usr/bin/env python3
"""Mist blocks an opponent's stat drop and wears off.

pokered mist.asm sets PROTECTED_BY_MIST until something else clears it, and
MoveHitTest rejects the stat-down effects while that bit is set. A drop the
user aims at itself is not that check.

docs/validation/fidelity-ledger.md Wide Guard row: "Gen V rules apply to
moves pokered has." Gen V Mist lasts 5 turns. The side timer counts the
setup round, so the stored turns read 4 after that round and the screen
wears off on a later round. Growl then lands.
"""

import unittest

from gap_move_cases import flag, number, run_case


class MistTests(unittest.TestCase):
    def test_mist_blocks_stat_drops_for_five_turns(self):
        rows = run_case("mist")
        self.assertTrue(flag(rows, "shrouded"))
        self.assertTrue(flag(rows, "protected"))
        self.assertFalse(flag(rows, "failed"))
        self.assertEqual(number(rows, "atk"), 0)
        self.assertEqual(number(rows, "turns"), 4)
        self.assertTrue(flag(rows, "wore-off"))
        self.assertTrue(flag(rows, "dropped-after"))
        self.assertEqual(rows["phase"], "command")


if __name__ == "__main__":
    unittest.main()
