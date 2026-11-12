#!/usr/bin/env python3
"""Lane A: Route 21 south is still handed back before the surf arrival.

28ede555 lets a surfing step leave a surf-surface origin and enter a
connection whose arrival is surf water. Pallet Town (5, 17) down is that
case: both banks are foot $14, and Pallet's own connections do not target
Pallet, so PewterWorld.connection reaches the surf arrival and returns the
Route 21 door. The old surfingWaterDoor patch is the same rule under a
name this branch does not use.

Route 21 (3, 89) down is the same water pair onto Cinnabar (3, 0). Route 21
also connects north to Pallet. The early return treats every downward step
on a map that merely has a Pallet connection as the KantoSlice Pallet
adapter, and it returns before the surf arrival. KantoWorld then has no
Route 21 adapter, so the step is dropped.

Defer only when the south connection itself targets Pallet. Apply
tools/notes/lane-a-surf-edge.patch. pewterWorld.lua stays Lane A's.
"""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PEWTER = ROOT / 'Source/game/pewterWorld.lua'
KANTO = ROOT / 'Source/game/kantoWorld.lua'
COMPACT = ROOT / 'Source/data/sourceMapCache/compact.json'

BAIL = 'if c.target_map == "PALLET_TOWN" and direction == "down" then return nil, false end'


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

        kanto = KANTO.read_text()
        start = kanto.index('function KantoWorld.connection')
        body = kanto[start:kanto.index('\nfunction ', start)]
        blocked = body.index('return nil,"blocked-origin"')
        self.assertIn('surfingOffWater', body[:blocked])
        self.assertIn('FieldTravel.surfSurface(arrival.terrain', PEWTER.read_text())

        self.assertTrue(
            BAIL not in PEWTER.read_text(),
            'Route 21 connects north to Pallet, so (3, 89) down onto Cinnabar '
            '(3, 0) returns before the surf-water arrival. Defer to KantoSlice '
            'only when the south connection itself targets Pallet. Apply '
            'tools/notes/lane-a-surf-edge.patch.',
        )


if __name__ == '__main__':
    unittest.main()
