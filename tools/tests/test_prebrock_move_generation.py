"""Bounded v3 migration and rejection mutants on real current move rows."""
import tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen,ROOT
KEYS=('electroBall','assurance','endeavor','suckerPunch','ragePowder','sweetScent')
EXPECTED={'electroBall':('powerRule','electroBall'),'assurance':('powerRule','assurance'),'endeavor':('damageRule','endeavor'),'suckerPunch':('attemptRule','suckerPunch'),'ragePowder':('attemptRule','singlesRedirect')}
def fixture():
    vectors=[(486,'electro-ball',13,3,0,100,10,10,0),(372,'assurance',17,2,50,100,10,10,0),(283,'endeavor',1,2,0,100,5,10,0),(389,'sucker-punch',17,2,80,100,5,10,1),(476,'rage-powder',7,1,0,0,20,7,3),(230,'sweet-scent',1,1,0,100,20,11,0)]
    moves=[dict(zip(('id','identifier','type_id','damage_class_id','power','accuracy','pp','target_id','priority'),map(str,row)),effect_chance='',generation_id='1')for row in vectors]
    meta=[dict(move_id=str(row[0]),crit_rate='0',meta_ailment_id='0',ailment_chance='0',flinch_chance='0',stat_chance='0',healing='0',drain='0',min_hits='',max_hits='')for row in vectors]
    return dict(moves=moves,move_changelog=[],move_meta=meta,move_meta_stat_changes=[dict(move_id='230',stat_id='8',change='-2')],types=[dict(id=str(i),identifier=s)for i,s in [(1,'normal'),(7,'bug'),(13,'electric'),(17,'dark')]])
def old_rows():
    rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())
    return '-- move-producer-contract: 2\n'+'\n'.join('    '+key+' = '+c.drop_fields(rows[key],c.RULE_FIELDS).replace('ModifyStat(DEFENDER, "eva", -1)','ModifyStat(DEFENDER, "eva", -2)')for key in KEYS)+'\n'
def generate(text,folder):
    src=folder/'input.lua';out=folder/'output.lua';src.write_text(text)
    with patch.object(gen,'MOVES_INPUT',str(src)),patch.object(gen,'MOVES_LUA',str(out)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(fixture(),True)
    return out.read_text()
class PreBrockProducerTests(unittest.TestCase):
    def test_exact_five_rule_fields_and_gen5_evasion_correction_then_idempotence(self):
        with tempfile.TemporaryDirectory()as tmp:
            p=Path(tmp);new=generate(old_rows(),p);rows=c.read_rows(new)
            for key,(field,value)in EXPECTED.items():self.assertEqual(c.fields(rows[key])[field],value)
            self.assertEqual(c.payload(rows['sweetScent']),{'effects':['ModifyStat ( DEFENDER , "eva" , -1 )'],'secondaries':[]})
            self.assertEqual(c.fields(rows['electroBall'])['power'],0);self.assertEqual(c.fields(rows['endeavor'])['power'],0)
            self.assertEqual(c.fields(rows['suckerPunch'])['power'],80);self.assertEqual(c.fields(rows['assurance'])['power'],50)
            self.assertEqual(generate(new,p),new)
    def test_each_current_rule_removal_wrong_value_and_wrong_type_is_rejected(self):
        with tempfile.TemporaryDirectory()as tmp:
            p=Path(tmp);new=generate(old_rows(),p)
            for key,(field,value)in EXPECTED.items():
                token=field+' = "'+value+'"'
                for replacement in ['',', '+field+' = "wrong"',', '+field+' = true']:
                    with self.subTest(key=key,replacement=replacement):
                        mutant=new.replace(', '+token,replacement,1)
                        with self.assertRaisesRegex(ValueError,'unexpected changes'):generate(mutant,p)
    def test_current_evasion_reversion_extra_payload_and_unrelated_scalars_reject(self):
        with tempfile.TemporaryDirectory()as tmp:
            p=Path(tmp);new=generate(old_rows(),p)
            for before,after in [('"eva", -1','"eva", -2'),('"eva", -1','"eva", -3'),('ModifyStat(DEFENDER, "eva", -1)','NoEffect()'),('power = 80','power = 79'),('pp = 20','pp = 19'),('power = 50','power = 50, unknownRule = true')]:
                with self.subTest(change=(before,after)),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(new.replace(before,after,1),p)
    def test_earlier_epoch_accepts_only_exact_declared_effect_pair(self):
        with tempfile.TemporaryDirectory()as tmp:
            p=Path(tmp)
            for mutant in [old_rows().replace('"eva", -2','"eva", -3'),old_rows().replace('power = 80','power = 79')]:
                with self.assertRaisesRegex(ValueError,'unexpected changes'):generate(mutant,p)
    def test_legacy_inverse_keeps_original_scalar_effect_oracles(self):
        rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text());lowered=c.legacy_rows(rows)
        import json
        self.assertEqual(c.digest(json.dumps(lowered,sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
