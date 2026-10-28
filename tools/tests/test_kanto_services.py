"""Pinned-input and generator checks only. Runtime witnesses live in SDK Lua."""
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tools import generate_kanto_services as generator


class KantoServiceInputs(unittest.TestCase):
    def test_all_pinned_inputs_match_manifest(self):
        pin = json.loads((generator.REFERENCE / 'manifest.json').read_text())
        self.assertEqual(pin['revision'], 'af519899719f0754965776faac0e836a3b906e6d')
        self.assertEqual(len(pin['files']), 12)
        for path, digest in pin['files'].items():
            self.assertEqual(hashlib.sha256((generator.REFERENCE / path).read_bytes()).hexdigest(), digest)

    def test_generated_outputs_are_current(self):
        for name, raw in generator.build().items():
            self.assertEqual((generator.ROOT / 'Source/data/kantoServices' / name).read_bytes(), raw)

    def test_tampered_script_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            reference = Path(tmp) / 'reference'
            shutil.copytree(generator.REFERENCE, reference)
            (reference / 'scripts/Museum1F.asm').write_text('different source')
            with self.assertRaisesRegex(ValueError, 'unverified service source'):
                generator.build(reference)

    def test_exact_service_identities_and_no_ordinary_registration(self):
        events = json.loads(generator.build()['events.json'])['events']
        self.assertEqual(set(events), {'pokered:MUSEUM_1F:objects:1',
                                     'pokered:MT_MOON_POKECENTER:objects:4',
                                     'pokered:BIKE_SHOP:objects:1'})
        ordinary = json.loads((generator.ROOT / 'Source/data/sourceSlice/events.json').read_text())['events']
        self.assertFalse(set(events) & set(ordinary))
        self.assertIn('pokered:MUSEUM_1F:objects:3', ordinary)  # existing Old Amber owner
        self.assertIn('pokered:BIKE_SHOP:objects:3', ordinary)  # existing conditional youngster

    def test_source_prices_species_and_visit_policy(self):
        policy = json.loads(generator.build()['policy.json'])
        self.assertEqual(policy['museum'], {'price': 50, 'flag': 'EVENT_BOUGHT_MUSEUM_TICKET',
                                          'reset_map': 'pokered:PEWTER_CITY', 'trigger_y': 4, 'trigger_x': [9, 10]})
        self.assertEqual(policy['magikarp'], {'price': 500, 'species': 'magikarp', 'level': 5,
                                            'flag': 'EVENT_BOUGHT_MAGIKARP'})
        self.assertEqual(policy['bicycle']['offer_price'], 1000000)
        self.assertEqual(policy['bicycle']['voucher'], 'bikeVoucher')

    def test_dialogue_recipes_retain_source_controls_and_prices(self):
        texts = json.loads(generator.build()['dialogue.json'])['texts']
        def literal(label):
            return ' '.join(row.get('text', '') for row in texts[label]['recipe'])
        self.assertIn('¥50', literal('_Museum1FScientist1WouldYouLikeToComeInText'))
        self.assertIn('¥500', literal('_MtMoonPokecenterMagikarpSalesmanIGotADealText'))
        self.assertIn('BIKE VOUCHER', literal('_BikeShopExchangedVoucherText'))
        self.assertIn('wNameBuffer', {row.get('symbol') for row in texts['_GotMonText']['recipe']})
        self.assertIn('wStringBuffer', {row.get('symbol') for row in texts['_SentToBoxText']['recipe']})


if __name__ == '__main__':
    unittest.main()
