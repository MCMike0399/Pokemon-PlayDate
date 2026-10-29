"""Primary source outputs only; gameplay runs exclusively in root's real SDK."""
import importlib.util
import json
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SafariServiceSources(unittest.TestCase):
    def test_generated_policy_and_text_match_pinned_blue(self):
        spec = importlib.util.spec_from_file_location('safari_source', ROOT / 'tools/safari-services/prepare_data.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for name, expected in module.generate(Path(os.environ['POKERED_REFERENCE_DIR'])).items():
            self.assertEqual(json.loads((ROOT / name).read_text()), expected, name)
