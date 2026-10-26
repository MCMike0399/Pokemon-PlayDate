"""Gen5 PoisonFang correction with exact historical migration chains."""
import json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen,ROOT
OLD='SecondaryEffect(DEFENDER, When(Chance(50), ApplyStatus(DEFENDER, "poison")))'
NEW='SecondaryEffect(DEFENDER, When(Chance(30), ApplyStatus(DEFENDER, "badPoison")))'
def fixture():
 return dict(moves=[dict(id='305',identifier='poison-fang',type_id='4',pp='15',damage_class_id='2',power='50',accuracy='100',target_id='10',priority='0',effect_chance='',generation_id='3')],move_changelog=[],move_meta=[dict(move_id='305',meta_ailment_id='5',ailment_chance='50',flinch_chance='0',stat_chance='0',healing='0',drain='0',min_hits='',max_hits='')],move_meta_stat_changes=[],types=[dict(id='4',identifier='poison')])
def prior():
 row=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())['poisonFang'].replace(NEW,OLD)
 return '-- move-producer-contract: 11\n    poisonFang = '+row+'\n'
def legacy():
 row=c.read_rows(prior())['poisonFang'];prefix,_=c.split_payload(c.drop_fields(row,('targetId',)+c.PRODUCER_FIELDS));return '    poisonFang = '+prefix+c.load_contract()['transitions']['poisonFang'][0]['legacy_suffix']+'\n'
def generate(text,path):
 source=path/'input.lua';output=path/'output.lua';source.write_text(text)
 with patch.object(gen,'MOVES_INPUT',str(source)),patch.object(gen,'MOVES_LUA',str(output)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(fixture(),True)
 return output.read_text()
class PoisonFangProducerTests(unittest.TestCase):
 def test_one_exact_gen5_secondary_change_with_all_prior_scalar_metadata_retained(self):
  with tempfile.TemporaryDirectory()as tmp:
   p=Path(tmp);old=c.read_rows(prior())['poisonFang'];text=generate(prior(),p);row=c.read_rows(text)['poisonFang'];self.assertEqual(c.producer_epoch(text),13)
   self.assertEqual(c.split_payload(row)[0],c.split_payload(old)[0]);self.assertEqual(c.payload(row),{'effects':[],'secondaries':['SecondaryEffect ( DEFENDER , When ( Chance ( 30 ) , ApplyStatus ( DEFENDER , "badPoison" ) ) )']})
   for key,value in dict(power=50,accuracy=100,pp=15,type='poison',category='physical',targetId=10,contact=True,protectable=True).items():self.assertEqual(c.fields(row)[key],value)
   self.assertEqual(generate(text,p),text)
 def test_current_probability_ordinary_poison_missing_extra_payload_and_scalar_mutants_reject(self):
  with tempfile.TemporaryDirectory()as tmp:
   p=Path(tmp);text=generate(prior(),p)
   for old,new in [('Chance(30)','Chance(50)'),('Chance(30)','Chance(31)'),('"badPoison"','"poison"'),(NEW,OLD),(NEW,'NoEffect()'),('power = 50','power = 51'),('pp = 15','pp = 14'),('targetId = 10','targetId = 7'),('"badPoison"','"badPoison"), NoEffect(')]:
    (p/'output.lua').write_text('DO NOT OVERWRITE')
    with self.subTest(change=(old,new)),self.assertRaises((ValueError,AssertionError)):generate(text.replace(old,new,1),p)
    self.assertEqual((p/'output.lua').read_text(),'DO NOT OVERWRITE')
 def test_exact_legacy_v0_to_v1_to_v12_chain_and_no_current_epoch_rollback(self):
  with tempfile.TemporaryDirectory()as tmp:
   p=Path(tmp);self.assertEqual(c.producer_epoch(legacy()),0);new=generate(legacy(),p);self.assertEqual(c.read_rows(new),c.read_rows(generate(prior(),p)))
   for old in [legacy().replace('Chance(50)','Chance(49)'),prior().replace('secondaries = { '+OLD+' }','effects = { When(Chance(50), ApplyStatus(DEFENDER, "poison")) }')]:
    with self.subTest(input=old),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(old,p)
 def test_original424_inverse_oracle_unchanged_and_current_effect_rollback_rejects(self):
  text=(ROOT/'Source/battle/moves.lua').read_text();rows=c.read_rows(text);epoch=c.producer_epoch(text);self.assertEqual(epoch,13)
  self.assertEqual(c.digest(json.dumps(c.legacy_rows(rows,epoch),sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
  changed=dict(rows);changed['poisonFang']=rows['poisonFang'].replace(NEW,OLD)
  # The same bytes are valid genuine v11 history, never a v12 rollback.
  historical=dict(changed)
  for key in ('whirlwind','roar'):
   prefix,_=c.split_payload(historical[key]);historical[key]=prefix+c.load_contract()['transitions'][key][0]['legacy_suffix']
  self.assertEqual(c.digest(json.dumps(c.legacy_rows(historical,11),sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
  with self.assertRaisesRegex(ValueError,'unowned move effect'):c.legacy_rows(changed,epoch)
