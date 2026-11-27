"""Full Heal and Paralyz Heal cure paralysis in and out of battle.

Hypno's party row showed PAR while Full Heal said it would have no effect.
The confirmed party slot was a healthy Pokemon, so the message matched that
target. These calls are the cure handler itself: Full Heal clears every
major status and confusion, and Paralyz Heal clears paralysis, both from
the bag and from Battle:useItem.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/status_cure_items_host.lua"


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua5.4", "lua"):
        found = shutil.which(name)
        if found:
            return found
    built = Path("/tmp/lua-5.4.7/src/lua")
    if built.is_file() and os.access(built, os.X_OK):
        return str(built)
    raise AssertionError("Lua 5.4 is required")


class StatusCureItemTests(unittest.TestCase):
    def test_full_heal_and_paralyz_heal_cure_paralysis(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("status-cure-items-host ok", completed.stdout)


if __name__ == "__main__":
    unittest.main()
