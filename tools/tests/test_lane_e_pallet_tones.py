"""Pallet mockup C grass is two strokes, chosen per cell.

Lane E has not applied this yet. tools/notes/lane-e-pallet-tones.patch
paints overworld tiles $23 and $39 with mockup C's open-center stroke
(192 black pixels) or its border stroke (78 black pixels). The center
stroke is a bit of the cell's map position. $39 keeps a tuft accent.
$2C keeps a lighter lawn stipple except on a center-stroke cell.
Shade.LIGHT and importedTonePatterns.json stay on the approved Bayer bytes.
"""
import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-pallet-tones.patch"
LIGHT = [0x55, 0xBB, 0x55, 0xFF, 0x55, 0xBB, 0x55, 0xFF]
DARK = [0x00, 0xAA, 0x44, 0xAA, 0x00, 0xAA, 0x44, 0xAA]


def _bytes(values):
    return "{" + ", ".join(f"0x{value:02X}" for value in values) + "}"


def assert_global_shades(root):
    shade = (root / "Source/lib/shade.lua").read_text()
    policy = json.loads((root / "Source/data/importedTonePatterns.json").read_text())
    if _bytes(LIGHT) not in shade or _bytes(DARK) not in shade:
        raise AssertionError("Shade.LIGHT or Shade.DARK changed")
    if policy["light"] != LIGHT or policy["dark"] != DARK:
        raise AssertionError("importedTonePatterns.json changed")


def _table_words(source, name):
    block = source.split(f"local {name}", 1)[1].split("}", 1)[0]
    return [int(value, 16) for value in re.findall(r"0x[0-9A-Fa-f]+", block)]


def _popcount(words):
    return sum(bin(word).count("1") for word in words)


def assert_pallet_tones(root):
    source = (root / "Source/world/tileRegistry.lua").read_text()
    overworld = (root / "Source/world/overworld.lua").read_text()
    assert_global_shades(root)
    start = source.find("local PALLET_CENTER <const>")
    stop = source.find("local function palletQuadrants")
    if start < 0 or stop < 0:
        raise AssertionError("Pallet stroke tables are missing")
    if "GYM" in source[start:stop]:
        raise AssertionError("Pallet tones touch the gym tileset")
    center = _table_words(source, "PALLET_CENTER <const>")
    border = _table_words(source, "PALLET_BORDER <const>")
    rows = _table_words(source, "PALLET_CENTER_ROW <const>")
    if len(center) != 32 or _popcount(center) != 192 or center[0] != 0x888A888A:
        raise AssertionError("open-center stroke is not mockup C's 192-pixel cell")
    if len(border) != 32 or _popcount(border) != 78 or border[0] != 0x88800000:
        raise AssertionError("border stroke is not mockup C's 78-pixel cell")
    if len(rows) != 18 or 0x07FC0 not in rows:
        raise AssertionError("center-stroke mask is not one row per map cell")
    if "19 - x" not in source:
        raise AssertionError("center stroke is not chosen from the map cell")
    tone = source[source.find("local PALLET_TONE"):source.find("local function palletQuadrants")]
    for label in ("23", "2c", "39"):
        if f'["{label}"]' not in tone:
            raise AssertionError(f"missing {label} overworld override")
    if 'tid == "39"' not in source or "blitTuft" not in source:
        raise AssertionError("$39 tuft accent is missing")
    if 'tid == "2c"' not in source or "blitLawnStipple" not in source:
        raise AssertionError("$2C lawn stipple is missing")
    if 'zone.stableID ~= "pokered:PALLET_TOWN"' not in source:
        raise AssertionError("Pallet field is not limited to Pallet Town")
    if "function TileRegistry:paintPalletField" not in source:
        raise AssertionError("Pallet field painter is missing")
    if "self.sprite:setImage(image)" not in overworld or "self.tilemap:draw(0, 0)" not in overworld:
        raise AssertionError("Pallet field is not drawn into the map sprite image")
    if "paintPalletField" not in overworld:
        raise AssertionError("Pallet field is not painted onto the map")


class LaneEPalletToneTests(unittest.TestCase):
    def test_pallet_tones_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        text = PATCH.read_text()
        self.assertNotIn("Source/lib/shade.lua", text)
        self.assertNotIn("importedTonePatterns.json", text)
        scratch = Path(tempfile.mkdtemp(prefix="lane-e-pallet-tones-"))
        try:
            completed = subprocess.run(
                ["git", "worktree", "add", "--detach", str(scratch), "HEAD"],
                cwd=ROOT, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            completed = subprocess.run(
                ["git", "apply", str(PATCH)],
                cwd=scratch, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            assert_pallet_tones(scratch)
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(scratch)], cwd=ROOT, check=False)
            shutil.rmtree(scratch, ignore_errors=True)

    @unittest.expectedFailure
    def test_pallet_ground_uses_per_tile_tones(self):
        assert_pallet_tones(ROOT)


if __name__ == "__main__":
    unittest.main()
