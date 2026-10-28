"""Primary-source/table/oracle checks only. Runtime Lua belongs to real SDK cases."""
import copy
import unittest
from tools import generate_pickup as pickup
from tools.generate_ability_move_metadata import entries


class PickupDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = pickup.load()
        cls.table, cls.mapping, cls.additions = pickup.collect(cls.raw)

    def test_exact_approved_110_native_cells(self):
        expected = [
            [17,18,26,3,79,78,27,25,2,25,92],
            [18,26,3,79,78,27,25,2,28,92,221],
            [26,3,79,78,27,25,2,28,50,221,23],
            [3,79,78,27,25,2,28,50,80,23,38],
            [79,78,27,25,2,28,50,80,81,38,278],
            [78,27,25,2,28,50,80,81,93,278,537],
            [27,25,2,28,50,80,81,93,23,537,40],
            [25,2,28,50,80,81,93,23,29,40,537],
            [2,28,50,80,81,93,23,29,51,537,234],
            [28,50,80,81,93,23,29,51,41,234,537],
        ]
        self.assertEqual(self.table, expected)
        self.assertEqual(len(self.mapping), 25)
        self.assertEqual(sum([30,10,10,10,10,10,10,4,4,1,1]), 100)

    def test_native_eligibility_and_draw_order_remain_pinned(self):
        native = self.raw['return']
        self.assertIn('prm->setup->battleType <= BATTLE_TYPE_TRAINER', native)
        self.assertIn('prm->setup->unkA8 == BATTLE_RESULT_WIN', native)
        self.assertLess(native.index('PokeParty_Copy(prm->setup->party[0], party)'),
                        native.index('EventBattleReturn_PickupItems(party)'))
        body = native[native.index('static void EventBattleReturn_PickupItems(PokeParty *party) {'):]
        for text in ['species != 0', 'species != SPECIES_EGG', 'item == 0',
                     'GFL_RandomLC(10) == 0', 'rand = GFL_RandomLC(100)',
                     'PKM_PARAM_LEVEL, NULL) - 1) / 10', 'levelSlot + (99 - rand)']:
            self.assertIn(text, body)
        self.assertNotIn('PKM_PARAM_HP', body.split('// Natural Cure')[0])

    def test_new_identity_and_historical_gen5_prices(self):
        self.assertEqual({key:(native,api,cost) for _,key,native,api,cost in self.additions}, {
            'sunStone':(80,80,2100), 'heartScale':(93,93,100),
            'kingsRock':(221,198,100), 'ironBall':(278,255,200),
            'prismScale':(537,580,500), 'leftovers':(234,211,200),
        })
        self.assertEqual(self.mapping[221], 'kingsRock')
        self.assertEqual(self.mapping[537], 'prismScale')
        self.assertEqual(self.mapping[234], 'leftovers')

    def test_generated_data_current(self):
        self.assertEqual((pickup.ROOT / 'Source/data/pickupData.lua').read_text(), pickup.render(self.raw))

    def test_changed_native_probability_rejected(self):
        raw = copy.copy(self.raw)
        raw['return'] = raw['return'].replace('30, 40, 50', '31, 40, 50')
        with self.assertRaises(AssertionError):
            pickup.collect(raw)

    def test_showdown_gen5_inherited_held_callbacks(self):
        base = entries(self.raw['ps_data_items.ts'])
        for gen in [8,7,6,5]:
            overrides = entries(self.raw[f'ps_data_mods_gen{gen}_items.ts'])
            for key in ['kingsrock', 'ironball', 'leftovers']:
                self.assertNotIn(key, overrides)
        self.assertIn('onModifyMovePriority: -1', base['kingsrock'])
        self.assertIn("secondary.volatileStatus === 'flinch'", base['kingsrock'])
        self.assertIn('chance: 10', base['kingsrock'])
        self.assertIn('chainModify(0.5)', base['ironball'])
        self.assertIn("move.type === 'Ground' && target.hasType('Flying')", base['ironball'])
        self.assertIn('return 0', base['ironball'])
        self.assertIn('onResidualOrder: 5', base['leftovers'])
        self.assertIn('onResidualSubOrder: 4', base['leftovers'])
        self.assertIn('this.heal(pokemon.baseMaxhp / 16)', base['leftovers'])
        grounded = self.raw['ps_sim_pokemon.ts'].split('isGrounded(negateImmunity = false) {', 1)[1].split('isSemiInvulnerable()', 1)[0]
        self.assertLess(grounded.index("item === 'ironball'"), grounded.index("hasType('Flying')"))
        self.assertLess(grounded.index("item === 'ironball'"), grounded.index("'levitate'"))
        actions = self.raw['ps_sim_battle-actions.ts']
        self.assertIn('this.secondaries(', actions)
        self.assertIn('move.multihit', actions)


if __name__ == '__main__':
    unittest.main()
