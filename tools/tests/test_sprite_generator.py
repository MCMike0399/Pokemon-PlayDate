import copy
import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools/generate_overworld_sprites.py"
spec = importlib.util.spec_from_file_location("sprite_generator", SCRIPT)
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class PinnedSpriteGeneration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.manifest = generator.load_manifest()

    def cli(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), *map(str, args)], capture_output=True, text=True)

    def test_current_protected_grids_match_pinned_sources(self):
        result = self.cli("--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["characters"]["oak"]["mapping"], "outline")
        self.assertEqual({record["mapping"] for key, record in report["characters"].items() if key != "oak"}, {"greyhair"})
        self.assertTrue(all(not record["differences"] for record in report["characters"].values()))

    def test_temp_output_reproduces_grids_ignoring_headers(self):
        result = self.cli("--write", "--output-dir", self.folder)
        self.assertEqual(result.returncode, 0, result.stderr)
        for key in generator.CHARS.values():
            generated = generator.parse_grids((self.folder / (key + ".lua")).read_text(), key)
            protected = generator.parse_grids((ROOT / "Source/world/sprites" / (key + ".lua")).read_text(), key)
            self.assertEqual(generated, protected)
        self.assertFalse((self.folder / "red.lua").exists())
        self.assertEqual(self.cli("--check", "--output-dir", self.folder).returncode, 0)

    def test_changed_grid_and_mask_fail_check(self):
        self.assertEqual(self.cli("--write", "--output-dir", self.folder).returncode, 0)
        path = self.folder / "oak.lua"
        frames = generator.parse_grids(path.read_text(), "oak")
        # A corner is transparent exterior in this protected frame. A black
        # cell adds exactly four native opacity pixels as well as changing art.
        frames["down"][0] = "#" + frames["down"][0][1:]
        path.write_text(generator.fmt("oak", frames, "outline", self.manifest["commit"]))
        result = self.cli("--check", "--output-dir", self.folder)
        self.assertEqual(result.returncode, 1)
        delta = json.loads(result.stdout)["characters"]["oak"]["differences"][0]
        self.assertEqual(delta["changed_grid_cells"], 1)
        self.assertEqual(delta["changed_mask_pixels"], 4)
        self.assertEqual(delta["grid_bbox"], [0, 0, 1, 1])

    def test_unknown_empty_duplicate_and_red_keys_fail(self):
        for key in ("red", "oak,unknown", "oak,", "", "oak,oak"):
            with self.subTest(key=key):
                self.assertEqual(self.cli("--check", "--only", key).returncode, 1)

    def test_unknown_frame_or_bad_row_fails(self):
        text = (ROOT / "Source/world/sprites/oak.lua").read_text()
        with self.assertRaises(ValueError):
            generator.parse_grids(text.replace("down =", "other =", 1), "oak")
        with self.assertRaises(ValueError):
            generator.parse_grids(text.replace(".....######.....", "too-short", 1), "oak")

    def test_palette_override_is_explicit_and_check_fails(self):
        result = self.cli("--check", "--only", "rival", "--map", "bw")
        self.assertEqual(result.returncode, 1)
        self.assertTrue(json.loads(result.stdout)["characters"]["rival"]["differences"])

    def test_corrupt_or_reordered_source_fails_before_output_write(self):
        inputs = self.folder / "inputs"
        shutil.copytree(generator.INPUT, inputs)
        data = (inputs / "oak.png").read_bytes()
        with self.assertRaisesRegex(ValueError, "checksum"):
            generator.load_source(data + b"x", self.manifest["characters"]["oak"])
        with Image.open(io.BytesIO(data)) as image:
            original = image.copy()
            image.paste(original.crop((0, 16, 16, 32)), (0, 0))
            image.paste(original.crop((0, 0, 16, 16)), (0, 16))
            image.save(inputs / "oak.png")
        outputs = self.folder / "outputs"
        result = self.cli("--write", "--input-dir", inputs, "--output-dir", outputs)
        self.assertEqual(result.returncode, 1)
        self.assertFalse(outputs.exists())

    def test_dimensions_colors_and_frame_bounds_fail_closed(self):
        entry = self.manifest["characters"]["oak"]
        with self.assertRaisesRegex(ValueError, "dimensions"):
            generator.validate_image(Image.new("L", (17, 96)), entry)
        with Image.open(generator.INPUT / "oak.png") as image:
            image = image.copy()
            image.putpixel((0, 0), 42)
            with self.assertRaisesRegex(ValueError, "four pinned"):
                generator.validate_image(image, entry)
            with self.assertRaisesRegex(ValueError, "frame index"):
                generator.frame_to_grid(image, 6, generator.MAPS["outline"])

    def test_frame_order_manifest_mutation_rejected(self):
        bad = copy.deepcopy(self.manifest)
        bad["characters"]["oak"]["frames"] = {"down": 1, "up": 0, "left": 2}
        path = self.folder / "bad.json"
        path.write_text(json.dumps(bad))
        with self.assertRaisesRegex(ValueError, "frame order"):
            generator.load_manifest(path)

    def test_enclosed_white_is_opaque_but_mask_leak_is_detected(self):
        sealed = ["." * 16 for _ in range(16)]
        for y in range(4, 12):
            sealed[y] = "...." + ("########" if y in (4, 11) else "#......#") + "...."
        mask = generator.mask_bytes(sealed)
        self.assertEqual(mask[16*32+16], 255)
        self.assertEqual(mask[0], 0)
        leaked = sealed.copy()
        leaked[4] = leaked[4][:7] + "." + leaked[4][8:]
        actual = {name: leaked if name == "down" else sealed for name in generator.FACINGS}
        expected = {name: sealed for name in generator.FACINGS}
        delta = generator.compare_frames(expected, actual)[0]
        self.assertEqual(delta["changed_grid_cells"], 1)
        self.assertGreater(delta["changed_mask_pixels"], 4)
        self.assertEqual(generator.mask_bytes(leaked)[16*32+16], 0)


if __name__ == "__main__":
    unittest.main()
