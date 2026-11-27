#!/usr/bin/env python3
"""Minimize raises evasion by two stages.

pokered sends Minimize through StatModifierUpEffect EVASION_UP1_EFFECT, one
stage. docs/validation/fidelity-ledger.md Combat row uses Gen V stages, and
the Wide Guard row says "Gen V rules apply to moves pokered has." The
generated move is evasion +2. The minimize flag is set on that use. The
ledger does not say whether Stomp and the other minimize-boosted moves deal
double damage, so this test stops at the evasion stage and the flag.
"""

import unittest

from gap_move_cases import flag, number, run_case


class MinimizeTests(unittest.TestCase):
    def test_minimize_raises_evasion_two_stages(self):
        rows = run_case("minimize")
        self.assertFalse(flag(rows, "failed"))
        self.assertTrue(flag(rows, "sharply"))
        self.assertEqual(number(rows, "eva"), 2)
        self.assertTrue(flag(rows, "flag"))


if __name__ == "__main__":
    unittest.main()
