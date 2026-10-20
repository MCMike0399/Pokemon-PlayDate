import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("visual_coverage", ROOT / "tools/visual/coverage.py")
coverage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)


class SpeciesAssetCoverage(unittest.TestCase):
    def test_production_manifest_resolves_all_151_species(self):
        report = coverage.inspect(ROOT / "Source")
        self.assertTrue(report["ok"], report["errors"])
        self.assertEqual(report["unreferenced_assets"], [])
        self.assertEqual(report["expected_assets"], 302)

    def test_removing_aliases_reproduces_all_six_original_defects(self):
        report = coverage.inspect(ROOT / "Source", aliases_override={})
        self.assertEqual(report["species"], 151)
        self.assertEqual(report["expected_assets"], 302)
        self.assertEqual(report["existing_assets"], 302)
        missing = {e["path"] for e in report["errors"] if e["reason"] == "canonical asset lookup missing"}
        expected = {f"images/pokemon/{species}-{view}.png" for species in ("nidoranF", "nidoranM", "mr") for view in ("front", "back")}
        self.assertEqual(missing, expected)
        self.assertFalse(report["ok"])


if __name__ == "__main__":
    unittest.main()
