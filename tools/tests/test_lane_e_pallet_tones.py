"""Pallet mockup C is a per-tile tone, not a new global shade.

Lane E has not applied this yet. tools/notes/lane-e-pallet-tones.patch
paints overworld tiles $23, $39 and $2C with the diagonal grass field
from mockup C's open center (192 black pixels in the 32x32 cell).
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
GROUND_BLACK = 192


def _bytes(values):
    return "{" + ", ".join(f"0x{value:02X}" for value in values) + "}"


def assert_global_shades(root):
    shade = (root / "Source/lib/shade.lua").read_text()
    policy = json.loads((root / "Source/data/importedTonePatterns.json").read_text())
    if _bytes(LIGHT) not in shade or _bytes(DARK) not in shade:
        raise AssertionError("Shade.LIGHT or Shade.DARK changed")
    if policy["light"] != LIGHT or policy["dark"] != DARK:
        raise AssertionError("importedTonePatterns.json changed")


def _ground_black(source):
    block = source.split("local PALLET_GROUND", 1)[1].split("}", 1)[0]
    words = [int(value, 16) for value in re.findall(r"0x[0-9A-Fa-f]+", block)]
    if len(words) != 32:
        raise AssertionError("Pallet ground field is not 32 rows")
    return sum(bin(word).count("1") for word in words)


def assert_pallet_tones(root):
    source = (root / "Source/world/tileRegistry.lua").read_text()
    assert_global_shades(root)
    start = source.find("local PALLET_GROUND")
    stop = source.find("local function palletQuadrants")
    if start < 0 or stop < 0:
        raise AssertionError("Pallet ground field is missing")
    if "GYM" in source[start:stop]:
        raise AssertionError("Pallet tones touch the gym tileset")
    if _ground_black(source) != GROUND_BLACK:
        raise AssertionError("Pallet ground field is not mockup C's 192-pixel cell")
    if "0x888A888A" not in source[start:stop]:
        raise AssertionError("Pallet ground field lost mockup C's first row")
    tone = source[source.find("local PALLET_TONE"):source.find("local function palletQuadrants")]
    for label in ("23", "2c", "39"):
        if f'["{label}"]' not in tone:
            raise AssertionError(f"missing {label} overworld override")
    if "return renderPalletTone" not in source:
        raise AssertionError("Pallet cells still use the baked atlas")


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
