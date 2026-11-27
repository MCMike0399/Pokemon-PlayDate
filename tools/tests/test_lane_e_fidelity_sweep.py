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


SPRITE = (0, 0, 140, 100)
TRAINER_PIC = (280, 0, 400, 120)


def badge_rects():
    rects = []
    for index in range(8):
        col = 2 + (index % 4) * 4
        row = 11 if index < 4 else 14
        x = (col + 1) * 20 + 8
        y = (row + 1) * 13 + 1
        rects.append((x, y, x + 24, y + 24))
    return rects


BADGE_RECTS = badge_rects()
BADGE_UNION = (
    min(rect[0] for rect in BADGE_RECTS),
    min(rect[1] for rect in BADGE_RECTS),
    max(rect[2] for rect in BADGE_RECTS),
    max(rect[3] for rect in BADGE_RECTS),
)


def hits(cell, rects):
    x0, y0, x1, y1 = cell
    for rx0, ry0, rx1, ry1 in rects:
        if x0 < rx1 and rx0 < x1 and y0 < ry1 and ry0 < y1:
            return True
    return False


def glyph_issues(path, skip):
    """Text ink is at most 12 by 12 and keeps a pixel of air from its neighbor.

    Full-cell borders and the HP bar are not text. Sprite and badge art is
    passed in skip. A problem list is empty only when every text cell fits.
    """
    image = Image.open(path).convert("L")
    cells = {}
    issues = []
    for row in range(240 // 13):
        for col in range(400 // 20):
            x0, y0 = col * 20, row * 13
            if hits((x0, y0, x0 + 20, y0 + 13), skip):
                continue
            minx, maxx, miny, maxy = 20, -1, 13, -1
            row_count = [0] * 13
            for dy in range(13):
                for dx in range(20):
                    if image.getpixel((x0 + dx, y0 + dy)) < 128:
                        minx, maxx = min(minx, dx), max(maxx, dx)
                        miny, maxy = min(miny, dy), max(maxy, dy)
                        row_count[dy] += 1
            if maxx < 0:
                continue
            width, height = maxx - minx + 1, maxy - miny + 1
            # A full-cell border stroke or corner runs at least 14px across.
            # A fitted glyph is 12px, so it cannot.
            if max(row_count) >= 14:
                continue
            if width >= 16 and height <= 8:
                continue
            if height >= 13 and width <= 10:
                continue
            cells[(col, row)] = (minx, maxx, miny, maxy)
            if width > 12 or height > 12:
                issues.append((col, row, width, height))
    for (col, row), box in cells.items():
        right = cells.get((col + 1, row))
        if right is not None and (20 - box[1] - 1) + right[0] < 1:
            issues.append(("h", col, row))
        below = cells.get((col, row + 1))
        if below is not None and (13 - box[3] - 1) + below[2] < 1:
            issues.append(("v", col, row))
    return issues


def ink_count(path, x0, y0, x1, y1):
    image = Image.open(path).convert("L")
    return sum(1 for y in range(y0, y1) for x in range(x0, x1) if image.getpixel((x, y)) < 128)


def same_ink(left, right, x0, y0, x1, y1):
    a = Image.open(left).convert("L")
    b = Image.open(right).convert("L")
    return all((a.getpixel((x, y)) < 128) == (b.getpixel((x, y)) < 128)
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
            self.assertNotIn("drawTight", text)
            self.assertIn("math.floor(y * 8 /", text)
            self.assertIn("math.floor(x * 8 /", text)
            self.assertIn("_FIT <const> = 12", text)
        party = PATCHES["party"].read_text(encoding="utf-8", errors="replace")
        self.assertIn("row = 1 + (i - 1) * 2", party)
        status = PATCHES["status"].read_text(encoding="utf-8", errors="replace")
        self.assertIn('statusFitString("PP", 11, row + 1)', status)
        self.assertIn("local row = 9 + (index - 1) * 2", status)
        trainer = PATCHES["trainer"].read_text(encoding="utf-8", errors="replace")
        self.assertIn("gfx/trainer_card/badges.png", trainer)
        self.assertIn("gfx/trainer_card/badge_numbers.png", trainer)
        self.assertIn("gfx/trainer_card/circle_tile.png", trainer)
        self.assertIn("hlcoord 2, 11", trainer)
        self.assertIn("hlcoord 2, 14", trainer)
        save = PATCHES["save"].read_text(encoding="utf-8", errors="replace")
        self.assertIn("engine/menus/save.asm SaveTheGame_YesOrNo", save)
        self.assertIn("home/text.asm TextBoxBorder", save)
        self.assertIn("engine/menus/main_menu.asm PrintSaveScreenText", save)
        self.assertIn("column 5 row 8", save)
        self.assertIn("columns 0-5 and rows 7-11", save)
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
        # The first name is tile row 1. Each mon takes two rows, and the
        # cursor sits on the HP row under that name.
        names = ink_bands(path, 70, 160, 0, 180)
        cursor = ink_bands(path, 0, 20, 20, 55, 6)
        if len(names) < 2 or not cursor:
            return False
        return (13 <= names[0][0] <= 16
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
        self.assertTrue(self.trainer_rows(FRAMES / "trainer-0.png"))

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

    def test_save_yes_box_covers_the_time_tile(self):
        # home/text.asm TextBoxBorder writes c inner tiles and then the
        # right border. data/yes_no_menu_strings.asm YES_NO is width 4,
        # height 3, with no blank line. engine/menus/save.asm
        # SaveTheGame_YesOrNo draws that box at hlcoord 0, 7, so it
        # occupies columns 0-5 and rows 7-11. engine/menus/main_menu.asm
        # PrintSaveScreenText places TIME at column 5 row 8. The later
        # border is that same tile, so the T stays covered.
        def full_height(path):
            image = Image.open(path).convert("L")
            x0, y0 = 5 * 20, 8 * 13
            top = any(image.getpixel((x0 + x, y0)) < 128 for x in range(20))
            bottom = any(image.getpixel((x0 + x, y0 + 12)) < 128 for x in range(20))
            return top and bottom

        self.assertFalse(full_height(FRAMES / "save-before.png"))
        self.assertTrue(full_height(FRAMES / "save-after.png"))

    def test_trainer_card_draws_faces_and_badges(self):
        # draw_badges.asm: unearned is the face, earned is the badge four
        # tiles later. gfx/trainer_card/badges.png. Each 2x2 graphic is
        # empty on the unpatched card, drawn for 0 badges, and different
        # when all eight badges are earned.
        before = FRAMES / "trainer-before.png"
        faces = FRAMES / "trainer-0.png"
        earned = FRAMES / "trainer-8.png"
        for rect in BADGE_RECTS:
            self.assertLess(ink_count(before, *rect), 80)
            self.assertGreater(ink_count(faces, *rect), 100)
            self.assertGreater(ink_count(earned, *rect), 100)
            self.assertFalse(same_ink(faces, earned, *rect))

    def test_glyph_ink_stays_in_its_cell_and_does_not_touch(self):
        before = [
            "party-before.png", "status-before.png", "summary-before.png",
            "save-before.png", "trainer-before.png",
        ]
        after = {
            "party-after.png": [],
            "status-after.png": [SPRITE],
            "summary-after.png": [SPRITE],
            "save-after.png": [],
            "trainer-0.png": [TRAINER_PIC, *BADGE_RECTS],
            "trainer-8.png": [TRAINER_PIC, *BADGE_RECTS],
        }
        for name in before:
            self.assertTrue(glyph_issues(FRAMES / name, []), name)
        for name, skip in after.items():
            self.assertEqual(glyph_issues(FRAMES / name, skip), [], name)


if __name__ == "__main__":
    unittest.main()
