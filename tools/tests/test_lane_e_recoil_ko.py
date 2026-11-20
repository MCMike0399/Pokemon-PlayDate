#!/usr/bin/env python3
"""A first-mover recoil KO still lets the living foe use the queued move.

The fainted user is announced, then the foe spends PP and finds no target.
The round ends in the forced switch. A replacement does not drop the queue."""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/recoil_ko_host.lua"


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua5.4", "lua"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required to call the battle host")


class RecoilKoTests(unittest.TestCase):
    def test_recoil_ko_spends_the_queued_move_against_no_target(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        text = completed.stdout
        self.assertIn("VENUSAUR fainted!", text)
        self.assertIn("damaged by recoil!", text)
        self.assertLess(text.index("VENUSAUR fainted!"), text.index("CHARIZARD used WING ATTACK!"))
        self.assertIn("But there was no target!", text)
        self.assertIn("phase forcedSwitch", text)
        self.assertIn("userhp 0", text)
        wing_before = next(line for line in text.splitlines() if line.startswith("wingpp-before "))
        wing_after = next(line for line in text.splitlines() if line.startswith("wingpp "))
        self.assertEqual(int(wing_before.split()[1]) - 1, int(wing_after.split()[1]))


if __name__ == "__main__":
    unittest.main()
