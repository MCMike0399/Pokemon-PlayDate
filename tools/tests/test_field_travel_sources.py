"""Verify small traversal outputs directly against immutable source bytes."""
import importlib.util
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class FieldTravelSources(unittest.TestCase):
    def test_pinned_blue_policy(self):
        spec = importlib.util.spec_from_file_location('field_travel_source', ROOT / 'tools/field-travel/prepare_data.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        reference = Path(os.environ['POKERED_REFERENCE_DIR'])
        import json
        for name, expected in module.generate(reference).items():
            self.assertEqual(json.loads((ROOT / name).read_text()), expected, name)
