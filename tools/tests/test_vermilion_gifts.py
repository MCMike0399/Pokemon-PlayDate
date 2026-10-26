"""Primary input and projection checks only; gameplay belongs to real SDK tests."""
import hashlib
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from tools import generate_vermilion_gifts as g


class GiftInputs(unittest.TestCase):
    def test_primary_source_pins(self):
        pin=json.loads((g.REFERENCE/'manifest.json').read_text())
        self.assertEqual(pin['revision'],g.REVISION)
        self.assertEqual(len(pin['files']),6)
        for name,digest in pin['files'].items():
            self.assertEqual(hashlib.sha256((g.REFERENCE/name).read_bytes()).hexdigest(),digest)

    def test_regeneration(self):
        for name,raw in g.build().items():
            self.assertEqual((g.ROOT/'Source/data/vermilionGifts'/name).read_bytes(),raw)

    def test_tampered_primary_script_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            ref=Path(tmp)/'ref'
            shutil.copytree(g.REFERENCE,ref)
            (ref/'engine/events/oaks_aide.asm').write_text('changed')
            with self.assertRaisesRegex(ValueError,'unverified gift source'):
                g.build(ref)

    def test_reused_dialogue_matches_pinned_primary_text(self):
        from tools.generate_vermilion_preparation import text_recipes
        from tools.generate_cerulean_content import blue_source
        ref=Path(os.environ['POKERED_REFERENCE_DIR'])
        pins=json.loads((g.ROOT/'tools/references/vermilion-preparation.json').read_text())
        self.assertEqual(pins['revision'],g.REVISION)
        texts=json.loads((g.PREPARATION/'dialogue.json').read_text())['texts']
        events=json.loads(g.build()['events.json'])['events']
        used=set()
        for d in events.values():
            for key in ['prompt','before','declined','completed','full','success','insufficient']:
                used.update(d.get(key,[]))
        for label in used:
            row=texts[label]
            raw=(ref/row['source']).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),pins['files'][row['source']])
            self.assertEqual(row['recipe'],text_recipes(blue_source(raw.decode()))[label])

    def test_four_objects_thresholds_and_actual_flags(self):
        events=json.loads(g.build()['events.json'])['events']
        self.assertEqual(set(events),{'pokered:POKEMON_FAN_CLUB:objects:5',
            'pokered:VERMILION_OLD_ROD_HOUSE:objects:1','pokered:ROUTE_2_GATE:objects:1',
            'pokered:ROUTE_11_GATE_2F:objects:2'})
        by_item={d['item']:d for d in events.values()}
        self.assertEqual(by_item['hm05']['threshold'],10)
        self.assertEqual(by_item['itemfinder']['threshold'],30)
        self.assertEqual(by_item['oldRod']['flag'],'pokered:wStatusFlags1:BIT_GOT_OLD_ROD')
        self.assertEqual(by_item['bikeVoucher']['flag'],'EVENT_GOT_BIKE_VOUCHER')
        self.assertEqual(by_item['bikeVoucher']['blocks'],['bicycle','bikeVoucher'])

    def test_story_and_layered_receipts_use_existing_source_resources(self):
        events=json.loads(g.build()['events.json'])['events']
        club=events['pokered:POKEMON_FAN_CLUB:objects:5']
        self.assertEqual(club['before'],['_PokemonFanClubChairmanStoryText'])
        self.assertEqual(len(club['success']),2)
        text=json.loads((g.PREPARATION/'dialogue.json').read_text())['texts']
        story=text[club['before'][0]]['recipe']
        self.assertIn('RAPIDASH...', [r.get('text') for r in story])
        self.assertEqual(len(story),24)
        self.assertEqual(events['pokered:ROUTE_2_GATE:objects:1']['prompt'],['_OaksAideHiText'])

if __name__=='__main__':
    unittest.main()
