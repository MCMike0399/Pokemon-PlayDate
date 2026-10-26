"""Pinned projection tests only. Gameplay witnesses run exclusively in the SDK."""
import json
from pathlib import Path
import tempfile
import unittest

from tools.generate_cerulean_routes import REFERENCE, OUTPUT, build, encoded, inputs, positions


class CeruleanRoutesProjectionTests(unittest.TestCase):
    def test_projection_is_byte_exact(self):
        self.assertEqual(OUTPUT.read_text(), encoded())

    def test_all_source_inputs_match_pins(self):
        source = inputs()
        self.assertIn('CeruleanHideRocket:', source['scripts/CeruleanCity_2.asm'])
        self.assertIn('TOGGLE_CERULEAN_ROCKET', source['constants/toggle_constants.asm'])

    def test_modified_pinned_script_is_rejected(self):
        import shutil
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'reference'
            shutil.copytree(REFERENCE, root)
            target = root / 'scripts/Route24.asm'
            target.write_text(target.read_text().replace('NUGGET, 1', 'NUGGET, 2'))
            with self.assertRaisesRegex(ValueError, 'input drift'):
                build(root)

    def test_original_triggers_and_one_based_coordinate_branch(self):
        value = build()
        self.assertEqual(value['triggers']['route22'], [{'x': 29, 'y': 4}, {'x': 29, 'y': 5}])
        self.assertEqual(value['triggers']['cerulean'], [{'x': 20, 'y': 6}, {'x': 21, 'y': 6}])
        self.assertEqual(value['triggers']['thief'], [{'x': 30, 'y': 7}, {'x': 30, 'y': 9}])
        self.assertEqual(value['triggers']['nugget'], [{'x': 10, 'y': 15}])
        self.assertEqual([len(row['approach']) for row in value['rivals']['route22']['variants']], [4, 3])

    def test_six_pinned_rival_roster_references_no_roster_copies(self):
        value = build()
        self.assertEqual(value['rivals']['route22']['roster_by_rival_starter'],
                         {'squirtle': 4, 'bulbasaur': 5, 'charmander': 6})
        self.assertEqual(value['rivals']['cerulean']['roster_by_rival_starter'],
                         {'squirtle': 7, 'bulbasaur': 8, 'charmander': 9})
        wire = json.dumps(value)
        self.assertNotIn('"party"', wire)
        self.assertNotIn('"texts"', wire)

    def test_approach_endpoints_are_adjacent_and_departures_converge(self):
        vectors = {'up': (0, -1), 'down': (0, 1), 'left': (-1, 0), 'right': (1, 0)}
        value = build()
        for name, rival in value['rivals'].items():
            final = []
            for trigger, variant in zip(value['triggers'][name], rival['variants']):
                x, y = variant['origin']['x'], variant['origin']['y']
                for direction in variant['approach']:
                    dx, dy = vectors[direction]
                    x, y = x + dx, y + dy
                self.assertEqual(abs(x-trigger['x']) + abs(y-trigger['y']), 1)
                for direction in variant['departure']:
                    dx, dy = vectors[direction]
                    x, y = x + dx, y + dy
                final.append((x, y))
            if name == 'route22':
                self.assertEqual(final, [(31, 10), (31, 10)])
            else:
                self.assertEqual(final, [(21, 11), (20, 11)])

    def test_declared_cells_are_only_pinned_paths_and_collision_exceptions_are_empty(self):
        for rival in build()['rivals'].values():
            found = set()
            for variant in rival['variants']:
                found.update((cell['x'], cell['y']) for cell in positions(variant['origin'],
                    [variant['approach'] + variant['departure']]))
            self.assertEqual(found, {(cell['x'], cell['y']) for cell in rival['script_positions']})
            self.assertEqual(rival['script_collision_positions'], [])
            self.assertLessEqual(len(found), 64)

    def test_blue_reward_order_and_loss_policy_are_in_pinned_script(self):
        source = inputs()
        bridge = source['scripts/Route24.asm'].split('Route24CooltrainerM1Text:', 1)[1]
        self.assertLess(bridge.index('call GiveItem'), bridge.index('call EngageMapTrainer'))
        self.assertLess(bridge.index('SetEvent EVENT_GOT_NUGGET'), bridge.index('call EngageMapTrainer'))
        self.assertIn('CheckEvent EVENT_GOT_NUGGET\n\tjr nz, .got_item', bridge)
        thief = source['scripts/CeruleanCity.asm'].split('CeruleanCityRocketText:', 1)[1]
        self.assertLess(thief.index('CheckEvent EVENT_BEAT_CERULEAN_ROCKET_THIEF'), thief.index('call GiveItem'))
        self.assertLess(thief.index('call GiveItem'), thief.index('farcall CeruleanHideRocket'))


if __name__ == '__main__':
    unittest.main()
