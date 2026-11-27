#!/usr/bin/env python3
"""Metronome calls a pokered move and cannot call the Gen V bans.

pokered MetronomePickMove (engine/battle/core.asm) rolls a move id below
Struggle. docs/validation/fidelity-ledger.md Wide Guard row: "Gen V rules
apply to moves pokered has." The pool is that pokered table, including the
field moves Cut, Fly, Surf, Strength, and Flash. Later-gen moves in moveData
stay out. The Gen V bans that exist in the pokered table are Metronome,
Struggle, Counter, Mimic, Mirror Move, and Transform. Forcing the roll at
each of those keys still cannot select it.
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
        self.assertEqual(number(rows, "banned-absent"), 6)
        self.assertEqual(number(rows, "forced-blocked"), 6)
        self.assertTrue(flag(rows, "has-tackle"))
        self.assertTrue(flag(rows, "has-cut"))
        self.assertFalse(flag(rows, "has-shadow-claw"))
        self.assertEqual(number(rows, "eligible"), 159)
        self.assertEqual(number(rows, "pp"), 9)
        self.assertEqual(rows["phase"], "command")


if __name__ == "__main__":
    unittest.main()
