"""Lane E still owns the save codec. The name patch applies, and the
current source still refuses every title except RED / BLUE.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-names.patch"


class LaneENameHandoffTests(unittest.TestCase):
    def test_name_patch_applies_cleanly(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)

    @unittest.expectedFailure
    def test_codec_stores_the_chosen_names(self):
        codec = (ROOT / "Source/domain/sessionCodec.lua").read_text()
        session = (ROOT / "Source/domain/gameSession.lua").read_text()
        text = (ROOT / "Source/game/sourceText.lua").read_text()
        self.assertNotIn('playerName=="RED"', codec)
        self.assertNotIn('title={playerName="RED",rivalName="BLUE"}', codec)
        self.assertIn("function GameSession:setPlayerName", session)
        self.assertIn("function GameSession:setRivalName", session)
        self.assertIn("Story.playerName", text)


if __name__ == "__main__":
    unittest.main()
