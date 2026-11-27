#!/usr/bin/env python3
"""Mimic replaces its own slot with 5 PP and restores that slot on clear.

pokered MimicEffect writes the copied move id into the Mimic slot and leaves
the slot's PP byte alone. The copy stays after the battle.

docs/validation/fidelity-ledger.md Wide Guard row: "Gen V rules apply to
moves pokered has." Gen V puts the copy in the Mimic slot with 5 PP and
drops it when the battler leaves. A target move the user already knows
fails. Clearing volatiles puts Mimic back.
"""

import unittest

from gap_move_cases import flag, number, run_case


class MimicTests(unittest.TestCase):
    def test_mimic_copies_into_its_slot_with_five_pp(self):
        rows = run_case("mimic")
        self.assertFalse(flag(rows, "failed"))
        self.assertTrue(flag(rows, "learned"))
        self.assertEqual(rows["slot"], "growl")
        self.assertEqual(number(rows, "pp"), 5)
        self.assertEqual(rows["other"], "splash")
        self.assertTrue(flag(rows, "fail-known"))
        self.assertEqual(rows["slot-kept"], "mimic")
        self.assertEqual(rows["restored"], "mimic")


if __name__ == "__main__":
    unittest.main()
