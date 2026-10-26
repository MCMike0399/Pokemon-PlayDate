"""Immutable map inputs and manifest checks. Runtime assertions use the SDK."""
import hashlib
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "895a874"


class SourceMapManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT / "Source/data/sourceMaps.json").read_text())
        cls.maps = cls.manifest["maps"]
        cls.pewter = json.loads((ROOT / "Source/data/pewterSlice/descriptors.json").read_text())["maps"]

    def test_exact_reviewed_inventory_and_unique_identities(self):
        self.assertEqual(self.manifest["schema"], 1)
        self.assertEqual(self.manifest["source_revision"], "af519899719f0754965776faac0e836a3b906e6d")
        expected = set(self.pewter) | {"Route1", "ViridianCity", "ViridianMart", "ViridianPokecenter"}
        self.assertEqual(set(self.maps), expected)
        self.assertEqual(len({entry["id"] for entry in self.maps.values()}), 12)
        self.assertEqual(len({entry["key"] for entry in self.maps.values()}), 12)

    def test_original_map_inputs_authored_pallet_and_renderers_are_unchanged(self):
        subprocess.run(["git", "diff", "--exit-code", BASE, "--",
                        "Source/data/viridianSlice", "Source/data/pewterSlice",
                        "Source/data/maps.lua", "Source/world/sprites", "Source/images",
                        "Source/world/tilefactory.lua", "Source/lib/shade.lua"],
                       cwd=ROOT, check=True, capture_output=True)

    def test_paths_revision_dimensions_and_padding_match_immutable_maps(self):
        for name, entry in self.maps.items():
            with self.subTest(name=name):
                path = ROOT / "Source" / entry["path"]
                self.assertEqual(entry["path"], f'data/{entry["profile"]}Slice/{name}.json')
                raw = json.loads(path.read_text())
                self.assertEqual(raw["name"], name)
                self.assertEqual(raw["id"], entry["id"])
                self.assertEqual(raw["source_revision"], self.manifest["source_revision"])
                width, height = raw["dimensions"]["cells"]
                self.assertEqual(entry["width"], max(13, width))
                self.assertEqual(entry["height"], height)
                self.assertEqual(entry["padding"], max(0, (13 - width) // 2))
                original = subprocess.check_output(["git", "show", f'{BASE}:Source/{entry["path"]}'], cwd=ROOT)
                self.assertEqual(hashlib.sha256(path.read_bytes()).digest(), hashlib.sha256(original).digest())
                for events in raw["events"].values():
                    for event in events:
                        self.assertTrue(0 <= event["x"] < width and 0 <= event["y"] < height)
                        self.assertTrue(0 <= event["x"] + entry["padding"] < entry["width"])

    def test_legacy_keys_padding_and_spawns_are_preserved(self):
        viridian = {
            "Route1": ("kanto_route1", 10, 35),
            "ViridianCity": ("kanto_viridian_city", 20, 35),
            "ViridianMart": ("kanto_viridian_mart", 5, 7),
            "ViridianPokecenter": ("kanto_viridian_center", 3, 7),
        }
        starts = {"Route2": (8, 71), "ViridianForestSouthGate": (5, 7),
                  "ViridianForest": (16, 47), "ViridianForestNorthGate": (5, 7),
                  "PewterCity": (18, 35), "PewterGym": (5, 13),
                  "PewterMart": (5, 7), "PewterPokecenter": (3, 7)}
        for name, entry in self.maps.items():
            if name in viridian:
                key, x, y = viridian[name]
                self.assertTrue(entry["resident"])
            else:
                original = self.pewter[name]
                key = original["key"]
                x, y = starts[name]
                self.assertEqual(entry["width"], original["width"])
                self.assertEqual(entry["padding"], original["padding"])
                self.assertFalse(entry.get("resident", False))
            self.assertEqual(entry["key"], key)
            self.assertEqual(entry["spawn"], {"x": x, "y": y, "facing": "up"})
