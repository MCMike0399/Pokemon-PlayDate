"""Independent bytes feed generation; these host checks do not execute Lua."""
import importlib.util
import json
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class FieldGearSources(unittest.TestCase):
    def test_generated_policy_matches_pinned_blue(self):
        spec = importlib.util.spec_from_file_location('field_gear_source', ROOT / 'tools/field-gear/prepare_data.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        outputs = module.generate(Path(os.environ['POKERED_REFERENCE_DIR']))
        for name, expected in outputs.items():
            self.assertEqual(json.loads((ROOT / name).read_text()), expected, name)
