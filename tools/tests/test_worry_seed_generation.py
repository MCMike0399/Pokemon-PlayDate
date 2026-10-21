"""Only the explicit Worry Seed producer/eligibility migration may change."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen,ROOT

def fixture():
    return dict(moves=[dict(id='388',identifier='worry-seed',type_id='12',damage_class_id='1',power='0',accuracy='100',pp='10',target_id='10',priority='0',effect_chance='',generation_id='4')],move_changelog=[],move_meta=[],move_meta_stat_changes=[],types=[dict(id='12',identifier='grass')])

def prior():
    row=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())['worrySeed']
    return '-- move-producer-contract: 7\n    worrySeed = '+c.drop_fields(row,('attemptRule',)).replace(', effects = { WorrySeedEffect() }','')+'\n'

def generate(text,folder):
    source=folder/'input.lua';target=folder/'output.lua';source.write_text(text)
    with patch.object(gen,'MOVES_INPUT',str(source)),patch.object(gen,'MOVES_LUA',str(target)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(fixture(),True)
    return target.read_text()

class WorrySeedProducerTests(unittest.TestCase):
    def test_exact_one_row_adds_no_constructor_or_scalar_changes_and_repeats(self):
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);old=c.read_rows(prior())['worrySeed'];text=generate(prior(),p);row=c.read_rows(text)['worrySeed']
            self.assertEqual(c.fields(row)['attemptRule'],'worrySeed')
            self.assertEqual(c.split_payload(c.drop_fields(row,('attemptRule',)))[0],c.split_payload(old)[0])
            self.assertEqual(c.payload(row),{'effects':['WorrySeedEffect ( )'],'secondaries':[]})
            self.assertEqual(generate(text,p),text)

    def test_current_missing_wrong_eligibility_and_payload_scalar_mutants_reject(self):
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);text=generate(prior(),p)
            for before,after in [(', attemptRule = "worrySeed"',''),('attemptRule = "worrySeed"','attemptRule = "wrong"'),('attemptRule = "worrySeed"','attemptRule = true'),(', effects = { WorrySeedEffect() }',''),('WorrySeedEffect()','NoEffect()'),('accuracy = 100','accuracy = 99'),('pp = 10','pp = 11'),('targetId = 10','targetId = 7')]:
                with self.subTest(change=(before,after)),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(text.replace(before,after,1),p)

    def test_current_epoch_exact_inverse_preserves_all_original_oracles(self):
        text=(ROOT/'Source/battle/moves.lua').read_text();rows=c.read_rows(text);epoch=c.producer_epoch(text)
        self.assertEqual(epoch,10)
        self.assertEqual(c.digest(json.dumps(c.legacy_rows(rows,epoch),sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
        for field in ('attemptRule','effects'):
            changed=dict(rows);changed['worrySeed']=c.drop_fields(rows['worrySeed'],(field,))
            with self.subTest(field=field),self.assertRaises(ValueError):c.legacy_rows(changed,epoch)
