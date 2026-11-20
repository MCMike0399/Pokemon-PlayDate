#!/usr/bin/env python3
"""Confuse Ray on a Pokémon that is already confused.

Haunter's Confuse Ray played its animation and never printed
``But it failed!``. The volatile guard returns before a new counter,
so the status is not reapplied, but a direct confuse status move
(Confuse Ray, Supersonic) has to announce the failure. A secondary
and Swagger's attack raise stay silent. tools/notes/lane-e-confuse-ray.patch.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ConfuseRayTests(unittest.TestCase):
    def test_direct_confuse_announces_and_keeps_the_counter(self):
        source = (ROOT / "Source/battle/dsl.lua").read_text(encoding="utf-8")
        branch = source.split('if self.status == "confuse" then', 1)[1]
        guard, assignment = branch.split("pokemon.confusion = RulesRNG", 1)
        self.assertIn("But it failed!", guard)
        self.assertIn("onlyConfuse", guard)
        self.assertIn("#move.effects==1", guard)
        self.assertIn("return", guard)
        self.assertTrue(assignment.startswith(".random(1, 4)"))


if __name__ == "__main__":
    unittest.main()
