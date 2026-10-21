"""Three exact side-condition migrations; no GenV scalar changes."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen,ROOT
KEYS=('lightScreen','safeguard','tailwind')

def fixture():
    vectors=[(113,'light-screen',14,30),(219,'safeguard',1,25),(366,'tailwind',3,30)]
    moves=[dict(id=str(i),identifier=k,type_id=str(t),pp=str(pp),damage_class_id='1',power='0',accuracy='0',target_id='4',priority='0',effect_chance='',generation_id='4')for i,k,t,pp in vectors]
    return dict(moves=moves,move_changelog=[],move_meta=[],move_meta_stat_changes=[],types=[dict(id=str(i),identifier=s)for i,s in ((1,'normal'),(3,'flying'),(14,'psychic'))])

def prior():
    rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())
    return '-- move-producer-contract: 9\n'+'\n'.join('    '+k+' = '+rows[k].replace(', effects = { SideConditionEffect("'+k+'") }','')for k in KEYS)+'\n'

def generate(text,folder):
    source=folder/'input.lua';target=folder/'output.lua';source.write_text(text)
    with patch.object(gen,'MOVES_INPUT',str(source)),patch.object(gen,'MOVES_LUA',str(target)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(fixture(),True)
    return target.read_text()

class SideProducerTests(unittest.TestCase):
    def test_exact_three_payloads_preserve_all_prior_fields_and_repeat(self):
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);old=c.read_rows(prior());text=generate(prior(),p);rows=c.read_rows(text)
            for key,pp in zip(KEYS,(30,25,30)):
                self.assertEqual(c.split_payload(rows[key])[0],c.split_payload(old[key])[0])
                self.assertEqual(c.payload(rows[key]),{'effects':['SideConditionEffect ( "'+key+'" )'],'secondaries':[]})
                self.assertEqual(c.fields(rows[key])['pp'],pp);self.assertEqual(c.fields(rows[key])['targetId'],4)
            self.assertEqual(generate(text,p),text)

    def test_current_missing_wrong_extra_effect_and_modern_pp_mutants_fail(self):
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);text=generate(prior(),p)
            for key in KEYS:
                for replacement in ('NoEffect()','SideConditionEffect("mist")','SideConditionEffect("'+key+'"), NoEffect()'):
                    mutant=text.replace('SideConditionEffect("'+key+'")',replacement,1)
                    with self.subTest(key=key,replacement=replacement),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(mutant,p)
            for a,b in [('pp = 30','pp = 15'),('pp = 25','pp = 24'),('targetId = 4','targetId = 7')]:
                with self.subTest(change=(a,b)),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(text.replace(a,b,1),p)

    def test_explicit_current_epoch_keeps_original424_inverse_hash(self):
        text=(ROOT/'Source/battle/moves.lua').read_text();rows=c.read_rows(text);epoch=c.producer_epoch(text);self.assertEqual(epoch,12)
        self.assertEqual(c.digest(json.dumps(c.legacy_rows(rows,epoch),sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
        for key in KEYS:
            changed=dict(rows);changed[key]=rows[key].replace('SideConditionEffect("'+key+'")','NoEffect()')
            with self.subTest(key=key),self.assertRaisesRegex(ValueError,'unowned move effect'):c.legacy_rows(changed,epoch)
