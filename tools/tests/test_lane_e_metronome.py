#!/usr/bin/env python3
"""Metronome calls another move and never calls itself or Struggle.

pokered MetronomePickMove (engine/battle/core.asm) rejects Metronome and any
roll from Struggle upward, so the called set is the earlier move ids.

docs/validation/fidelity-ledger.md Wide Guard row: "Gen V rules apply to
moves pokered has." The ledger does not list the B2W2 call ban. This call
also refuses the Gen V bans that exist in moveData: afterYou, bestow,
copycat, counter, covet, destinyBond, detect, endure, feint, focusPunch,
followMe, helpingHand, meFirst, metronome, mimic, mirrorCoat, mirrorMove,
protect, quickGuard, ragePowder, sleepTalk, snore, struggle, switcheroo,
transform, trick, and wideGuard. The pool is the project's move table, not
the pokered id range. The ledger does not say which of those two pools it
means.
"""

import unittest

from gap_move_cases import flag, number, run_case


class MetronomeTests(unittest.TestCase):
    def test_metronome_excludes_itself_and_struggle(self):
        rows = run_case("metronome")
        self.assertFalse(flag(rows, "failed"))
        self.assertTrue(flag(rows, "called-tackle"))
        self.assertGreater(number(rows, "dealt"), 0)
        self.assertFalse(flag(rows, "has-metronome"))
        self.assertFalse(flag(rows, "has-struggle"))
        self.assertGreater(number(rows, "eligible"), 0)
        self.assertEqual(number(rows, "pp"), 9)
        self.assertEqual(rows["phase"], "command")


if __name__ == "__main__":
    unittest.main()
