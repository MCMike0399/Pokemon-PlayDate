#!/usr/bin/env python3
"""A wild battle win shows no victory line.

Main 821694b8 removed "You won the battle!" from a wild win. pokered
returns to the map after the faint and EXP pages. data/text/text_2.asm
has no such string. A trainer win still says the defeated line. This
fails if that wild page comes back.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(os.environ.get("WILD_WIN_ROOT", Path(__file__).resolve().parents[2]))
HOST = Path(__file__).resolve().parent / "wild_win_host.lua"


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua5.4", "lua"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required to call the battle host")


def run_wild():
    completed = subprocess.run(
        [lua_binary(), str(HOST), str(ROOT)],
        check=False, capture_output=True, text=True)
    if completed.returncode != 0:
        raise AssertionError(completed.stderr or completed.stdout)
    rows = {}
    for line in completed.stdout.splitlines():
        if " " not in line:
            continue
        key, value = line.split(" ", 1)
        rows[key] = value
    return rows


class WildWinTextTest(unittest.TestCase):
    def test_wild_ko_has_no_victory_line(self):
        rows = run_wild()
        self.assertEqual(rows["outcome"], "victory", rows.get("transcript"))
        self.assertEqual(rows["enemy-hp"], "0", rows.get("transcript"))
        self.assertEqual(rows["fainted"], "true", rows.get("transcript"))
        self.assertEqual(rows["exp"], "true", rows.get("transcript"))
        self.assertEqual(rows["victory-line"], "false", rows.get("transcript"))
        self.assertEqual(rows["defeated-line"], "false", rows.get("transcript"))
        self.assertNotIn("You won the battle!", rows.get("transcript", ""))


if __name__ == "__main__":
    unittest.main()
