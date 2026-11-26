"""Front-end tile positions against pokered af519899.

The START menu already uses the 20 by 13 dex cell. The party, status,
summary, trainer card, and save screen do not. Each gap is a patch in
tools/notes. These checks measure the Simulator frames: the predicate
fails on the unpatched frame and passes on the patched one. A text row
of PlaceString <NEXT> is two cells, 26px.
"""
import subprocess
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FRAMES = ROOT / "artifacts/lane-g/fidelity-sweep"
NOTES = ROOT / "tools/notes"
PATCHES = {
    "party": NOTES / "lane-e-party-fidelity.patch",
    "status": NOTES / "lane-e-status-fidelity.patch",
    "trainer": NOTES / "lane-e-trainer-fidelity.patch",
    "save": NOTES / "lane-e-save-fidelity.patch",
}


def ink_bands(path, x0, x1, y0, y1, min_height=8):
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
    if start is not None and y1 - start >= min_height:
        bands.append((start, y1 - 1))
    return bands


def blank(path, x0, x1, y0, y1):
    image = Image.open(path).convert("L")
    return not any(image.getpixel((x, y)) < 128
                   for y in range(y0, y1) for x in range(x0, x1))


class LaneEFidelitySweepTests(unittest.TestCase):
    def test_patches_apply_alone_and_stacked(self):
        for patch in PATCHES.values():
            completed = subprocess.run(
                ["git", "apply", "--check", str(patch)],
                cwd=ROOT, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            text = patch.read_text(encoding="utf-8", errors="replace")
            self.assertNotIn("MallocPoolSize", text)
            self.assertIn("GbFont.drawString", text)
            self.assertNotIn("drawTight", text)
        # --check of two files does not stack them. Apply the pair, then
        # put the tree back. Source/ stays unchanged after the test.
        try:
            for first, second in (("party", "status"), ("trainer", "save")):
                applied = subprocess.run(
                    ["git", "apply", str(PATCHES[first])],
                    cwd=ROOT, check=False, capture_output=True, text=True)
                self.assertEqual(applied.returncode, 0, applied.stderr)
                stacked = subprocess.run(
                    ["git", "apply", "--check", str(PATCHES[second])],
                    cwd=ROOT, check=False, capture_output=True, text=True)
                self.assertEqual(stacked.returncode, 0, stacked.stderr)
                subprocess.run(
                    ["git", "checkout", "--", "Source"], cwd=ROOT, check=True)
        finally:
            subprocess.run(["git", "checkout", "--", "Source"], cwd=ROOT, check=True)

    def test_start_menu_already_matches_the_tile_rows(self):
        # draw_start_menu.asm DrawStartMenu: box at hlcoord 10, 0, first
        # item at row 2 column 12, cursor at column 11, PrintStartMenuItem
        # steps two rows. The before and after frames are the same bytes.
        for name in ("start-before.png", "start-after.png"):
            path = FRAMES / name
            rows = ink_bands(path, 250, 380, 0, 210)
            self.assertEqual([row[0] for row in rows], [26, 52, 78, 104, 130, 156, 182])
            self.assertTrue(blank(path, 250, 380, 13, 26))
            cursor = ink_bands(path, 220, 239, 20, 45, 4)
            self.assertTrue(cursor and cursor[0][0] >= 26)

    def party_rows(self, path):
        # RedrawPartyMenu_ names at row 0, 2, 4. The cursor is on the HP
        # row, one cell below the name (PartyMenuInit Y = 1).
        names = ink_bands(path, 24, 90, 0, 120)
        cursor = ink_bands(path, 0, 16, 0, 40, 6)
        if len(names) < 2 or not cursor:
            return False
        return (names[0][0] <= 2
                and names[1][0] - names[0][0] >= 26
                and cursor[0][0] >= names[0][1])

    def test_party_names_use_two_row_spacing(self):
        self.assertFalse(self.party_rows(FRAMES / "party-before.png"))
        self.assertTrue(self.party_rows(FRAMES / "party-after.png"))

    def status_rows(self, path):
        # StatusScreen name at row 1. StatsText ATTACK is row 9, then
        # every two rows.
        labels = ink_bands(path, 20, 100, 110, 220)
        name = ink_bands(path, 180, 320, 0, 40)
        if len(labels) < 2 or not name:
            return False
        return (117 <= labels[0][0] <= 120
                and labels[1][0] - labels[0][0] >= 26
                and 13 <= name[0][0] <= 16)

    def test_status_page_puts_attack_on_row_nine(self):
        self.assertFalse(self.status_rows(FRAMES / "status-before.png"))
        self.assertTrue(self.status_rows(FRAMES / "status-after.png"))

    def summary_rows(self, path):
        # StatusScreen2 EXP POINTS at row 3. Moves at row 9, two apart.
        # PP is the next row.
        exp = ink_bands(path, 180, 340, 30, 60)
        moves = ink_bands(path, 40, 160, 100, 220)
        pp = ink_bands(path, 220, 250, 100, 220)
        if not exp or len(moves) < 2 or not pp:
            return False
        return (39 <= exp[0][0] <= 42
                and 117 <= moves[0][0] <= 120
                and moves[1][0] - moves[0][0] >= 26
                and pp[0][0] >= moves[0][1])

    def test_summary_page_puts_exp_on_row_three(self):
        self.assertFalse(self.summary_rows(FRAMES / "summary-before.png"))
        self.assertTrue(self.summary_rows(FRAMES / "summary-after.png"))

    def trainer_rows(self, path):
        # DrawTrainerInfo NAME/ at row 2, then MONEY/ and TIME/ two rows
        # apart.
        labels = ink_bands(path, 40, 120, 20, 100)
        if len(labels) < 2:
            return False
        return 26 <= labels[0][0] <= 28 and labels[1][0] - labels[0][0] >= 26

    def test_trainer_card_labels_start_on_row_two(self):
        self.assertFalse(self.trainer_rows(FRAMES / "trainer-before.png"))
        self.assertTrue(self.trainer_rows(FRAMES / "trainer-after.png"))

    def save_rows(self, path):
        # PrintSaveScreenText PLAYER at row 2. YES is row 8 and NO is
        # row 10 (yes_no_menu_strings.asm, no blank line).
        player = ink_bands(path, 100, 180, 20, 45)
        yes = ink_bands(path, 40, 70, 90, 150)
        if not player or len(yes) < 2:
            return False
        return (26 <= player[0][0] <= 28
                and 104 <= yes[0][0] <= 108
                and yes[1][0] - yes[0][0] >= 26)

    def test_save_screen_puts_player_on_row_two(self):
        self.assertFalse(self.save_rows(FRAMES / "save-before.png"))
        self.assertTrue(self.save_rows(FRAMES / "save-after.png"))


if __name__ == "__main__":
    unittest.main()
