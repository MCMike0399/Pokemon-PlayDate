#!/usr/bin/env python3
"""A first-mover recoil KO cancels the opponent's queued move."""

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
    def test_recoil_ko_skips_the_queued_move_and_keeps_its_pp(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        text = completed.stdout
        self.assertIn("VENUSAUR fainted!", text)
        self.assertIn("damaged by recoil!", text)
        self.assertNotIn("CHARIZARD used WING ATTACK!", text)
        self.assertIn("phase forcedSwitch", text)
        self.assertIn("userhp 0", text)
        wing_before = next(line for line in text.splitlines() if line.startswith("wingpp-before "))
        wing_after = next(line for line in text.splitlines() if line.startswith("wingpp "))
        self.assertEqual(wing_before.split()[1], wing_after.split()[1])


if __name__ == "__main__":
    unittest.main()
