"""Only declared charge/lock metadata may migrate; attack scalars stay GenV."""
import tempfile,unittest,json
from pathlib import Path
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen,ROOT
KEYS=('solarBeam','skullBash','petalDance')
RULES={'solarBeam':('chargeRule','solarBeam'),'skullBash':('chargeRule','skullBash'),'petalDance':('lockRule','rampage')}
def fixture():
    raw=[(76,'solar-beam',12,3,120,100,10,10),(130,'skull-bash',1,2,100,100,15,10),(80,'petal-dance',12,3,120,100,10,8)]
    moves=[dict(zip(('id','identifier','type_id','damage_class_id','power','accuracy','pp','target_id'),map(str,row)),priority='0',effect_chance='',generation_id='1')for row in raw]
    meta=[dict(move_id=str(row[0]),crit_rate='0',meta_ailment_id='0',ailment_chance='0',flinch_chance='0',stat_chance='0',healing='0',drain='0',min_hits='',max_hits='')for row in raw]
    return dict(moves=moves,move_changelog=[],move_meta=meta,move_meta_stat_changes=[],types=[dict(id='1',identifier='normal'),dict(id='12',identifier='grass')])
def generate(text,folder):
    src=folder/'input.lua';out=folder/'output.lua';src.write_text(text)
    with patch.object(gen,'MOVES_INPUT',str(src)),patch.object(gen,'MOVES_LUA',str(out)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(fixture(),True)
    return out.read_text()
def prior():
    rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())
    return '-- move-producer-contract: 5\n'+'\n'.join('    '+k+' = '+c.drop_fields(rows[k],('chargeRule','lockRule'))for k in KEYS)+'\n'
class ChargeProducerTests(unittest.TestCase):
    def test_only_exact_three_fields_added_to_complete_epoch5_and_idempotent(self):
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);old=c.read_rows(prior());text=generate(prior(),p);rows=c.read_rows(text)
            for key,(field,value)in RULES.items():
                self.assertEqual(c.fields(rows[key])[field],value);self.assertEqual(c.drop_fields(rows[key],('chargeRule','lockRule')),old[key])
            self.assertEqual(c.fields(rows['skullBash'])['power'],100);self.assertEqual(c.fields(rows['skullBash'])['pp'],15)
            self.assertEqual(c.fields(rows['petalDance'])['targetId'],8);self.assertIs(c.fields(rows['petalDance'])['contact'],True)
            self.assertEqual(generate(text,p),text)
    def test_current_deletion_wrong_rule_type_and_power_pp_payload_mutants_reject(self):
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);text=generate(prior(),p)
            for key,(field,value)in RULES.items():
                for before,after in [(', '+field+' = "'+value+'"',''),(field+' = "'+value+'"',field+' = "wrong"'),(field+' = "'+value+'"',field+' = true')]:
                    with self.subTest(key=key,change=(before,after)),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(text.replace(before,after,1),p)
            for before,after in [('power = 100','power = 130'),('pp = 15','pp = 10'),('targetId = 8','targetId = 10'),('lockRule = "rampage"','lockRule = "rampage", effects = { NoEffect() }')]:
                with self.subTest(change=(before,after)),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(text.replace(before,after,1),p)
    def test_complete_source_epoch_requires_all_three_rules_and_preserves_original_hashes(self):
        text=(ROOT/'Source/battle/moves.lua').read_text();rows=c.read_rows(text);epoch=c.producer_epoch(text);self.assertEqual(epoch,13)
        for key,(field,value)in RULES.items():
            changed=dict(rows);changed[key]=c.drop_fields(rows[key],(field,))
            with self.subTest(key=key),self.assertRaisesRegex(ValueError,'producer metadata'):c.legacy_rows(changed,epoch)
        self.assertEqual(c.digest(json.dumps(c.legacy_rows(rows,epoch),sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
