#!/usr/bin/env python3
"""Conversion changes the user to one of its own move types.

pokered conversion.asm copies the target's types onto the user.

docs/validation/fidelity-ledger.md Wide Guard row: "Gen V rules apply to
moves pokered has." Gen V Conversion becomes the type of one of the user's
moves and fails when every move is already that single type. A Squirtle
whose moves are Conversion and Ember becomes Normal, not the Gastly target's
Ghost. A Rattata with only Normal moves fails and stays Normal.
"""

import unittest

from gap_move_cases import flag, run_case


class ConversionTests(unittest.TestCase):
    def test_conversion_uses_the_users_move_type(self):
        rows = run_case("conversion")
        self.assertFalse(flag(rows, "failed"))
        self.assertEqual(rows["type1"], "normal")
        self.assertEqual(rows["type2"], "nil")
        self.assertEqual(rows["target1"], "ghost")
        self.assertFalse(flag(rows, "became-target"))
        self.assertTrue(flag(rows, "mono-failed"))
        self.assertEqual(rows["mono-type"], "normal")


if __name__ == "__main__":
    unittest.main()
