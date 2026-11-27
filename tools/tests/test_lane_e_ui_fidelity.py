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
        self.assertIn("GbFont.drawCharAt(TitleIdle.CURSOR, 5 * TitleIdle.COL, nameY)", text)
        self.assertNotIn('"> "', text)
        self.assertIn("local textRow = TitleIdle.ROW * 2", text)
        self.assertIn("local ruleInset = TitleIdle.ROW - 9", text)
        self.assertIn("local nameOrigin = TitleIdle.ROW + textRow - ruleInset", text)
        self.assertIn("local nameY = nameOrigin + n * textRow * 2", text)
        self.assertIn("local quantityY = nameY + textRow", text)
        self.assertIn("GbFont.drawStringAt(label, 6 * TitleIdle.COL, nameY)", text)
        self.assertIn("local quantityCol = 19 - GbFont.tiles(quantity)", text)
        self.assertIn("GbFont.drawStringAt(quantity, quantityCol * TitleIdle.COL, quantityY)", text)
        self.assertNotIn("drawOpenString", text)
        self.assertNotIn("OPEN_ROWS", text)
        self.assertNotIn("local nameRow = 4 + n * 2", text)
        self.assertNotIn("local quantityRow = nameRow + 1", text)
        self.assertNotIn("14, row + 1", text)
        self.assertNotIn("14, quantityRow", text)
        self.assertIn("local window = 4", text)
        self.assertIn('GbFont.drawStringAt("CANCEL", 6 * TitleIdle.COL, nameY)', text)
        self.assertIn("local bottomY = lastQuantity + TitleIdle.ROW - ruleInset", text)
        self.assertNotIn("h = 17 * TitleIdle.ROW", text)
        self.assertNotIn("gfx.drawText(hint", text)
        self.assertNotIn("boxCol, boxRow, boxRight, boxBottom = 4, 2, 19, 12", text)
        self.assertIn("item.sourceName or item.name", text)
        self.assertIn("return count + 1", text)
        self.assertIn("start_sub_menus.asm:315", text)
        self.assertIn("core.asm:2226", text)
        self.assertNotIn("drawMoneyRight", text)
        self.assertNotIn("¥", text)
        self.assertNotIn('"$"', text)
        self.assertNotIn("Registered:", text)
        self.assertNotIn("SORT BAG", text)
        self.assertIn('"A: Choose  B: Back"', text)

    def ink_bands(self, path, x0, x1, y0, y1, min_height=6):
        image = Image.open(path).convert("L")
        bands, start = [], None
        for y in range(y0, y1):
            ink = any(image.getpixel((x, y)) < 128 for x in range(x0, x1))
            if ink and start is None:
                start = y
            elif not ink and start is not None:
                if y - start >= min_height:
                    bands.append((start, y - 1))
                start = None
        return bands

    def quantity_on_its_own_row(self, path):
        # Names in the left of the list, quantities on the right. The
        # quantity's top is at or below its name and above the next name,
        # and its bottom clears that next name by half a glyph. r5 leaves
        # only a couple of pixels, so the × sits in the crack.
        names = self.ink_bands(path, 120, 300, 8, 210)
        quantities = self.ink_bands(path, 330, 379, 8, 210)
        if len(quantities) < 2 or len(names) < len(quantities) + 1:
            return False
        for index, (top, bottom) in enumerate(quantities):
            _, name_bottom = names[index]
            next_top, _ = names[index + 1]
            name_height = names[index][1] - names[index][0] + 1
            if top < name_bottom or top >= next_top or bottom >= next_top:
                return False
            if next_top - bottom < name_height // 2:
                return False
        return True

    def test_bag_drawn_rows_keep_each_quantity_on_its_own_line(self):
        frames = ROOT / "artifacts/lane-g/ui-fidelity"
        self.assertFalse(self.quantity_on_its_own_row(frames / "bag-r5.png"))
        self.assertFalse(self.quantity_on_its_own_row(frames / "battle-bag-r5.png"))
        self.assertTrue(self.quantity_on_its_own_row(frames / "bag-r6.png"))
        self.assertTrue(self.quantity_on_its_own_row(frames / "battle-bag-r6.png"))
        self.assertTrue(self.quantity_on_its_own_row(frames / "bag-r7.png"))
        self.assertTrue(self.quantity_on_its_own_row(frames / "battle-bag-r7.png"))

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
        dex = self.painted_height(frames / "pokedex-list-r6.png", 20, 13, 160, 13)
        bag = self.painted_height(frames / "bag-r6.png", 120, 13, 120, 13)
        battle = self.painted_height(frames / "battle-bag-r6.png", 120, 13, 120, 13)
        squashed = self.painted_height(frames / "bag-r4.png", 120, 52, 120, 13)
        self.assertEqual(bag, dex)
        self.assertEqual(battle, dex)
        self.assertNotEqual(squashed, dex)
        self.assertLess(squashed, dex)

    def rule_rows(self, path, y0, y1):
        image = Image.open(path).convert("L")
        return [y for y in range(y0, y1)
                if sum(1 for x in range(310, 340) if image.getpixel((x, y)) < 128) >= 20]

    def borders_clear(self, path):
        # LIST_MENU_BOX leaves one text row between the top rule and the
        # first name, and the bottom rule sits below CANCEL. A text row is
        # two 13px cells. r6 starts the name on the top rule.
        text_row = 26
        top = self.rule_rows(path, 0, 24)
        names = self.ink_bands(path, 120, 300, (top[-1] + 1) if top else 0, 236)
        bottom = self.rule_rows(path, 200, 240)
        if not top or not names or not bottom:
            return False
        bottom_top = bottom[0]
        for previous, y in zip(bottom, bottom[1:]):
            if y - previous > 6:
                bottom_top = y
        return names[0][0] >= top[-1] + text_row and names[-1][1] < bottom_top

    def test_bag_items_clear_the_box_borders(self):
        frames = ROOT / "artifacts/lane-g/ui-fidelity"
        self.assertFalse(self.borders_clear(frames / "bag-r6.png"))
        self.assertFalse(self.borders_clear(frames / "battle-bag-r6.png"))
        self.assertTrue(self.borders_clear(frames / "bag-r7.png"))
        self.assertTrue(self.borders_clear(frames / "battle-bag-r7.png"))

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
