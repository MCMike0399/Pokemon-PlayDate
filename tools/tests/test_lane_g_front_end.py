"""Lane G front end against pret/pokered af519899.

Title, main menu, naming, start menu, options, and the intro skip rules
are checked on the host. The Simulator is not required.
"""
import hashlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_g_host.lua"
TITLE_HOST = ROOT / "tools/tests/title_idle_host.lua"
PLAYER = ROOT / "Source/images/title/player.png"
MANIFEST = ROOT / "tools/references/title-art.json"


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


class LaneGFrontEndTests(unittest.TestCase):
    def test_host_matches_pokered_strings(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("lane-g-host ok", completed.stdout)
        title = (ROOT / "Source/game/titleState.lua").read_text()
        self.assertIn("Story.playerName({session = session})", title)

    def test_existing_title_idle_host(self):
        completed = subprocess.run(
            [lua_binary(), str(TITLE_HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("title-idle-host ok", completed.stdout)

    def test_player_sheet_is_the_pinned_title_output(self):
        import json
        manifest = json.loads(MANIFEST.read_text())
        entry = next(row for row in manifest["inputs"] if row["path"] == "gfx/title/player.png")
        self.assertEqual(entry["sha256"], "d8c5b2ded27a989786a20fa4e56b108cd466dde6b79c0f29798c3e9aa2d8b1ca")
        self.assertEqual(entry["size"], [40, 56])
        self.assertEqual(entry["output"], "player.png")
        self.assertEqual(entry["scale"], 1)
        digest = hashlib.sha256(PLAYER.read_bytes()).hexdigest()
        self.assertEqual(digest, "f6368b9681aeb6e98660050bb80fd55efd9dcced7fd5281395387a55516d272e")

    def test_intro_fight_uses_tilemaps_and_dmg_palette(self):
        from PIL import Image
        intro = ROOT / "Source/images/title/intro"
        expected = {
            "gengar_1.png": (140, 91, "3b6e677697bba92ac2628e636b418b89ba704115b5f975f463ffff063268bf8f"),
            "gengar_2.png": (140, 91, "da5abee17b0ac1d5c2074c9b5c1d1058a388c0af089a8e5d91a3001be08ba506"),
            "gengar_3.png": (140, 91, "efd3ec2fdda6544876da68cbc41d594a01c3639b43f3191926bbd8b56e20cd71"),
            "fight_jiggly_1.png": (120, 78, "457aecc3c2fea6db8b24d15acf51ddec13be85af47eb7b9d1049cf50df4bb6e6"),
            "fight_jiggly_2.png": (120, 78, "54db023f80bb93a09d5d09c2f81f573755c0120dfea6b22fe3ba47b186140635"),
            "fight_jiggly_3.png": (120, 78, "323584127d69fd4bdf6301f89c85fcafc265821725d3e4f725adec0b11bd4548"),
        }
        for name, (width, height, digest) in expected.items():
            raw = (intro / name).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), digest, name)
            image = Image.open(io.BytesIO(raw))
            self.assertEqual(image.size, (width, height), name)
            self.assertEqual(image.mode, "1", name)
        # The old crop was the first 56px of the 168px sheet. These frames are the 7 by 7 tilemap.
        with Image.open(intro / "gengar_1.png") as gengar:
            self.assertNotEqual(gengar.size[0], 56)
            self.assertEqual(gengar.getpixel((0, 0)), 255)

    def test_naming_grid_matches_alphabets(self):
        # data/text/alphabets.asm UpperCaseAlphabet / LowerCaseAlphabet.
        # <PK> <MN> <ED> are one tile each. <DOT> is the decimal point, the same mark as ".".
        rows = {
            "UPPER": [
                list("ABCDEFGHI"),
                list("JKLMNOPQR"),
                list("STUVWXYZ "),
                ["×", "(", ")", ":", ";", "[", "]", "PK", "MN"],
                ["-", "?", "!", "♂", "♀", "/", ".", ",", "ED"],
            ],
            "LOWER": [
                list("abcdefghi"),
                list("jklmnopqr"),
                list("stuvwxyz "),
                ["×", "(", ")", ":", ";", "[", "]", "PK", "MN"],
                ["-", "?", "!", "♂", "♀", "/", ".", ",", "ED"],
            ],
        }
        source = (ROOT / "Source/game/namingState.lua").read_text()
        self.assertNotIn("B delete", source)
        self.assertNotIn("A on ED done", source)
        for name, expected in rows.items():
            matched = _lua_grid(source, name)
            self.assertEqual(matched, expected, name)
            self.assertEqual(matched[2][8], " ", name + " row 3 space")

    def test_title_mons_do_not_cover_the_copyright(self):
        import json
        from PIL import Image
        idle = (ROOT / "Source/game/titleIdle.lua").read_text()
        draw = (ROOT / "Source/game/titleState.lua").read_text()
        self.assertIn("TitleIdle.titleMonSlot()", draw)
        self.assertIn("setClipRect(0, slot.y, 400, slot.h)", draw)
        self.assertNotIn("drawScaled(layout.mon", draw)
        self.assertIn("TitleIdle.COPYRIGHT_TILES", draw)
        self.assertIn("TitleIdle.copyrightSource", draw)
        self.assertIn("images/title/font/copyright_tiles", draw)
        self.assertIn("images/title/font/gamefreak_inc", draw)
        species = []
        collecting = False
        for line in idle.splitlines():
            if line.startswith("TitleIdle.MONS"):
                collecting = True
            if collecting:
                species.extend(part.strip('",') for part in line.split() if part.startswith('"'))
            if collecting and "}" in line:
                break
        self.assertEqual(len(species), 16)
        aliases = json.loads((ROOT / "Source/data/pokemon-art.json").read_text())["aliases"]
        col, row = 20, 13
        slot = (5 * col, 10 * row, 7 * col, 7 * row)
        copyright_rect = (2 * col, 17 * row, 16 * col, row)
        self.assertLessEqual(slot[1] + slot[3], copyright_rect[1])
        for name in species:
            path = ROOT / "Source/images/pokemon" / f"{aliases.get(name, name)}-front.png"
            with Image.open(path) as image:
                self.assertGreater(image.size[0], 0, name)
                self.assertGreater(image.size[1], 0, name)
            self.assertFalse(_rects_overlap(slot, copyright_rect), name)
        sequence = _copyright_tiles_from_asm()
        rendered = _lua_copyright_tiles(idle)
        self.assertEqual(rendered, sequence)
        self.assertEqual(rendered.count(0x42), 3)
        with Image.open(ROOT / "Source/images/title/font/title_copyright.png") as strip:
            self.assertEqual(strip.size, (8 * len(sequence), 8))
            self.assertEqual(strip.mode, "1")
            rendered_row = _render_copyright_row(sequence)
            self.assertEqual(strip.tobytes(), rendered_row.tobytes())
        with Image.open(ROOT / "Source/images/title/font/ed.png") as ed:
            self.assertEqual(ed.size, (8, 8))
            self.assertEqual(ed.mode, "1")


def _lua_grid(source, name):
    import re
    start = source.index(f"NamingScreen.{name} = {{")
    end = source.index("\n}", start)
    block = source[start:end]
    rows = []
    for line in block.splitlines():
        cells = re.findall(r'"([^"]*)"', line)
        if cells:
            rows.append(cells)
    return rows


def _copyright_tiles_from_asm():
    roots = [os.environ.get("POKERED"), "/tmp/pokered"]
    text = None
    for root in roots:
        if not root:
            continue
        path = Path(root) / "engine/movie/title.asm"
        if path.is_file():
            text = path.read_text()
            break
    if text is None:
        raise AssertionError("engine/movie/title.asm is required to parse .tileScreenCopyrightTiles")
    from tools.generate_title_art import copyright_tile_sequence
    return copyright_tile_sequence(text)


def _lua_copyright_tiles(source):
    import re
    match = re.search(r"TitleIdle\.COPYRIGHT_TILES = \{([^}]+)\}", source)
    if not match:
        raise AssertionError("copyright tile list missing")
    return [int(item, 16) for item in re.findall(r"0x([0-9A-Fa-f]+)", match.group(1))]


def _render_copyright_row(sequence):
    from PIL import Image
    nintendo = Image.open(ROOT / "Source/images/title/font/copyright_tiles.png").convert("1")
    freak = Image.open(ROOT / "Source/images/title/font/gamefreak_inc.png").convert("1")
    from tools.generate_title_art import copyright_tile
    strip = Image.new("1", (8 * len(sequence), 8), 1)
    for index, tile in enumerate(sequence):
        strip.paste(copyright_tile(nintendo, freak, tile), (index * 8, 0))
    return strip


def _rects_overlap(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


if __name__ == "__main__":
    unittest.main()
