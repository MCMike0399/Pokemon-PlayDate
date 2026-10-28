import importlib.util
import json
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('silph_generator', ROOT / 'tools/generate_silph_story.py')
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)
REFERENCE = Path(os.environ.get('POKERED_REFERENCE_DIR', Path.home() / 'Developer/Pokemon-PlayDate-env/pokered'))


class SilphSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.generated = GEN.build(REFERENCE)
        cls.scenes = json.loads(cls.generated['scenes.json'])['scenes']

    def test_projections_match_verified_source_inputs(self):
        for name, raw in self.generated.items():
            self.assertEqual((GEN.OUTPUT / name).read_bytes(), raw)

    def test_all_twenty_doors_keep_source_flags_blocks_and_unique_trigger_ids(self):
        doors = [door for floor in self.scenes['doors'].values() for door in floor]
        self.assertEqual(len(doors), 20)
        self.assertEqual(len({door['id'] for door in doors}), 20)
        self.assertTrue(all(int(door['id'].rsplit(':', 1)[1]) >= 1001 for door in doors))
        eleventh = self.scenes['doors']['pokered:SILPH_CO_11F'][0]
        self.assertEqual((eleventh['x'], eleventh['y'], eleventh['closed_block'], eleventh['open_block']), (3, 6, 32, 3))
        self.assertTrue(all(d['open_block'] == 14 for d in doors if d['map'] != 'SilphCo11F'))

    def test_one_based_coord_index_preserves_real_source_rival_routes(self):
        first, second = self.scenes['rival']['variants']
        self.assertEqual(first['trigger'], dict(x=3, y=2))
        self.assertEqual(first['approach'], ['up'] * 4)
        self.assertEqual(first['battle_pose'], dict(x=3, y=3))
        self.assertEqual(first['departure'], ['right', 'right'])
        self.assertEqual(second['approach'], ['up'] * 3)
        self.assertEqual(second['battle_pose'], dict(x=3, y=4))
        self.assertEqual(second['departure'], ['left', 'up', 'up', 'right', 'right', 'right', 'down'])
        self.assertEqual(self.scenes['rival']['rival_party_indices'], dict(charmander=7, squirtle=8, bulbasaur=9))

    def test_elevator_uses_all_eleven_zero_based_source_warp_bytes(self):
        self.assertEqual([f['floor'] for f in self.scenes['elevator']], list(range(1, 12)))
        self.assertEqual([f['source_warp_byte'] for f in self.scenes['elevator']], [3] + [2] * 9 + [1])
        self.assertEqual(self.scenes['elevator'][6]['destination'], dict(x=18, y=0))

    def test_source_toggles_are_object_ids_not_suffix_guesses(self):
        hide, show = self.scenes['toggles']['hide'], self.scenes['toggles']['show']
        self.assertEqual((len(hide), len(show)), (40, 6))
        self.assertIn('pokered:SILPH_CO_11F:objects:3', hide)
        self.assertNotIn('pokered:SILPH_CO_7F:objects:9', hide)
        self.assertNotIn('pokered:SILPH_CO_11F:objects:1', hide)
        self.assertEqual(len(set(hide + show)), 46)


if __name__ == '__main__':
    unittest.main()
