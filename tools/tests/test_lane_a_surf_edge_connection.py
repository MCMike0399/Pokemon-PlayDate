#!/usr/bin/env python3
"""Route 21 south reaches Cinnabar. Only Route 1's south edge defers to Pallet.

pret/pokered af519899 data/maps/headers/Route1.asm connects south to
PALLET_TOWN. data/maps/headers/Route21.asm connects north to PALLET_TOWN
and south to CINNABAR_ISLAND. Both banks of the Route 21 south step are
foot tile $14. Deferring every downward step on a map that merely has a
Pallet connection drops that surf arrival.
"""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PEWTER = ROOT / 'Source/game/pewterWorld.lua'
KANTO = ROOT / 'Source/game/kantoWorld.lua'
COMPACT = ROOT / 'Source/data/sourceMapCache/compact.json'

OLD_BAIL = 'if c.target_map == "PALLET_TOWN" and direction == "down" then return nil, false end'
SOUTH_BAIL = 'if c.direction == "south" and c.target_map == "PALLET_TOWN" and direction == "down" then return nil, false end'


def foot(maps, tiles, name, x, y):
    entry = maps[name]
    tid = int(entry['tile_rows'][y][x * 2:x * 2 + 2], 16)
    cell = tiles[entry['palette'][tid - 1]]
    terrain = cell['terrain']
    return terrain['foot_tile'], terrain.get('water_candidate') is True, cell['collision']


class SurfEdgeConnectionTest(unittest.TestCase):
    def test_route21_south_reaches_the_surf_arrival(self):
        compact = json.loads(COMPACT.read_text())
        maps, tiles = compact['maps'], compact['tiles']
        self.assertEqual(foot(maps, tiles, 'PalletTown', 5, 17), (0x14, True, 1))
        self.assertEqual(foot(maps, tiles, 'Route21', 5, 0), (0x14, True, 1))
        self.assertEqual(foot(maps, tiles, 'Route21', 3, 89), (0x14, True, 1))
        self.assertEqual(foot(maps, tiles, 'CinnabarIsland', 3, 0), (0x14, True, 1))
        route21 = [(c['direction'], c['target_map']) for c in maps['Route21']['connections']]
        self.assertIn(('north', 'PALLET_TOWN'), route21)
        self.assertIn(('south', 'CINNABAR_ISLAND'), route21)
        route1 = [(c['direction'], c['target_map']) for c in maps['Route1']['connections']]
        self.assertIn(('south', 'PALLET_TOWN'), route1)

        kanto = KANTO.read_text()
        start = kanto.index('function KantoWorld.connection')
        body = kanto[start:kanto.index('\nfunction ', start)]
        blocked = body.index('return nil,"blocked-origin"')
        self.assertIn('surfingOffWater', body[:blocked])
        self.assertIn('FieldTravel.surfSurface(arrival.terrain', PEWTER.read_text())
        source = PEWTER.read_text()
        self.assertNotIn(OLD_BAIL, source)
        self.assertIn(SOUTH_BAIL, source)


if __name__ == '__main__':
    unittest.main()
