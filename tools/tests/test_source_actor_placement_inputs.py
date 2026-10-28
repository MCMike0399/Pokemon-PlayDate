"""Pinned placement inputs; production policy execution remains an SDK check."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class SourceActorPlacementInputs(unittest.TestCase):
    def record(self, name):
        entry = json.loads((ROOT / 'Source/data/sourceMaps.json').read_text())['maps'][name]
        raw = (ROOT / 'Source' / entry['path']).read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), entry['source_sha256'])
        return entry, json.loads(raw)

    def test_blocked_stay_homes_match_pinned_source_objects(self):
        cases = [
            ('Museum1F', 5, 16, 2, 'SPRITE_OLD_AMBER', 'kanto-services'),
            ('MtMoonPokecenter', 5, 7, 2, 'SPRITE_CLIPBOARD', 'kanto-services'),
            ('CeruleanGym', 3, 8, 7, 'SPRITE_SWIMMER', 'cerulean-story'),
        ]
        for name, index, x, y, sprite, reference in cases:
            with self.subTest(name=name):
                entry, data = self.record(name)
                actor = data['events']['objects'][index - 1]
                self.assertEqual(actor['id'], entry['id'] + ':objects:' + str(index))
                self.assertEqual((actor['x'], actor['y'], actor['movement']), (x, y, 'STAY'))
                self.assertEqual(actor['sprite'], sprite)
                self.assertEqual(data['collision'][y][x], 1)
                source = (ROOT / 'tools/references' / reference /
                          'data/maps/objects' / (name + '.asm')).read_text()
                self.assertRegex(source, rf'object_event\s+{x},\s+{y}, {sprite}, STAY,')
                self.assertNotIn((x, y), {(w['x'], w['y']) for w in data['events']['warps']})

    def test_guide_route_crosses_exactly_two_door_arrivals_and_no_warps(self):
        _, data = self.record('PewterCity')
        scene = json.loads((ROOT / 'Source/data/tutorialEscort/scenes.json').read_text())
        actor = scene['actors']['escort']
        self.assertEqual(actor['id'], 'pokered:PEWTER_CITY:objects:5')
        x, y = actor['x'], actor['y']
        route = []
        for direction in scene['escort']['npc_route'] + scene['escort']['departure']:
            dx, dy = {'up': (0, -1), 'down': (0, 1), 'left': (-1, 0), 'right': (1, 0)}[direction]
            x, y = x + dx, y + dy
            route.append((x, y))
        warps = {(w['x'], w['y']) for w in data['events']['warps']}
        self.assertFalse(set(route) & warps)
        self.assertEqual(set(route) & {(x, y + 1) for x, y in warps}, {(23, 18), (16, 18)})
        for x, y in route:
            self.assertEqual(data['collision'][y][x], 0)
