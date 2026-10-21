"""Declared v2 producer migration; synthetic literal inputs, actual checked-in rows."""
import json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen,ROOT
KEYS=('razorLeaf','focusEnergy','stormThrow')
NONZERO=('karateChop','razorWind','razorLeaf','skyAttack','crabhammer','slash','crossChop','blazeKick','airCutter','leafBlade','nightSlash','shadowClaw','psychoCut','crossPoison','stoneEdge','drillRun')
def fixture():
    def move(id,key,type,category,power,accuracy,pp,target):return dict(id=str(id),identifier=key,type_id=str(type),damage_class_id=str(category),power=str(power),accuracy=str(accuracy),pp=str(pp),target_id=str(target),priority='0',effect_chance='',generation_id='1')
    def meta(id,crit):return dict(move_id=str(id),crit_rate=str(crit),meta_ailment_id='0',ailment_chance='0',flinch_chance='0',stat_chance='0',healing='0',drain='0',min_hits='',max_hits='')
    return dict(moves=[move(75,'razor-leaf',12,2,55,95,25,11),move(116,'focus-energy',1,1,0,0,30,7),move(480,'storm-throw',2,2,40,100,10,10)],move_changelog=[],move_meta=[meta(75,1),meta(116,0),meta(480,6)],move_meta_stat_changes=[],types=[dict(id='12',identifier='grass'),dict(id='1',identifier='normal'),dict(id='2',identifier='fighting')])
def legacy():
    rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())
    return '-- move-producer-contract: 1\n'+'\n'.join('    '+k+' = '+c.drop_fields(rows[k],('critStage','effects'))for k in KEYS)+'\n'
def generate(text,folder,data=None):
    src=folder/'input.lua';out=folder/'output.lua';src.write_text(text)
    with patch.object(gen,'MOVES_INPUT',str(src)),patch.object(gen,'MOVES_LUA',str(out)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(data or fixture(),True)
    return out.read_text()
class CriticalProducerTests(unittest.TestCase):
    def test_declared_focus_and_stage_migrate_from_complete_epoch1_and_are_idempotent(self):
        with tempfile.TemporaryDirectory()as tmp:
            folder=Path(tmp);text=generate(legacy(),folder);rows=c.read_rows(text)
            self.assertEqual(c.fields(rows['razorLeaf'])['critStage'],1)
            self.assertEqual(c.payload(rows['focusEnergy']),{'effects':['FocusEnergyEffect ( )'],'secondaries':[]})
            self.assertIs(c.fields(rows['stormThrow'])['willCrit'],True);self.assertNotIn('critStage',c.fields(rows['stormThrow']))
            self.assertIn('self.critStage = m.critStage or 0',text)
            self.assertEqual(generate(text,folder),text)
    def test_current_epoch_missing_wrong_or_legacy_effect_and_critical_metadata_reject(self):
        with tempfile.TemporaryDirectory()as tmp:
            folder=Path(tmp);text=generate(legacy(),folder)
            for old,new in [('critStage = 1','critStage = 2'),(', critStage = 1',''),('critStage = 1','critStage = true'),('critStage = 1','critStage = 6'),('effects = { FocusEnergyEffect() }','effects = { }'),('FocusEnergyEffect()','NoEffect()'),(', contact = false',''),(', targetId = 7','')]:
                with self.subTest(mutation=(old,new)):
                    with self.assertRaisesRegex(ValueError,'unexpected changes'):generate(text.replace(old,new,1),folder)
    def test_invalid_source_stage_and_unexpected_forced_marker_reject(self):
        with tempfile.TemporaryDirectory()as tmp:
            folder=Path(tmp)
            for rate in (5,6,-1):
                data=fixture();data['move_meta'][0]['crit_rate']=str(rate)
                with self.subTest(rate=rate):
                    with self.assertRaisesRegex(ValueError,'critical stage|forced-crit'):generate(legacy(),folder,data)
    def test_exact_sixteen_primary_critical_entries_and_separate_focus_contract(self):
        value=c.load_contract();self.assertEqual(value['critical']['nonzero'],dict.fromkeys(NONZERO,1))
        self.assertEqual(value['critical']['forced_marker'],{'stormThrow':6})
        self.assertEqual(value['critical']['move_meta_sha256'],'93b92d5bddf4fc1536ca0a647c20453bf92e6389010f33ca6fc4c5e9c54363be')
        entries=value['transitions']['focusEnergy'];self.assertEqual(len(entries),1)
        self.assertEqual(entries[0]['version'],2);self.assertEqual(entries[0]['before'],{'effects':[],'secondaries':[]})
        self.assertEqual(entries[0]['after'],{'effects':['FocusEnergyEffect ( )'],'secondaries':[]})
if __name__=='__main__':unittest.main()
