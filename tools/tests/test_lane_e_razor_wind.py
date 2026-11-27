#!/usr/bin/env python3
"""Razor Wind charges for one turn, then hits, and stays targetable.

pokered ChargeEffect (engine/battle/effects.asm) sets CHARGING_UP and prints
MadeWhirlwindText. It sets INVULNERABLE only for Fly and Dig. The release is
the next turn and spends the move's PP once.

docs/validation/fidelity-ledger.md Combat row gives pokered moves Gen V
physical/special damage. Razor Wind is special here. The charge itself is the
pokered handler. The generated record still has critStage 1; the ledger does
not say whether that high-crit stage remains.
"""

import unittest

from gap_move_cases import flag, number, run_case


class RazorWindTests(unittest.TestCase):
    def test_two_turn_charge_does_not_grant_invulnerability(self):
        rows = run_case("razor-wind")
        self.assertTrue(flag(rows, "whirlwind"))
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
