"""StartBattle slides both pics in before PrintBeginningBattleText.

engine/battle/core.asm:9 SlidePlayerAndEnemySilhouettesOnScreen
engine/battle/core.asm:100 jpfar PrintBeginningBattleText
engine/battle/core.asm:6738 call SlidePlayerAndEnemySilhouettesOnScreen
engine/battle/core.asm:6763 call StartBattle

ld c, $90 steps by 2 for 72 Game Boy frames. At 30fps and 2x art that is
36 frames at 8px. The slide is an x delta on pics the scene already holds.
The live script prints the intro with no slide. The patch is
tools/notes/lane-e-battle-slide-in.patch.
"""

import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-battle-slide-in.patch"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=False, capture_output=True, text=True)


class BattleSlideInTests(unittest.TestCase):
    def test_patch_applies_and_allocates_nothing(self):
        text = PATCH.read_text()
        self.assertIn('self:present("silhouetteEnter")', text)
        self.assertIn("engine/battle/core.asm:9", text)
        self.assertIn("engine/battle/core.asm:100", text)
        self.assertIn("core.asm:6738", text)
        self.assertIn("core.asm:6763", text)
        self.assertIn("duration = 36", text)
        self.assertNotIn("MallocPoolSize", text)
        self.assertNotIn("gfx.image.new", text)
        reference = os.environ.get("POKERED_REFERENCE_DIR")
        if not reference:
            raise RuntimeError("explicit pinned POKERED_REFERENCE_DIR required; no skipped checks")
        core = (Path(reference) / "engine/battle/core.asm").read_text().splitlines()
        self.assertEqual(core[8], "SlidePlayerAndEnemySilhouettesOnScreen:")
        self.assertEqual(core[99], "\tjpfar PrintBeginningBattleText")
        self.assertEqual(core[6737], "\tcall SlidePlayerAndEnemySilhouettesOnScreen")
        self.assertEqual(core[6762], "\tcall StartBattle")
        checked = git("apply", "--check", str(PATCH))
        self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_live_script_slides_both_pics_before_the_first_line(self):
        battle = (ROOT / "Source/battle/battle.lua").read_text()
        script = battle.split("self:runScript(function()", 1)[1].split("self:say(", 1)[0]
        self.assertIn('self:present("silhouetteEnter")', script)
        scene = (ROOT / "Source/battle/battleScene.lua").read_text()
        offset = scene.split("function BattleScene:silhouetteOffset()", 1)[1].split("function BattleScene:", 1)[0]
        self.assertNotIn("gfx.image.new", offset)
        self.assertIn("return remain * step", offset)
        visual = scene.split("function BattleScene:updateVisualEvent", 1)[1].split("function BattleScene:", 1)[0]
        self.assertIn('request.kind == "silhouetteEnter"', visual)
        self.assertIn("duration = 36", visual)
        field = scene.split("function BattleScene:drawBattleField()", 1)[1].split("function BattleScene:", 1)[0]
        self.assertIn("self:silhouetteOffset()", field)


if __name__ == "__main__":
    unittest.main()
