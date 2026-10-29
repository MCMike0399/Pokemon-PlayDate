"""Data exposure checks only. Mechanics witnesses must execute in the real SDK."""
import hashlib
import unittest

from tools.audit_cerulean_abilities import ROOT, inventory
from tools.verify_moves.parse_lua import LuaParser


class CeruleanAbilityExposureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = inventory()
        cls.rows = {row['species']: row for row in cls.report['species']}

    def test_complete_ordinary_inventory_and_bounded_evolution_scope(self):
        self.assertFalse(self.report['acceptance'])
        self.assertEqual(len(self.rows), 57)
        self.assertEqual(len({a for row in self.rows.values() for a in row['ordinary_ids']}), 44)
        self.assertTrue({'gyarados', 'golbat', 'kadabra', 'nidoqueen', 'nidoking',
                         'clefable', 'wigglytuff', 'charmeleon'} <= self.rows.keys())
        self.assertFalse({'alakazam', 'venusaur', 'blastoise', 'golem', 'vileplume',
                          'victreebel', 'charizard', 'raichu'} & self.rows.keys())
        self.assertFalse(any(e['kind'] == 'player-evolution'
                             for e in self.rows['parasect']['exposure']))

    def test_all_normal_slots_match_independent_pinned_personal_bytes(self):
        personal = (ROOT / 'tools/references/traits/personal_b2w2').read_bytes()
        self.assertEqual(hashlib.sha256(personal).hexdigest(),
                         '6df24e7f00dab32322d9d8f8b3209d30de1c89b0de88277081fe53434211830f')
        for row in self.rows.values():
            with self.subTest(species=row['species']):
                self.assertEqual(row['ordinary_ids'],
                                 list(personal[row['dex']*76+24:row['dex']*76+26]))

    def test_finding_species_have_real_low_level_wild_exposure(self):
        for species, abilities, source, level in (
            ('zubat', [39, 39], 'pokered:MT_MOON_1F:grass:0', 8),
            ('paras', [27, 87], 'pokered:MT_MOON_1F:grass:7', 8),
            ('clefairy', [56, 98], 'pokered:MT_MOON_1F:grass:9', 8),
            ('abra', [28, 39], 'pokered:ROUTE_24:grass:5', 10),
        ):
            row = self.rows[species]
            self.assertEqual(row['ordinary_ids'], abilities)
            self.assertIn(dict(source=source, level=level, kind='wild'), row['exposure'])

    def test_bound_rival_variants_and_actual_gift_are_included(self):
        self.assertIn(dict(source='pokered:CERULEAN_CITY:objects:1', level=18, kind='rival'),
                      self.rows['pidgeotto']['exposure'])
        self.assertIn(dict(source='pokered:ROUTE_22:objects:1', level=8, kind='rival'),
                      self.rows['squirtle']['exposure'])
        self.assertIn(dict(source='pokered:MT_MOON_POKECENTER:objects:4', level=5, kind='gift'),
                      self.rows['magikarp']['exposure'])
        self.assertEqual(self.rows['gyarados']['ordinary_ids'], [22,22])

    def test_common_missing_effects_have_concrete_trainer_owners(self):
        for species, ability, source, level in (
            ('ekans', 22, 'pokered:ROUTE_3:objects:3', 11),
            ('koffing', 26, 'pokered:MT_MOON_B2F:objects:1', 12),
            ('mankey', 72, 'pokered:ROUTE_24:objects:3', 18),
            ('shellder', 75, 'pokered:CERULEAN_GYM:objects:3', 16),
            ('goldeen', 41, 'pokered:CERULEAN_GYM:objects:2', 19),
            ('drowzee', 108, 'pokered:CERULEAN_CITY:objects:2', 17),
        ):
            self.assertIn(ability,self.rows[species]['ordinary_ids'])
            self.assertIn(dict(source=source,level=level,kind='trainer'),
                          self.rows[species]['exposure'])

    def test_reachable_trigger_moves_are_in_realistic_level_up_data(self):
        species_data = LuaParser(ROOT / 'Source/data/pokemon.lua').parse()
        for species, key, level in (('squirtle','waterGun',15), ('charmander','ember',15),
                                    ('rattata','bite',15), ('paras','stunSpore',15),
                                    ('shellder','icicleSpear',16), ('pidgey','whirlwind',18)):
            learnset = species_data[species]['learnset']
            self.assertTrue(any(row['move'] == key and row['level'] <= level
                                for row in learnset), (species, key, level))


if __name__ == '__main__':
    unittest.main()
