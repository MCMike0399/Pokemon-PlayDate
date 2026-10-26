"""Exact Roost recovery/typing migration retains original scalar/effect oracles."""
import json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen,ROOT
LEGACY='Heal(ATTACKER, Product(MaxHPOf(ATTACKER), 0.5))'
def fixture():
 return dict(moves=[dict(id='355',identifier='roost',type_id='3',pp='10',damage_class_id='1',power='0',accuracy='0',target_id='7',priority='0',effect_chance='',generation_id='4')],move_changelog=[],move_meta=[dict(move_id='355',meta_ailment_id='0',ailment_chance='0',flinch_chance='0',stat_chance='0',healing='50',drain='0',min_hits='',max_hits='')],move_meta_stat_changes=[],types=[dict(id='3',identifier='flying')])
def prior():
 row=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())['roost'].replace('RoostEffect()',LEGACY)
 return '-- move-producer-contract: 10\n    roost = '+row+'\n'
def generate(text,folder):
 source=folder/'input.lua';target=folder/'output.lua';source.write_text(text)
 with patch.object(gen,'MOVES_INPUT',str(source)),patch.object(gen,'MOVES_LUA',str(target)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(fixture(),True)
 return target.read_text()
class RoostProducerTests(unittest.TestCase):
 def test_one_exact_payload_migrates_without_scalar_or_metadata_changes_and_repeats(self):
  with tempfile.TemporaryDirectory()as tmp:
   p=Path(tmp);old=c.read_rows(prior())['roost'];text=generate(prior(),p);row=c.read_rows(text)['roost'];self.assertEqual(c.producer_epoch(text),13)
   self.assertEqual(c.split_payload(row)[0],c.split_payload(old)[0]);self.assertEqual(c.payload(row),{'effects':['RoostEffect ( )'],'secondaries':[]})
   f=c.fields(row)
   # Zero priority is omitted by the existing exact producer format; Move's
   # unchanged constructor supplies zero. An invented priority must reject.
   self.assertNotIn('priority',f)
   for k,v in dict(pp=10,targetId=7,power=0,accuracy=0,type='flying',category='status',contact=False,protectable=False,breaksProtect=False).items():self.assertIs(type(f[k]),type(v));self.assertEqual(f[k],v)
   self.assertEqual(generate(text,p),text)
 def test_current_legacy_payload_wrong_producer_extra_effect_and_scalar_changes_reject_atomically(self):
  with tempfile.TemporaryDirectory()as tmp:
   p=Path(tmp);text=generate(prior(),p)
   changes=[('RoostEffect()',LEGACY),('RoostEffect()','NoEffect()'),('RoostEffect()','RoostEffect(), NoEffect()'),('RoostEffect()','WeatherHealEffect()'),('pp = 10','pp = 5'),('pp = 10','pp = 10, priority = 1'),('targetId = 7','targetId = 10'),('type = "flying"','type = "normal"'),('protectable = false','protectable = true')]
   for a,b in changes:
    (p/'output.lua').write_text('PRESERVE PRIOR OUTPUT')
    with self.subTest(change=(a,b)),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(text.replace(a,b,1),p)
    self.assertEqual((p/'output.lua').read_text(),'PRESERVE PRIOR OUTPUT')
 def test_exact_current_inverse_retains_original424_hash_and_rejects_unowned_effects(self):
  text=(ROOT/'Source/battle/moves.lua').read_text();rows=c.read_rows(text);epoch=c.producer_epoch(text);self.assertEqual(epoch,13)
  self.assertEqual(c.digest(json.dumps(c.legacy_rows(rows,epoch),sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
  for replacement in (LEGACY,'NoEffect()','RoostEffect(), NoEffect()'):
   changed=dict(rows);changed['roost']=rows['roost'].replace('RoostEffect()',replacement)
   with self.subTest(effect=replacement),self.assertRaisesRegex(ValueError,'unowned move effect'):c.legacy_rows(changed,epoch)
