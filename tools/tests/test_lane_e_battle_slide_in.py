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

from PIL import Image

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.tests.lane_e_apply import accepts

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-battle-slide-in.patch"
BEFORE = ROOT / "artifacts/lane-g/e4"
AFTER = ROOT / "artifacts/lane-g/e4-after"
# drawTrainer rests at 340 - width/2, y = 8. The pic is 112x112 (56x56 doubled).
PORTRAIT = (284, 8, 396, 120)
TRAINERS = {
    "lorelei": "lorelei",
    "bruno": "bruno",
    "agatha": "agatha",
    "lance": "lance",
    "champion": "rival3",
}


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
        checked = accepts(PATCH)
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
        present = battle.split("function Battle:present(", 1)[1].split("function Battle:", 1)[0]
        self.assertIn('kind == "silhouetteEnter" and not self.presentationAttached', present)
        self.assertIn("self.pendingSilhouette = true", present)
        self.assertNotIn('kind ~= "silhouetteEnter"', present)
        self.assertIn("openingSlide", scene)
        sync = scene.split("function BattleScene:syncMessage()", 1)[1].split("function BattleScene:", 1)[0]
        self.assertIn("silhouetteOffset() > 0", sync)

    def test_settled_enemy_portrait_matches_before_and_the_threshold(self):
        reference = os.environ.get("POKERED_REFERENCE_DIR")
        if not reference:
            raise RuntimeError("explicit pinned POKERED_REFERENCE_DIR required; no skipped checks")
        root = Path(reference) / "gfx/trainers"
        for name, source_name in TRAINERS.items():
            before = Image.open(BEFORE / f"{name}-pic.png").convert("L").crop(PORTRAIT)
            after = Image.open(AFTER / f"{name}-pic.png").convert("L").crop(PORTRAIT)
            original = Image.open(root / f"{source_name}.png")
            doubled = original.point(lambda value: 255 if value >= 128 else 0, "1").resize(
                (112, 112), Image.Resampling.NEAREST).convert("L")
            after_px = list(after.get_flattened_data())
            before_px = list(before.get_flattened_data())
            doubled_px = list(doubled.get_flattened_data())
            self.assertEqual(len(after_px), len(before_px), name)
            self.assertEqual(len(after_px), len(doubled_px), name)
            self.assertEqual(sum(left != right for left, right in zip(after_px, before_px)), 0, name)
            self.assertEqual(sum(left != right for left, right in zip(after_px, doubled_px)), 0, name)


if __name__ == "__main__":
    unittest.main()
