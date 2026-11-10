"""The 43 constants missing from the 205-map manifest, and the source encounters."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from tools.activate_remainder import manifest
from tools.generate_remainder_maps import REFERENCE_DEFAULT, classify
from tools.tests.test_endgame_story import lua_binary, lua_literal

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = Path(os.environ.get('POKERED_REFERENCE_DIR', REFERENCE_DEFAULT))

STATICS = {
    'MOLTRES': ('VictoryRoad2F', 'pokered:VICTORY_ROAD_2F:objects:6', 11, 5, '50'),
    'ZAPDOS': ('PowerPlant', 'pokered:POWER_PLANT:objects:9', 4, 9, '50'),
    'ARTICUNO': ('SeafoamIslandsB4F', 'pokered:SEAFOAM_ISLANDS_B4F:objects:3', 6, 1, '50'),
    'MEWTWO': ('CeruleanCaveB1F', 'pokered:CERULEAN_CAVE_B1F:objects:1', 27, 13, '70'),
}


def snorlax_level(script):
    match = re.search(
        r'ld a, SNORLAX\s+ld \[wCurOpponent\], a\s+ld a, (\d+)\s+ld \[wCurEnemyLevel\], a',
        script.read_text())
    if not match:
        raise AssertionError('Snorlax level is not the source opponent write: ' + str(script))
    return int(match.group(1))


class RemainderMapTests(unittest.TestCase):
    def test_the_43_missing_constants_are_listed_and_the_playable_ones_are_installed(self):
        inventory = classify(REFERENCE)
        pinned = json.loads((ROOT / 'Source/data/zRemainder/inventory.json').read_bytes())
        self.assertEqual(pinned, inventory)
        self.assertEqual(inventory['constant_count'], 248)
        self.assertEqual(inventory['installed_before'], 205)
        self.assertEqual(len(inventory['missing_constants']), 43)
        self.assertEqual(len(inventory['unused_zero_size']), 22)
        self.assertEqual(set(inventory['header_aliases']), {
            'CERULEAN_TRASHED_HOUSE_COPY', 'UNDERGROUND_PATH_ROUTE_6_COPY', 'CINNABAR_MART_COPY'})
        self.assertEqual(inventory['duplicate_headers'], {
            'UNDERGROUND_PATH_ROUTE_7_COPY': 'UndergroundPathRoute7'})
        for name in inventory['already_present']:
            self.assertIn(name, ('DiglettsCave', 'DiglettsCaveRoute2', 'DiglettsCaveRoute11',
                                 'RockTunnelPokecenter', 'RockTunnel1F', 'RockTunnelB1F',
                                 'Route2', 'Route2Gate', 'Route2TradeHouse',
                                 'ViridianForestNorthGate', 'ViridianForestSouthGate', 'ViridianForest'))
        installed = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
        self.assertEqual(installed, manifest())
        self.assertEqual(len(installed['maps']), 222)
        self.assertTrue(set(inventory['installed_by_this_packet']) <= set(installed['maps']))

    def test_legendaries_are_static_objects_and_are_absent_from_the_wild_tables(self):
        maps = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())['maps']
        for species, (name, object_id, x, y, level) in STATICS.items():
            raw = json.loads((ROOT / 'Source' / maps[name]['path']).read_bytes())
            obj = next(row for row in raw['events']['objects'] if row['id'] == object_id)
            self.assertEqual(obj['extra'], [species, level])
            self.assertEqual((obj['x'], obj['y']), (x, y))
            wild = [slot['species_source'] for slot in raw['encounters']['grass']['slots']]
            self.assertNotIn(species, wild)

    def test_snorlax_uses_the_flute_script_level_and_not_a_wild_slot(self):
        self.assertEqual(snorlax_level(REFERENCE / 'scripts/Route12.asm'), 30)
        self.assertEqual(snorlax_level(REFERENCE / 'scripts/Route16.asm'), 30)
        story = json.loads((ROOT / 'Source/data/towerStory/scenes.json').read_bytes())['scenes']['snorlax']
        self.assertEqual([(row['id'], row['species'], row['level']) for row in story], [
            ('pokered:ROUTE_12:objects:1', 'snorlax', 30),
            ('pokered:ROUTE_16:objects:7', 'snorlax', 30),
        ])
        maps = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())['maps']
        for name in ('Route12', 'Route16'):
            raw = json.loads((ROOT / 'Source' / maps[name]['path']).read_bytes())
            wild = [slot['species_source'] for slot in raw['encounters']['grass']['slots']]
            self.assertNotIn('SNORLAX', wild)
            snorlax = [row for row in raw['events']['objects'] if row['sprite'] == 'SPRITE_SNORLAX']
            self.assertEqual(len(snorlax), 1)
            self.assertEqual(snorlax[0]['kind'], 'npc')
            self.assertEqual(snorlax[0]['extra'], [])
        probe = r'''
TowerStory = { scenes = function() return scenes end }
dofile(module_path)
local function check(actual, expected, label)
    if actual ~= expected then
        error(label .. " got " .. tostring(actual) .. " expected " .. tostring(expected))
    end
end
local session = {
    flags = {EVENT_FIGHT_ROUTE12_SNORLAX = true},
    questFlag = function(self, name) return self.flags[name] == true end,
    inventory = function()
        return { quantity = function(_, item) return item == "pokeFlute" and 1 or 0 end }
    end,
}
local request = SnorlaxStory.request(session, "pokered:ROUTE_12:objects:1")
check(request.species, "snorlax", "species")
check(request.level, 30, "level")
check(request.guards.items.pokeFlute, 1, "flute")
local quiet = {
    flags = {},
    questFlag = function(self, name) return self.flags[name] == true end,
    inventory = function()
        return { quantity = function() return 0 end }
    end,
}
local missing = SnorlaxStory.request(quiet, "pokered:ROUTE_16:objects:7")
check(missing, nil, "no flute")
print("snorlax ok")
'''
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'probe.lua'
            path.write_text('scenes = ' + lua_literal({'snorlax': story})
                            + '\nmodule_path = ' + json.dumps(str(ROOT / 'Source/game/snorlaxStory.lua'))
                            + '\n' + probe)
            completed = subprocess.run([lua_binary(), str(path)], check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn('snorlax ok', completed.stdout)


if __name__ == '__main__':
    unittest.main()
