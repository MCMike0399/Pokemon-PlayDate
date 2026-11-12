"""The Mew scientist is on the loaded Cerulean Cave map.

The gift giver is the object in tools/notes/lane-e-mew-scientist.patch.
The patch is already applied, so a dry run does not apply it again.
The runtime cache and the cell cache pin the cave bytes that contain him.
"""
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-mew-scientist.patch"
CELL_HEADER = struct.Struct("<4sHHH64s64s")


def load_cerulean_cave_1f():
    """The SourceMaps runtime path: manifest pin, runtime record, cell pin."""
    manifest_bytes = (ROOT / "Source/data/sourceMaps.json").read_bytes()
    manifest = json.loads(manifest_bytes)
    entry = manifest["maps"]["CeruleanCave1F"]
    raw = (ROOT / "Source" / entry["path"]).read_bytes()
    if hashlib.sha256(raw).hexdigest() != entry["source_sha256"]:
        raise AssertionError("pinned map checksum differs")
    manifest_sha = hashlib.sha256(manifest_bytes).hexdigest()
    compact = json.loads((ROOT / "Source/data/sourceMapCache/compact.json").read_bytes())
    if compact["manifest_sha256"] != manifest_sha:
        raise AssertionError("compact manifest pin differs")
    descriptor = compact["maps"]["CeruleanCave1F"]
    if descriptor["source_sha256"] != entry["source_sha256"]:
        raise AssertionError("compact source pin differs")
    runtime = json.loads((ROOT / "Source/data/sourceMapCache/runtime-CeruleanCave1F.json").read_bytes())
    if runtime["manifest_sha256"] != manifest_sha or runtime["source_sha256"] != entry["source_sha256"]:
        raise AssertionError("runtime map cache differs from manifest")
    definition = runtime["definition"]
    if definition["name"] != "CeruleanCave1F" or definition["id"] != entry["id"]:
        raise AssertionError("runtime map identity mismatch")
    cell = (ROOT / "Source/data/sourceMapCells/CeruleanCave1F.bin").read_bytes()
    width, height = definition["dimensions"]["cells"]
    palette = len(definition["grids"])
    expected = CELL_HEADER.size + width * height * 2
    if len(cell) != expected:
        raise AssertionError("binary cell byte count differs")
    magic, w, h, count, manifest_pin, source_pin = CELL_HEADER.unpack_from(cell)
    if (magic, w, h, count) != (b"SMC1", width, height, palette):
        raise AssertionError("binary cell header differs")
    if manifest_pin.decode() != manifest_sha or source_pin.decode() != entry["source_sha256"]:
        raise AssertionError("binary cell pins differ")
    return definition


class MewScientistMapTests(unittest.TestCase):
    def test_patch_is_already_applied_and_only_names_the_cave(self):
        patch = PATCH.read_text()
        self.assertIn("postgame:CERULEAN_CAVE_1F:mew-gift", patch)
        self.assertIn("SPRITE_SCIENTIST", patch)
        self.assertIn("4bc3a9b4778f66051ce151cdeba61e48c8b4af85fc5797ca79e6c0cf1a048019", patch)
        self.assertIn("python3 tools/generate_source_map_cache.py", patch)
        self.assertIn("--cells-output", patch)
        diffs = [line for line in patch.splitlines() if line.startswith("diff --git ")]
        self.assertEqual(diffs, ["diff --git a/Source/data/zRemainder/CeruleanCave1F.json b/Source/data/zRemainder/CeruleanCave1F.json"])
        completed = subprocess.run(
            ["patch", "--dry-run", "--fuzz=0", "-p1"],
            input=patch, text=True, capture_output=True, cwd=ROOT)
        self.assertNotEqual(completed.returncode, 0, completed.stdout)

    def test_loaded_cave_has_the_scientist_and_still_loads(self):
        definition = load_cerulean_cave_1f()
        scientists = [
            event for event in definition["events"]["objects"]
            if event["sprite"] == "SPRITE_SCIENTIST" and event["x"] == 23 and event["y"] == 16]
        self.assertEqual(len(scientists), 1)
        scientist = scientists[0]
        self.assertEqual(scientist["id"], "postgame:CERULEAN_CAVE_1F:mew-gift")
        self.assertEqual(scientist["kind"], "npc")
        self.assertEqual(scientist["movement"], "STAY")
        self.assertEqual(scientist["range_or_facing"], "RIGHT")
        self.assertEqual(definition["name"], "CeruleanCave1F")
        self.assertEqual(definition["tileset"]["constant"], "CAVERN")
