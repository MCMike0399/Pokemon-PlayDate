"""Pins and data only. Native movement/text/lifecycle belong to SDK contracts."""
import json
import tempfile
import unittest
from pathlib import Path
from tools.tests.host_fixtures import installed_map_names
from tools.generate_saffron_guards import build, REFERENCE, OUTPUT, FLAG


class SaffronGuardDataTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(build()['guards.json'])

    def test_generated_bytes(self):
        for name, raw in build().items():
            self.assertEqual((OUTPUT / name).read_bytes(), raw)

    def test_only_current_guards_active(self):
        active = {id for id, d in self.data['guards'].items() if d['active']}
        self.assertEqual(active, {f'pokered:ROUTE_{n}_GATE:objects:1'
                                  for n in (5, 6, 7, 8)
                                  if f'Route{n}Gate' in installed_map_names()})
        self.assertEqual(len(self.data['guards']), 4)

    def test_source_positions_and_asymmetric_talk(self):
        for n, y, push, facing in [(5, 3, 'up', 'left'), (6, 2, 'down', 'right')]:
            d = self.data['guards'][f'pokered:ROUTE_{n}_GATE:objects:1']
            self.assertEqual(d['trigger'], [dict(x=3, y=y), dict(x=4, y=y)])
            self.assertEqual(d['entry_push'], push)
            self.assertEqual(d['entry_facing'], facing)
            self.assertEqual(d['talk_push'], 'up')

    def test_flag_priority_and_full_text(self):
        self.assertEqual(self.data['flag'], FLAG)
        self.assertNotIn('EVENT_', FLAG)
        self.assertEqual(self.data['drinks'], ['freshWater', 'sodaPop', 'lemonade'])
        thirsty = self.data['texts'][self.data['thirsty'][0]]['recipe']
        self.assertEqual([row.get('text') for row in thirsty if 'text' in row],
                         ["I'm on guard duty.", "Gee, I'm thirsty,", 'though!',
                          'Oh wait there,', "the road's closed."])
        self.assertEqual(len(self.data['accepted']), 2)
        self.assertEqual(len(self.data['completed']), 1)

    def test_pin_mutation_rejected(self):
        import shutil
        with tempfile.TemporaryDirectory() as tmp:
            candidate = Path(tmp) / 'reference'
            shutil.copytree(REFERENCE, candidate)
            path = candidate / 'scripts/Route6Gate.asm'
            path.write_text(path.read_text().replace('PAD_DOWN', 'PAD_UP'))
            with self.assertRaisesRegex(AssertionError, 'unverified guard source'):
                build(candidate)

    def test_prepared_source_identities(self):
        for n in (5, 6):
            path = OUTPUT.parent / 'vermilionPreparation' / f'Route{n}Gate.json'
            actor = json.loads(path.read_text())['events']['objects'][0]
            guard = self.data['guards'][actor['id']]
            self.assertEqual(guard['actor'], dict(x=actor['x'], y=actor['y'],
                                                 facing=actor['range_or_facing'].lower()))


if __name__ == '__main__':
    unittest.main()
