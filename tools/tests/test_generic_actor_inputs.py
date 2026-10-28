"""Validate immutable fixture inputs only; actor execution belongs to real SDK."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class GenericActorInputTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads((ROOT / 'Source/dev/genericActorFixture.json').read_text())
        cls.records = json.loads((ROOT / 'Source/dev/sourceMapFixture.json').read_text())
        cls.raw = cls.records[cls.fixture['record']]
        cls.entry = cls.records['data/sourceMaps.json']['maps'][cls.raw['name']]

    def test_fixture_extends_manifest_without_editing_regional_inventory(self):
        live = json.loads((ROOT / 'Source/data/sourceMaps.json').read_text())
        self.assertEqual(len(live['maps']), 30)
        self.assertNotIn(self.raw['name'], live['maps'])
        self.assertEqual(self.entry['profile'], 'source')
        self.assertEqual(self.fixture['source_revision'], live['source_revision'])
        self.assertEqual([a['id'] for a in self.fixture['objects']],
                         [a['id'] for a in self.raw['events']['objects']])

    def test_synthetic_walk_and_sight_cells_are_passable_and_avoid_warps(self):
        warp_cells = {(w['x'], w['y']) for w in self.raw['events']['warps']}
        # Inputs use original source coordinates; production applies padding.
        for x, y in [(3, 5), (4, 5), (1, 2), (1, 3), (1, 4), (1, 5)]:
            self.assertEqual(self.raw['collision'][y][x], 0)
            self.assertNotIn((x, y), warp_cells)
        self.assertEqual(self.entry['padding'], 2)
        self.assertEqual(self.fixture['objects'][0]['movement'], 'WALK')
        self.assertEqual(self.fixture['objects'][0]['range_or_facing'], 'RIGHT')

    def test_native_witness_coordinates_match_pinned_padded_geometry(self):
        padding = self.entry['padding']
        exits = {(w['x'] + padding, w['y']) for w in self.raw['events']['warps']}
        self.assertEqual(exits, {(4, 7), (5, 7)})
        # The old (6,7) warp assertion targeted ordinary passable floor.
        self.assertNotIn((6, 7), exits)
        self.assertEqual(self.raw['collision'][7][6 - padding], 0)
        walker = self.fixture['objects'][0]
        self.assertEqual((walker['x'] + padding, walker['y']), (5, 5))
        self.assertEqual(self.raw['collision'][5][6 - padding], 0)

    def test_fixture_reuses_pinned_art_and_valid_roster_content(self):
        roster = json.loads((ROOT / 'Source/data/pewterSlice/trainers.json').read_text())
        self.assertEqual(roster['source_revision'], self.fixture['source_revision'])
        # The existing generator owns/checks immutable sprite strips. The actor
        # fixture only references an already imported source family.
        art = json.loads((ROOT / 'Source/data/pewterSlice/sprites.json').read_text())
        strip = art['sprites'][art['mapping']['SPRITE_YOUNGSTER']['name']]
        self.assertEqual(art['source_revision'], self.fixture['source_revision'])
        self.assertTrue(strip['sha256'])
        for direction, index in strip['walking'].items():
            self.assertIn(str(index), strip['frames'])
        for actor in self.fixture['objects']:
            self.assertEqual(actor['sprite'], 'SPRITE_YOUNGSTER')
        self.assertTrue(any(t['party'][0]['species'] == 'weedle' for t in roster['trainers']))
        for stable, trainer in self.fixture['trainers'].items():
            self.assertEqual(stable, trainer['id'])
            self.assertEqual(trainer['map_id'], self.raw['id'])
            self.assertEqual(trainer['sprite_source'], 'SPRITE_YOUNGSTER')
            self.assertEqual(trainer['party'], [{'species': 'weedle', 'level': 6}])
            self.assertEqual(self.fixture['events'][stable]['content'], self.fixture['content'])
