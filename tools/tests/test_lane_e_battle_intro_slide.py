#!/usr/bin/env python3
"""The opening slide shows silhouettes before any name box or the starter.

pret/pokered af519899 engine/battle/core.asm:

- line 9 SlidePlayerAndEnemySilhouettesOnScreen
- line 10 call LoadPlayerBackPic (RED's back, not the starter)
- lines 70-84 .slideSilhouettesLoop slides both pics in
- line 100 jpfar PrintBeginningBattleText

PrintBeginningBattleText draws the enemy name and HP, then
"Wild RATTATA appeared!" or the trainer intro. The starter is sent
only after "Go! SQUIRTLE!". tools/notes/lane-e-battle-intro-slide.patch
is the note. This test captures the middle of the slide and stays red
until that note is applied.
"""

import json
import os
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.harness.run import sdk_path

PATCH = ROOT / "tools/notes/lane-e-battle-intro-slide.patch"
CORE = Path(os.environ.get("POKERED_REFERENCE_DIR", "/tmp/pokered")) / "engine/battle/core.asm"
SCENARIO = {
    "commands": [
        {
            "op": "fixture",
            "options": {
                "intro": "skip",
                "opening": False,
                "seed": 1,
                "zone": "reds_house_2f",
                "player_pokemon": {"species": "squirtle", "level": 16, "nature_id": 0},
                "inventory": {"money": 1234, "slots": []},
            },
        },
        {"op": "await", "path": "player.settled", "equals": True, "frames": 120},
        "battle rattata 5",
        "wait 8",
        "record mid-slide 10",
    ],
    "outputs": ["mid-slide-01-display.png", "mid-slide-10-display.png"],
}


def black_run(image, y, x0, x1):
    run = best = 0
    for x in range(x0, x1):
        if image.getpixel((x, y)) < 128:
            run += 1
            best = max(best, run)
        else:
            run = 0
    return best


def ink(image, x0, y0, x1, y1):
    return sum(
        image.getpixel((x, y)) < 128
        for y in range(y0, y1)
        for x in range(x0, x1)
    )


class BattleIntroSlideTests(unittest.TestCase):
    def test_mid_slide_frames_have_no_hud_and_no_starter(self):
        lines = CORE.read_text(encoding="utf-8").splitlines()
        self.assertEqual(lines[8], "SlidePlayerAndEnemySilhouettesOnScreen:")
        self.assertIn("LoadPlayerBackPic", lines[9])
        self.assertIn(".slideSilhouettesLoop", lines[69])
        self.assertEqual(lines[99].strip(), "jpfar PrintBeginningBattleText")
        note = PATCH.read_text(encoding="utf-8")
        self.assertIn("core.asm:100", note)
        self.assertIn("core.asm:70", note)
        self.assertNotIn("MallocPoolSize", note)

        output = Path(os.environ.get(
            "BATTLE_INTRO_SLIDE_OUTPUT", "/tmp/battle-intro-slide"))
        if output.exists():
            shutil.rmtree(output)
        scenario = output.parent / "battle-intro-slide.json"
        # The runner requires the output directory to be absent, so the
        # scenario file lives beside it.
        scenario.write_text(json.dumps(SCENARIO))
        proc = subprocess.run(
            [
                sys.executable, "tools/harness/run.py",
                "--sdk", str(sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))),
                "--scenario", str(scenario),
                "--output", str(output),
                "--timeout", "180",
                "--ready-timeout", "90",
            ],
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
        )
        summary_path = output / "summary.json"
        if not summary_path.is_file():
            summary_path = output / "run.json"
        self.assertTrue(summary_path.is_file(), proc.stderr[-1500:] or proc.stdout[-1500:])
        frames = sorted((output / "frames").glob("mid-slide-*-display.png"))
        self.assertGreaterEqual(len(frames), 8, proc.stderr[-800:])
        for path in frames:
            image = Image.open(path).convert("L")
            hud = max(black_run(image, y, 0, 170) for y in range(0, 48))
            self.assertLess(
                hud, 40,
                "%s still draws the name/HP box during the slide" % path.name)
            self.assertLess(
                ink(image, 50, 70, 145, 145), 80,
                "%s shows the starter during the slide" % path.name)
            self.assertGreater(
                ink(image, 180, 40, 390, 150), 400,
                "%s missed the sliding pics" % path.name)


if __name__ == "__main__":
    unittest.main()
