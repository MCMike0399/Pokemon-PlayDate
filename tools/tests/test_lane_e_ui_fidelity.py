"""Pokédex side menu, bag money, trainer card, and Bill's PC text.

Lane E has not applied this yet. tools/notes/lane-e-ui-fidelity.patch
is the source change. These checks fail on the live tree and pass once
that patch is applied. The Gen V ATTACK/DEFENSE/SP. ATK/SP. DEF/SPEED
split stays.
"""
import subprocess
import unittest
from pathlib import Path

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
        self.assertIn("local row=10+index-1", listed)
        self.assertIn("GbFont.drawString(label, 16, row)", listed)
        self.assertNotIn("drawFront", listed)
        self.assertNotIn("No.%03d", listed)
        self.assertIn("drawFront", entry)
        self.assertIn("No.%03d", entry)

    def test_bag_list_matches_the_item_menu(self):
        text = (ROOT / "Source/game/bagState.lua").read_text(encoding="utf-8")
        self.assertIn("GbFont.drawChar(TitleIdle.CURSOR, 5, row)", text)
        self.assertNotIn('"> "', text)
        self.assertIn('GbFont.drawString("×" .. slot.quantity, 14, row + 1)', text)
        self.assertIn('GbFont.drawString("CANCEL", 6, row)', text)
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
