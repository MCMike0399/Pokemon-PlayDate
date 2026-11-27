#!/usr/bin/env python3
"""Minimize raises evasion by two stages.

pokered sends Minimize through StatModifierUpEffect EVASION_UP1_EFFECT, one
stage. docs/validation/fidelity-ledger.md Combat row uses Gen V stages, and
the Wide Guard row says "Gen V rules apply to moves pokered has." The
generated move is evasion +2, and the minimize flag is set. Showdown's
Generation V Stomp text doubles damage when the target has used Minimize.
The gen5 Minimize condition keeps that damage modifier and drops the
accuracy bypass. Body Slam does not gain the modifier until Generation VI,
so a Tackle against the same flag is unchanged.
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
        plain = number(rows, "stomp-plain")
        self.assertGreater(plain, 0)
        self.assertEqual(number(rows, "stomp-min"), plain * 2)
        tackle = number(rows, "tackle-plain")
        self.assertGreater(tackle, 0)
        self.assertEqual(number(rows, "tackle-min"), tackle)


if __name__ == "__main__":
    unittest.main()
