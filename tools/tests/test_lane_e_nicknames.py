"""Catch and gift paths ask for a nickname. The Name Rater hook is a comment."""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-nicknames.patch"


class LaneENicknameHandoffTests(unittest.TestCase):
    def test_nickname_hooks_are_installed(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertNotEqual(completed.returncode, 0, completed.stderr)
        battle = (ROOT / "Source/battle/battle.lua").read_text()
        house = (ROOT / "Source/game/sourceEventHandlers.lua").read_text()
        lapras = (ROOT / "Source/game/silphStoryController.lua").read_text()
        codec = (ROOT / "Source/domain/pokemonCodec.lua").read_text()
        self.assertIn("pendingNickname", battle)
        self.assertIn("NAME_RATERS_HOUSE", house)
        self.assertIn("promptNickname", lapras)
        self.assertIn("nameCount>=1 and nameCount<=10", codec)
        self.assertIn("0x2642", codec)
        main = (ROOT / "Source/main.lua").read_text()
        self.assertNotIn('import "game/namingState"', main)


if __name__ == "__main__":
    unittest.main()
