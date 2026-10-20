import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("visual_compare", ROOT / "tools/visual/compare.py")
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)


class ExactVisualComparison(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.original = self.folder / "original.png"
        self.changed = self.folder / "changed.png"
        self.image = Image.new("RGBA", (32, 32), (255, 255, 255, 255))
        self.image.save(self.original)

    def test_identical_image_passes(self):
        self.image.save(self.changed)
        self.assertTrue(compare.compare_image(self.original, self.changed)["equal"])

    def test_one_pixel_defect_fails_cli_and_reports_region(self):
        self.image.putpixel((7, 11), (0, 0, 0, 255))
        self.image.save(self.changed)
        result = compare.compare_image(self.original, self.changed, self.folder / "diff.png")
        self.assertFalse(result["equal"])
        self.assertEqual(result["changed_pixels"], 1)
        self.assertEqual(result["bbox"], (7, 11, 8, 12))
        self.assertEqual(result["alpha_pixels"], 0)
        proc = subprocess.run([sys.executable, str(ROOT / "tools/visual/compare.py"), str(self.original), str(self.changed)], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 1)
        self.assertEqual(json.loads(proc.stdout)["changed_pixels"], 1)

    def test_one_mask_pixel_defect_fails_with_identical_rgb(self):
        self.image.putpixel((3, 5), (255, 255, 255, 0))
        self.image.save(self.changed)
        result = compare.compare_image(self.original, self.changed)
        self.assertFalse(result["equal"])
        self.assertEqual(result["rgb_pixels"], 0)
        self.assertEqual(result["alpha_pixels"], 1)
        self.assertEqual(result["alpha_bbox"], (3, 5, 4, 6))

    def test_dimensions_fail(self):
        Image.new("1", (31, 32)).save(self.changed)
        self.assertEqual(compare.compare_image(self.original, self.changed)["reason"], "dimensions")

    def test_catalog_cannot_hide_deleted_inventory(self):
        before, after = self.folder / "before", self.folder / "after"
        before.mkdir()
        after.mkdir()
        for folder, images in [(before, [{"path": "a.png"}, {"path": "b.png"}]), (after, [{"path": "a.png"}])]:
            (folder / "catalog.json").write_text(json.dumps({"images": images, "missing": []}))
            self.image.save(folder / "a.png")
            self.image.save(folder / "b.png")
        result = compare.compare_catalog(before, after)
        self.assertFalse(result["equal"])
        self.assertEqual(result["failures"][0]["reason"], "inventory")

    def test_run_root_frames_layout_matches_flat_baseline(self):
        before, after = self.folder / "flat", self.folder / "run"
        before.mkdir(); after.mkdir(); (after / "frames").mkdir()
        manifest = {"images": [{"path": "a.png", "category": "tile"}], "missing": []}
        (before / "catalog.json").write_text(json.dumps(manifest))
        (after / "catalog.json").write_text(json.dumps(manifest | {"image_root": "frames"}))
        self.image.save(before / "a.png"); self.image.save(after / "frames/a.png")
        self.assertTrue(compare.compare_catalog(before, after)["equal"])
        proc = subprocess.run([sys.executable, str(ROOT / "tools/visual/review.py"), str(after), str(self.folder / "review")], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_catalog_path_traversal_and_symlink_escape_are_rejected(self):
        for image_root in ("../outside", "/tmp", "frames/../../outside"):
            with self.subTest(image_root=image_root):
                from tools.visual.paths import image_directory
                with self.assertRaises(ValueError):
                    image_directory(self.folder, {"image_root": image_root})
        from tools.visual.paths import contained
        with self.assertRaises(ValueError):
            contained(self.folder, "../outside.png")
        link = self.folder / "escape"
        link.symlink_to(self.folder.parent, target_is_directory=True)
        with self.assertRaises(ValueError):
            contained(self.folder, "escape/outside.png")

    def test_standalone_mask_bitmap_defect_fails(self):
        original = Image.new("1", (32, 32), 1)
        original.save(self.original)
        original.putpixel((2, 8), 0)
        original.save(self.changed)
        result = compare.compare_image(self.original, self.changed)
        self.assertFalse(result["equal"])
        self.assertEqual(result["rgb_pixels"], 1)


if __name__ == "__main__":
    unittest.main()
