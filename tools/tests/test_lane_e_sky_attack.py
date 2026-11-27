#!/usr/bin/env python3
"""Sky Attack charges for one turn, then hits, and stays targetable.

pokered ChargeEffect prints SkyAttackGlowingText ("is glowing!") and does not
set INVULNERABLE. The next turn is the strike. PP is spent on the charge.

docs/validation/fidelity-ledger.md does not replace this charge. Sky Attack
stays a physical Flying move in both the pokered effect and the Gen V record.
"""

import unittest

from gap_move_cases import flag, number, run_case


class SkyAttackTests(unittest.TestCase):
    def test_two_turn_charge_does_not_grant_invulnerability(self):
        rows = run_case("sky-attack")
        self.assertTrue(flag(rows, "glowing"))
        self.assertFalse(flag(rows, "failed"))
        self.assertEqual(number(rows, "charge-dealt"), 0)
        self.assertGreater(number(rows, "charge-hurt"), 0)
        self.assertEqual(number(rows, "pp"), 1)
        self.assertTrue(flag(rows, "continued"))
        self.assertGreater(number(rows, "release-dealt"), 0)
        self.assertFalse(flag(rows, "release-failed"))
        self.assertEqual(rows["phase"], "command")


if __name__ == "__main__":
    unittest.main()
