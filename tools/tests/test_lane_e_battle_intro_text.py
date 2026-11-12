"""Wild and trainer send-out lines use pokered's appeared pages.

Lane E has not applied this yet. tools/notes/lane-e-battle-intro-text.patch
replaces the wild line with _WildMonAppearedText (data/text/text_2.asm:1237)
and the trainer send-out with _EnemyAppearedText (text_2.asm:1252).
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-battle-intro-text.patch"


class LaneEBattleIntroTextTests(unittest.TestCase):
    def test_intro_text_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        patch = PATCH.read_text()
        self.assertIn("_WildMonAppearedText", patch)
        self.assertIn("_EnemyAppearedText", patch)
        self.assertIn('self:say("Wild " .. self.enemy.name .. "\\nappeared!")', patch)
        self.assertIn('self:say(self.enemy.name .. "\\nappeared!")', patch)

    @unittest.expectedFailure
    def test_wild_and_trainer_use_appeared(self):
        source = (ROOT / "Source/battle/battle.lua").read_text()
        self.assertIn('self:say("Wild " .. self.enemy.name .. "\\nappeared!")', source)
        self.assertIn('self:say(self.enemy.name .. "\\nappeared!")', source)
        self.assertNotIn("A wild ", source)
        self.assertNotIn(" sent out ", source)


if __name__ == "__main__":
    unittest.main()
