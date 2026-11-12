"""Lane G front end against pret/pokered af519899.

Title, main menu, naming, start menu, options, and the intro skip rules
are checked on the host. The Simulator is not required.
"""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_g_host.lua"
TITLE_HOST = ROOT / "tools/tests/title_idle_host.lua"
PLAYER = ROOT / "Source/images/title/player.png"
MANIFEST = ROOT / "tools/references/title-art.json"


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua", "lua5.4"):
        found = shutil.which(name)
        if found:
            return found
    built = Path("/tmp/lua-5.4.7/src/lua")
    if built.is_file() and os.access(built, os.X_OK):
        return str(built)
    raise AssertionError("Lua 5.4 is required")


class LaneGFrontEndTests(unittest.TestCase):
    def test_host_matches_pokered_strings(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("lane-g-host ok", completed.stdout)

    def test_existing_title_idle_host(self):
        completed = subprocess.run(
            [lua_binary(), str(TITLE_HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("title-idle-host ok", completed.stdout)

    def test_player_sheet_is_the_pinned_title_output(self):
        import json
        manifest = json.loads(MANIFEST.read_text())
        entry = next(row for row in manifest["inputs"] if row["path"] == "gfx/title/player.png")
        self.assertEqual(entry["sha256"], "d8c5b2ded27a989786a20fa4e56b108cd466dde6b79c0f29798c3e9aa2d8b1ca")
        self.assertEqual(entry["size"], [40, 56])
        self.assertEqual(entry["output"], "player.png")
        self.assertEqual(entry["scale"], 1)
        digest = hashlib.sha256(PLAYER.read_bytes()).hexdigest()
        self.assertEqual(digest, "f6368b9681aeb6e98660050bb80fd55efd9dcced7fd5281395387a55516d272e")


if __name__ == "__main__":
    unittest.main()
