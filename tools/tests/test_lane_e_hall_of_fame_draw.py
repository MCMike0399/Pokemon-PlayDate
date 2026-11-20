"""Hall of Fame draw on E's tip, from the lane G dry run.

pokered af519899 shows the copyright notice, THE END, white credits glyphs,
and the player name on the card. These checks fail on the live tree.
tools/notes/lane-e-hall-of-fame-draw.patch is the unapplied fix.
"""

import os
from pathlib import Path
import shutil
import subprocess
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DRY = ROOT / "artifacts/lane-g/hof-dryrun"


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


class HallOfFameDrawTests(unittest.TestCase):
    def test_player_name_is_on_the_hall_card(self):
        script = r"""
dofile("Source/game/endgameStory.lua")
local row = EndgameStory.playerHallRows({name = "RED"})[1]
local _, y = EndgameStory.hallPixel(row.col * 8, row.row * 8)
io.write(tostring(y))
"""
        completed = subprocess.run(
            [lua_binary(), "-e", script],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertGreaterEqual(int(completed.stdout), 0)

    def test_credits_draw_shows_the_notice_and_the_end(self):
        draw = (ROOT / "Source/game/eventState.lua").read_text()
        story = (ROOT / "Source/game/endgameStory.lua").read_text()
        start = draw.index("local view = CreditsPlayer.view(self.credits)")
        block = draw[start:draw.index("gfx.popContext()", start)]
        shown = block + "\n" + story
        if "EndgameStory.drawCredits" in block:
            self.assertIn("creditsBands", story)
            self.assertIn('text = "black"', story)
        else:
            self.assertIn("kDrawModeFillWhite", block)
        self.assertIn("©'95.'96.'98 Nintendo", shown)
        self.assertIn("©'95.'96.'98 Creatures inc.", shown)
        self.assertIn("©'95.'96.'98 GAME FREAK inc.", shown)
        self.assertNotIn('view.ending and view.phase == "done"', shown)
        self.assertIn("if view.ending then", shown)

    def test_dry_run_credits_frames_show_text(self):
        blank = []
        for name in ("credits-00.png", "credits-34.png", "the-end.png"):
            path = DRY / name
            self.assertTrue(path.is_file(), name)
            with Image.open(path) as image:
                self.assertEqual(image.size, (400, 240), name)
                if sum(image.convert("L").histogram()[1:]) == 0:
                    blank.append(name)
        self.assertEqual(blank, [])


if __name__ == "__main__":
    unittest.main()
