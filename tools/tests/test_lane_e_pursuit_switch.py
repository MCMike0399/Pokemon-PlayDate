#!/usr/bin/env python3
"""Switching into Pursuit must close the party selection.

Route 23 Spearow level 26 knows Pursuit. Choosing a bench member returns
success while selectionKind is still \"party\", and BattleScene:completeSelection
then asserts selection-unresolved. The live crash was party confirm on
Drowzee against that Spearow."""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/pursuit_switch_host.lua"


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua5.4", "lua"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required to call the battle host")


class PursuitSwitchTests(unittest.TestCase):
    def test_pursuit_switch_clears_the_party_selection(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("selection-cleared", completed.stdout)


if __name__ == "__main__":
    unittest.main()
