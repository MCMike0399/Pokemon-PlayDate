#!/usr/bin/env python3
"""Dream Eater fails unless the target is asleep, then heals half the damage.

pokered MoveHitTest misses DREAM_EATER_EFFECT when the target is awake.
drain_hp.asm then restores half the damage and prints DreamWasEatenText.

docs/validation/fidelity-ledger.md Combat row keeps Gen V damage. The heal
is the existing drain owner: half the HP removed, rounded half up, at least
1. The sleep gate is the pokered check. An awake target loses nothing and
the user is not healed.
"""

import unittest

from gap_move_cases import flag, number, run_case


class DreamEaterTests(unittest.TestCase):
    def test_dream_eater_requires_sleep_and_drains_half(self):
        rows = run_case("dream-eater")
        self.assertTrue(flag(rows, "failed"))
        self.assertEqual(number(rows, "dealt"), 0)
        self.assertEqual(number(rows, "healed"), 0)
        dealt = number(rows, "asleep-dealt")
        self.assertFalse(flag(rows, "asleep-failed"))
        self.assertGreater(dealt, 0)
        self.assertTrue(flag(rows, "drained"))
        self.assertEqual(number(rows, "asleep-healed"), max(1, (dealt * 50 + 50) // 100))
        self.assertEqual(rows["phase"], "command")


if __name__ == "__main__":
    unittest.main()
