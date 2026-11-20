#!/usr/bin/env python3
"""Pins the faithful Misty fight: send-out, Bite range, bridge level, Mart prices.

These are the numbers in docs/validation/lane-k-misty-assist.md. The test
passes while that plan is still true. It is not a Source failure.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_k_misty_assist_host.lua"


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua5.4", "lua"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required to call the battle host")


class MistyAssistPins(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        if completed.returncode != 0:
            raise AssertionError(completed.stderr or completed.stdout)
        cls.lines = completed.stdout.splitlines()

    def pins(self):
        return {line.split(" ", 1)[0]: line.split(" ", 1)[1] for line in self.lines if " " in line}

    def test_moves_damage_and_shop_match_the_plan(self):
        got = self.pins()
        self.assertEqual(got["staryu-18"], "tackle,waterGun")
        self.assertEqual(got["starmie-21"], "tackle,waterGun,bubbleBeam")
        self.assertEqual(got["starmie-hp"], "56")
        self.assertEqual(got["crit"], "16")
        self.assertEqual(got["bite-17"], "12-16")
        self.assertEqual(got["bite-20"], "18-22")
        self.assertEqual(got["tackle-17"], "11-13")
        self.assertEqual(got["watergun-17"], "3-4")
        self.assertEqual(got["bridge-with-side"], "20")
        self.assertEqual(got["bridge-main"], "19")
        self.assertEqual(got["nugget-sell"], "5000")
        self.assertEqual(got["potion-price"], "300")
        self.assertEqual(got["super-price"], "700")
        self.assertIn("potion", got["cerulean-mart"].split(","))
        self.assertNotIn("superPotion", got["cerulean-mart"].split(","))
        self.assertEqual(got["ai-lowhp"], "tackle 200 waterGun 0 bubbleBeam 0")
        self.assertIn("misty-assist-ok", self.lines)


if __name__ == "__main__":
    unittest.main()
