import importlib.util
import json
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('late_kanto', ROOT / 'tools/generate_late_kanto_story.py')
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)
REFERENCE = Path(os.environ.get('POKERED_REFERENCE_DIR', Path.home() / 'Developer/Pokemon-PlayDate-env/pokered'))


class LateKantoSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.generated = GEN.build(REFERENCE)
        cls.scenes = json.loads(cls.generated['scenes.json'])['scenes']

    def test_installed_plan_matches_the_pinned_generator(self):
        for name, raw in self.generated.items():
            self.assertEqual((GEN.OUTPUT / name).read_bytes(), raw, name)

    def test_static_legendaries_keep_source_coordinates_and_are_not_trainers(self):
        articuno = self.scenes['statics']['articuno']
        self.assertEqual((articuno['map'], articuno['x'], articuno['y'], articuno['level'], articuno['kind']),
                         ('SeafoamIslandsB4F', 6, 1, 50, 'static'))
        self.assertEqual(articuno['id'], 'pokered:SEAFOAM_ISLANDS_B4F:objects:3')
        self.assertEqual(articuno['map_constant'], 'SEAFOAM_ISLANDS_B4F')
        zapdos = self.scenes['statics']['zapdos']
        self.assertEqual((zapdos['x'], zapdos['y'], zapdos['level']), (4, 9, 50))
        moltres = self.scenes['statics']['moltres']
        self.assertEqual((moltres['map'], moltres['x'], moltres['y'], moltres['level']),
                         ('VictoryRoad2F', 11, 5, 50))
        mewtwo = self.scenes['statics']['mewtwo']
        self.assertEqual((mewtwo['map'], mewtwo['x'], mewtwo['y'], mewtwo['level'], mewtwo['kind']),
                         ('CeruleanCaveB1F', 27, 13, 70, 'static'))
        self.assertNotIn('mew', self.scenes['statics'])

    def test_secret_key_blaine_and_viridian_giovanni_are_source_objects(self):
        key = self.scenes['secret_key']
        self.assertEqual((key['map'], key['x'], key['y'], key['species'], key['level']),
                         ('PokemonMansionB1F', 5, 13, 'SECRET_KEY', None))
        blaine = self.scenes['trainers']['blaine']
        self.assertEqual((blaine['x'], blaine['y'], blaine['species'], blaine['party_index']), (3, 3, 'OPP_BLAINE', 1))
        self.assertNotIn('level', blaine)
        self.assertTrue(blaine['id'].startswith('pokered:CINNABAR_GYM:objects:'))
        giovanni = self.scenes['trainers']['giovanni']
        self.assertEqual((giovanni['map'], giovanni['x'], giovanni['y'], giovanni['party_index']),
                         ('ViridianGym', 2, 1, 3))
        self.assertNotIn('level', giovanni)
        self.assertEqual(giovanni['map_constant'], 'VIRIDIAN_GYM')

    def test_cinnabar_lab_fossil_revival_uses_the_source_scientist(self):
        revival = self.scenes['fossil_revival']
        scientist = revival['scientist']
        self.assertEqual(scientist['id'], 'pokered:CINNABAR_LAB_FOSSIL_ROOM:objects:1')
        self.assertEqual(
            (scientist['map'], scientist['map_constant'], scientist['x'], scientist['y'], scientist['text_id']),
            ('CinnabarLabFossilRoom', 'CINNABAR_LAB_FOSSIL_ROOM', 5, 2, 'TEXT_CINNABARLABFOSSILROOM_SCIENTIST1'))
        self.assertEqual(revival['results'], [
            {'item': 'DOME_FOSSIL', 'species': 'KABUTO'},
            {'item': 'HELIX_FOSSIL', 'species': 'OMANYTE'},
            {'item': 'OLD_AMBER', 'species': 'AERODACTYL'},
        ])
        self.assertEqual(revival['level'], 30)
        self.assertEqual(revival['give_sets'], ['EVENT_GAVE_FOSSIL_TO_LAB', 'EVENT_LAB_STILL_REVIVING_FOSSIL'])
        self.assertEqual(revival['handover_sets'], ['EVENT_LAB_HANDING_OVER_FOSSIL_MON'])
        self.assertTrue(revival['handover_when_still_reviving_clear'])
        self.assertEqual(revival['success_resets'], [
            'EVENT_GAVE_FOSSIL_TO_LAB', 'EVENT_LAB_STILL_REVIVING_FOSSIL', 'EVENT_LAB_HANDING_OVER_FOSSIL_MON'])
        self.assertEqual(revival['still_reviving_cleared_on_map_load'], {
            'event': 'EVENT_LAB_STILL_REVIVING_FOSSIL',
            'map': 'CinnabarIsland',
            'map_constant': 'CINNABAR_ISLAND',
        })
        for name in (scientist['map'], revival['still_reviving_cleared_on_map_load']['map']):
            self.assertNotIn(name, self.scenes['missing_maps'])
        self.assertEqual(self.scenes['missing_maps'], [])
        cave = self.scenes['cerulean_cave']
        self.assertEqual((cave['guard_id'], cave['guard_x'], cave['guard_y'], cave['guard_initial']),
                         ('pokered:CERULEAN_CITY:objects:10', 4, 12, 'ON'))
        self.assertEqual((cave['warp_id'], cave['warp_x'], cave['warp_y'], cave['destination'], cave['hide']),
                         ('pokered:CERULEAN_CITY:warps:7', 4, 11, 'CERULEAN_CAVE_1F', 'TOGGLE_CERULEAN_CAVE_GUY'))

    def test_route23_checks_and_league_order_follow_the_source_warps(self):
        self.assertEqual(self.scenes['route23_badge_checks'], [
            'EARTHBADGE', 'VOLCANOBADGE', 'MARSHBADGE', 'SOULBADGE',
            'RAINBOWBADGE', 'THUNDERBADGE', 'CASCADEBADGE'])
        self.assertEqual(self.scenes['elite_four'], [
            'INDIGO_PLATEAU_LOBBY', 'LORELEIS_ROOM', 'BRUNOS_ROOM', 'AGATHAS_ROOM',
            'LANCES_ROOM', 'CHAMPIONS_ROOM', 'HALL_OF_FAME'])
        self.assertEqual(self.scenes['hall_of_fame']['hides'], ['TOGGLE_CERULEAN_CAVE_GUY'])

    def test_champion_ace_follows_the_rival_starter(self):
        teams = self.scenes['champion']['by_rival_starter']
        self.assertEqual(self.scenes['champion']['selector'], 'wRivalStarter')
        self.assertEqual(teams['STARTER2']['ace'], 'BLASTOISE')
        self.assertEqual(teams['STARTER3']['ace'], 'VENUSAUR')
        self.assertEqual(teams['STARTER1']['ace'], 'CHARIZARD')

    def test_remainder_maps_are_installed_and_the_cave_stays_closed(self):
        import subprocess
        import tempfile
        from tools.tests.test_endgame_story import lua_binary, lua_literal
        installed = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())['maps']
        self.assertEqual(self.scenes['missing_maps'], [])
        for name in ('PowerPlant', 'CeruleanCave1F', 'CeruleanCave2F', 'CeruleanCaveB1F'):
            self.assertIn(name, installed)
        module = ROOT / 'Source/game/lateKantoStory.lua'
        document = json.loads((GEN.OUTPUT / 'scenes.json').read_text())
        probe = r'''
json = { decodeFile = function() return document end }
pokemonData = {articuno=true, zapdos=true, moltres=true, mewtwo=true}
import = function() end
dofile(module_path)
local function check(actual, expected, label)
    if actual ~= expected then
        error(label .. " got " .. tostring(actual) .. " expected " .. tostring(expected))
    end
end
check(LateKantoStory.caveEntry({}), "blocked", "cave closed")
check(LateKantoStory.caveEntry({TOGGLE_CERULEAN_CAVE_GUY = true}), "open", "cave open")
check(LateKantoStory.staticBattle("zapdos").level, 50, "zapdos")
check(LateKantoStory.staticBattle("zapdos").map_id, "pokered:POWER_PLANT", "zapdos map")
check(LateKantoStory.staticBattle("zapdos").species, "zapdos", "zapdos species")
check(LateKantoStory.staticBattle("zapdos").source, "object_event", "zapdos source")
check(LateKantoStory.staticBattle("mewtwo").level, 70, "mewtwo")
check(LateKantoStory.staticBattle("moltres").level, 50, "moltres")
check(LateKantoStory.staticBattle("moltres").map_id, "pokered:VICTORY_ROAD_2F", "moltres map")
check(LateKantoStory.staticBattle("articuno").species, "articuno", "articuno")
check(LateKantoStory.actorMetadata("pokered:CERULEAN_CITY:objects:10").visibility[1].equals, false, "guard visible")
print("late-kanto ok")
'''
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'probe.lua'
            path.write_text('document = ' + lua_literal(document)
                            + '\nmodule_path = ' + json.dumps(str(module)) + '\n' + probe)
            completed = subprocess.run([lua_binary(), str(path)], check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn('late-kanto ok', completed.stdout)
