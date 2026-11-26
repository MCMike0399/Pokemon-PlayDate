"""Pokédex side menu, bag money, trainer card, and Bill's PC text.

Lane E has not applied this yet. tools/notes/lane-e-ui-fidelity.patch
is the source change. These checks fail on the live tree and pass once
that patch is applied. The Gen V ATTACK/DEFENSE/SP. ATK/SP. DEF/SPEED
split stays.
"""
import subprocess
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-ui-fidelity.patch"


class LaneEUIFidelityTests(unittest.TestCase):
    def test_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        patch = PATCH.read_text(encoding="utf-8", errors="replace")
        self.assertIn("PokedexState.SIDE", patch)
        self.assertIn("images/trainer/badges", patch)
        self.assertIn("BOX No.", patch)
        self.assertNotIn("MallocPoolSize", patch)

    def test_pokedex_side_menu_uses_the_cursor_tile(self):
        text = (ROOT / "Source/game/pokedexState.lua").read_text(encoding="utf-8")
        self.assertIn('PokedexState.SIDE = {"DATA", "CRY", "AREA", "QUIT"}', text)
        self.assertIn("GbFont.drawChar(TitleIdle.CURSOR", text)
        self.assertNotIn('i==self.selected and ">"', text)
        self.assertIn('self.phase, self.menuIndex = "menu", 1', text)

    def test_pokedex_list_panel_matches_the_menu(self):
        text = (ROOT / "Source/game/pokedexState.lua").read_text(encoding="utf-8")
        self.assertIn("function PokedexState:drawList()", text)
        listed, entry = text.split("function PokedexState:drawList()", 1)[1].split(
            "function PokedexState:drawEntry", 1)
        self.assertIn('GbFont.drawString("CONTENTS", 1, 1)', listed)
        self.assertNotIn("POKEDEX", listed)
        self.assertIn('GbFont.drawString("SEEN", 16, 2)', listed)
        self.assertIn('GbFont.drawString(string.format("%3d", seen), 16, 3)', listed)
        self.assertIn('GbFont.drawString("OWN", 16, 5)', listed)
        self.assertIn('GbFont.drawString(string.format("%3d", owned), 16, 6)', listed)
        self.assertIn('GbFont.drawChar("│", 14, row)', listed)
        self.assertIn("local sideRows={10,12,14,16}", listed)
        self.assertNotIn("10+index-1", listed)
        self.assertIn("GbFont.drawString(label, 16, row)", listed)
        self.assertNotIn("drawFront", listed)
        self.assertNotIn("No.%03d", listed)
        self.assertIn("drawFront", entry)
        self.assertIn("No.%03d", entry)

    def test_bag_list_matches_the_item_menu(self):
        text = (ROOT / "Source/game/bagState.lua").read_text(encoding="utf-8")
        self.assertIn("GbFont.drawChar(TitleIdle.CURSOR, 5, nameRow)", text)
        self.assertNotIn('"> "', text)
        self.assertIn("local nameRow = 4 + n * 2", text)
        self.assertIn("local quantityRow = nameRow + 1", text)
        self.assertIn("GbFont.drawString(label, 6, nameRow)", text)
        self.assertIn("local quantityCol = 19 - GbFont.tiles(quantity)", text)
        self.assertIn("GbFont.drawString(quantity, quantityCol, quantityRow)", text)
        self.assertNotIn("drawOpenString", text)
        self.assertNotIn("OPEN_ROWS", text)
        self.assertNotIn("local row = 4 + n * 2", text)
        self.assertNotIn("14, row + 1", text)
        self.assertNotIn("14, quantityRow", text)
        self.assertIn("local window = 4", text)
        self.assertIn('GbFont.drawString("CANCEL", 6, nameRow)', text)
        self.assertIn("item.sourceName or item.name", text)
        self.assertIn("return count + 1", text)
        self.assertIn("boxCol, boxRow, boxRight, boxBottom = 4, 2, 19, 12", text)
        self.assertIn("start_sub_menus.asm:315", text)
        self.assertIn("core.asm:2226", text)
        self.assertNotIn("drawMoneyRight", text)
        self.assertNotIn("¥", text)
        self.assertNotIn('"$"', text)
        self.assertNotIn("Registered:", text)
        self.assertNotIn("SORT BAG", text)
        self.assertIn('"A: Choose  B: Back"', text)

    def test_bag_drawn_rows_keep_each_quantity_on_its_own_line(self):
        # Names stay on rows 4, 6, 8, 10 and the quantity on the row below,
        # in the same 20 by 13 cell the Pokédex list uses. The quantity sits
        # to the right of a nine-tile name, so the two full cells do not meet.
        text = (ROOT / "Source/game/bagState.lua").read_text(encoding="utf-8")
        font = (ROOT / "Source/game/gbFont.lua").read_text(encoding="utf-8")
        self.assertIn("function GbFont.drawString", font)
        self.assertNotIn("OPEN_ROWS", font)
        self.assertNotIn("drawOpenString", font)
        self.assertIn("local quantityCol = 19 - GbFont.tiles(quantity)", text)
        row_px, col_px = 13, 20
        glyph = row_px
        for n in range(4):
            name_row = 4 + n * 2
            quantity_row = name_row + 1
            name_top = name_row * row_px
            name_bottom = name_top + glyph
            quantity_top = quantity_row * row_px
            quantity_bottom = quantity_top + glyph
            self.assertEqual(quantity_row, name_row + 1)
            self.assertGreaterEqual(quantity_top, name_bottom)
            if n < 3:
                next_name_top = (4 + (n + 1) * 2) * row_px
                self.assertGreaterEqual(next_name_top, quantity_bottom)
            quantity_col = 19 - 2
            name_last = 6 + 9 - 1
            name_right = (name_last + 1) * col_px
            quantity_left = quantity_col * col_px
            self.assertGreaterEqual(quantity_col, name_last + 1)
            self.assertGreaterEqual(quantity_left, name_right)
            self.assertLessEqual((quantity_col + 2) * col_px, 19 * col_px)
            self.assertLessEqual(quantity_bottom, 12 * row_px)

    def painted_height(self, path, x, y, w, h):
        image = Image.open(path).convert("L")
        rows = [yy for yy in range(y, y + h)
                if any(image.getpixel((xx, yy)) < 128 for xx in range(x, x + w))]
        self.assertTrue(rows, path)
        return rows[-1] - rows[0] + 1

    def test_bag_glyph_height_matches_the_pokedex_list(self):
        # CONTENTS and POTION are both drawn by GbFont.drawString into a
        # 20 by 13 cell. r4's bag glyphs are the 8px open tiles, so this
        # equality fails on bag-r4.png.
        frames = ROOT / "artifacts/lane-g/ui-fidelity"
        dex = self.painted_height(frames / "pokedex-list-r5.png", 20, 13, 160, 13)
        bag = self.painted_height(frames / "bag-r5.png", 120, 52, 120, 13)
        battle = self.painted_height(frames / "battle-bag-r5.png", 120, 52, 120, 13)
        squashed = self.painted_height(frames / "bag-r4.png", 120, 52, 120, 13)
        self.assertEqual(bag, dex)
        self.assertEqual(battle, dex)
        self.assertNotEqual(squashed, dex)
        self.assertLess(squashed, dex)

    def test_trainer_card_draws_red_and_badges(self):
        text = (ROOT / "Source/game/pauseState.lua").read_text(encoding="utf-8")
        self.assertIn("images/player/red-pic-front", text)
        self.assertIn("images/trainer/badges", text)
        self.assertIn("function PauseState:drawTrainer", text)
        self.assertNotIn('"BADGES  "', text)
        self.assertTrue((ROOT / "Source/images/trainer/badges.png").is_file())

    def test_pc_matches_bills_pc_text(self):
        pc = (ROOT / "Source/game/pcState.lua").read_text(encoding="utf-8")
        idle = (ROOT / "Source/game/titleIdle.lua").read_text(encoding="utf-8")
        menu = (ROOT / "Source/ui/menu.lua").read_text(encoding="utf-8")
        self.assertIn('"BILL\'s PC"', pc)
        self.assertNotIn("BILL'S PC", pc)
        self.assertIn('"BOX No. "', pc)
        self.assertIn('"WITHDRAW PKMN"', pc)
        self.assertIn('pair == "PK" or pair == "MN"', idle)
        self.assertIn("self.gbText", menu)
        self.assertIn("self.menu.gbText=true", pc)


if __name__ == "__main__":
    unittest.main()
