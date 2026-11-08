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
        self.assertEqual(articuno['id'], 'pokered:SEAFOAMISLANDSB4F:objects:3')
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
        self.assertEqual((blaine['x'], blaine['y'], blaine['species'], blaine['level']), (3, 3, 'OPP_BLAINE', 1))
        giovanni = self.scenes['trainers']['giovanni']
        self.assertEqual((giovanni['map'], giovanni['x'], giovanni['y'], giovanni['level']),
                         ('ViridianGym', 2, 1, 3))

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

    def test_plan_maps_are_not_in_the_installed_manifest(self):
        installed = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())['maps']
        self.assertTrue(set(self.scenes['missing_maps']).isdisjoint(installed))
