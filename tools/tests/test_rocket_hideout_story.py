"""Source-derived path and identity checks; these do not execute gameplay Lua."""
import importlib.util
import json
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('hideout_generator', ROOT / 'tools/generate_rocket_hideout_story.py')
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)
REFERENCE = Path(os.environ.get('POKERED_REFERENCE_DIR', Path.home() / 'Developer/Pokemon-PlayDate-env/pokered'))


class HideoutSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.generated = GEN.build(REFERENCE)
        cls.scenes = json.loads(cls.generated['scenes.json'])['scenes']

    def test_checked_in_projection_matches_verified_source(self):
        for name, value in self.generated.items():
            self.assertEqual((GEN.OUTPUT / name).read_bytes(), value)

    def test_reverse_rle_reaches_source_stop_cells(self):
        # Source entry (4,16) reads UP1, RIGHT4, UP4, finishing at (8,11).
        route = self.scenes['spinners']['pokered:ROCKET_HIDEOUT_B2F'][3]
        self.assertEqual((route['x'], route['y']), (4, 16))
        self.assertEqual(route['path'], ['up'] + ['right'] * 4 + ['up'] * 4)
        delta = dict(up=(0, -1), down=(0, 1), left=(-1, 0), right=(1, 0))
        for routes in self.scenes['spinners'].values():
            for route in routes:
                x, y = route['x'], route['y']
                for direction in route['path']:
                    dx, dy = delta[direction]
                    x, y = x + dx, y + dy
                    self.assertGreaterEqual(min(x, y), 0)
                    self.assertLess(max(x, y), 32)

    def test_reserved_ids_are_unique_and_bounded(self):
        routes = [r for group in self.scenes['spinners'].values() for r in group]
        self.assertEqual(len(routes), 59)
        self.assertEqual(len({r['id'] for r in routes}), 59)
        self.assertLessEqual(max(len(r['path']) for r in routes), 64)

    def test_elevator_raw_bytes_select_exact_warp_entries(self):
        self.assertEqual([(f['floor'], f['source_warp_byte'], f['destination'])
                          for f in self.scenes['elevator']], [
            ('B1F', 4, dict(x=25, y=19)),
            ('B2F', 4, dict(x=25, y=19)),
            ('B4F', 2, dict(x=25, y=15)),
        ])

    def test_terrain_projects_source_blocks_without_new_art(self):
        effects = self.scenes['terrain']
        self.assertEqual((effects['b4-open']['x'], effects['b4-open']['y'], effects['b4-open']['block']), (12, 5, 14))
        self.assertEqual(effects['entrance-open']['block'], 67)
        self.assertTrue(all(key.startswith('pokered:') for effect in effects.values() for key in effect['keys']))


if __name__ == '__main__':
    unittest.main()
