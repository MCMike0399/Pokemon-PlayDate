#!/usr/bin/env python3
"""Confuse Ray and Supersonic leave an existing confusion counter alone.

The source guard is test_lane_e_confuse_ray. This runs the battle script:
both moves print But it failed! and do not roll a new counter.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_k_confuse_ray_host.lua"


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua5.4", "lua"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required to call the battle host")


class ConfuseRayFlowTests(unittest.TestCase):
    def test_already_confused_target_keeps_its_counter(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("confuseRay failed-and-kept 2", completed.stdout)
        self.assertIn("supersonic failed-and-kept 2", completed.stdout)
        self.assertIn("confuse-ray-flow-ok", completed.stdout)


if __name__ == "__main__":
    unittest.main()
