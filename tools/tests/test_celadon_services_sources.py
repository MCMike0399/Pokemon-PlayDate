"""Source-only projection checks; real owner behavior belongs to SDK contracts."""
import importlib.util
import json
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('celadon_prepare', ROOT / 'tools/celadon-services/prepare.py')
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)
REFERENCE = Path(os.environ.get('POKERED_REFERENCE_DIR', Path.home() / 'Developer/Pokemon-PlayDate-env/pokered'))


class CeladonSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.generated = GEN.build(REFERENCE)
        cls.policy = json.loads(cls.generated['policy.json'])['policy']

    def test_checked_in_data_matches_verified_external_source(self):
        for name, raw in self.generated.items():
            self.assertEqual((GEN.OUT / name).read_bytes(), raw)

    def test_vending_prices_and_drink_rewards_are_original_blue(self):
        self.assertEqual([(d['item'],d['price'],d['tm'],d['flag']) for d in self.policy['drinks']], [
            ('freshWater',200,'tm13','EVENT_GOT_TM13'),('sodaPop',300,'tm48','EVENT_GOT_TM48'),
            ('lemonade',350,'tm49','EVENT_GOT_TM49')])
        self.assertEqual(self.policy['vending_minimum_money'],200)
        self.assertEqual(self.policy['eevee']['level'],25)

    def test_blue_prize_versions_levels_prices_and_order(self):
        rows = [p for window in self.policy['prizes'] for p in window]
        self.assertEqual([(p.get('species'),p.get('level'),p['price']) for p in rows[:6]], [
            ('abra',6,120),('clefairy',12,750),('nidorino',17,1200),
            ('pinsir',20,2500),('dratini',24,4600),('porygon',18,6500)])
        self.assertEqual([(p['item'],p['price']) for p in rows[6:]], [('tm23',3300),('tm15',5500),('tm50',7700)])
        self.assertEqual(self.policy['coin_sale'],dict(price=1000,coins=50,full_threshold=9990))

    def test_slots_keep_all_three_reels_and_source_hidden_event_priority(self):
        self.assertEqual([len(w) for w in self.policy['wheels']],[18,18,18])
        self.assertEqual([w[0] for w in self.policy['wheels']],['SLOTS7']*3)
        self.assertEqual(len(self.policy['machines']),36)
        self.assertEqual(len(self.policy['hidden_coins']),12)
        self.assertTrue(self.policy['hidden_coins'][-1]['shadowed_by_slot'])
        self.assertEqual(self.policy['hidden_coins'][-1]['index'],48)
        typo = next(h for h in self.policy['hidden_coins'] if h['coins']==40)
        self.assertEqual(typo['credited_coins'],20)
        self.assertEqual((typo['x'],typo['y']),(11,7))

    def test_elevator_source_zero_based_destinations_are_not_guessed(self):
        self.assertEqual([f['source_warp_byte'] for f in self.policy['elevator']],[5,2,2,2,2])
        self.assertEqual([f['floor'] for f in self.policy['elevator']],[1,2,3,4,5])


if __name__ == '__main__':
    unittest.main()
