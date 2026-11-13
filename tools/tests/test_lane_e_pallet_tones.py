"""Pallet mockup C is a per-tile tone, not a new global shade.

Lane E has not applied this yet. tools/notes/lane-e-pallet-tones.patch
tints overworld tile $23, keeps $39 faint, and stipples $2C. Shade.LIGHT
and importedTonePatterns.json stay on the approved Bayer bytes.
"""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-pallet-tones.patch"
LIGHT = [0x55, 0xBB, 0x55, 0xFF, 0x55, 0xBB, 0x55, 0xFF]
DARK = [0x00, 0xAA, 0x44, 0xAA, 0x00, 0xAA, 0x44, 0xAA]
PATCHY = [0x9F, 0xFF, 0xF3, 0xFF, 0xE7, 0x7F, 0xBF, 0xDD]
STIPPLE = [0xAA, 0xFF, 0xAA, 0xFF, 0xAA, 0xFF, 0xAA, 0xFF]
FAINT = [0xFF, 0xFF, 0xFF, 0xFF, 0xAA, 0xFF, 0xFF, 0xFF]


def _bytes(values):
    return "{" + ", ".join(f"0x{value:02X}" for value in values) + "}"


def assert_global_shades(root):
    shade = (root / "Source/lib/shade.lua").read_text()
    policy = json.loads((root / "Source/data/importedTonePatterns.json").read_text())
    if _bytes(LIGHT) not in shade or _bytes(DARK) not in shade:
        raise AssertionError("Shade.LIGHT or Shade.DARK changed")
    if policy["light"] != LIGHT or policy["dark"] != DARK:
        raise AssertionError("importedTonePatterns.json changed")


def assert_pallet_tones(root):
    source = (root / "Source/world/tileRegistry.lua").read_text()
    assert_global_shades(root)
    if "GYM" in source[source.find("PALLET_TONE"):source.find("local function palletQuadrants")]:
        raise AssertionError("Pallet tones touch the gym tileset")
    for label, pattern in (("23", PATCHY), ("2c", STIPPLE), ("39", FAINT)):
        needle = f'["{label}"] = {_bytes(pattern)}'
        if needle not in source:
            raise AssertionError(f"missing {label} tone {needle}")
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
