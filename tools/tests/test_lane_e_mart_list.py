#!/usr/bin/env python3
"""Mart buy list against pokered af519899.

main 247d60a9 draws "POKE MART - BUY" and "A: Choose   B: Back" from
ShopState, and every clerk opens that one overlay. pokered's list
(home/list_menu.asm, engine/menus/text_box.asm DisplayMoneyBox, and
data/text_boxes.asm LIST_MENU_BOX / MONEY_BOX_TEMPLATE) has neither.

This fails until tools/notes/lane-e-mart-list-fidelity.patch is applied.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/mart_list_host.lua"


def lua_bin():
    if os.environ.get("LUA"):
        return os.environ["LUA"]
    bundled = "/tmp/lua-5.4.7/src/lua"
    if os.path.isfile(bundled):
        return bundled
    return shutil.which("lua") or bundled
POKERED = Path(os.environ.get("POKERED_REFERENCE_DIR", "/tmp/pokered"))


class MartListFidelityTests(unittest.TestCase):
    def test_every_mart_uses_the_pokered_list_and_money_box(self):
        shop = (ROOT / "Source/game/shopState.lua").read_text()
        self.assertNotIn(" - BUY", shop)
        self.assertNotIn(" - SELL", shop)
        self.assertNotIn("A: Choose   B: Back", shop)
        self.assertIn("drawPokeredList", shop)
        drawers = []
        for path in (ROOT / "Source").rglob("*.lua"):
            text = path.read_text(errors="ignore")
            if 'drawText("POKE MART"' in text or "drawPokeredList" in text:
                drawers.append(path.relative_to(ROOT).as_posix())
        self.assertEqual(drawers, ["Source/game/shopState.lua"])
        boxes = (POKERED / "data/text_boxes.asm").read_text()
        self.assertIn("LIST_MENU_BOX", boxes)
        self.assertIn("MONEY_BOX_TEMPLATE", boxes)
        completed = subprocess.run(
            [lua_bin(), str(HOST), str(ROOT)],
            cwd=ROOT, check=False, text=True, capture_output=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)


if __name__ == "__main__":
    unittest.main()
