import importlib.util
import json
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('gym_generator', ROOT / 'tools/generate_midgame_gym_story.py')
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)
REFERENCE = Path(os.environ.get('POKERED_REFERENCE_DIR', Path.home() / 'Developer/Pokemon-PlayDate-env/pokered'))


class GymSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.generated = GEN.build(REFERENCE)
        cls.events = json.loads(cls.generated['events.json'])['events']

    def test_generated_values_match_verified_source(self):
        for name, raw in self.generated.items():
            self.assertEqual((GEN.OUTPUT / name).read_bytes(), raw)

    def test_badges_are_confirmed_victory_effects_separate_from_bag_retry(self):
        for zone, badge, item, count in [('CELADON_GYM', 'RAINBOW', 'tm21', 7),
                                         ('FUCHSIA_GYM', 'SOUL', 'tm06', 6),
                                         ('SAFFRON_GYM', 'MARSH', 'tm46', 7)]:
            d = self.events[f'pokered:{zone}:objects:1']
            self.assertTrue(d['victory']['flags']['BADGE_' + badge])
            self.assertNotIn(d['reward']['flag'], d['victory']['flags'])
            self.assertEqual(d['reward']['item'], item)
            self.assertEqual(len(d['victory']['trainers']), count)

    def test_dojo_master_and_choices_preserve_source_unlock_boundary(self):
        master = self.events['pokered:FIGHTING_DOJO:objects:1']
        self.assertNotIn('EVENT_DEFEATED_FIGHTING_DOJO', master['victory']['flags'])
        self.assertEqual(len(master['victory']['trainers']), 4)
        self.assertEqual(self.events['pokered:FIGHTING_DOJO:objects:6']['species'], 'hitmonlee')
        self.assertEqual(self.events['pokered:FIGHTING_DOJO:objects:7']['species'], 'hitmonchan')
        self.assertEqual(self.events['pokered:FIGHTING_DOJO:objects:6']['level'], 30)


if __name__ == '__main__':
    unittest.main()
