"""Exact epoch7 rain migration; original scalar/effect oracles remain fixed."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen,ROOT

KEYS=('rainDance','thunder','hurricane')

def fixture():
    vectors=[(240,'rain-dance',11,1,0,0,5,12),(87,'thunder',13,3,120,70,10,10),(542,'hurricane',3,3,120,70,10,10)]
    moves=[dict(zip(('id','identifier','type_id','damage_class_id','power','accuracy','pp','target_id'),map(str,row)),priority='0',effect_chance='30' if row[0]!=240 else '',generation_id='1') for row in vectors]
    meta=[dict(move_id=str(row[0]),crit_rate='0',meta_ailment_id=str(1 if row[0]==87 else 6 if row[0]==542 else 0),ailment_chance='30' if row[0]!=240 else '0',flinch_chance='0',stat_chance='0',healing='0',drain='0',min_hits='',max_hits='') for row in vectors]
    return dict(moves=moves,move_changelog=[],move_meta=meta,move_meta_stat_changes=[],types=[dict(id=str(i),identifier=s)for i,s in ((11,'water'),(13,'electric'),(3,'flying'))])

def prior():
    rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())
    return '-- move-producer-contract: 6\n'+'\n'.join('    '+key+' = '+c.drop_fields(rows[key],('weatherAccuracy',)).replace(', effects = { WeatherEffect("raindance") }','')for key in KEYS)+'\n'

def generate(text,folder):
    source=folder/'input.lua';target=folder/'output.lua';source.write_text(text)
    with patch.object(gen,'MOVES_INPUT',str(source)),patch.object(gen,'MOVES_LUA',str(target)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(fixture(),True)
    return target.read_text()

class RainProducerTests(unittest.TestCase):
    def test_only_exact_three_rows_migrate_then_regenerate_identically(self):
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);old=c.read_rows(prior());new=generate(prior(),p);rows=c.read_rows(new)
            for key in ('thunder','hurricane'):
                self.assertIs(c.fields(rows[key])['weatherAccuracy'],True)
                self.assertEqual(c.drop_fields(rows[key],('weatherAccuracy',)),old[key])
                self.assertEqual(c.fields(rows[key])['power'],120)
                self.assertEqual(c.fields(rows[key])['accuracy'],70)
            self.assertEqual(c.payload(rows['rainDance']),{'effects':['WeatherEffect ( "raindance" )'],'secondaries':[]})
            self.assertEqual(c.split_payload(rows['rainDance'])[0],c.split_payload(old['rainDance'])[0])
            self.assertEqual(generate(new,p),new)

    def test_current_missing_wrong_type_false_and_effect_scalar_mutants_reject(self):
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);text=generate(prior(),p)
            for before,after in [(', weatherAccuracy = true',''),('weatherAccuracy = true','weatherAccuracy = false'),('weatherAccuracy = true','weatherAccuracy = "true"'),('WeatherEffect("raindance")','NoEffect()'),(', effects = { WeatherEffect("raindance") }',''),('power = 120','power = 110'),('accuracy = 70','accuracy = 100'),('Chance(30)','Chance(31)')]:
                with self.subTest(change=(before,after)),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(text.replace(before,after,1),p)

    def test_original424_hash_and_current_exact_metadata_and_payload_inverse(self):
        text=(ROOT/'Source/battle/moves.lua').read_text();rows=c.read_rows(text);epoch=c.producer_epoch(text)
        self.assertEqual(epoch,10)
        self.assertEqual(c.digest(json.dumps(c.legacy_rows(rows,epoch),sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
        for key in ('thunder','hurricane'):
            changed=dict(rows);changed[key]=c.drop_fields(rows[key],('weatherAccuracy',))
            with self.subTest(key=key),self.assertRaisesRegex(ValueError,'producer metadata'):c.legacy_rows(changed,epoch)
        changed=dict(rows);changed['rainDance']=rows['rainDance'].replace('WeatherEffect("raindance")','WeatherEffect("hail")')
        with self.assertRaisesRegex(ValueError,'unowned move effect'):c.legacy_rows(changed,epoch)
