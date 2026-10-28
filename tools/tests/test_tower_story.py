"""Pinned Blue scripts independently bound coordinate and outcome projections."""
import importlib.util
import json
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('tower_generator', ROOT / 'tools/generate_tower_story.py')
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)
REFERENCE = Path(os.environ.get('POKERED_REFERENCE_DIR', Path.home() / 'Developer/Pokemon-PlayDate-env/pokered'))


class TowerSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.generated = GEN.build(REFERENCE)
        cls.scenes = json.loads(cls.generated['scenes.json'])['scenes']

    def test_projections_match_verified_inputs(self):
        for name, value in self.generated.items():
            self.assertEqual((GEN.OUTPUT / name).read_bytes(), value)

    def test_rocket_paths_preserve_all_twelve_coordinate_cases(self):
        rockets = self.scenes['rockets']
        self.assertEqual([len(r['variants']) for r in rockets], [4, 4, 4])
        first = rockets[0]['variants'][0]
        self.assertEqual(first['player'], dict(x=9, y=12))
        self.assertEqual(first['path'], ['right'] + ['down'] * 5 + ['left'])
        self.assertEqual(first['destination'], dict(x=9, y=16))
        # Source intentionally disappears before reaching the actual stairs.
        self.assertEqual(rockets[2]['variants'][1]['destination'], dict(x=9, y=12))
        delta = dict(up=(0, -1), down=(0, 1), left=(-1, 0), right=(1, 0))
        for rocket in rockets:
            declared = {(p['x'], p['y']) for p in rocket['script_positions']}
            for variant in rocket['variants']:
                x, y = variant['origin']['x'], variant['origin']['y']
                self.assertIn((x, y), declared)
                for direction in variant['path']:
                    dx, dy = delta[direction]
                    x, y = x + dx, y + dy
                    self.assertIn((x, y), declared)
                self.assertEqual(dict(x=x, y=y), variant['destination'])

    def test_flute_uses_exact_source_range_and_stable_object_ids(self):
        route12, route16 = self.scenes['snorlax']
        self.assertEqual(route12['id'], 'pokered:ROUTE_12:objects:1')
        self.assertEqual(route16['id'], 'pokered:ROUTE_16:objects:7')
        self.assertEqual(route12['flute_positions'], [dict(x=9, y=62), dict(x=10, y=61), dict(x=10, y=63), dict(x=11, y=62)])
        self.assertEqual(route16['flute_positions'], [dict(x=27, y=10), dict(x=25, y=10)])
        self.assertEqual((route12['x'], route12['y'], route12['level']), (10, 62, 30))
        self.assertEqual((route16['x'], route16['y'], route16['level']), (26, 10, 30))

    def test_ghost_and_rescue_coordinates_are_source_values(self):
        ghost = self.scenes['ghost']
        self.assertEqual((ghost['x'], ghost['y'], ghost['species'], ghost['level']), (10, 16, 'marowak', 30))
        self.assertEqual(self.scenes['fuji']['destination'], dict(map_id='pokered:MR_FUJIS_HOUSE', x=3, y=7, facing='up'))


if __name__ == '__main__':
    unittest.main()
