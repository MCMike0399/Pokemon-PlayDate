import json
from pathlib import Path
import tempfile
import unittest

from tools.profiling.anchors import replace
from tools.profiling.analyze import analyze


class WorldProfileTests(unittest.TestCase):
    def test_instrumentation_anchor_requires_exactly_one_match(self):
        self.assertEqual(replace('start TOKEN end', 'TOKEN', 'observer'), 'start observer end')
        for changed in ('no marker', 'TOKEN TOKEN'):
            with self.assertRaisesRegex(ValueError, 'profiling anchor changed'):
                replace(changed, 'TOKEN', 'observer')

    def test_analysis_keeps_observer_and_harness_separate_from_heap(self):
        samples = [
            {'label': 'initial-fixture:post-gc', 'lua_heap_kib': 100, 'observer_rows': 1},
            {'label': 'cycle-01-retained:post-gc', 'lua_heap_kib': 140, 'observer_rows': 4},
            {'label': 'cycle-02-retained:post-gc', 'lua_heap_kib': 147, 'observer_rows': 7},
        ]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = root / 'world-profile.json'
            report.write_text(json.dumps({'build_id': 'exact-build', 'world_profile': {'samples': samples}}))
            original = report.read_bytes()
            for i in range(2):
                (root / f'{i:05d}-request.json').write_text(json.dumps({'id': f'unique-{i}'}))
            result = analyze(report)
            self.assertEqual(result['mean_delta_kib'], 7)
            self.assertEqual(result['first_cycle_cold_delta_kib'], 40)
            self.assertEqual(result['observer_inventory']['retained_row_tables'], 3)
            self.assertEqual(result['observer_inventory']['rows_between_cycle_endpoints'], [3])
            self.assertEqual(result['harness_inventory']['unique_request_ids'], 2)
            self.assertEqual(result['harness_inventory']['seen_id_string_payload_bytes'], 16)
            self.assertIn('NOT Lua allocation sizes', result['observer_inventory']['meaning'])
            self.assertEqual(report.read_bytes(), original)

    def test_future_observer_handles_numeric_simulator_flag(self):
        observer = (Path(__file__).parents[1] / 'profiling/worldProfile.lua').read_text()
        self.assertIn('simulator=not not playdate.isSimulator', observer)
        self.assertIn('simulator_value_type=type(playdate.isSimulator)', observer)
        self.assertNotIn('playdate.isSimulator==true', observer)
        self.assertIn('local LIMIT <const> = 512', observer)


if __name__ == '__main__':
    unittest.main()
