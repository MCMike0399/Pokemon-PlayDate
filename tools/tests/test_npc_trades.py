"""Primary input/data/oracle checks only. Actual Lua runs solely in the SDK."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from tools.generate_npc_trades import build, OUTPUT, REFERENCE, ROOT


class NPCTradeDataTests(unittest.TestCase):
    def test_generated_data_is_current(self):
        self.assertEqual(json.loads(OUTPUT.read_text()), build())

    def test_exact_nine_original_identities(self):
        trades = build()['trades']
        self.assertEqual(sorted(t['index'] for t in trades.values()), [0, 1, 3, 4, 5, 6, 7, 8, 9])
        self.assertEqual({t['nickname'] for t in trades.values()},
                         {'TERRY', 'MARCEL', 'SAILOR', 'DUX', 'MARC', 'LOLA', 'DORIS', 'CRINKLES', 'SPOT'})
        self.assertEqual(len({t['flag'] for t in trades.values()}), 9)
        self.assertEqual(len(build()['events']), 4)
        self.assertNotIn('pokered:CERULEAN_TRADE_HOUSE:objects:2', build()['events'])

    def test_all_source_dialogue_branches_and_literal_species(self):
        data = build()
        self.assertEqual(len(data['texts']), 17)
        for t in data['trades'].values():
            for branch in ['WannaTrade', 'NoTrade', 'WrongMon', 'Thanks', 'AfterTrade']:
                self.assertIn(f'_{branch}{t["dialogue"]}Text', data['texts'])
        spot = next(t for t in data['trades'].values() if t['nickname'] == 'SPOT')
        self.assertEqual((spot['wantedName'], spot['offeredName']), ('NIDORAN♂', 'NIDORAN♀'))
        marcel = next(t for t in data['trades'].values() if t['nickname'] == 'MARCEL')
        self.assertEqual(marcel['offeredName'], 'MR.MIME')

    def test_corrupt_source_rejected_before_generation(self):
        with tempfile.TemporaryDirectory() as tmp:
            candidate = Path(tmp)
            import shutil
            shutil.copytree(REFERENCE, candidate, dirs_exist_ok=True)
            target = candidate / 'data/events/trades.asm'
            target.write_text(target.read_text().replace('TERRY', 'WRONG'))
            with self.assertRaises(AssertionError):
                build(candidate)

    def test_native_xp_order_and_q12_ties_oracle(self):
        raw = (ROOT / 'tools/references/rewards/btl_server_flow_sub.c').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),
                         '224b984bfeb441a1761cb82cf11447b2507beda8a6e5644d1bbbf19cd9f9736a')
        body = raw.decode().split('entry->exp = ScaleExpGainedByLevel', 1)[1]
        self.assertLess(body.index('IsTrainerOT'), body.index('ITEM_LUCKY_EGG'))
        self.assertLess(body.index('0x1800'), body.index('entry->exp > 100000'))
        native_path = ROOT / 'tools/references/pickup/btl_calc.c'
        pins = json.loads((ROOT / 'tools/references/pickup-sources.json').read_text())
        native = native_path.read_text()
        self.assertIn(hashlib.sha256(native_path.read_bytes()).hexdigest(), json.dumps(pins))
        self.assertIn('fraction > 0x800', native)
        # Independent native fixed_round oracle; checked into SDK witnesses below.
        vectors = {1: 1, 2: 3, 3: 4, 66: 99, 67: 100, 99999: 100000, 100001: 100000}
        for award, expected in vectors.items():
            product = award * 0x1800
            actual = (product >> 12) + ((product & 0xfff) > 0x800)
            self.assertEqual(min(100000, actual), expected)


if __name__ == '__main__':
    unittest.main()
