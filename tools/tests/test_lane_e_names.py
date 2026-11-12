"""Chosen player and rival names round-trip. Old saves still load as RED and BLUE."""
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-names.patch"


def lua_binary():
    for name in ("lua", "lua5.4"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required")


class LaneENameHandoffTests(unittest.TestCase):
    def test_name_patch_is_installed(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertNotEqual(completed.returncode, 0, completed.stderr)
        codec = (ROOT / "Source/domain/sessionCodec.lua").read_text()
        session = (ROOT / "Source/domain/gameSession.lua").read_text()
        text = (ROOT / "Source/game/sourceText.lua").read_text()
        self.assertIn("VERSION=5", codec)
        self.assertIn("data.version==4 or data.version==SessionCodec.VERSION", codec)
        self.assertNotIn('playerName=="RED"', codec)
        self.assertNotIn('title={playerName="RED",rivalName="BLUE"}', codec)
        self.assertIn('personName(data.title.playerName,"RED")', codec)
        self.assertIn('personName(data.title.rivalName,"BLUE")', codec)
        self.assertIn("function GameSession:setPlayerName", session)
        self.assertIn("function GameSession:setRivalName", session)
        self.assertIn("Story.playerName", text)
        rival = (ROOT / "Source/data/vermilionStory/trainers.json").read_text()
        self.assertIn('"name": "BLUE"', rival)

    def test_player_names_count_glyphs(self):
        session = (ROOT / "Source/domain/gameSession.lua").read_text()
        start = session.index("local function personName")
        finish = session.index("function GameSession:setPlayerName")
        probe = session[start:finish] + """
assert(personName("RED") == true)
assert(personName("BLUE") == true)
assert(personName("♂♀×AB") == true)
assert(personName(string.rep("♂", 7)) == true)
assert(personName(string.rep("♂", 8)) == false)
assert(personName("") == false)
assert(personName("é") == false)
assert(personName("ABCDEFGH") == false)
print("glyphs-ok")
"""
        completed = subprocess.run(
            [lua_binary(), "-e", probe],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("glyphs-ok", completed.stdout)


if __name__ == "__main__":
    unittest.main()
