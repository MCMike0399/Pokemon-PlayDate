"""Real producer preservation failures on actual production rows; no network/SDK."""
import importlib.util,json,re,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from tools import move_producer_contract as contract
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('preservation_generator',ROOT/'tools/generate_gen5_data.py');gen=importlib.util.module_from_spec(spec);spec.loader.exec_module(gen)
KEYS=('tackle','poisonSting','guillotine','sandstorm','thunderWave','growl')
def fixture():
    def row(id,key,type,category,power,accuracy,pp,target):return {'id':str(id),'identifier':key,'type_id':str(type),'damage_class_id':str(category),'power':str(power),'accuracy':str(accuracy),'pp':str(pp),'target_id':str(target),'priority':'0','effect_chance':'','generation_id':'1'}
    def meta(id,ailment=0,chance=0):return {'move_id':str(id),'meta_ailment_id':str(ailment),'ailment_chance':str(chance),'flinch_chance':'0','stat_chance':'0','healing':'0','drain':'0','min_hits':'','max_hits':''}
    return {'moves':[row(33,'tackle',1,2,50,100,35,10),row(40,'poison-sting',4,2,15,100,35,10),row(12,'guillotine',1,2,0,30,5,10),row(201,'sandstorm',6,1,0,0,10,12),row(86,'thunder-wave',13,1,0,100,20,10),row(45,'growl',1,1,0,100,40,11)],'move_changelog':[],
            'move_meta':[meta(40,5,30),meta(86,1)],'move_meta_stat_changes':[{'move_id':'45','stat_id':'2','change':'-1'}],
            'types':[{'id':'1','identifier':'normal'},{'id':'4','identifier':'poison'},{'id':'6','identifier':'rock'},{'id':'13','identifier':'electric'}]}
def production():
    allrows=contract.read_rows((ROOT/'Source/battle/moves.lua').read_text())
    return '\n'.join('    '+key+' = '+allrows[key]for key in KEYS)+'\n'
def generate(text,output,source):
    source.write_text(text)
    with patch.object(gen,'MOVES_INPUT',str(source)),patch.object(gen,'MOVES_LUA',str(output)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(fixture(),True)
class ProducerPreservationTests(unittest.TestCase):
    def rejects(self,old,new):
        text=production();self.assertIn(old,text)
        with tempfile.TemporaryDirectory()as tmp:
            root=Path(tmp);output=root/'output.lua';output.write_text('PREEXISTING OUTPUT MUST SURVIVE')
            with self.assertRaisesRegex(ValueError,'unexpected changes'):generate(text.replace(old,new,1),output,root/'input.lua')
            self.assertEqual(output.read_text(),'PREEXISTING OUTPUT MUST SURVIVE')
    def test_actual_rows_reproduce_exactly(self):
        with tempfile.TemporaryDirectory()as tmp:
            root=Path(tmp);generate(production(),root/'out.lua',root/'input.lua')
            self.assertEqual(contract.read_rows((root/'out.lua').read_text()),contract.read_rows(production()))
    def test_wrong_already_present_target_contact_secondary_ohko_type_immunity_reject(self):
        for before,after in [('targetId = 10','targetId = 7'),('contact = true','contact = false'),('hasSecondary = true','hasSecondary = false'),('ohko = true','ohko = false'),('typeImmunity = true','typeImmunity = false')]:
            with self.subTest(field=before):self.rejects(before,after)
    def test_current_epoch_metadata_removal_rejects(self):
        for before in (', contact = true',', contact = false',', hasSecondary = true',', ohko = true',', typeImmunity = true',', targetId = 10'):
            with self.subTest(field=before):self.rejects(before,'')
        recover=contract.read_rows((ROOT/'Source/battle/moves.lua').read_text())['recover']
        self.assertFalse(contract.compatible('recover',contract.drop_fields(recover,('targetId',)),recover,contract.metadata()['recover'],epoch=1))
    def test_unknown_scalar_and_power_pp_type_mutations_reject(self):
        for before,after in [('power = 50','power = 51'),('pp = 35','pp = 34'),('type = "normal"','type = "water"'),('power = 50','power = 50, surprise = 1'),('targetId = 11','targetId = true')]:
            with self.subTest(field=before):self.rejects(before,after)
    def test_owned_secondary_chance_status_target_and_extra_effect_reject(self):
        for before,after in [('Chance(30)','Chance(31)'),('"poison"','"burn"'),('SecondaryEffect(DEFENDER','SecondaryEffect(ATTACKER'),('ApplyStatus(DEFENDER, "poison")','ApplyStatus(DEFENDER, "poison"), DirectDamage(DEFENDER, 1)')]:
            with self.subTest(payload=before):self.rejects(before,after)
    def test_owned_ohko_and_weather_payloads_reject_even_exact_legacy_reintroduction(self):
        for before,after in [('ohko = true','ohko = true, effects = { DirectDamage(DEFENDER, 1) }'),('ohko = true','ohko = true, effects = { DirectDamage(DEFENDER, CurrentHPOf(DEFENDER)) }'),('SandstormEffect()','MudSportEffect()'),('effects = { SandstormEffect() }','effects = { }')]:
            with self.subTest(payload=after):self.rejects(before,after)
    def test_original_early_combat_hashes_are_not_updated(self):
        manifest=json.loads((ROOT/'tools/references/early-combat.json').read_text())
        self.assertEqual(manifest['original_scalars_sha256'],'888e16018e3e58593bf2a608309f85fb483a3b6c85af8f44dfc36a69bc966ca6')
        self.assertEqual(manifest['unchanged_rows_sha256'],'56de9c3ad26dd413935390799afa87680138c335067786f8eb18b721f820206c')
        self.assertEqual(manifest['candidate_rows_sha256'],'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
        rows=contract.read_rows((ROOT/'Source/battle/moves.lua').read_text());lowered=contract.legacy_rows(rows,contract.producer_epoch((ROOT/'Source/battle/moves.lua').read_text()))
        encoded=json.dumps(lowered,sort_keys=True,separators=(',',':')).encode();self.assertEqual(contract.digest(encoded),manifest['candidate_rows_sha256'])
    def test_reference_exact106_typed_transitions_and_primary_pins(self):
        value=contract.load_contract();entries=[e for es in value['transitions'].values()for e in es];self.assertEqual(sum(e['version']==1 for e in entries),106);self.assertEqual(value['counts'],{'typed-secondary':99,'ohko-dispatch':4,'weather-producer':3})
        self.assertEqual([k for k,es in value['transitions'].items()if any(e['version']==2 for e in es)],['focusEnergy'])
        self.assertEqual(value['metadata_artifact_sha256'],contract.META_SHA256)
        self.assertEqual(value['source_revision'],'9b136a8c8cdb860a8ab96fa063f906604e352547')
        self.assertEqual(len(value['source_sha256']),5)
    def test_contract_tampering_and_duplicate_rows_fail(self):
        with tempfile.TemporaryDirectory()as tmp:
            root=Path(tmp);path=root/'tools/references';path.mkdir(parents=True)
            (path/'move-producer-migrations.json').write_text('{}')
            with patch.object(contract,'ROOT',root):
                with self.assertRaisesRegex(ValueError,'checksum'):contract.load_contract()
        rows=production();line=rows.splitlines()[0]
        with self.assertRaisesRegex(ValueError,'duplicate'):contract.read_rows(rows+line+'\n')
if __name__=='__main__':unittest.main()
