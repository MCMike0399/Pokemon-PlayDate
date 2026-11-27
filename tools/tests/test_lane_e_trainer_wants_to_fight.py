"""Every trainer battle uses pokered's TrainerWantsToFightText.

data/text/text_2.asm:1258 _TrainerWantsToFightText
    text_ram wTrainerName
    text " wants"
    line "to fight!"
    prompt
engine/battle/common_text.asm:24 ld hl, TrainerWantsToFightText
engine/battle/common_text.asm:85 text_far _TrainerWantsToFightText

The live Source tree still says "wants to battle!". The patch is
tools/notes/lane-e-trainer-wants-to-fight.patch.
"""

import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-trainer-wants-to-fight.patch"
FIGHT = 'self:say(self.trainerName .. " wants\\nto fight!", "prompt")'


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=False, capture_output=True, text=True)


class TrainerWantsToFightTests(unittest.TestCase):
    def test_patch_applies_and_cites_pokered(self):
        text = PATCH.read_text()
        self.assertIn("data/text/text_2.asm:1258", text)
        self.assertIn("engine/battle/common_text.asm:24", text)
        self.assertIn("engine/battle/common_text.asm:85", text)
        self.assertIn("engine/battle/common_text.asm:86", text)
        self.assertIn(FIGHT, text)
        self.assertNotIn("MallocPoolSize", text)
        reference = os.environ.get("POKERED_REFERENCE_DIR")
        if not reference:
            raise RuntimeError("explicit pinned POKERED_REFERENCE_DIR required; no skipped checks")
        root = Path(reference)
        text_2 = (root / "data/text/text_2.asm").read_text().splitlines()
        common = (root / "engine/battle/common_text.asm").read_text().splitlines()
        self.assertEqual(text_2[1257], "_TrainerWantsToFightText::")
        self.assertEqual(text_2[1259], '\ttext " wants"')
        self.assertEqual(text_2[1260], '\tline "to fight!"')
        self.assertEqual(text_2[1261], "\tprompt")
        self.assertEqual(common[23], "\tld hl, TrainerWantsToFightText")
        self.assertEqual(common[84], "TrainerWantsToFightText:")
        self.assertEqual(common[85], "\ttext_far _TrainerWantsToFightText")
        checked = git("apply", "--check", str(PATCH))
        self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_live_trainer_intro_is_the_fight_line(self):
        battle = (ROOT / "Source/battle/battle.lua").read_text()
        script = battle.split("self:runScript(function()", 1)[1].split("function Battle:runScript", 1)[0]
        self.assertIn(FIGHT, script)
        self.assertNotIn('wants to battle!"', script)
        say = battle.split("function Battle:say(", 1)[1].split("function Battle:", 1)[0]
        self.assertIn("self.messageEnding = ending", say)
        scene = (ROOT / "Source/battle/battleScene.lua").read_text()
        sync = scene.split("function BattleScene:syncMessage()", 1)[1].split("function BattleScene:", 1)[0]
        self.assertIn('ending = self.battle.messageEnding', sync)


if __name__ == "__main__":
    unittest.main()
