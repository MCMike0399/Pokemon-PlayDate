"""Lane E still owns capture, gift, and the Name Rater house hook.
The patch applies. The current sources do not ask for a nickname.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-nicknames.patch"


class LaneENicknameHandoffTests(unittest.TestCase):
    def test_nickname_patch_applies_cleanly(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)

    @unittest.expectedFailure
    def test_catch_and_gifts_ask_for_a_nickname(self):
        battle = (ROOT / "Source/battle/battle.lua").read_text()
        house = (ROOT / "Source/game/sourceEventHandlers.lua").read_text()
        lapras = (ROOT / "Source/game/silphStoryController.lua").read_text()
        self.assertIn("pendingNickname", battle)
        self.assertIn("NAME_RATERS_HOUSE", house)
        self.assertIn("promptNickname", lapras)


if __name__ == "__main__":
    unittest.main()
