#!/usr/bin/env python3
"""Route 19 and Route 20 water against pokered SeaRoutesWildMons.

The coast maps carry that table. Zone projects a nonzero water byte through
WaterEncounters instead of fail-closing it.
"""

import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REF = Path(os.environ.get('POKERED_REFERENCE_DIR', Path.home() / 'Developer/Pokemon-PlayDate-env/pokered'))
ODDS = (51, 51, 39, 25, 25, 25, 13, 13, 11, 3)
LEVELS = (5, 10, 15, 5, 10, 15, 20, 30, 35, 40)


def sea_routes():
    text = (REF / 'data/wild/maps/SeaRoutes.asm').read_text()
    rate = re.search(r'def_water_wildmons (\d+)', text)
    slots = re.findall(r'db\s+(\d+)\s*,\s*(\w+)', text)
    assert rate and len(slots) == 10
    return int(rate.group(1)), [(int(level), species) for level, species in slots]


class SeaRoutesWaterTest(unittest.TestCase):
    def test_route_19_and_20_water_matches_searoutes(self):
        rate, slots = sea_routes()
        self.assertEqual(rate, 5)
        self.assertEqual(slots, [(level, 'TENTACOOL') for level in LEVELS])
        grass = (REF / 'data/wild/grass_water.asm').read_text()
        files = {'ROUTE_19': 'Route19.json', 'ROUTE_20': 'Route20.json'}
        for route, filename in files.items():
            self.assertRegex(grass, rf'dw SeaRoutesWildMons\s+; {route}\n')
            installed = json.loads((ROOT / 'Source/data/zCoast' / filename).read_text())
            water = installed['encounters']['water']
            self.assertEqual(installed['encounters']['source'], 'data/wild/maps/SeaRoutes.asm')
            self.assertEqual(installed['encounters']['source_pointer'], 'SeaRoutesWildMons')
            self.assertEqual(water['rate_byte'], 5)
            self.assertEqual(installed['encounters']['grass']['rate_byte'], 0)
            self.assertEqual(
                [(slot['level'], slot['species_source'], slot['weight_256']) for slot in water['slots']],
                [(level, 'TENTACOOL', weight) for level, weight in zip(LEVELS, ODDS)],
            )
        water = json.loads((ROOT / 'Source/data/zCoast/Route19.json').read_text())['encounters']['water']
        with tempfile.NamedTemporaryFile('w', suffix='.json') as payload:
            json.dump(water, payload, separators=(',', ':'))
            payload.flush()
            completed = subprocess.run(
                ['lua5.4', str(ROOT / 'tools/tests/searoutes_host.lua'), str(ROOT / 'Source'), payload.name],
                check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('zone projected 5:tentacool:51', completed.stdout)


if __name__ == '__main__':
    unittest.main()
