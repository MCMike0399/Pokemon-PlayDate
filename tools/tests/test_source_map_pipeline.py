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
        additions = json.loads((ROOT / 'Source/data/sourceSlice/manifest-entries.json').read_bytes())['maps']
        vermilion = json.loads((ROOT / 'Source/data/vermilionPreparation/manifest-entries.json').read_bytes())['maps']
        expected = set(additions) | set(vermilion) | set(self.pewter) | {"Route1", "ViridianCity", "ViridianMart", "ViridianPokecenter"}
        self.assertEqual(set(self.maps), expected)
        self.assertEqual(len({entry["id"] for entry in self.maps.values()}), 65)
        self.assertEqual(len({entry["key"] for entry in self.maps.values()}), 65)

    def test_original_map_inputs_authored_pallet_and_renderers_are_unchanged(self):
        subprocess.run(["git", "diff", "--exit-code", BASE, "--",
                        "Source/data/viridianSlice", "Source/data/pewterSlice",
                        "Source/data/maps.lua", "Source/world/sprites", "Source/images",
                        "Source/world/tilefactory.lua", "Source/lib/shade.lua",
                        ":(exclude)Source/images/title"],
                       cwd=ROOT, check=True, capture_output=True)

    def test_paths_revision_dimensions_and_padding_match_immutable_maps(self):
        for name, entry in self.maps.items():
            with self.subTest(name=name):
                path = ROOT / "Source" / entry["path"]
                vermilion = entry['path'].startswith('data/vermilionPreparation/')
                package = 'vermilionPreparation' if vermilion else entry['profile'] + 'Slice'
                self.assertEqual(entry["path"], f'data/{package}/{name}.json')
                raw = json.loads(path.read_text())
                self.assertEqual(raw["name"], name)
                self.assertEqual(raw["id"], entry["id"])
                self.assertEqual(raw["source_revision"], self.manifest["source_revision"])
                width, height = raw["dimensions"]["cells"]
                self.assertEqual(entry["width"], max(13, width))
                self.assertEqual(entry["height"], height)
                self.assertEqual(entry["padding"], max(0, (13 - width) // 2))
                pin = 'b2a497b' if vermilion else '7eae5e1' if entry['profile'] == 'source' else BASE
                original = subprocess.check_output(["git", "show", f'{pin}:Source/{entry["path"]}'], cwd=ROOT)
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
        self.assertEqual(len(viridian), 4)
        self.assertEqual(len(self.pewter), 8)
        for name in set(viridian) | set(self.pewter):
            entry = self.maps[name]
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


class GeneratedSourceCacheTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from tools.generate_source_map_cache import build
        cls.artifacts = build()
        cls.compact = json.loads(cls.artifacts["compact.json"])
        cls.atlas = json.loads(cls.artifacts["tile-grids.json"])["tiles"]
        cls.manifest = json.loads((ROOT / "Source/data/sourceMaps.json").read_text())

    def test_complete_generation_is_deterministic_and_checked_in_bytes_are_exact(self):
        from tools.generate_source_map_cache import build, check
        self.assertEqual(self.artifacts, build())
        check(self.artifacts, ROOT / "Source/data/sourceMapCache")
        self.assertEqual(set(self.compact["maps"]), set(self.manifest["maps"]))
        self.assertNotIn(b'"grid":', self.artifacts["compact.json"])
        self.assertNotIn(b'"source_refs":', self.artifacts["compact.json"])

    def test_shared_door_foot_rules_preserve_the_pinned_source_table(self):
        original = json.loads((ROOT / 'Source/data/pewterSlice/doors.json').read_bytes())
        self.assertEqual(self.compact['door_tiles'], original['tilesets'])

    def test_each_compact_cell_and_shared_grid_matches_the_pinned_input(self):
        for name, entry in self.manifest["maps"].items():
            raw = json.loads((ROOT / "Source" / entry["path"]).read_text())
            descriptor = self.compact["maps"][name]
            width, height = raw["dimensions"]["cells"]
            for y in range(height):
                row = descriptor["tile_rows"][y]
                self.assertEqual(len(row), entry["width"] * 2)
                for x in range(entry["width"]):
                    key = descriptor["palette"][int(row[x * 2:x * 2 + 2], 16) - 1]
                    tile = self.atlas[key]
                    metadata = self.compact["tiles"][key]
                    self.assertEqual(metadata, {field: value for field, value in tile.items() if field != "grid"})
                    if entry["padding"] <= x < entry["padding"] + width:
                        source_x = x - entry["padding"]
                        grid = raw["grids"][raw["tile_ids"][y][source_x] - 1]
                        self.assertEqual(key, grid["stable_id"])
                        self.assertEqual(tile["grid"], grid["grid"])
                        self.assertEqual(tile["terrain"], grid["terrain"])
                        self.assertEqual(tile["collision"], raw["collision"][y][source_x])
                    else:
                        self.assertEqual(tile["grid"], ["#" * 16] * 16)
                        self.assertEqual(tile["collision"], 1)

    def test_accepted_pewter_descriptors_preserve_surfaces_except_declared_museum_openings(self):
        old = json.loads((ROOT / "Source/data/pewterSlice/compact.json").read_text())
        for name, original in old["maps"].items():
            for field, value in original.items():
                if name == "PewterCity" and field == "blocked":
                    opened = {"pokered:PEWTER_CITY:warps:1", "pokered:PEWTER_CITY:warps:2"}
                    value = {cell: event for cell, event in value.items() if event not in opened}
                if name == "Route2" and field == "blocked":
                    opened = {f'pokered:ROUTE_2:warps:{index}' for index in (1, 3, 4, 5)}
                    value = {cell: event for cell, event in value.items() if event not in opened}
                self.assertEqual(self.compact["maps"][name][field], value, (name, field))
        city = self.compact["maps"]["ViridianCity"]
        self.assertEqual(set(city["blocked"].values()), {
            "pokered:VIRIDIAN_CITY:warps:3", "pokered:VIRIDIAN_CITY:warps:4", "pokered:VIRIDIAN_CITY:warps:5"})
        for name, descriptor in self.compact["maps"].items():
            if name != "ViridianCity" and self.manifest["maps"][name]["profile"] == "viridian":
                self.assertEqual(descriptor["blocked"], {})

    def test_destination_projections_preserve_every_source_warp_field_and_connection(self):
        for name, entry in self.manifest["maps"].items():
            raw = json.loads((ROOT / "Source" / entry["path"]).read_text())
            descriptor = self.compact["maps"][name]
            self.assertEqual(descriptor["source_map_constant"], raw["source_map_constant"])
            self.assertEqual(descriptor["connections"], raw["connections"])
            for actual, original in zip(descriptor["warps"], raw["events"]["warps"]):
                expected = dict(original)
                if entry["padding"] or entry["profile"] == "pewter":
                    expected["source_x"], expected["source_y"] = original["x"], original["y"]
                expected["x"] += entry["padding"]
                self.assertEqual(actual, expected)
            self.assertEqual(len(descriptor["warps"]), len(raw["events"]["warps"]))

    def test_changed_extra_missing_or_symlinked_artifacts_are_rejected_without_repair(self):
        import tempfile
        from tools.generate_source_map_cache import check
        for mutation in ("change", "extra", "missing", "symlink"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                output = Path(temporary) / "generated"
                output.mkdir()
                for name, content in self.artifacts.items():
                    (output / name).write_bytes(content)
                target = output / "compact.json"
                if mutation == "change":
                    target.write_bytes(target.read_bytes() + b" ")
                elif mutation == "extra":
                    (output / "extra.json").write_text("{}")
                elif mutation == "missing":
                    target.unlink()
                else:
                    target.unlink()
                    target.symlink_to(ROOT / "Source/data/sourceMapCache/compact.json")
                before = {p.name: p.read_bytes() for p in output.iterdir()}
                with self.assertRaises(ValueError):
                    check(self.artifacts, output)
                self.assertEqual(before, {p.name: p.read_bytes() for p in output.iterdir()})

    def test_unpinned_input_mutation_fails_without_writing(self):
        import tempfile
        from tools.generate_source_map_cache import build
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            for entry in self.manifest['maps'].values():
                path = source / entry['path']
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((ROOT / 'Source' / entry['path']).read_bytes())
            entry = self.manifest["maps"]["PewterCity"]
            path = source / entry["path"]
            path.write_bytes((ROOT / "Source" / entry["path"]).read_bytes() + b" ")
            with self.assertRaisesRegex(ValueError, "checksum"):
                build(source_root=source)
            self.assertEqual(list(source.rglob("compact.json")), [])

    def test_manifest_identity_padding_blocker_and_profile_corruption_is_rejected(self):
        import copy
        import tempfile
        from tools.generate_source_map_cache import build
        for mutation in ("identity", "padding", "blocker", "profile", "revision", "path"):
            manifest = copy.deepcopy(self.manifest)
            entry = manifest["maps"]["PewterCity"]
            if mutation == "identity":
                entry["id"] = "pokered:WRONG"
            elif mutation == "padding":
                entry["padding"] = 1
            elif mutation == "blocker":
                entry.setdefault("blocked_events", []).append("pokered:PEWTER_CITY:objects:1")
            elif mutation == "profile":
                entry["profile"] = "unknown"
            elif mutation == "revision":
                manifest["source_revision"] = "wrong"
            else:
                entry["path"] = "../outside.json"
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                path = Path(temporary) / "manifest.json"
                path.write_text(json.dumps(manifest))
                with self.assertRaises(ValueError):
                    build(path)

    def test_shared_grid_corruption_is_rejected_even_if_input_pin_is_updated(self):
        import copy
        import tempfile
        from tools.generate_source_map_cache import build
        manifest = copy.deepcopy(self.manifest)
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "Source"
            for entry in manifest["maps"].values():
                path = source / entry["path"]
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((ROOT / "Source" / entry["path"]).read_bytes())
            entry = manifest["maps"]["Route2"]
            path = source / entry["path"]
            raw = json.loads(path.read_text())
            route1 = json.loads((ROOT / "Source/data/viridianSlice/Route1.json").read_text())
            shared = {grid["stable_id"] for grid in route1["grids"]}
            grid = next(grid for grid in raw["grids"] if grid["stable_id"] in shared)
            row = grid["grid"][0]
            grid["grid"][0] = ("." if row[0] == "#" else "#") + row[1:]
            path.write_text(json.dumps(raw))
            entry["source_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            manifest_path = Path(temporary) / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "shared source grid differs"):
                build(manifest_path, source)


class SourceMapExtensionTests(unittest.TestCase):
    def test_sdk_fixture_is_reproducible_from_pinned_extra_maps_without_regional_metadata(self):
        import os
        from tools.source_map_fixture import records
        from tools.generate_source_map_cache import canonical
        reference = os.environ.get('POKERED_REFERENCE_DIR')
        self.assertTrue(reference, 'source the project environment before host checks')
        fixture = records(reference)
        self.assertEqual((ROOT / 'Source/dev/sourceMapFixture.json').read_bytes(), canonical(fixture))
        compact = fixture['data/sourceMapCache/compact.json']
        self.assertEqual(len(compact['maps']), 66)
        self.assertNotIn('pokered:VIRIDIAN_CITY:warps:3', compact['maps']['ViridianCity']['blocked'].values())
        for name in ('Route22', 'ViridianSchoolHouse'):
            d = fixture[f'dev/source-map-extension/{name}.json']
            self.assertEqual(d['source_revision'], fixture['data/sourceMaps.json']['source_revision'])
            self.assertEqual(compact['maps'][name]['connections'], d['connections'])
            self.assertEqual(fixture['data/sourceMaps.json']['maps'][name]['profile'], 'source')
            active = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())['maps']
            if name == 'Route22':
                self.assertIn(name, active)
                self.assertNotEqual(active[name]['key'], fixture['data/sourceMaps.json']['maps'][name]['key'])
            else:
                self.assertNotIn(name, active)
